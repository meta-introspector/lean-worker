// room.mjs — per-room state for the OTC desk relay, and the invite check.
//
// Split out of the prototype worker so a Durable Object can own one RoomState
// per room. Everything here is the code that was already reviewed in
// worker-invite-test.mjs; the change is that it is now reachable from a module
// that lives longer than a request, rather than a Map rebuilt per request.
//
// State is in memory, deliberately. The relay is a dumb append-only mailbox:
// it holds a room while the room is happening, forgets it on the TTL, and
// keeps no archive. That is the same contract `server/relay.mjs` has always
// had (`this.map = new Map()`), and the same one `skills/kant-cli/SKILL.md`
// describes: the room is public and append-only, and *consumers* record it
// into their own sqlite and mesh-sync from there.
//
// So nothing here is written to Durable Object storage. A DO instance's memory
// is lost if the instance is evicted, and a lost room is a room whose history
// now lives only in the peers that synced it. If you need the relay to be an
// archive rather than a mailbox, that is a different design and it should be
// a deliberate one — an earlier version of this file did persist to DO storage
// and that commit (`b288abd`) reversed it.

// Defaults. A Worker has no `process`, and wrangler vars arrive on `env` inside
// fetch rather than at module scope, so these literals are the fallback and
// configFromEnv is what actually applies `[vars]`.
const CONFIG = {
  inviteRequired: true,

  gasLimitPerPeerPerHour: 1000000, // 1M gas units per peer per hour
  gasCostPerMessage: 1000,         // gas per message posted
  gasCostPerByte: 1,               // gas per byte of message data

  maxLine: 262144,                 // bytes in one line
  maxLines: 4096,                  // lines retained per room

  roomTTL: 6 * 60 * 60 * 1000,     // 6 hours
};

// No local `crypto` binding.
//
// There used to be a `const crypto = { subtle: {...} }` shim here. It was
// removed because declaring it shadowed the global `crypto` for this whole
// module, and a shim carrying only `subtle` silently removed every other
// member: `crypto.randomUUID()` became undefined and every POST that did not
// supply a peer-id failed with "crypto.randomUUID is not a function". The
// shim's own digest also recursed into itself. A Worker already has full
// WebCrypto on globalThis.crypto — the wrapper bought nothing and cost two
// bugs. Anything that needs the platform reaches it through globalThis.

