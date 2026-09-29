# Gokujo Cut → Bones Session — 2026-09-28

The full arc of making `gokujo cut` real: stack-safe scanners with machine-checked
proofs, the corpus-carving `cut` command, independent validation of its output,
the bones generator for the launchpad, and the wiring into the proof-mesh protocol.

Repo: `lean-worker` (branch `feature/gokujo-updates`). Commits:
`697da2c` scanBlock TR, `7762da8` docs, `70feb29` checker, `354d1e5` watcher,
`40aa93e` emit-bones.

---

## 1. The proof: `scanBlockAux_eq`

**Problem.** `scanBlock` (block-comment scanner) consumed one C stack frame per
character. Any corpus file with a long `/- ... -/` comment crashed the compiled
binary with "Stack overflow detected". Bisection pinned the failure at 222–224
lines of comment — the `server_variant_*_Stdlib.lean` files in the corpus start
a ~200-line doc block right there.

**Fix.** `scanBlockAux : Nat → List Char → List Char → List Char × List Char`,
an accumulator twin, plus `scanBlockTR d cs := scanBlockAux d cs []` and
`@[csimp] scanBlock_eq_scanBlockTR` so the compiled binary uses the twin.

**The proof that worked** (after ~60 probe files in `/tmp/fi_p*.lean`):

```lean
theorem scanBlockAux_eq (d : Nat) (cs acc : List Char) :
    scanBlockAux d cs acc = (acc.reverse ++ (scanBlock d cs).1, (scanBlock d cs).2) := by
  fun_induction scanBlock d cs generalizing acc with
  | case1 => simp [scanBlockAux, scanBlock]
  | case2 => simp [scanBlockAux, scanBlock]
  | case3 rest n ih1 ih2 =>
      show scanBlockAux n.succ ('-' :: '/' :: rest) acc = _
      rw [show scanBlockAux n.succ ('-' :: '/' :: rest) acc = scanBlockAux n rest ('/' :: '-' :: acc) from rfl]
      rw [ih2 ('/' :: '-' :: acc)]
      simp [scanBlock, List.reverse_append, List.cons_append, ih1]
  | case4 n rest xs r =>
      show scanBlockAux n ('/' :: '-' :: rest) acc = _
      rw [show scanBlockAux n ('/' :: '-' :: rest) acc = scanBlockAux n.succ rest ('-' :: '/' :: acc) from rfl]
      rw [r]
      simp [scanBlock, List.reverse_append, List.cons_append]
      exact ⟨rfl, rfl⟩
  | case5 n c rest h1 h2 r ih =>
      simp only [scanBlockAux]
      rw [ih (c :: acc)]
      simp [scanBlock, List.reverse_append, List.cons_append]
      exact ⟨rfl, rfl⟩
```

**Hard-won `fun_induction` lessons:**

1. **`generalizing acc` is mandatory.** Without it the accumulator is fixed and
   the IH cannot be applied at `c :: acc`. Every earlier probe died here.
2. **Case binder order does not follow the definition's pattern order.** Use
   `trace_state` (see `/tmp/fi_p24.lean`) — the `Nat` depth and the list swap
   roles between cases. Case names: case2 = 1 binder, case3 = `rest n ih1 ih2`,
   case4 = 4 binders (`r` is the IH by position), case5 = 7 binders.
3. **case3's `ih2` is the accumulative one** (`rw [ih2 ('/' :: '-' :: acc)]`),
   `ih1` goes into the simp set.
4. **The residual goals after simp in case4/case5 are `Prod` pair identities**
   (`r.fst = r.fst ∧ ...` where `r` is a let-fvar): `exact ⟨rfl, rfl⟩` closes them.
