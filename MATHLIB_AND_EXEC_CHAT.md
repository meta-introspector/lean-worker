# Shared Mathlib & Exec Chat Instructions

## Overview

This document describes the **two-stage build** for lean-worker:

1. **Stage 1 (Fast)**: Build without mathlib — for rapid iteration and CI checks
2. **Stage 2 (Full)**: Build with mathlib — for complete verification

## Shared Mathlib

### What is mathlib4?

`mathlib4` is the Lean 4 mathematical library containing thousands of theorems, definitions, and tactics. It's used by importing modules from `Mathlib` namespace.

### How mathlib is shared

In a two-stage build, mathlib is shared via:

1. **Lake cache**: `minimal/.lake` contains compiled oleans and cached dependencies
2. **Binary cache**: Pre-built mathlib artifacts from [leanprover-community/binary-repo](https://github.com/leanprover-community/binary-repo)
3. **Local cache**: `~/.lake` contains downloaded source artifacts

### Sharing mathlib between stages

```bash
# Stage 1: Build without mathlib (fast)
cd minimal
cp lakefile.toml lakefile.toml.bak
cat > lakefile.toml << 'EOF'
name = "RequestProject"
version = "0.1.0"
defaultTargets = ["RequestProject"]

[[lean_lib]]
name = "RequestProject"
dir = "RequestProject"
roots = ["Agent", "APICapabilities", "CommandExecution", "CreditUsage", "ExecutionTrace", "ToolProvenance", "Twin", "Main", "ProxyReport"]
EOF
lake build

# Stage 2: Full build with mathlib (reuses stage 1 cache)
cp lakefile.toml.bak lakefile.toml
lake build  # Uses full lakefile.toml with mathlib4 dependency
```

### Mathlib cache locations

| Location | Purpose |
|----------|---------|
| `minimal/.lake/build/lib/` | Compiled project oleans |
| `~/.lake/packages/mathlib4/` | mathlib4 source |
| `~/.lake/build/lib/mathlib4/` | Compiled mathlib4 oleans |
| `~/.cache/lean/` | Lean compilation cache |

### Clearing mathlib cache

```bash
# Clear lake build cache
rm -rf minimal/.lake
rm -rf ~/.lake/build

# Clear lean compilation cache
rm -rf ~/.cache/lean

# Start fresh
lake update
```

### Optimizing mathlib downloads

For CI/CD and shared environments:

```bash
# Use binary cache (pre-built mathlib)
lake config cache true

# Or set cache directory
export LAKE_CACHE_DIR=/shared/lake-cache

# Download mathlib once, share across runs
lake update
```

## Exec Chat (Lean REPL / CLI)

### Running the Lean executable

```bash
# Build the project
cd minimal
lake build

# Run the main executable
lake exe RequestProject
```

### Using the REPL

```bash
# Start Lean REPL with project dependencies
lake exe lean

# Or use nix shell
nix develop -c lean

# Load a specific file
lake exe lean minimal/RequestProject/Twin.lean
```

### Chat integration

For chat/bot integration with Lean verification:

```bash
# Run verification and output JSON result
lake build && lake exe RequestProject --format json

# Or use gokujo for single-file verification
gokujo check RequestProject --json
```

Example output format for chat integration:

```json
{
  "project": "lean-worker",
  "theorems": 86,
  "sorrys": 0,
  "warnings": 0,
  "status": "verified",
  "stage": "full",
  "mathlib_version": "v4.28.0"
}
```

### CI/CD chat notifications

Add to GitHub Actions (see `.github/workflows/lean.yml`):

```yaml
- name: Notify chat
  if: always()
  run: |
    curl -X POST ${CHAT_WEBHOOK_URL} \
      -H "Content-Type: application/json" \
      -d '{
        "project": "lean-worker",
        "status": "${{ job.status }}",
        "stage": "${{ matrix.stage }}",
        "commit": "${{ github.sha }}"
      }'
```

## Two-Stage Build Summary

| Stage | Mathlib | Speed | Purpose |
|-------|---------|-------|---------|
| 1 | No | Fast (~5s) | Rapid iteration, CI gate |
| 2 | Yes | Slower (~30s) | Full verification, release |

### When to use each stage

- **Stage 1**: Development, PR checks, quick feedback
- **Stage 2**: Release, deployment, formal proof audit

### Integration with gokujo

gokujo works across both stages:

```bash
# Stage 1: gokujo check (no mathlib)
cd minimal
../gokujo check RequestProject

# Stage 2: gokujo check (with mathlib)
lake build
../gokujo check RequestProject  # Uses lake-built modules
```