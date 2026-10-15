/-!
# TestSuite: Automated test runner for Lean 4 projects
-/

import RequestProject.Test

namespace TestSuite

/-- The main entry point for test execution. -/
def main : IO UInt32 := do
  let testDir := "tests"
  let infos ← scanPaths config ([".", testDir])
  let tc ← toolchain config
  let (results, graphErrors) ← buildAll config tc infos
  let failures := results.filter (fun r => r.status == .failed)
  let successes := results.filter (fun r => r.status == .built)

  if failures.isEmpty && graphErrors.isEmpty then
    IO.println "✅ All tests passed"
    IO.println (toString successes.length ++ " tests passed, 0 failed")
  else
    IO.println "❌ Test failures detected"
    for err in graphErrors do
      IO.println ("  Graph error: " ++ err)
    for result in failures do
      IO.println ("  " ++ result.module ++ ": " ++ result.status.name)
      if result.log != "" then
        IO.println ("    " ++ String.intercalate "\n    " (Util.lines result.log))
    return 1

  IO.println "TestSuite complete"
  return 0

end TestSuite