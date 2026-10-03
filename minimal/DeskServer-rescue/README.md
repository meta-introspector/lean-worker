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
| Edge bridge | `worker/worker.js` | Cloudflare Workers | — |

The relay is the desk proper: an append-only log per room (inheriting the
kant-zk rendezvous design) plus quote/ticket/escrow endpoints, with a
hand-rolled RFC 6455 WebSocket server so a browser can stream instead of poll.
It has **zero dependencies** — Node's own `http` plus a small WebSocket
implementation.

The worker mirrors the relay at the Cloudflare edge, bridging rooms and
proxying `/desk/*`. It exists so peers can reach the desk from outside the
local network.

## Layout

```
desk-relay.mjs              576 lines — the relay (zero deps)
web/desk.html               136 lines — the entire frontend
worker/worker.js            799 lines — Cloudflare edge bridge
worker/wrangler.toml                  worker name + bindings
worker/package.json                  build/test scripts (see defects)
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

Copies were verified byte-identical (`worker.js` md5
`951140c3fc3a4ea4144e93480e433c7a`) and both files pass `node --check`.

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

# worker
cd worker && npm run build     # cp worker.js dist/worker.js
npx wrangler deploy
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

### 1. The worker's invite check accepts any 8 characters

`worker/worker.js:107`:

```js
// Simplified invite verification:
// In reality, this would check that the invite token
// corresponds to the room secret via witness function
// For demo, we accept any non-empty invite as valid
return inviteToken.length >= 8;
```

This build is what was uploaded to the **production** environment of
`otc-desk-relay` (`cf:environment=production`, `workers/triggered_by: upload`
in the stored settings), and it ships `corsOrigin: "*"`. So the deployed
worker grants unauthenticated room access while its bindings assert
`INVITE_REQUIRED=true`.

The assertion is the problem as much as the check: config claims a protection
the code does not implement, which is what made this invisible.

**Fix before any re-deploy.** Either implement real invite verification or stop
claiming it in the bindings.

### 2. `npm test` cannot fail

```json
"test": "echo 'Tests passed'"
```

The entire test suite. Nothing was ever tested, and `npm run build` is a `cp`,
so `dist/worker.js` is a byte-for-byte copy of the source — which is why an
untested build went straight to production.

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

- The escrow and KB endpoints have no persistence or backing store — they read
  and write in-memory state that a restart discards.
- The relay's WebSocket server is hand-rolled; no fuzzing or protocol test
  coverage.
- No reconciliation between this copy and `minimal/DeskServer/`.
- The Cloudflare API token needed to deploy the worker was never entered —
  `.sops/credentials.sops.yaml` is a plaintext template with empty values. This
  is separate from every issue above.