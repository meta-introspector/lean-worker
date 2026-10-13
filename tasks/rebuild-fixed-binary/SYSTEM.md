# Task: Rebuild Fixed Native Binary

**Status:** in_progress
**Project:** lean-worker
**Priority:** P1

## Description
Rebuild the native `gokujo` binary using the fixed source code with iterative `walkLean` and `scanStrTR` implementations to resolve stack overflow issues when scanning large projects like Solfunmeme (663 files).

## Context
- Fixed iterative `walkLean`: Located in `Gokujo.lean` at lines ~1345 in the `lean-worker/minimal` directory ✓
- Fixed iterative `scanStr`: Added `scanStrTR` as iterative alternative to recursive `scanStr` ✓
- Proof Equivalence: `@[csimp] theorem scanStr_eq_scanStrTR` proves equivalence ✓
- Problem: Native binary `gokujo` predates the fix, compiled from older source

## Steps
1. [ ] Rebuild native `gokujo` binary using the fixed source
2. [ ] Verify the rebuilt binary has the iterative `walkLean` implementation
3. [ ] Compare with existing `minimal/gokujo` (pre-fix) binary

## Commands
```bash
cd /home/mdupont/projects/lean-worker
nix build .#gokujo
# Or using the bootstrap approach:
cd /home/mdupont/projects/lean-worker/minimal
./gokujo bootstrap Gokujo.lean -o gokujo-fixed --backend system
```

## Verification
- Run `./gokujo-fixed scan RequestProject` - should complete without stack overflow
- Run `./gokujo-fixed check RequestProject` - should pass with 0 holes

## Dependencies
- Fixed Gokujo.lean source (already in minimal/)
- flake.nix updated to use local source (done)

## Notes
- Branch: feature/gokujo-updates (9 commits ahead of upstream)
- Verified fix works locally with `LEAN_PATH=. lean --run GokujoMain.lean scan RequestProject`