function positive(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

// Apply wrangler [vars] over the defaults. One source of truth: the values the
// relay enforces are the same values /health reports and the same values the
// caller is charged against.
export function configFromEnv(env = {}) {
  return {
    ...CONFIG,
    inviteRequired: env.INVITE_REQUIRED === undefined
      ? CONFIG.inviteRequired
      : String(env.INVITE_REQUIRED) === "true",
    gasLimitPerPeerPerHour: positive(env.GAS_LIMIT_PER_PEER_PER_HOUR, CONFIG.gasLimitPerPeerPerHour),
    gasCostPerMessage: positive(env.GAS_COST_PER_MESSAGE, CONFIG.gasCostPerMessage),
    gasCostPerByte: positive(env.GAS_COST_PER_BYTE, CONFIG.gasCostPerByte),
    maxLine: positive(env.MAX_LINE, CONFIG.maxLine),
    maxLines: positive(env.MAX_LINES, CONFIG.maxLines),
    roomTTL: positive(env.ROOM_TTL_MS, CONFIG.roomTTL),
  };
}

// ── invite helpers ────────────────────────────────────────────────────────

// Hex SHA-256 of a UTF-8 string, lower case.
async function sha256Hex(text) {
  const bytes = new TextEncoder().encode(text);
  const digest = await globalThis.crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Length-independent equality for two hex digests. These values are not secret
// (a holder of the invite can recompute one), so this is about not
// short-circuiting on the first differing character, not about secrecy.
function timingSafeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// ── per-peer gas accounting ───────────────────────────────────────────────

class PeerState {
  constructor(peerId, inviteToken, config = CONFIG) {
    this.peerId = peerId || globalThis.crypto.randomUUID();
    this.inviteToken = inviteToken;
    this.config = config;
    this.windowStart = Date.now(); // start of the current gas hour
    this.gasUsed = 0;
    this.messageCount = 0;
    this.lastMessageAt = 0;
  }

  // Reset the gas counter once the hour is up. The prototype reset against
  // joinedAt, so a peer that joined at :59 got a fresh full budget a second
  // later; the window is anchored to when the budget was last refilled.
  rollWindow(now) {
    if (now - this.windowStart < 3600000) return;
    this.windowStart = now;
    this.gasUsed = 0;
  }

  hasGasAvailable(cost, now) {
    this.rollWindow(now);
    return this.gasUsed + cost <= this.config.gasLimitPerPeerPerHour;
  }

  consumeGas(cost, now) {
    if (!this.hasGasAvailable(cost, now)) {
      throw new Error("Peer gas limit exceeded");
    }
    this.gasUsed += cost;
    this.messageCount++;
    this.lastMessageAt = now;
  }
}

// ── room ──────────────────────────────────────────────────────────────────

class RoomState {
  constructor(config = CONFIG) {
    this.config = config;
    this.lines = [];
    this.base = 0;
    this.inviteHash = null; // SHA-256 of the room's invite, null until first join
    this.inviteRequired = config.inviteRequired;
    this.peers = new Map();    // peerId -> PeerState
    this.waiters = new Set();  // long-poll resumers
    this.lastTouch = Date.now();
  }

  get cursor() {
    return this.base + this.lines.length;
  }

  // ── invite ─────────────────────────────────────────────────────────────

  // Verify an invite token for a room.
  //
  // The relay names a room from the URL path and never learns the secret that
  // produced that name, so this cannot be a witness check the way kant-net.mjs
  // does it. What it CAN do is make the invite a shared capability: the first
  // peer to join sets the room's invite hash, and every later peer must
  // present an invite hashing to the same value.
  //
  // What this guarantees: a peer that does not hold the room's invite cannot
  // join or post. That is what was missing — the previous check accepted any
  // string of length >= 8.
  //
  // What this does NOT guarantee, stated plainly so nobody upgrades the claim:
  //   * it is trust-on-first-use. Whoever reaches an empty room first sets it.
  //     An attacker who can create the room first owns it.
  //   * it is a shared room secret, not an identity. Every holder of the
  //     invite has identical rights; there are no tiers and no revocation.
  //   * it does not bind a peer id to an invite. A leaked invite is a leaked
  //     key, and rotating it invalidates every current holder at once.
  //
  // A per-peer tier system needs a real keypair and signature check, which is a
  // design decision, not a patch. Until then the binding is INVITE_REQUIRED and
  // this is what enforces it.
  async verifyInvite(inviteToken) {
    if (!this.inviteRequired) return true;
    if (!inviteToken || typeof inviteToken !== "string" || !inviteToken.length) return false;

    const hash = await sha256Hex(inviteToken);
    if (this.inviteHash === null) {
      this.inviteHash = hash; // first joiner defines this room's invite
      return true;
    }
    return timingSafeEqual(hash, this.inviteHash);
  }

  async addPeer(peerId, inviteToken) {
    // verifyInvite is async (SHA-256 via crypto.subtle), so this is too —
    // every caller must await it. The prototype had call sites that did not,
    // which is why the check looked present and was not.
    if (!(await this.verifyInvite(inviteToken))) {
      throw new Error("Invalid or missing invite");
    }

    let peer = this.peers.get(peerId);
    if (!peer) {
      peer = new PeerState(peerId, inviteToken, this.config);
      this.peers.set(peerId, peer);
    }
    return peer;
  }

  removePeer(peerId) {
    this.peers.delete(peerId);
  }

  // ── messages ───────────────────────────────────────────────────────────

  post(newLines, peerId) {
    const peer = this.peers.get(peerId);
    if (!peer) throw new Error("Peer not in room");

    const now = Date.now();
    let gasCost = this.config.gasCostPerMessage;
    for (const line of newLines) gasCost += line.length * this.config.gasCostPerByte;

    if (!peer.hasGasAvailable(gasCost, now)) {
      throw new Error("Peer gas limit exceeded");
    }

    const maxLines = this.config.maxLines;
    if (this.lines.length + newLines.length > maxLines) {
      const drop = this.lines.length + newLines.length - maxLines;
      this.base += drop;
      this.lines.splice(0, drop);
    }
    this.lines.push(...newLines);
    this.lastTouch = now;
    peer.consumeGas(gasCost, now);

    for (const waiter of [...this.waiters]) {
      this.waiters.delete(waiter);
      waiter();
    }
  }

  fetch(cursor) {
    const from = Math.max(cursor, this.base);
    const end = this.cursor;
    return {
      cursor: end,
      lines: this.lines.slice(from - this.base),
      truncated: cursor < this.base,
    };
  }

  wait(ms) {
    return new Promise((resolve) => {
      const wake = () => {
        clearTimeout(timeout);
        this.waiters.delete(wake);
        resolve(this.fetch(this.cursor));
      };
      const timeout = setTimeout(() => {
        this.waiters.delete(wake);
        resolve(this.fetch(this.cursor));
      }, ms);
      this.waiters.add(wake);
    });
  }

  expired(now = Date.now()) {
    return now - this.lastTouch > this.config.roomTTL;
  }
}

export { CONFIG, PeerState, RoomState, sha256Hex, timingSafeEqual };