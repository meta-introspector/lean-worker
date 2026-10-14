/-
# MicroGokujo — Gokujo × MicroLean: fast dependency extraction for interfaces

**Goal.** Break the mathlib monolith: for every constant, compute its true
used-constant set directly from compiled `.olean` files — *no re-elaboration
of mathlib source*.  The output feeds an interface synthesizer that emits
per-declaration minimal `import` sets, so a split declaration builds against
its own closure instead of `import Mathlib`.

**Lineage.**
- Gokujo: pure-Lean lossless tokenizer + command splitter (fast front-end).
- MicroLean: micro-core AST + `ofExpr` projection (verified reification).
- MicroGokujo: kernel-level constant-graph extraction over cached oleans.

## Commands

    microgokujo modules            list all modules reachable on LEAN_PATH
    microgokujo deps  <Module>...  per-constant TSV of used constants

Output TSV columns (one line per constant defined in the requested modules):

    <module>\t<constant>\t<kind>\t<used_const,used_const,...>

Used constants include both the type and the value of each declaration:
an interface must import whatever the *signature* mentions, not only what
the proof term uses.

## Usage with the shared mathlib cache

    LEAN_PATH=<mathlib-cache>/lib/lean4 microgokujo deps Mathlib.Data.Nat.Basic

The tool loads oleans via `importModules` — mathlib is *read*, never rebuilt.
-/

import Lean

open Lean

namespace MicroGokujo

def version : String := "0.1.0"

def usage : String := "microgokujo " ++ version ++ "\n" ++
  "  modules                 list modules on the search path\n" ++
  "  deps <Module>...        dump per-constant used-constants TSV\n"

/-- Classify a constant for the TSV `kind` column. -/
def kindOf : ConstantInfo → String
  | .axiomInfo  _ => "axiom"
  | .defnInfo   _ => "def"
  | .thmInfo    _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .quotInfo   _ => "quot"
  | .inductInfo _ => "inductive"
  | .ctorInfo   _ => "ctor"
  | .recInfo    _ => "recursor"

/-- All constants a declaration mentions: its type *and* its value.
An interface must import whatever the signature mentions, not only what
the proof term uses. -/
def usedConstants (ci : ConstantInfo) : Array Name :=
  let fromType := ci.type.getUsedConstants
  match ci.value? with
  | some v => fromType ++ v.getUsedConstants
  | none   => fromType

/-- Dump the used-constant TSV for every constant defined in `targets`. -/
def dumpDeps (env : Environment) (targets : List Name) : IO Unit := do
  let mut idxOf : Array (Name × ModuleIdx) := #[]
  for m in targets do
    let some midx := env.getModuleIdx? m
      | throw (IO.userError s!"module not on search path: {m}")
    idxOf := idxOf.push (m, midx)
  for (n, midx) in env.const2ModIdx do
    for (m, tidx) in idxOf do
      if midx == tidx then
        let some ci := env.find? n | continue
        let used := usedConstants ci
        let line := s!"{m}\t{ci.name}\t{kindOf ci}\t" ++
          String.intercalate "," (used.toList.map toString)
        IO.println line

def listModules (env : Environment) : IO Unit := do
  for m in env.header.moduleNames do
    IO.println m

end MicroGokujo

open MicroGokujo in
def main (args : List String) : IO UInt32 := do
  match args with
  | ["modules"] =>
      initSearchPath (← Lean.findSysroot)
      let env ← importModules #[{ module := `Init : Import }] {}
      listModules env
      pure 0
  | "deps" :: ms =>
      if ms.isEmpty then IO.eprintln usage; pure 1
      else
        initSearchPath (← Lean.findSysroot)
        let imports : Array Import := ms.toArray.map fun s => { module := s.toName }
        let env ← importModules imports {}
        dumpDeps env (ms.map String.toName)
        pure 0
  | _ => IO.eprintln usage; pure 1
