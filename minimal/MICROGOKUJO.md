# MicroGokujo — Gokujo × MicroLean: faster parser, modular mathlib interfaces

**Status:** v0.1.0 — dep extraction working (2,051 consts from 2 toolchain
modules in 0.6 s, olean-read only, zero elaboration).

## The problem

Splitting mathlib today means `import Mathlib` + full re-elaboration per
declaration — the 5,790 mathlib-split decl flakes each drag in the monolith.
The splitter is fast but *useless* if every shard still depends on everything.

## The merge

| layer | tool | what it contributes |
|---|---|---|
| front | **Gokujo** | pure-Lean lossless tokenizer + command splitter (no imports, proven lossless) |
| mid | **MicroLean** | micro-core AST + `ofExprPure` total projection (verified reification) |
| kernel | **MicroGokujo.lean** | constant-graph extraction from cached `.olean` via `importModules` — reads mathlib, never rebuilds it |
| synth | **synth_interfaces.py** | transitive closure over used-constants → per-decl minimal `import` set |

## Pipeline

```
mathlib oleans (shared cache)
      │  microgokujo deps-prefix Mathlib       ← kernel: name,kind,used-consts
      ▼
deps.tsv  (constant → module, used-constant graph)
      │  synth_interfaces.py --module Mathlib.X --out ifaces/
      ▼
ifaces/<Decl>.lean  (minimal imports — true closure, not `import Mathlib`)
      │  + Gokujo token layer (source spans, sorry audit)
      ▼
per-decl flake builds closure only — monolith broken
```

## Key properties

- **Type + value used-constants**: interfaces import what the *signature*
  mentions, not only the proof term.
- **External anchors**: constants outside the TSV's module set are leaves —
  run `deps` over the full corpus for complete closures.
- **No mathlib rebuild**: `importModules` reads oleans from `LEAN_PATH`.

## Commands

    microgokujo modules
    microgokujo deps <Module>...           # TSV: module\tname\tkind\tused,...
    synth_interfaces.py deps.tsv --stats
    synth_interfaces.py deps.tsv --decl <Const>
    synth_interfaces.py deps.tsv --module <Module> --out ifaces/

## Roadmap

- [ ] full-mathlib deps dump (needs unpacked olean cache on LEAN_PATH)
- [ ] module-import minimization (drop imports implied transitively)
- [ ] Gokujo source-span join: emit full per-decl source + minimal imports
- [ ] per-decl flake.nix generation against shared mathlib cache
- [ ] hub-node pruning report (the "mega-hub" problem from mathlib-split)
