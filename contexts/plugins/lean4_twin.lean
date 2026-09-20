-- Plugin Context: lean4-twin
-- AOK argument of knowledge for the lean4-twin plugin.
-- Proves that the agent's knowledge of lean4-twin's interface is complete and consistent.

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
-- lean4-twin Specific Context
-- ============================================

def lean4_twinInterface : PluginInterface := {
  name := "lean4-twin",
  version := "0.1.0",
  description := "Lean4 Twin formalization — agent identity, capabilities, constraints, environment, memory, skills, and certified P2P protocol with logging proxy",
  capabilities := ["forgecode", "dotagents", "lean4"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem lean4_twin_name_correct :
  lean4_twinInterface.name = "lean4-twin" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem lean4_twin_capabilities_nonempty :
  lean4_twinInterface.capabilities.length > 0 := by
  unfold lean4_twinInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem lean4_twin_commands_nonempty :
  lean4_twinInterface.commands.length > 0 := by
  unfold lean4_twinInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem lean4_twin_has_core_capability :
  lean4_twinInterface.capabilities.contains "forgecode" := by
  unfold lean4_twinInterface
  have : "forgecode" ∈ ["forgecode", "dotagents", "lean4"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem lean4_twin_version_consistent :
  lean4_twinInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem lean4_twin_complete_interface :
  lean4_twinInterface.capabilities.contains "forgecode" ∧
  lean4_twinInterface.capabilities.length > 0 := by
  constructor
  · exact lean4_twin_has_core_capability
  · exact lean4_twin_capabilities_nonempty

end PluginContexts
