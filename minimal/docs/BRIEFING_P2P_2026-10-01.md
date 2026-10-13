# Briefing: p2p campaign knowledge — 2026-10-01

What the twin learned today, in prose to accompany `minimal/AgentP2P.lean`
(formalized there; this document carries the narrative and the evidence).

## 1. The kant p2p webapp exists and is deployed

Built on pastebin-lean (branch `buffy/p2p-wasm-ipfs-20261001`, worktree
`~/projects/worktrees/buffy-p2p-wasm-20261001`, pushed to the kant-zk-pastebin
git mirror). Pieces: `web/kant-ipfs.mjs` (client-side CIDv1/raw addressing,
kubo add/cat with fallbacks, kzcid room records), `web/kant-p2p.mjs` (the
P2PApp: presence, publish/subscribe, dedupe, repin-to-kubo, experiment
dispatch), `web/p2p.html` (UI), `web/arist-wasm.mjs` (vendored aristotle-wasm
as the heavier experiment module), `scripts/build-arist-wasm.sh`,
`test/test-kant-p2p.mjs` (20 tests).

Deployed: `kant-p2p-relay.service` on 127.0.0.1:8796, exposed at
`https://solana.solfunmeme.com/p2p-relay/` via nginx strip-prefix + WS upgrade.
Deploy unit + nginx conf live in the branch's `deploy/`.

## 2. Verification tiers achieved (all green, 2026-10-01)

1. **Unit** — 20 node:test cases: CID shape (CIDv1/raw/sha2-256/base32),
   RFC4648 vectors (cross-checked against python b32encode), record
   envelopes, kubo/gateway-absent fallbacks, lying-gateway rejection,
   relay dedupe by CID, oversized-line refusal.
2. **Kernel golden** — the repo's existing 59 vectors against the
   Lean-extracted kernel still pass (we added code, broke nothing).
3. **Live two-peer** — two P2PApp instances through a real relay: publish →
   announce → fetch → verify → merge-cids → identical room digests.
4. **gui2proof** — two real Chromium browsers on Xvfb :99 through the TLS
   edge: join, publish (real CIDv1 `bafkrei…`), fetch + CID-verify,
   kernel `merge_cids` (`merged = 15731439230876154891` in that run),
   digests agree on both sides. Evidence: `e2e-out-p2p/` (8 screenshots +
   timeline.json) committed to the branch.

## 3. Facts the twin should reason with

- **CID parity rule**: for ≤ 256 KiB (one kubo chunk), the client-computed
  CID equals `kubo add --cid-version=1 --raw-leaves` — this is why
  client-side addressing is trustworthy.
- **Integrity is transport-independent**: every fetch re-verifies the CID
  over the bytes; a lying gateway or tampered room line is rejected.
- **Room line budget**: ≤ 60 KB per line (relay `--max-line` backstops);
  embedded fallbacks additionally capped at 256 KiB artifact size.
- **Relay honesty**: the kant-zk relay stores only a hash of the room name,
  never parses lines; pass-db auth is optional per deployment.
- **Edge pattern**: strip-prefix rewrite (aristo/tracker pattern) because the
  app derives its relay base from the page path — works at any mount point.
- **GUI testing stack repaired**: snapd + snapd.apparmor must be active for
  chromium to launch under playwright (`Target ... closed` errors mean this).

## 4. The Forgejo incident (mfng/tracker #209) — formalized as lessons

- Round 1: "twin" verification compared a path with ITSELF through a symlink
  loop; 250 repos self-deleted. Recovered 250/250 (112 mirror re-clones,
  135 empties, 1 surviving checkout relink, 2 stubs).
- Round 2: `~/.local/share/forgejo` → `/mnt/data1/forgejo` meant src == dst;
  ~1,051 more names self-deleted. DB-census-driven repair ran:
  483 empties re-inited, 543 mirrors re-cloned, 25 stubbed (no upstream URL).
- **Rules extracted** (in AgentP2P.lean §6): never migrate between
  same-directory endpoints (device:inode guard); verification must not
  follow symlinks when classifying "twins"; batch limits are blast-radius
  controls; interrupted operations leave partial states (HEAD-less bare
  dirs) that the resume path must classify.

## 5. What remains open (next learnings to seek)

- kubo CORS: browser publishes currently fall back to room transport
  (`via=room`); enabling kubo CORS upgrades them to `via=ipfs` pinning.
- IPFS pinning as a system-manager service; CAR-shmem integration for the
  dasl tile pipeline (ipld-car-ipc-shmem-linux) — the tiles the twin can
  already model.
- gui2proof scheduling: fold `scripts/p2p-gui-e2e.mjs --ffmpeg` into
  tracker-gui2proof.timer for recurring proofs.
