/-!
# TestSuite: Automated test runner for Lean 4 projects
-/

import RequestProject.Test

namespace TestSuite

/-- The main entry point for test execution. -/
def main : IO UInt32 := do
  let testDir := "tests"
  let infos := scanPaths (config) (["."] ++ [testDir])
  let (results, graphErrors) := buildAll (config) (toolchain config) infos
  let failures := results.filter (fun r => r.status == .failed)
  let successes := results.filter (fun r => r.status == .built)
  
  if failures.isEmpty then
    IO.println "✅ All tests passed"
    IO.println (toString successes.length ++ " tests passed, 0 failed")
  else
    IO.println "❌ Test failures detected"
    for result in failures do
      IO.println s!"  " ++ result.module ++ ": " ++ result.status.name
      if result.log != "" then
        IO.println s!"    " ++ (Util.lines result.log).join "\n    "n    return 1
  
  IO.println "TestSuite complete"
  return 0

end TestSuite