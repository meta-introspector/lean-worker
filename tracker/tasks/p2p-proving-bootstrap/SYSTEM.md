# Task: p2p-proving-bootstrap

- **Name:** p2p-proving-bootstrap
- **Priority:** P2
- **Area:** lean-worker
- **Status:** in_progress
- **Branch:** agent/p2p-proving-bootstrap
- **Worktree:** worktrees/p2p-proving-bootstrap
- **Created:** 2026-09-30

## Description
Wire kant rooms (transport) + control mesh (gossip) + bone offers (jobs) + gokujo (checker) + task-runner (agents) into a self-hosting p2p proving loop, then self-apply: use the network to rewrite and check the apps themselves until the proof engine lives in the browser

## Done
(append commits here as you land them)

## Components (existing, all live)

| Layer | Component | Where | Status |
|---|---|---|---|
| Transport | kant rooms (append-only logs, pass-gated) | `~/projects/pastebin-lean/server/relay.mjs` (CF worker) + `arist-kant relay` (Rust twin, `~/projects/arist/src/kant_relay/`) | deployed: kant-zk-relay.jmikedupont2.workers.dev |
| Gossip | control mesh (`/control/sync`, `/control/snapshot`, x-control-token) | `~/projects/twitterstorm/worktrees/lean-freetier-import/lib/control.mjs`, workerd :3318 | running |
| Jobs | bone offers (obligations.jsonl -> offers.jsonl -> results.jsonl) | `/mnt/data1/aristotle-merge/bones/`, bone-worker systemd (STATE_DIR=/var/lib/bone-worker) | running 21h, 417 knife failures = real proof holes |
| Checker | gokujo check knife | lean-worker minimal/ (Job.proveGoal, Protocol/Core.lean) | running |
| Agents | task-runner | `~/.local/bin/task-runner`, `~/dotagents/tasks/bone-*` | 5 bone tasks created |

## Wire-up (phase 1)

1. **job intake over kant**: bone-worker emits offers -> POST to kant room `jobs` (append-only). Agents subscribe.
2. **proof transport over kant**: proved results (results.jsonl entries) -> POST to kant room `proofs:<project>`. Room name = digest of secret (zk pastebin model).
3. **gossip for discovery**: control mesh `/control/sync` carries room registry + peer health; `/control/snapshot` for catch-up.
4. **arist-kant as Rust twin**: same relay protocol in Rust (`arist-kant relay`) so the mesh is not CF-worker-only. Each service gets a Cloudflare p2p twin.
5. **task-runner as agent pool**: bone-* tasks in ~/dotagents/tasks are the agent-side queue; summaries flow back through results.jsonl -> kant `proofs` rooms.

## Self-application (phase 2)

Use the p2p network to rewrite and check the apps themselves:
- relay.mjs, control.mjs, bone-worker, arist-kant each get obligations extracted (bones) and proved via the same loop.
- The loop rewrites its own transport in Lean (Protocol/Core.lean Job.proveGoal is the seed) — system rewrites itself many times.
- Target: entire proof engine lives in the browser (CF Pages + worker twin), self-improving via proved rewrites.

## Verification
- phase 1: `curl -s localhost:3318/control/snapshot | jq .rooms` shows jobs + proofs rooms gossiped across peers
- phase 1: a bone offer round-trips: offers.jsonl -> kant room -> agent task -> results.jsonl -> proved
- phase 2: relay.mjs itself has bones in /mnt/data1/aristotle-merge/bones/ and a proved result

## Done
- 91f031c task created (component map + phases)
- 9ac84b8 offers-to-kant.mjs — bone offers -> kant jobs room, verified live on :8787 (10 offers round-trip)

## Next
- [ ] proofs return path: results.jsonl -> kant `proofs:<project>` room (mirror of step 1)
- [ ] control mesh room registry sync (:3318 /control/sync carries jobs/proofs room pointers)
- [ ] arist-kant relay smoke test against CF worker twin
- [ ] kant pass for bone-worker (rate limit: anonymous = 10 lines/10min)
- [ ] phase 2: extract bones from relay.mjs/control.mjs/bone-worker/arist-kant themselves (self-apply)
