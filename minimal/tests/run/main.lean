/-!
# TestSuite: Automated test runner for Lean 4 projects
-/

import RequestProject.Test
import RequestProject.PluginContexts

namespace TestSuite

/-- The main entry point for test execution. -/
def main : IO Unit := do
  let testDir := "tests"
  let infos := scanPaths (config) (["."] ++ [testDir])
  let results := buildAll (config) (toolchain config) infos
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
        IO.println s!"    " ++ (Util.lines result.log).join "\n    "
  
  IO.println "TestSuite complete"

end TestSuite