# Gokujo - The Swiss Army Knife for Lean 4

`gokujo` is **one Lean file** and **one Markdown file**.  The Lean file is the
program; the Markdown file contains the Lean file; the program contains the
documentation; the program prints the documentation as text (CLI) or as a
single self-contained HTML page.

## Overview

`gokujo` is meant to be dropped into any Lean project as the only build- and
proof-checking tool that project needs: it replaces the roles of `make`,
`lake`, `elan` and `nix` for the job of *preparing and checking proofs*.

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

### `gokujo tangle GOKUJO.md`
Markdown → Lean (tangle).

### `gokujo weave Gokujo.lean`
Lean → Markdown (weave).

### `gokujo selfcheck`
The two files still agree.

### `gokujo bootstrap`
Compile gokujo itself to a native binary.

### `gokujo targets`
The per-platform executable matrix.

### `gokujo infra`
Generate build infrastructure files (lakefile.toml, fast-lakefile.toml, flake.nix, .github/workflows/lean.yml, pipelight.yml).

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
./Gokujo.lean bootstrap -o lean-worker --backend system
./Gokujo.lean check RequestProject
```

**Stage 2: Full verification (with mathlib, ~30s)**
```bash
./Gokujo.lean check RequestProject --stage full
```

## Quick Start

1. Generate infrastructure files:
   ```bash
   ./Gokujo.lean infra
   ```

2. Run verification:
   ```bash
   ./Gokujo.lean check RequestProject
   ```

3. Build native executable:
   ```bash
   ./Gokujo.lean bootstrap -o lean-worker
   ```

## Documentation

For detailed documentation, see the `help` command or generate HTML output:
```bash
./Gokujo.lean html -o gokujo.html
```