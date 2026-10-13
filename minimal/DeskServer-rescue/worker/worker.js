// otc-desk-relay-v2 — OTC Proof Trading Desk relay.
//
// This is the stateful rewrite of the prototype. The prototype kept its state
// in a plain Map on an OTCDeskHandler built fresh inside the fetch listener:
//
//     addEventListener('fetch', e => e.respondWith(new OTCDeskHandler()…))
//
// so every request started from an empty map. Rooms, lines, cursors, peer gas
// counters and the invite hash were all discarded before the next request
// arrived. Two posts to one room both answered `cursor: 1` and a read returned
// `lines: []`. The invite check was correct code that never had anything to
// compare against — not a broken check, a check with no room behind it.
//
// State now lives in a Durable Object per room, which is what the sibling
// worker (kant-zk-relay-wasm) already does with its ROOMS binding. Routing is
// by room name via idFromName, so every peer of a room reaches the same
// instance and the same RoomState.
//
// A DO instance is also in memory and can be evicted, and this room is NOT
// written back to DO storage. The relay is a mailbox, not an archive: it holds
// a room while the room is happening and forgets it on the TTL, exactly like
// `server/relay.mjs` has always done. History is the consumers' business —
// they sync lines out of the room into their own sqlite and mesh from there.

import { RoomState, configFromEnv } from "./room.mjs";

// ── per-room Durable Object ────────────────────────────────────────────────

export class Room {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.config = configFromEnv(env);
    // idFromName is deterministic on the room name, so every request routed to
    // this instance gets the same RoomState. That is the whole fix: the
    // prototype rebuilt an empty one per request.
    this.room = new RoomState(this.config);
  }

  async fetch(request) {
    const room = this.room;

    const url = new URL(request.url);
    const name = url.searchParams.get("room") ?? "";
    const peerId =
      request.headers.get("peer-id") ||
      url.searchParams.get("peer") ||
      globalThis.crypto.randomUUID();
    const inviteToken =
      request.headers.get("invite-token") || url.searchParams.get("invite");

    const json = (body, status = 200) =>
      new Response(JSON.stringify(body), {
        status,
        headers: {
          "content-type": "application/json",
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET, POST, OPTIONS",
          "access-control-allow-headers": "content-type, invite-token, peer-id",
        },
      });

    if (request.method === "OPTIONS") return json({ ok: true }, 204);
    if (!name) return json({ ok: false, error: "no room", type: "no_room" }, 400);

    try {
      if (request.method === "POST") {
        const body = await request.text();
        const lines = body.split("\n").map((l) => l.trim()).filter(Boolean);
        if (lines.some((l) => l.length > this.config.maxLine)) {
          return json({ ok: false, error: "line too long", type: "line_too_long" }, 413);
        }

        // addPeer awaits verifyInvite, so a wrong invite throws here and is
        // reported as 403 below. This is the check the bindings claim.
        await room.addPeer(peerId, inviteToken);
        room.post(lines, peerId);
        return json({
          ok: true,
          cursor: room.cursor,
          accepted: lines.length,
          peerId,
          gasUsed: room.peers.get(peerId)?.gasUsed ?? 0,
          gasLimit: this.config.gasLimitPerPeerPerHour,
        });
      }

      if (request.method === "GET") {
        const cursor = Number(url.searchParams.get("cursor") ?? 0) || 0;
        const wait = Math.min(Math.max(Number(url.searchParams.get("wait") ?? 0) || 0, 0), 60);

        // A peer that already holds an invite may read without re-joining.
        // A peer that does not must present the room's invite, so this is
        // enforced rather than assumed.
        if (!room.peers.has(peerId)) {
          if (!(await room.verifyInvite(inviteToken))) {
            return json({ ok: false, error: "invite required", type: "invite_invalid" }, 403);
          }
          await room.addPeer(peerId, inviteToken);
        }

        let out = room.fetch(cursor);
        if (wait > 0 && out.lines.length === 0) {
          out = await room.wait(wait * 1000);
        }
        return json({ ok: true, room: name, ...out });
      }

      return json({ ok: false, error: "method not allowed", type: "method_not_allowed" }, 405);
    } catch (err) {
      const m = String(err?.message ?? err);
      if (/invite/i.test(m)) return json({ ok: false, error: m, type: "invite_invalid" }, 403);
      if (/gas/i.test(m)) return json({ ok: false, error: m, type: "gas_limit_exceeded" }, 429);
      return json({ ok: false, error: m, type: "post_failed" }, 500);
    }
  }
}

// ── router ─────────────────────────────────────────────────────────────────
//
// No handler is constructed per request. Every request that names a room is
// forwarded to that room's Durable Object instance; /health is answered here
// because it needs no state.

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const config = configFromEnv(env);
    const h = {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET, POST, OPTIONS",
      "access-control-allow-headers": "content-type, invite-token, peer-id",
    };
    const json = (body, status = 200) =>
      new Response(JSON.stringify(body), { status, headers: { ...h, "content-type": "application/json" } });

    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: h });

    if (url.pathname === "/health") {
      return json({
        ok: true,
        name: "otc-desk-relay",
        version: "2.0.0",
        platform: "cloudflare",
        state: "durable-object per room, in memory, no archive",
        durable: false,
        archive: "consumers sync lines into their own sqlite",
        features: {
          inviteOnly: config.inviteRequired,
          inviteEnforced: true,
          gasLimit: true,
          gasLimitPerPeerPerHour: config.gasLimitPerPeerPerHour,
          maxLine: config.maxLine,
          maxLines: config.maxLines,
        },
      });
    }

    const m = url.pathname.match(/^\/room\/([^/]+)$/);
    if (m) {
      const roomName = decodeURIComponent(m[1]);
      const id = env.ROOMS.idFromName(roomName);
      // The DO cannot see the original path, so the room name travels as a
      // query parameter. That is the interlink: same name, same instance.
      //
      // The caller's own query string has to be carried over too. `new
      // Request(url, request)` takes the body and headers from the old request
      // but builds a brand-new URL, so anything the caller passed as a query
      // parameter — cursor, wait, peer — was silently dropped on the way in.
      // Reads ignored `cursor` and every read-only peer got a fresh random
      // identity. Nothing errored; the arguments just stopped arriving.
      const params = new URLSearchParams(url.search);
      params.set("room", roomName);
      return env.ROOMS.get(id).fetch(
        new Request(`https://room.internal/?${params}`, request),
      );
    }

    return json({ ok: false, error: "not found", type: "not_found", hint: "POST/GET /room/{room}" }, 404);
  },
};