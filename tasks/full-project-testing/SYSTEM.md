# Task: Full Project Testing with Fixed Binary

**Status:** pending
**Project:** lean-worker
**Priority:** P2

## Description
Run comprehensive testing of the rebuilt native binary on the full Solfunmeme project to verify stack overflow fix works in production context.

## Context
After rebuilding the fixed binary, we need to test it on the actual Solfunmeme project (663 files) that previously caused stack overflow with the old recursive implementation.

## Steps
1. [ ] Run `./gokujo-fixed scan RequestProject` on the rebuilt binary
2. [ ] Run `./gokujo-fixed check --json RequestProject` to verify JSON output
3. [ ] Test `gokujo scan`, `gokujo check`, and `gokujo build` commands directly
4. [ ] Verify no stack overflow occurs during large project scans

## Commands
```bash
# Test scan (should complete without stack overflow)
cd /home/mdupont/projects/lean-worker/minimal
./gokujo-fixed scan RequestProject

# Test check
./gokujo-fixed check RequestProject

# Test JSON output
./gokujo-fixed check --json RequestProject
```

## Expected Results
- Scan RequestProject: Exit code 0, processes all declarations
- Check RequestProject: Exit code 0, Result: PASS
- No "Stack overflow detected. Aborting." messages

## Dependencies
- Rebuilt native binary from rebuild-fixed-binary task
- Access to RequestProject module

## Notes
- Original issue: Binary caused stack overflow when scanning large projects like Solfunmeme (663 files)
- Fix: Replaced recursive `walkLean` and `scanStr` with iterative implementations