5. **csimp `show` direction matters**: `show scanBlock d cs = scanBlockAux d cs []`
   (RHS unfolds `scanBlockTR` because that's its definitional body); the reverse
   direction fails with "'show' tactic failed".

**The proof caught a real bug.** The TR `d = 0` branch pushed `['-','/']` so the
reversed output emitted `/-` instead of the closing `-/`. simp "proved" the goal
`False` — always suspect that when the goal is decidable and simp closes it.
Fix: push `['/','-']`.

Verification: `lean Gokujo.lean` 0 errors; selftest 24/24; 2,000-line doc
comments (open and unterminated) scan clean; the 361-line `server_variant_*_Stdlib.lean`
scans clean.

---

## 2. `cut` validated against independent tools

`cut /mnt/data1/aristotle-results/01611b1b-20e1-40ac-8da1-7ea508d9520c_aristotle`
→ 2,370 files, **324 unique**, 69,714 decls, 7 obligations (~7 min wall).

Cross-check (`scripts/check-cut-manifest.py`) against the old scan cache
(`/mnt/data1/aristotle-merge/manifest.jsonl`, 322,153 entries, built by
`scan_manifest.py`):

| metric | cut | cache | ground truth | verdict |
|---|---|---|---|---|
| files | 2,370 | 2,370 | 2,370 | ✓ exact |
| unique_files | 324 | 324 (distinct sha256) | — | ✓ exact — dedup validated |
| decls | 69,714 | 3,242 | 60,868 decl-lines | cache counts only `@[...]`-attributed decls (`DECL_RE` requires a leading attribute); cut's lexical count is the true one |
| holes | 7 | 36 | 0 real sorry | both over-count differently; see below |

**Holes ground truth = the knife itself.** The cache's `sorry` field is
`text.count("sorry")` — `sorryAx` contains "sorry". grep's `\bsorry\b` still
hits doc-comment prose ("with no `sorry` and no added axioms", 8 files). Only
the lexer is token-faithful: `gokujo scan --json` reports exactly 1 hole in
`Audit.lean` (`axiomBad_sorryAx`, a *proved theorem about* sorryAx whose proof
cites `` `sorryAx `` — a deliberate lexical over-approximation; a real hole can
never be missed) and 0 in `Status.lean`. cut's 7 obligations = the lexer's 7.

---

## 3. Bones: content-addressed launchpad input

`scripts/emit-bones.py PROJECT_DIR` reads the scan cache, groups by sha256, and
emits `<out>/<project>/`:

- **specs.jsonl** — one per unique file: `{id, digest, module, path, imports, decls, lines, bytes}`
- **twins.jsonl** — duplicate groups: `{id, digest, canonical, members, n}`
- **obligations.jsonl** — holes via `gokujo scan --json`, deduped by (digest, decl):
  `{id, project, module, decl, kind, line, digest, path, weight}`
- **summary.json** — the counts, plus internal consistency check

**Result on 01611b1b** (2,370 files):

```
unique_files 324 = 280 twin groups + 44 singletons
files 2,370 = twin_members 2,326 + singletons 44 ✓
obligations 1
```

The one obligation: `Mojo.Audit.axiomBad_sorryAx` at `Audit.lean:459`,
**weight 7** — cut's 7 obligations are exactly the seven digest-identical
`server_variant_*Audit.lean` twins. **Prove once, discharge seven corpus
instances.** That is the whole point of content addressing.

**Gotcha written into the script:** gokujo's scan digest is 16 hex chars; the
cache's is 64-char sha256. Never join on digest across the two systems — join
on the canonical file's realpath.

Counts cross-check: `len(specs) == unique_files`,
`twin_members + singletons == files`, cut obligations / weight = corpus instances.

---

## 4. Wiring bones to the mesh

`Protocol/Core.lean` (`P2P` namespace, 136 lines, zero sorry) already declares
exactly the right job type:

```lean
inductive Job where
  | proveGoal (moduleName declName : String) (sourceDigest : Digest) : Job
  | checkProof (artifactDigest : Digest) : Job
  | runExe (exeName : String) (argvDigest : Digest) : Job
```

Mapping obligations → mesh:

| bones obligation field | protocol | gossip (tracker `lib/control.mjs`) |
|---|---|---|
| `module`, `decl` | `Job.proveGoal moduleName declName` | announce: `{kind: 'offer', job: {proveGoal…}, digest}` to `/control/sync` |
| `digest` (sha256 of source) | `sourceDigest : Digest` (Nat — hash hex to Nat) | claim: `{kind: 'claim', action: 'prove:<id>', actor: nodeId}` — same `claimAction` dedup |
| `weight` | — | offer carries weight; workers sort by weight first |
| `kind`, `line` | diagnostics only | — |
| proof artifact | `Outcome.proved axioms` → `Certificate` | gossip `{kind: 'result', digest, artifactDigest}`; peers verify via `checkProof` |

Anti-replay (`Nonce`), authentication (`macTag`/`verifyTag`), and the
`Certificate` path are already proved in Core.lean — the worker only needs to
instantiate `Job` with the obligation fields and reuse the tracker's
announce/claim gossip, which is exactly the launchpad plan's
offer/claim-on-`Protocol/Core.lean` design.

Each `obligations.jsonl` line ≙ one `P2P.Job.proveGoal` offer:
`proveGoal "<module>" "<decl>" <digest-as-Nat>`.

---

## 5. Operational notes (for the next session)

- **RAID resync**: `md0` resync (150 MB/s) starves /mnt/data1 I/O; the corpus
  cut crawls (~60 KB/s). Check `/proc/mdstat`; the cut → cross-check → bones
  chain is wired via `scripts/cut-then-bones.sh` so it runs unattended.
- **Detached processes die with the tool's timeout**: use
  `setsid nohup CMD >log 2>&1 </dev/null & disown` as the *only* command in the
  tool call (no trailing polling), and poll in a separate call with an exact
  `ps -eo pid,etime,cmd | grep` filter — `pgrep -f NAME` matches your own poll.
- **Root-owned files/dirs**: `.git`, several files under `minimal/`, the
  installed `gokujo` binary — `sudo chown mdupont:mdupont` before writing.
  Commits need `sudo git` + `-c user.name=code -c user.email=code@solfunmeme.com`.
- **Rebuild recipe** (olean header changes require `rm` of the old olean):
  ```bash
  cd ~/projects/lean-worker/minimal
  lean Gokujo.lean -o .gokujo/build/Gokujo.olean -c .gokujo/build/gokujo.c
  LEAN_PATH=.gokujo/build lean GokujoMain.lean -c /tmp/gokujo-main.c
  leanc .gokujo/build/gokujo.c /tmp/gokujo-main.c -o /tmp/gokujo-new
  /tmp/gokujo-new selftest   # expect 24/24
  ```
- Full-corpus artifacts land at `/mnt/data1/aristotle-merge/`:
  `cut-manifest.json`, `cut-manifest.check.log`, `bones/<project>/…`,
  `bones/ALL/summary.json`, `phase2/ledger.jsonl`.

## 6. SCP containment (2026-09-29)

**Policy**: over-budget sources are quarantined to phase 2, not debugged in
phase 1. A budget is given; anything past it is contained, logged, and
deferrged. Secure. Contain. Protect.

**The "second stack overflow" was two different animals**:

1. **Lake-walk overflow** (most cut failures): `<project>/.lake/packages/*`
   are symlinks into the shared lake cache (`mathlib`, `batteries`, …). The
   knife **follows symlinks** when walking a project dir, walks all of
   Mathlib (with cyclic version dirs), and dies — or grinds I/O for 25 min
   (this is what hung `solfunmeme-split`; killed by hand, logged FAIL).
   A symlink **lab** of the project's own `.lean` files is immune: `find`
   never descends into symlinked dirs, and `*/.lake/*` is pruned anyway.
   Consequence: most "failed" projects cut **clean** in the lab and are
   fully rescuable — and per-project file counts stay honest (shared deps
   not counted 572×).
2. **File-budget overflow**: a single pathological file overflows the knife
   alone. `MonsterCharacterTable.lean` (giant `/-!` doc block + thousands of
   number tokens) and its whole twin family — `MonsterCharTableFactorization`,
   `MonsterCharTableSparse`, and the `server_variant_*_` nestings — abort
   (SIGABRT/134) even solo. The bisect re-derives the family automatically:
   every project embedding it gets exactly its family members quarantined.

**Tooling** (`scripts/scp-quarantine.sh CORPUS CUTPARTS PHASE2 [BUDGET]`):
for each project in `failures.log`, bisect via symlink labs; clean subset →
RESCUED (folded into a cut-all-resume manifest — re-run `cut-all.sh` to
resume+merge); single over-budget file → one `phase2/ledger.jsonl` line
(`reason`: `crash-signal-134` | `budget-timeout` | `depth-limit-block`).
Field bugs fixed on the way: list/dir **namespace collision** (v1 wrote 29
garbage manifests: `all.list.a` became both list and dir — v2 keeps
`$LAB/l/` and `$LAB/d/` disjoint, inode-keyed ids); stdin hygiene
(`</dev/null` on every knife call — a shared stdin made `wc` eat the loop's
position); rescue manifest always written so resume never re-crashes.

**Worker side**: knife timeout now records `status: "quarantined"` (budget
exceeded), not `failed`; `coverage-report.py` prints a `q` column and
quarantined twin weight **leaves the phase-1 denominator** — phase 1 is done
when every non-quarantined obligation is proved (exit 0).

**First-run ledger facts** (run in progress at write time): Monster-family
files dominate quarantines; rescued counters per project in
`phase2/projects.tsv`, summary in `phase2/summary.json`.
