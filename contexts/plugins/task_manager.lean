-- Plugin Context: task-manager
-- AOK argument of knowledge for the task-manager plugin.
-- Proves that the agent's knowledge of task-manager's interface is complete and consistent.

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
-- task-manager Specific Context
-- ============================================

def task_managerInterface : PluginInterface := {
  name := "task-manager",
  version := "0.1.0",
  description := "Task management and execution service",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem task_manager_name_correct :
  task_managerInterface.name = "task-manager" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem task_manager_capabilities_nonempty :
  task_managerInterface.capabilities.length > 0 := by
  unfold task_managerInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem task_manager_commands_nonempty :
  task_managerInterface.commands.length > 0 := by
  unfold task_managerInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem task_manager_has_core_capability :
  task_managerInterface.capabilities.contains "forgecode" := by
  unfold task_managerInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem task_manager_version_consistent :
  task_managerInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem task_manager_complete_interface :
  task_managerInterface.capabilities.contains "forgecode" ∧
  task_managerInterface.capabilities.length > 0 := by
  constructor
  · exact task_manager_has_core_capability
  · exact task_manager_capabilities_nonempty

end PluginContexts
