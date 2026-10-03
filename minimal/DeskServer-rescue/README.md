# OTC Desk — rescued source

Provenance and status of the OTC Proof Trading Desk. Everything here was
recovered on 2026-10-03 from locations that were about to be lost or that
nobody could find. Read the **Known defects** section before deploying any of
it — one of the defects is a live security hole in code already uploaded to
Cloudflare production.

## What this is

Two halves of one desk:

| Piece | File | Runs on | Port |
|---|---|---|---|
| Local relay | `desk-relay.mjs` | this box | 8788 |
| Edge relay | `worker/worker.js` + `worker/room.mjs` | Cloudflare Workers | — |

The relay is the desk proper: an append-only log per room (inheriting the
kant-zk rendezvous design) plus quote/ticket/escrow endpoints, with a
hand-rolled RFC 6455 WebSocket server so a browser can stream instead of poll.
It has **zero dependencies** — Node's own `http` plus a small WebSocket
implementation.

The worker mirrors the relay at the Cloudflare edge. It exists so peers can
reach the desk from outside the local network. As of 2026-10-03 it implements
the room log and the invite/gas rules; the `/desk/*` quote/ticket/escrow
surface and the WebSocket stream are still local-only.

## Layout

```
desk-relay.mjs              576 lines — the relay (zero deps)
web/desk.html               136 lines — the entire frontend
worker/worker.js                      Cloudflare router + `Room` Durable Object
worker/room.mjs                       room state, invite check, gas, serialization
worker/worker-invite-test.mjs          9 invite assertions
worker/worker-room-test.mjs          19 durability + enforcement assertions
worker/live-pb22-test.sh              the same assertions against a deployed worker
worker/wrangler.toml                  worker name, DO binding, [vars]
worker/package.json                  test script (see defects)
relay.log.2026-09-29                 last observed runtime log
relay.out.2026-09-29                 startup banner + routes, from the last run
```

`relay.out` is kept because it is the authoritative record of the route
surface — it was the only place the full API was written down.

## Where it came from

| Now | Was | Risk |
|---|---|---|
| `desk-relay.mjs`, `web/desk.html` | `minimal/DeskServer/` in this repo | **untracked**, in a tree owned by the `otc-desk` user |
| `worker/*` | `/mnt/data1/tmp/otc-desk-worker/` | shared scratch dir, 1016 entries, 1415 files touched since Oct 1 |
| `relay.log*`, `relay.out*` | `/mnt/data1/tmp/` | same |

The worker had no version-controlled home at all. The relay source sat
untracked in a repo with unrelated uncommitted work, so it was one `git clean`
from gone.

Copies were verified byte-identical at the time of the rescue (`worker.js`
md5 `951140c3fc3a4ea4144e93480e433c7a`) and all files pass `node --check`.

**Since then, `worker/worker.js` has been rewritten** — it is no longer the
rescued bytes. See defect 6; the rescue tree is now the home of the working
relay, not a snapshot of the broken one.

### Note on the original location

`minimal/DeskServer/` was **not** modified. It is owned by `otc-desk` (uid 938)
and is not writable by `mdupont`, so this rescue is a copy rather than a move.
The originals are still in place and are the same bytes; reconciling the two
is an open decision, not something to do by accident.

## Running it

```bash
# relay — defaults to 0.0.0.0:8787 per its own usage string; pass --port 8788
# to match the nginx config in system-manager/nginx/otc-desk.conf
node desk-relay.mjs --port 8788 --static web

# worker — there is no build step; wrangler bundles worker.js and its import
# of room.mjs directly. The old `npm run build` was `cp worker.js dist/`, which
# copied one file and would have shipped nothing else.
cd worker && npm test
npx wrangler deploy

# against a deployed worker
bash live-pb22-test.sh https://your-worker.workers.dev
```

Verified 2026-10-03: the relay boots and serves.

```
$ curl -s http://127.0.0.1:8799/health
{"ok":true,"name":"otc-desk-relay","version":"1.0.0","rooms":0,"lines":0,"sockets":0}
```

### Routes

```
POST /room/{room}                    append lines
GET  /room/{room}?cursor=N[&wait=S]  poll (long poll with wait)
WS   /ws/{room}?cursor=N             stream
GET  /desk/board                     get bounty board
POST /desk/quote                     request quote
POST /desk/ticket                    post trade ticket
POST /desk/escrow                    deposit into escrow
GET  /desk/escrow/{id}               get escrow state
POST /desk/approve/promote           approve layer promotion
GET  /desk/kb?q=                     query witnessed KB
GET  /health                         health check
```

