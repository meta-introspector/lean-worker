-- Plugin Context: forgejo
-- AOK argument of knowledge for the local forgejo git forge.
-- Facts verified against http://127.0.0.1:3000/api/v1 on 2026-10-01
-- (version 14.0.1; mirrors mdupont/tracker; commit-status API receives
-- the pipelight-build statuses).

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

structure ForgejoInterface where
  name         : String
  version      : String
  description  : String
  capabilities : List String
  commands     : List String

def forgejoInterface : ForgejoInterface := {
  name := "forgejo",
  version := "14.0.1",
  description := "Local git forge (\"Forgejo: Local Git Archive\") on 127.0.0.1:3000 — build tracking sink",
  capabilities := ["git-mirror", "commit-status-api", "private-repos"],
  commands := ["web", "api"]
}

theorem forgejo_name_correct :
  forgejoInterface.name = "forgejo" := rfl

theorem forgejo_version_consistent :
  forgejoInterface.version = "14.0.1" := rfl

theorem forgejo_capabilities_nonempty :
  forgejoInterface.capabilities.length > 0 := by decide

theorem forgejo_commands_nonempty :
  forgejoInterface.commands.length > 0 := by decide

theorem forgejo_has_core_capability :
  "commit-status-api" ∈ forgejoInterface.capabilities := by decide

theorem forgejo_complete_interface :
  "api" ∈ forgejoInterface.commands ∧
  "git-mirror" ∈ forgejoInterface.capabilities := by decide

end PluginContexts
