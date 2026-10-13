# Task: CI/CD Integration

**Status:** pending
**Project:** lean-worker
**Priority:** P2

## Description
Ensure CI/CD pipelines work with the fixed build and add test steps for the stack-overflow fix in CI. Update GitHub Actions workflows to verify the fix on every commit.

## Context
The lean-worker project has GitHub Actions workflows that need to verify the gokujo fix works correctly on every commit to prevent regressions.

## Steps
1. [ ] Update `.github/workflows/lean.yml` to include fix verification steps
2. [ ] Add test steps for stack-overflow fix in CI (scan RequestProject, check theorems)
3. [ ] Verify `flake.nix` and generated infrastructure files work with the fix in CI
4. [ ] Run CI pipeline to confirm all steps pass
5. [ ] Add badge or status indicator for build success

## Commands
```bash
# Run the fix verification as CI step
cd /home/mdupont/projects/lean-worker/minimal
LEAN_PATH=. lean --run GokujoMain.lean scan RequestProject

# Or use native binary if rebuilt
./gokujo-fixed scan RequestProject
./gokujo-fixed check RequestProject
```

## Verification
- CI pipeline passes on push to main/feature branches
- Status checks show successful build and test
- No stack overflow errors in CI logs
- Fixed binary is used in CI workflows

## Dependencies
- Rebuilt native binary from rebuild-fixed-binary task
- Access to GitHub Actions workflow files in .github/workflows/
- Ability to modify repository CI configuration

## Notes
- Branch: feature/gokujo-updates
- Current CI may reference old binary; needs updating to use fixed source
- Shared Nix cache can speed up CI builds (SHARED_LAKE_CACHE.md)
- Consider adding matrix testing for different OS/platforms