The relay's own header documents two deliberate deviations from the proved
model, both about memory exhaustion rather than semantics: lines over
`--max-line` bytes are rejected 413, and a room holds at most `--max-lines`
lines and is forgotten after `--room-ttl` of silence. Cursors stay absolute; a
poll from a trimmed cursor gets `truncated: true`.

## Known defects

Ordered by how much damage they do if ignored.

### 1. FIXED — the worker's invite check accepted any 8 characters

The original `worker/worker.js` contained:

```js
// Simplified invite verification:
// In reality, this would check that the invite token
// corresponds to the room secret via witness function
// For demo, we accept any non-empty invite as valid
return inviteToken.length >= 8;
```

That build is what was uploaded to the **production** environment of
`otc-desk-relay` (`cf:environment=production`, `workers/triggered_by: upload`
in the stored settings), and it ships `corsOrigin: "*"`. So the deployed
worker granted unauthenticated room access while its bindings asserted
`INVITE_REQUIRED=true`.

The assertion was the problem as much as the check: config claimed a
protection the code did not implement, which is what made this invisible.

Fixed in two steps. First (`d749d19`) `inviteToken.length >= 8` became a
SHA-256 shared capability and all five `addPeer`/`verifyInvite` call sites
were awaited. That was still not enough — see defect 6. As of the Durable
Object rewrite the check is real and enforced end to end.

**What the invite is now**, stated plainly so the claim is not upgraded:

- The first peer to reach an empty room **sets** that room's invite hash;
  every later peer must present an invite hashing to the same value.
- It is a **shared room secret, not an identity**. Every holder has identical
  rights. There are no tiers and no revocation.
- It is **trust-on-first-use**. An attacker who creates the room first owns
  it. Room names are chosen by the caller, so this is not a small caveat.
- A leaked invite is a leaked key. Rotating it invalidates every holder at
  once.

A per-peer tier system needs a real keypair and signature check. That is a
design decision, not a patch.

### 2. FIXED — `npm test` could not fail

```json
"test": "echo 'Tests passed'"
```

The entire test suite. Nothing was ever tested, and `npm run build` was a
`cp`, so `dist/worker.js` was a byte-for-byte copy of the source — which is
why an untested build went straight to production.

Now `npm test` runs 28 real assertions across two files and exits non-zero
when any fails. This was verified, not assumed: breaking one assertion makes
the script exit 1.

### 3. The relay is down

Nothing has listened on 8788 since 2026-09-29. `relay.log.2026-09-29` shows two
`/health` probes ten minutes apart and then nothing.

Consequently every nginx route in `system-manager/nginx/otc-desk.conf`
(`/desk/`, `/ws/`, `/room/`) proxies to a dead backend. Note also that it
defines a **global** `location = /health`, so `/health` on the whole server
resolves to the desk and fails while the desk is down.

### 4. `/var/lib/otc-desk` is empty

Owned by `otc-desk`, created 2026-09-28, never written. State was meant to live
there; the relay keeps state in memory instead, so it does not survive a
restart. Ownership is also split: the worker files are `mdupont`, the original
DeskServer tree is `otc-desk`.

### 5. No service unit for the relay

There are systemd units for the four deploy layers but **none** for the relay
itself, which is why it stopped and nothing brought it back. It is also not
covered by the build loop, which is broken anyway — see below.

### 6. FIXED — the worker had no state at all between requests

This is the defect the invite bug was a *symptom* of. The prototype did:

```js
addEventListener('fetch', e => e.respondWith(new OTCDeskHandler()…))
```

so every request constructed a fresh `OTCDeskHandler` with a fresh `Map`.
Rooms, lines, cursors, peer gas counters and the invite hash were all
discarded before the next request arrived. Live proof, before the rewrite:
two posts to one room both answered `cursor: 1`, and a read returned
`lines: []`. The invite check was correct code with nothing to compare
against.

State now lives in a **Durable Object per room** (`env.ROOMS.idFromName`),
the same pattern the sibling `kant-zk-relay-wasm` worker already used. The
room is held **in memory**, deliberately: the relay is a mailbox, not an
archive. It keeps a room while the room is happening, forgets it on the TTL,
and writes nothing to DO storage — the same contract `server/relay.mjs` has
always had (`this.map = new Map()`).

History is the consumers' business, which is the pattern
`skills/kant-cli/SKILL.md` already describes for fleet builds: "any sink can
record builds into sqlite and mesh-sync them." Peers sync lines out of the
room into their own sqlite. See `server/room-store.mjs` in the pastebin repo
for the peer-side replica.

