# OTC Proof Trading Desk — Implementation Notes

## Path/Version Pre-Fixes (settled before any code)

### 1. Stale `kant-relay.service` target
- **Before:** `WorkingDirectory=/mnt/data1/time-2026/05-may/07/arist/6f91c03d-87e8-4c6a-8d3f-de39edee2f6d`
- **After:** `WorkingDirectory=/home/mdupont/projects/pastebin-lean/server/`
- **ExecStart:** now points at the live `relay.mjs` in the live source tree.
- **ReadOnlyPaths:** narrowed to the live server dir (no longer the deleted arist path).
- File: `/etc/systemd/system/kant-relay.service`

### 2. Lean toolchain version split
- **Before:** `leanprover/lean4:v4.28.0` (in `minimal/lean-toolchain`)
- **After:** `leanprover/lean4:v4.29.1`
- Rationale: the DMZ formalization corpus at `lean-split-tool/dasl-verification/RequestProject/` (the structural prior art for the desk's `TypedDMZ`/`UmweltGodelTrust` layers) is built on `v4.29.1`. The desk's new modules must share the same kernel to import cleanly.
- File: `/mnt/data1/time-2026/09-september/18/lean-worker/minimal/lean-toolchain`

---

## Build Order (per plan §4)

| Step | File | Status |
|---|---|---|
| 1 | `minimal/Desk/Metameme.lean` | ✅ completed |
| 2 | `minimal/DMZ/Release.lean` | ✅ completed |
| 3 | `minimal/DMZ/Policy.lean` | ✅ completed |
| 4 | `minimal/Desk/Trade.lean` | ✅ completed |
| 5 | `minimal/Desk/Escrow.lean` | ✅ completed |
| 6 | `minimal/DMZ/Approval.lean` | ✅ completed |
| 7 | `minimal/DeskServer/` (Node relay + `/desk/*`) | ✅ completed |
| 8 | `minimal/DeskWeb/` (static GUI) | ✅ completed |
| 9 | `minimal/DeskDeploy/` (systemd + nginx + install.sh) | ✅ completed |
| 10 | `minimal/DeskKb/` (witness records + OeisSimilarity) | ✅ completed |
| 11 | Docs (`DESK.md`, `TRUST_BOUNDARY-DESK.md`, `LAYERS.md`) | ✅ completed |