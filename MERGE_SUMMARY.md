# Merge Summary: Vaciu PRs + Aleph Cloud Removal

**Branch:** `merge/vaciu-prs`  
**Date:** 2026-10-09  
**Status:** Ready for review

## Changes Made

### 1. Aleph Cloud Removal
**Commit:** `042a5c5`  
**Files:** `minimal/Twin.lean`

Removed all references to "Aleph Cloud" and generalized to "Cloud Provider":
- `cloudProvider := "Aleph Cloud"` → `"Cloud Provider"`
- `aleph-cloud-self-deployment` → `cloud-self-deployment`
- `aleph_cloud_sponsors` → `cloud_provider_sponsors`
- `sponsor_is_aleph_cloud` → `sponsor_is_cloud_provider`
- `agent_runs_on_aleph_cloud` → `agent_runs_on_cloud`
- Updated comments and documentation strings

**Rationale:** Aleph Cloud helped but is over quota and no longer active. Generalizing to avoid promoting any single provider.

---

### 2. PR #10: CI Workflow Fix
**Commit:** `c82120b`  
**Files:** `.github/workflows/lean.yml`

- Move `schedule:` from job level to workflow level (was invalid)
- Add `if:` conditions to gate jobs appropriately
- YAML now parses correctly

**Verification:** `python3 -c "import yaml; yaml.safe_load(...)"` ✓

---

### 3. PR #11: Module Path Fixes
**Commit:** `20315df`  
**Files:** `minimal/ProxyReport.lean`, `minimal/RequestProject/ProxyReport.lean`, `minimal/lakefile.toml`

- Fix `RequestProject.Proxy.Export` → `Proxy.Export`
- Qualify lakefile roots: `Proxy.Concrete`, `Protocol.Framing`, etc.
- Fix module paths to match actual directory structure

**Verification:** `grep "import Proxy.Export"` ✓

---

### 4. PR #12: Revert Wave VI GCP
**Commit:** `18df6e8`  
**Files:** `minimal/Twin.lean`

- Revert invalid late imports (lines 929-931 after declarations)
- Remove GCP section that broke Lean 4 build
- Twin.lean now valid

**Verification:** `grep "^import GCP" minimal/Twin.lean` → no results ✓

---

### 5. PR #13: Remove Unused Mathlib Scopes
**Commit:** `c7eb7bc`  
**Files:** `minimal/Main.lean`

- Remove unused `BigOperators`, `Real`, `Pointwise` scopes
- Only affects `minimal/Main.lean` (RequestProject/ keeps them)
- Fixes Stage-1 build blocker

**Verification:** `grep "open scoped (BigOperators|Real|Pointwise)" minimal/Main.lean` → no results ✓

---

### 6. PR #14: Fix Gokujo CI Gate
**Commit:** `7d1c1d3`  
**Files:** `.github/workflows/lean.yml`

Fixed 5 bugs:
1. Invalid `lean --make` (doesn't exist in Lean 4)
2. `-o` misuse (doesn't create runnable executable)
3. `gojo`/`gogo` typo
4. Stale path (`minimal/RequestProject` → `minimal/`)
5. Fail-open `|| true` swallowing exit code

**Verification:** All 5 patterns no longer present ✓

---

### 7. PR #15: Remove Stale Exe
**Commit:** `5e5385e`  
**Files:** `.github/workflows/lean.yml`

- Remove `lake exe RequestProject` (no exe exists)
- Keep only valid `lake build RequestProject`

**Verification:** `grep "lake exe RequestProject"` → no results ✓

---

### 8. PR #9: Security Fix (Fail-Closed Axiom Audit)
**Commit:** `c21c32f`  
**Files:** `minimal/Gokujo.lean`, `tools/gokujo/Gokujo.lean`

**LW-GOKUJO-01:** Make axiom audit fail closed instead of fail-open.

Security improvements:
- Track unaudited theorems (private decls could hide axioms)
- Fail on driver errors or exit code != 0
- Fail if any requested declaration has no result
- Fail on duplicate or unexpected results
- Fail if declared-axiom scan doesn't finish
- Fail if project declares disallowed axiom
- Fail if no source files to audit
- Includes `tools/gokujo/` mirror sync + tests

**Supersedes:** PR #16

**Verification:** `grep -E "unaudited|fail.*closed|exitCode" minimal/Gokujo.lean` ✓

---

## Testing

### Syntax Validation
All modified files pass Lean 4.28.0 dependency check:
- `minimal/Twin.lean` ✓
- `minimal/Main.lean` ✓
- `minimal/Gokujo.lean` ✓

### YAML Validation
`.github/workflows/lean.yml` parses as valid YAML ✓

### No Merge Conflicts
No conflict markers in any file ✓

---

## Commit History

```
c21c32f Merge PR #9: gokujo: fail-closed axiom audit (LW-GOKUJO-01)
5e5385e Merge PR #15: ci: drop stale lake exe RequestProject
7d1c1d3 Merge PR #14: ci: fix gokujo gate bugs
c7eb7bc Merge PR #13: minimal: drop Mathlib-only open scoped
18df6e8 Merge PR #12: minimal: revert Wave VI GCP section
20315df Merge PR #11: minimal: import Proxy.Export fix
c82120b Merge PR #10: ci: fix lean.yml workflow parse
042a5c5 chore: remove Aleph Cloud references, generalize to Cloud Provider
```

---

## Next Steps

1. **Review** — Check each merge commit
2. **Test** — Run full CI pipeline (with mathlib)
3. **Merge** — Merge to main if CI passes

