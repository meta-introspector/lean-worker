/-! GokujoExec — Agent workflow execution
-/

namespace Exec

/-- Run an agent workflow by name. -/
def run (name : String) : IO UInt32 := do
  match name with
  | "agent-a" =>
      IO.println "running agent-a workflow"
      return 0
  | "agent-b" =>
      IO.println "running agent-b workflow"
      return 0
  | "agent-c" =>
      IO.println "running agent-c workflow"
      return 0
  | _ =>
      IO.eprintln ("unknown agent workflow: " ++ name)
      return 2

end Exec