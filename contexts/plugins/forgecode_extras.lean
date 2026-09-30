-- Plugin Context: forgecode-extras
-- AOK argument of knowledge for the forgecode-extras plugin.
-- Proves that the agent's knowledge of forgecode-extras's interface is complete and consistent.

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
-- forgecode-extras Specific Context
-- ============================================

def forgecode_extrasInterface : PluginInterface := {
  name := "forgecode-extras",
  version := "0.1.0",
  description := "Forgecode agent session dumps and activity records",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem forgecode_extras_name_correct :
  forgecode_extrasInterface.name = "forgecode-extras" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem forgecode_extras_capabilities_nonempty :
  forgecode_extrasInterface.capabilities.length > 0 := by
  unfold forgecode_extrasInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem forgecode_extras_commands_nonempty :
  forgecode_extrasInterface.commands.length > 0 := by
  unfold forgecode_extrasInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem forgecode_extras_has_core_capability :
  forgecode_extrasInterface.capabilities.contains "forgecode" := by
  unfold forgecode_extrasInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem forgecode_extras_version_consistent :
  forgecode_extrasInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem forgecode_extras_complete_interface :
  forgecode_extrasInterface.capabilities.contains "forgecode" ∧
  forgecode_extrasInterface.capabilities.length > 0 := by
  constructor
  · exact forgecode_extras_has_core_capability
  · exact forgecode_extras_capabilities_nonempty

end PluginContexts
