/-
# MicroGokujo — Gokujo × MicroLean: fast dependency extraction for interfaces

See MICROGOKUJO.md for the design.  Commands:

    microgokujo modules
    microgokujo deps        <Module>...   dump per-constant used-constants TSV
    microgokujo deps-prefix <Prefix>...   same, for every imported module whose
                                          name starts with a prefix

Output TSV: <module>\t<constant>\t<kind>\t<used_const,used_const,...>
Used constants cover the type *and* the value of each declaration.
-/

import Lean

open Lean

namespace MicroGokujo

def version : String := "0.2.0"

def usage : String := "microgokujo " ++ version ++ "\n" ++
  "  modules                   list modules on the search path\n" ++
  "  deps <Module>...          dump per-constant used-constants TSV\n" ++
  "  deps-prefix <Prefix>...   dump TSV for all modules under a prefix\n"

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

/-- All constants a declaration mentions: its type *and* its value. -/
def usedConstants (ci : ConstantInfo) : Array Name :=
  let fromType := ci.type.getUsedConstants
  match ci.value? with
  | some v => fromType ++ v.getUsedConstants
  | none   => fromType

/-- Dump the used-constant TSV for every constant defined in `targets`.
Single pass over `const2ModIdx` with a HashSet of target module indices. -/
def dumpDeps (env : Environment) (targets : List Name) : IO Unit := do
  let mut idxSet : Std.HashSet ModuleIdx := {}
  let mut nameOfIdx : Std.HashMap ModuleIdx Name := {}
  for m in targets do
    let some midx := env.getModuleIdx? m
      | throw (IO.userError s!"module not on search path: {m}")
    idxSet := idxSet.insert midx
    nameOfIdx := nameOfIdx.insert midx m
  let out ← IO.getStdout
  for (n, midx) in env.const2ModIdx do
    if idxSet.contains midx then
      let some ci := env.find? n | continue
      let used := usedConstants ci
      let m := nameOfIdx[midx]?.getD Name.anonymous
      out.putStrLn (s!"{m}\t{ci.name}\t{kindOf ci}\t" ++
        String.intercalate "," (used.toList.map toString))

def listModules (env : Environment) : IO Unit := do
  for m in env.allImportedModuleNames do
    IO.println m

/-- Modules under any of the given prefixes, among everything imported. -/
def modulesUnder (env : Environment) (prefixes : List Name) : List Name :=
  env.allImportedModuleNames.toList.filter fun m =>
    prefixes.any fun p => m.getPrefix == p || m == p

/-- Search-path directories: the fully initialized search path
(`initSearchPath` result: LEAN_PATH env + toolchain lib/lean + sysroot).
Callers must `initSearchPath (← Lean.findSysroot)` before calling. -/
def leanPathDirs : IO (List System.FilePath) := do
  searchPathRef.get

/-- All modules under `prefix` resolvable on the search path.
The prefix itself may be a module (olean file) and/or a directory of
submodules. -/
def resolvePrefixModules (pfx : Name) : IO (List Name) := do
  let rel := pfx.toString.replace "." "/"
  let mut mods : List Name := []
  for dir in ← leanPathDirs do
    let base := dir / rel
    if ← (base.withExtension "olean").pathExists then
      mods := pfx :: mods
    if ← base.isDir then
      for f in ← System.FilePath.walkDir base do
        if f.extension == some "olean" then
          let relF := f.toString.drop (dir.toString.length + 1)
          let modName := (relF.dropEnd 6).replace "/" "."
          mods := modName.toName :: mods
  pure mods.eraseDups

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
  | "deps-prefix" :: ps =>
      if ps.isEmpty then IO.eprintln usage; pure 1
      else
        initSearchPath (← Lean.findSysroot)
        let mut mods : List Name := []
        for p in ps do
          let ms ← resolvePrefixModules p.toName
          if ms.isEmpty then
            -- maybe it is a plain module: import it directly
            mods := p.toName :: mods
          else
            mods := ms ++ mods
        mods := mods.eraseDups
        IO.eprintln s!"deps-prefix: {mods.length} modules under {ps}"
        let imports : Array Import := mods.toArray.map fun m => { module := m }
        let env ← importModules imports {}
        dumpDeps env mods
        pure 0
  | _ => IO.eprintln usage; pure 1
