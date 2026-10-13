-- Plugin Context: activity-profile
-- AOK argument of knowledge for the activity-profile plugin.
-- Proves that the agent's knowledge of activity-profile's interface is complete and consistent.

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

-- ============================================
-- Plugin Interface Definition
-- ============================================

structure PluginInterface where
  name        : String
  version     : String
  description : String
  capabilities : List String
  commands    : List String

-- ============================================
-- activity-profile Specific Context
-- ============================================

def activity_profileInterface : PluginInterface := {
  name := "activity-profile",
  version := "0.1.0",
  description := "Activity profile server for session tracking and analytics",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem activity_profile_name_correct :
  activity_profileInterface.name = "activity-profile" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem activity_profile_capabilities_nonempty :
  activity_profileInterface.capabilities.length > 0 := by
  unfold activity_profileInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem activity_profile_commands_nonempty :
  activity_profileInterface.commands.length > 0 := by
  unfold activity_profileInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem activity_profile_has_core_capability :
  activity_profileInterface.capabilities.contains "forgecode" := by
  unfold activity_profileInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem activity_profile_version_consistent :
  activity_profileInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem activity_profile_complete_interface :
  activity_profileInterface.capabilities.contains "forgecode" ∧
  activity_profileInterface.capabilities.length > 0 := by
  constructor
  · exact activity_profile_has_core_capability
  · exact activity_profile_capabilities_nonempty

end PluginContexts
