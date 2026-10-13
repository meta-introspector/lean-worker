-- Plugin Context: nora
-- AOK argument of knowledge for the nora artifact-registry service.
-- Facts verified against http://127.0.0.1:4000/health on 2026-10-01
-- (version 0.9.2; cargo registry enabled with crates.io proxy; the raw
-- registry serves the /raw/{path} PUT used by the build service).

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

structure NoraInterface where
  name         : String
  version      : String
  description  : String
  capabilities : List String
  commands     : List String

def noraInterface : NoraInterface := {
  name := "nora",
  version := "0.9.2",
  description := "Local artifact & package registry on 127.0.0.1:4000 — build-service artifact store",
  capabilities := ["cargo-registry", "cargo-proxy", "raw-artifact-store"],
  commands := ["health", "cargo-index", "raw-put"]
}

theorem nora_name_correct :
  noraInterface.name = "nora" := rfl

theorem nora_version_consistent :
  noraInterface.version = "0.9.2" := rfl

theorem nora_capabilities_nonempty :
  noraInterface.capabilities.length > 0 := by decide

theorem nora_commands_nonempty :
  noraInterface.commands.length > 0 := by decide

theorem nora_has_core_capability :
  "raw-artifact-store" ∈ noraInterface.capabilities := by decide

theorem nora_complete_interface :
  "raw-put" ∈ noraInterface.commands ∧
  "cargo-proxy" ∈ noraInterface.capabilities := by decide

end PluginContexts
