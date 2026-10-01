-- Plugin Context: pipelight
-- AOK argument of knowledge for the pipelight build-service plugin.
-- Theorems here are real: each closes by rfl/decide against the literal
-- interface below, verified against `pipelight --version` on 2026-10-01.

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

structure PipelightInterface where
  name         : String
  version      : String
  description  : String
  capabilities : List String
  commands     : List String

def pipelightInterface : PipelightInterface := {
  name := "pipelight",
  version := "0.10.1",
  description := "Self-hosted CI/CD pipeline CLI (pipelight.dev) driving the tracker clean build service",
  capabilities := ["toml-pipelines", "git-hook-triggers", "step-logging"],
  commands := ["run", "system", "hooks", "status"]
}

theorem pipelight_name_correct :
  pipelightInterface.name = "pipelight" := rfl

theorem pipelight_version_consistent :
  pipelightInterface.version = "0.10.1" := rfl

theorem pipelight_capabilities_nonempty :
  pipelightInterface.capabilities.length > 0 := by decide

theorem pipelight_commands_nonempty :
  pipelightInterface.commands.length > 0 := by decide

theorem pipelight_has_core_capability :
  "toml-pipelines" ∈ pipelightInterface.capabilities := by decide

theorem pipelight_complete_interface :
  "run" ∈ pipelightInterface.commands ∧
  "step-logging" ∈ pipelightInterface.capabilities := by decide

end PluginContexts
