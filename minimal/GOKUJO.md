# Gokujo - The Swiss Army Knife for Lean 4

`gokujo` is **one Lean file** and **one Markdown file**.  The Lean file is the
program; the Markdown file contains the Lean file; the program contains the
documentation; the program prints the documentation as text (CLI) or as a
single self-contained HTML page.

## Overview

`gokujo` is meant to be dropped into any Lean project as the only build- and
proof-checking tool that project needs: it replaces the roles of `make`,
`lake`, `elan` and `nix` for the job of *preparing and checking proofs*.

## Key Improvements

- **Stack-overflow fix (2026-09-22)**: The recursive `walkLean` function was replaced with an **iterative** implementation using an explicit stack (`def walkLean`, lines ~1345 in `Gokujo.lean`). This allows scanning large Lean trees (e.g., `RequestProject` with 663 files) without stack overflow.
- **All compilation errors fixed**: The previously failing `GokujoCore.lean` and related modules now compile without errors.
- **String concatenation uses `++`**: All `String` concatenations now use Lean 4's `++` operator, eliminating type-mismatch errors.
- **Self-contained bootstrap**: `Gokujo.lean` now compiles as a single import-free file, and the `infra` command is recognized via the `bootstrap` sub-command.
- **Verified builds**: `Gokujo.lean` and all supporting modules (`GokujoCore.lean`, `GokujoInfra.lean`, `GokujoTest.lean`, `GokujoExec.lean`, `ProductCatalog.lean`) compile successfully with zero errors.
- **CLI compatibility**: `./Gokujo.lean infra`, `./Gokujo.lean test`, and `./Gokujo.lean exec` commands now work as expected.

## ⚠️ Important: Use the Native Binary for Large Projects

**`lean --run GokujoMain.lean` still uses the old recursive `scanStr` from `GokujoCore.lean`, which causes stack overflows on large projects like Solfunmeme.** The iterative `walkLean` fix is only compiled into the native binary. Always use the native binary for full-directory scans:

```bash
# Build native binary with the iterative fix
./gokujo bootstrap -o gokujo --backend system

# Scan large project (works!)
./gokujo scan /path/to/large/project

# Check large project
./gokujo check /path/to/large/project
```

## Commands

### `gokujo help`
Display this manual in the terminal.

### `gokujo html -o gokujo.html`
Generate a single self-contained HTML page with the manual.

### `gokujo doctor`
Check which toolchains this machine can use.

### `gokujo scan RequestProject`
Parse Lean sources and list declarations.

### `gokujo sorry RequestProject`
Fail if any `sorry`/`admit` is reachable.

### `gokujo graph RequestProject`
Import graph + verified topological order.

### `gokujo build RequestProject`
Compile every module, no lake, no make.

### `gokujo axioms RequestProject`
Audit the axioms behind every theorem.

### `gokujo check`
Scan + build + sorry + axioms, one gate.

### `gokujo html [-o FILE] [paths...]`
Write the manual, and any scan report, as one HTML page.

### `gokujo tangle [FILE.md] [-o OUT.lean]`
Extract the Lean source from the Markdown file.

### `gokujo weave [FILE.lean] [-o OUT.md]`
Write the Markdown file: manual, then the whole source.

### `gokujo selfcheck`
Verify that `Gokujo.lean` and `GOKUJO.md` still agree.

### `gokujo bootstrap`
Compile `gokujo` itself to a native binary. Uses the iterative `walkLean` from the fixed source.

### `gokujo targets`
The per-platform executable matrix.

### `gokujo infra`
Generate build infrastructure files (`lakefile.toml`, `fast-lakefile.toml`, `flake.nix`, `.github/workflows/lean.yml`, `pipelight.yml`, `Makefile`).

### `gokujo test`
Validate the generated infrastructure files.

### `gokujo weave`
Weave modular Lean files into a single file.

## How It Works

The `gokujo` file is a single Lean file that:
1. Contains all utilities needed for build and proof checking
2. Implements the command-line interface
3. Provides infrastructure generation (`gokujo infra`)
4. Provides testing infrastructure validation (`gokujo test`)
5. Provides agent workflow execution (`gokujo exec`)
6. Weaves modular Lean files into the single file (`gokujo weave`)

The single-file approach ensures:
- **No imports** needed (except for modular components)
- **Core Lean 4 only** functionality
- **Compiles in about a second** with a bare `lean` binary
- **No package manager** and **no network** required
- **Proven correctness** of key components

## Two-Stage Build Strategy

**Stage 1: Fast iteration (no mathlib, ~5s)**
```bash
./gokujo bootstrap -o lean-worker --backend system
./gokujo check minimal/RequestProject
```

**Stage 2: Full verification (with mathlib, ~30s)**
```bash
./gokujo check minimal/RequestProject --stage full
```

## Quick Start

1. Generate infrastructure files:
   ```bash
   ./gokujo infra
   ```

2. Run verification:
   ```bash
   ./gokujo check minimal/RequestProject
   ```

3. Build native executable:
   ```bash
   ./gokujo bootstrap -o lean-worker
   ```

## Agent Workflows

Execute agent workflows using `gokujo`:
```bash
./gokujo exec agent-a
./gokujo exec agent-b
./gokujo exec agent-c
```

## Docker Build

Build a self-contained container:
```bash
./gokujo bundle -o gokujo-bundle ~/.elan/toolchains/leanprover--lean4-v4.28.0
./gokujo-bundle infra
```

## CI/CD Integration

The generated files include:
- `lakefile.toml` - Full build configuration (with mathlib)
- `fast-lakefile.toml` - Fast build configuration (no mathlib)
- `flake.nix` - Nix-based reproducible builds
- `.github/workflows/lean.yml` - GitHub Actions CI
- `pipelight.yml` - pipelight.dev deployment
- `Makefile` - Convenience targets

## Final Verification

All Lean files now compile without errors:
- `Gokujo.lean` (main self-contained file, with iterative walkLean)
- `GokujoCore.lean` (repaired skill-tree implementation)
- `GokujoInfra.lean` (infrastructure with correct string concatenation)
- `GokujoTest.lean` (test infrastructure validation)
- `GokujoExec.lean` (execution module)
- `ProductCatalog.lean` (module catalog)

The project is now ready for end-to-end testing and deployment.