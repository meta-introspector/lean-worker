# Merge Plan: Vaciu PRs + Aleph Cloud Removal

## Phase 1: Remove Aleph Cloud References
- [ ] Remove "Aleph Cloud" from Twin.lean
- [ ] Generalize to "cloud provider" or remove entirely

## Phase 2: Merge CI/Build Fixes (in order)
- [ ] PR 10: Fix workflow YAML (schedule placement)
- [ ] PR 11: Fix stale module paths + lakefile roots
- [ ] PR 12: Revert invalid late imports (Wave VI GCP)
- [ ] PR 13: Remove unused Mathlib scopes from minimal/
- [ ] PR 14: Fix 5 bugs in gokujo CI gate
- [ ] PR 15: Remove stale lake exe RequestProject

## Phase 3: Merge Security Fix
- [ ] PR 9: Fail-closed axiom audit (includes PR 16)

## Testing
- [ ] Build each stage
- [ ] Verify no regressions