**The trade, stated plainly:** because the relay keeps no archive, an evicted
DO instance loses that room and the only remaining copies are the peers that
synced it. `b288abd` had persisted rooms to DO storage; that was reverted
because it contradicts the mailbox model, not because it was wrong about
durable objects. If the relay should be an archive after all, that is a
deliberate design change and `worker-room-test.mjs` has a test
(`the relay keeps no archive: a fresh instance starts empty`) that is written
to fail when that happens, so the change cannot land unnoticed.

Two more bugs were found while testing the rewrite, both of the same kind —
something claimed to work while silently not doing it:

- **Config was duplicated.** `worker.js` and the state module each held their
  own `CONFIG`. The relay could enforce one gas limit while `/health` reported
  another. There is now one `configFromEnv(env)`, and `/health` reports what
  the relay actually enforces.
- **The router dropped the caller's query string.** `new Request(url, request)`
  takes the body and headers from the old request but builds a brand-new URL,
  so `cursor`, `wait` and `peer` never reached the room: reads ignored
  `cursor` and every read-only peer got a fresh random identity. Nothing
  errored — the arguments just stopped arriving. The router now carries the
  caller's parameters across, with `room` set from the path so a caller
  cannot override which room they are routed to.

### Deployed

The Durable Object relay is live at
`https://otc-desk-relay-v2.jmikedupont2.workers.dev`, with
`15 passed, 0 failed` from `worker/live-pb22-test.sh` against it — including
the exact sequence the prototype passed and should not have: posts with
invites `aaaaaaaa` / `bbbbbbbb` / `aaaaaaaa` now give 200 / **403** / 200 with
cursors 1 / — / 2.

Note the worker name: it is `otc-desk-relay-v2`, not `otc-desk-relay`. The
name `otc-desk-relay` lives in account `purple-fire-b881`, which the
available API token cannot reach. So the production worker named in defect 1
is **still unpatched** — this rewrite is not on it. See "Still missing".

## Related, and also broken

The `otc-desk-*` deploy pipeline is described in
`~/projects/otc-desk-services.md`. That document describes an intended design,
not a working system. Corrections as of 2026-10-03:

- **`otc-desk-sops` never decrypts anything.** It runs
  `deploy-cloudflare-worker.sh status`, whose body is two `wrangler` calls with
  stderr to `/dev/null` and `|| true` on everything — no `sops` call, and it
  cannot fail. It has reported success hourly while doing nothing.
- **`SOPS_CONFIG` points at a placeholder.** The unit sets it to
  `~/projects/system-manager/.sops.yaml`, which is a 4037-byte doc containing
  `age1xxxx…` and `ENC[…data:xxxxxx…]` and **no `creation_rules` key at all**.
- **`otc-desk-build` and `otc-desk-deploy` are in a hot-restart loop**
  (614 and 413 retries at time of writing), both dying `203/EXEC`: `nix` is not
  on the `mkForce`d `PATH`, and `deploy`'s `ExecStart` starts with `cd … &&`,
  which systemd tries to exec as a binary named `cd` rather than run in a shell.
- **`otc-desk-project` does not load** (`bad-setting`).

So nothing downstream of the sops layer has ever run.

## What is still missing

- **The production worker is still vulnerable.** `otc-desk-relay` on account
  `purple-fire-b881` is the build with the 8-character invite check. The API
  token available to this machine has no access to that account, so the fix
  cannot be deployed there from here. The patched relay is a *different*
  worker (`otc-desk-relay-v2`) on a different account.
- The Durable Object relay implements `/room/{room}` and `/health`. The
  `/desk/*` quote/ticket/escrow surface and the WebSocket endpoint exist only
  in the local `desk-relay.mjs` and have **not** been ported to the worker.
- Room state is in memory in the DO. There is no history beyond `MAX_LINES`,
  nothing is replicated, and an eviction loses the room. Peers must sync out
  what they need — the relay is not a backup.
- The invite check is trust-on-first-use and a shared secret, not per-peer
  identity. See defect 1.
- The escrow and KB endpoints have no persistence or backing store — they read
  and write in-memory state that a restart discards.
- The relay's WebSocket server is hand-rolled; no fuzzing or protocol test
  coverage.
- No reconciliation between this copy and `minimal/DeskServer/`.
- The Cloudflare API token is now stored via sops (see
  `~/projects/system-manager/scripts/sops-*.sh` and `docs/SOPS.md`), so that
  last item from the original list is resolved.