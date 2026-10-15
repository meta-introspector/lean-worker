# Lean-Worker Task List

## Status: ✅ Partially Complete

### Core Fixed Issues
- [✅] Fixed stack-overflow in `Gokujo.lean` - replaced recursive `walkLean` with iterative implementation (lines ~1345)
- [✅] Updated documentation (`README.md`, `GOKUJO.md`) with fix details and new build commands
- [✅] Fixed `flake.nix` - changed `gokujo = self` to use local source instead of broken github URL
- [✅] Rebased `feature/gokujo-updates` onto upstream
- [✅] Verified fix works: `lean --run GokujoMain.lean scan RequestProject` and `check RequestProject` both pass

## Remaining Work

### Priority 1: Rebuild with Fixed Source
- [ ] Rebuild native `gokujo` binary using the fixed source
- [ ] Verify the rebuilt binary has the iterative `walkLean` implementation
- [ ] Compare with existing `minimal/gokujo` (pre-fix) binary

### Priority 2: Full Project Testing
- [ ] Run `lean --run GokujoMain.lean scan RequestProject` on the rebuilt binary
- [ ] Run `lean --run GokujoMain.lean check --json RequestProject` to verify JSON output
- [ ] Test `gokujo scan`, `gokujo check`, and `gokujo build` commands directly

### Priority 3: CI/CD Integration
- [ ] Ensure `.github/workflows/lean.yml` works with the fixed build
- [ ] Add test steps for stack-overflow fix in CI
- [ ] Verify `flake.nix` and generated infrastructure files work with the fix

### Priority 4: Documentation Updates
- [ ] Update any additional docs that mention build processes
- [ ] Document the iterative `walkLean` algorithm for future maintainers
- [ ] Add test cases for large directory traversal

## Current State

### Files Modified
- `/home/mdupont/projects/lean-worker/flake.nix` - Fixed gokujo input to self
- `/home/mdupont/projects/lean-worker/minimal/README.md` - Added stack-overflow fix documentation
- `/home/mdupont/projects/lean-worker/minimal/GOKUJO.md` - Added fix details and build strategy
- `/home/mdupont/projects/lean-worker/minimal/build.sh` - Updated to use `lean --run GokujoMain.lean` pattern

### Branch Status
- Current: `feature/gokujo-updates`
- Base: `upstream/feature/gokujo-updates` (9 commits ahead)
- Verified: Fix works locally with `LEAN_PATH=. lean --run GokujoMain.lean scan RequestProject`

### Project Test Results
```bash
# Directory scan - no stack overflow
LEAN_PATH=. lean --run GokujoMain.lean scan RequestProject
# Exit: 0, Files: 9, Declarations: 285

# Project check - all pass
LEAN_PATH=. lean --run GokujoMain.lean check RequestProject
# Exit: 0, Result: PASS
```

## Technical Details

### Stack-Overflow Fix
**File**: `Gokujo.lean` (~1345)
**Problem**: Recursive `walkLean` with `acc := acc ++ (← walkLean (p ++ "/" ++ name))`
**Solution**: Iterative implementation using explicit `stack : List String` and `while !stack.isEmpty` loop

### Build Strategy
1. **Stage 1**: `lean --run GokujoMain.lean bootstrap -o lean-worker --backend system`
2. **Stage 2**: `lean --run GokujoMain.lean check RequestProject --stage full`

### Verification Commands
```bash
# Test scan
cd /home/mdupont/projects/lean-worker/minimal
LEAN_PATH=. lean --run GokujoMain.lean scan RequestProject

# Test check
cd /home/mdupont/projects/lean-worker/minimal
LEAN_PATH=. lean --run GokujoMain.lean check RequestProject

# Rebuild native binary
cd /home/mdupont/projects/lean-worker
nix build .#gokujo
```

## Next Steps

1. **Immediate**: Rebuild native binary with fix
2. **Test**: Run full scan and check on Solfunmeme project
3. **Deploy**: Update CI/CD and generate final infrastructure files
4. **Document**: Add test cases and algorithm documentation

## Files in Repo (Untracked)
- `.gitignore` - Git ignore rules
- `minimal/ProductCatalog.lean` - Product catalog module
- `minimal/regendocs.sh` - Documentation regeneration script
- `minimal/gokujo` - Native binary (pre-fix)
- `minimal/test` - Test artifacts

---
*Generated on: 2026-09-22*
*Branch: feature/gokujo-updates*