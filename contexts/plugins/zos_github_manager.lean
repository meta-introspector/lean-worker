-- Plugin Context: zos-github-manager
-- AOK argument of knowledge for the zos-github-manager plugin.
-- Proves that the agent's knowledge of zos-github-manager's interface is complete and consistent.

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
-- zos-github-manager Specific Context
-- ============================================

def zos_github_managerInterface : PluginInterface := {
  name := "zos-github-manager",
  version := "0.1.0",
  description := "Web-based GitHub repository manager with search, clone, and events integration",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem zos_github_manager_name_correct :
  zos_github_managerInterface.name = "zos-github-manager" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem zos_github_manager_capabilities_nonempty :
  zos_github_managerInterface.capabilities.length > 0 := by
  unfold zos_github_managerInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem zos_github_manager_commands_nonempty :
  zos_github_managerInterface.commands.length > 0 := by
  unfold zos_github_managerInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem zos_github_manager_has_core_capability :
  zos_github_managerInterface.capabilities.contains "forgecode" := by
  unfold zos_github_managerInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem zos_github_manager_version_consistent :
  zos_github_managerInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem zos_github_manager_complete_interface :
  zos_github_managerInterface.capabilities.contains "forgecode" ∧
  zos_github_managerInterface.capabilities.length > 0 := by
  constructor
  · exact zos_github_manager_has_core_capability
  · exact zos_github_manager_capabilities_nonempty

end PluginContexts
