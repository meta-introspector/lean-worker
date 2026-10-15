# lean-worker — Agent Conventions

## Objective
Lean4 worker infrastructure: the gokujo knife (proof checking), bone-worker
mesh (obligation claiming), Desk/DMZ modules, and the bridge to dotagents
task-runner. Aristotle proof obligations flow: bones → offers → knife →
agent tasks.

## Repo layout
- `minimal/` — the Lean4 workspace (lake) + node scripts. Most work happens here.
- `minimal/scripts/` — bone-worker.mjs, emit-offers.mjs, failed-to-taskrunner.mjs
- `minimal/gokujo` — compiled knife binary (gitignored; build via `lake build` / see GOKUJO.md)
- `tracker/` — THIS task system: tasks/, current-task.md, AGENTS.md
- `worktrees/` — per-task worktrees (gitignored; `scripts/new-task.sh` creates them)

## Priority
1. Close the bone proof loop (knife → agent → re-check)
2. Desk/DMZ module completion
3. Shared lake-cache tooling

## Worktree rules (like twitterstorm/tracker)
- NEVER work in the main checkout — one task = one worktree = one branch.
- `bash scripts/new-task.sh <name>` → creates `tracker/tasks/<name>/SYSTEM.md`
  + worktree `worktrees/<name>` on branch `agent/<name>`.
- Work the task, commit in the worktree, then update
  `tracker/current-task.md` and the task's SYSTEM.md status.
- Merge finished branches to `feature/gokujo-updates` (or main when stable).

## Git rules
- **NEVER run git as root.** The 2026-09-29 root session left .git
  root-owned and 152 mode-swept files (fixed 2026-09-30, commits 1106ae0,
  2b2907d, 501ffa1). If you see "Permission denied" on .git/index.lock,
  STOP — fix ownership, do not sudo around it.
- Conventional commits: `feat(scope):`, `fix(scope):`, `chore:`, `docs:`.
- Never commit compiled artifacts (minimal/gokujo, minimal/test, *.olean,
  .gokujo/ caches) — all gitignored.

## The knife (gokujo)
- `gokujo check <file>` = scan + graph + build + sorry + axioms as one gate.
  Exit 0 = clean.
- cwd MUST be the source file's directory (job paths resolved against cwd;
  .gokujo build cache lives in cwd — empirical, not documented).
- Failures print `has a hole` (sorry) or `trusts the evaluator` (axiom) —
  those are agent work, not infra failures.

## Bone pipeline
```
/mnt/data1/aristotle-merge/bones/<project>/obligations.jsonl
  → emit-offers.mjs → offers.jsonl
  → bone-worker.mjs (systemd bone-worker, STATE_DIR=/var/lib/bone-worker)
  → results.jsonl: proved | failed | quarantined
  → failed-to-taskrunner.mjs → ~/dotagents/tasks/bone-* (agent tasks)
```

## Verification
- `cd minimal && lake build` — workspace compiles
- `gokujo check <file>` exit 0 — proof clean
- `node minimal/scripts/failed-to-taskrunner.mjs` — dry-run bridge stats
