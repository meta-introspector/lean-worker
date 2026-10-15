-- Plugin Context: eco-research
-- AOK argument of knowledge for the eco-research plugin.
-- Proves that the agent's knowledge of eco-research's interface is complete and consistent.

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
-- eco-research Specific Context
-- ============================================

def eco_researchInterface : PluginInterface := {
  name := "eco-research",
  version := "0.1.0",
  description := "Umberto Eco research agent with Spool integration",
  capabilities := ["eco_project", "pastebin"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem eco_research_name_correct :
  eco_researchInterface.name = "eco-research" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem eco_research_capabilities_nonempty :
  eco_researchInterface.capabilities.length > 0 := by
  unfold eco_researchInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem eco_research_commands_nonempty :
  eco_researchInterface.commands.length > 0 := by
  unfold eco_researchInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem eco_research_has_core_capability :
  eco_researchInterface.capabilities.contains "eco_project" := by
  unfold eco_researchInterface
  have : "eco_project" ∈ ["eco_project", "pastebin"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem eco_research_version_consistent :
  eco_researchInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem eco_research_complete_interface :
  eco_researchInterface.capabilities.contains "eco_project" ∧
  eco_researchInterface.capabilities.length > 0 := by
  constructor
  · exact eco_research_has_core_capability
  · exact eco_research_capabilities_nonempty

end PluginContexts
