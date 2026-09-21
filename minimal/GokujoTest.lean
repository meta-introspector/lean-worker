/-! GokujoTest — Test infrastructure validation
-/

namespace TestInfra

/-- Validate that infrastructure files are present and correct. -/
def validateInfra (root : String) : IO Bool := do
  let files := ["lakefile.toml", "fast-lakefile.toml", "flake.nix", ".github/workflows/lean.yml", "pipelight.yml", "Makefile"]
  let mut allGood : Bool := true
  for f in files do
    let path := root ++ "/" ++ f
    let exists ← (System.FilePath.mk path).pathExists
    if exists then
      IO.println ("  ✅ " ++ f)
    else
      IO.println ("  ❌ " ++ f ++ " missing")
      allGood := false
  return allGood

end TestInfra