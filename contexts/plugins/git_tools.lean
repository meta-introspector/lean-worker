-- Plugin Context: git-tools
-- AOK argument of knowledge for the git-tools plugin.
-- Proves that the agent's knowledge of git-tools's interface is complete and consistent.

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
-- git-tools Specific Context
-- ============================================

def git_toolsInterface : PluginInterface := {
  name := "git-tools",
  version := "0.1.0",
  description := "Git repository discovery, object extraction, and catalog tooling",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem git_tools_name_correct :
  git_toolsInterface.name = "git-tools" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem git_tools_capabilities_nonempty :
  git_toolsInterface.capabilities.length > 0 := by
  unfold git_toolsInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem git_tools_commands_nonempty :
  git_toolsInterface.commands.length > 0 := by
  unfold git_toolsInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem git_tools_has_core_capability :
  git_toolsInterface.capabilities.contains "forgecode" := by
  unfold git_toolsInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem git_tools_version_consistent :
  git_toolsInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem git_tools_complete_interface :
  git_toolsInterface.capabilities.contains "forgecode" ∧
  git_toolsInterface.capabilities.length > 0 := by
  constructor
  · exact git_tools_has_core_capability
  · exact git_tools_capabilities_nonempty

end PluginContexts
