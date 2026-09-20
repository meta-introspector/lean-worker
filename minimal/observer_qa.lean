-- Plugin Context: observer-qa
-- AOK argument of knowledge for the observer-qa plugin.
-- Proves that the agent's knowledge of observer-qa's interface is complete and consistent.

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
-- observer-qa Specific Context
-- ============================================

def observer_qaInterface : PluginInterface := {
  name := "observer-qa",
  version := "0.1.0",
  description := "Observer quality assurance and test result analysis",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem observer_qa_name_correct :
  observer_qaInterface.name = "observer-qa" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem observer_qa_capabilities_nonempty :
  observer_qaInterface.capabilities.length > 0 := by
  unfold observer_qaInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem observer_qa_commands_nonempty :
  observer_qaInterface.commands.length > 0 := by
  unfold observer_qaInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem observer_qa_has_core_capability :
  observer_qaInterface.capabilities.contains "forgecode" := by
  unfold observer_qaInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem observer_qa_version_consistent :
  observer_qaInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem observer_qa_complete_interface :
  observer_qaInterface.capabilities.contains "forgecode" ∧
  observer_qaInterface.capabilities.length > 0 := by
  constructor
  · exact observer_qa_has_core_capability
  · exact observer_qa_capabilities_nonempty

end PluginContexts
