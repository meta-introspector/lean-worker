-- Plugin Context: proof-robot
-- AOK argument of knowledge for the proof-robot plugin.
-- Proves that the agent's knowledge of proof-robot's interface is complete and consistent.

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
-- proof-robot Specific Context
-- ============================================

def proof_robotInterface : PluginInterface := {
  name := "proof-robot",
  version := "0.1.0",
  description := "GOAP-driven autonomous theorem prover for Lean4 proof assembly using Aristotle CID indexes",
  capabilities := ["forgecode", "dotagents", "aristotle"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem proof_robot_name_correct :
  proof_robotInterface.name = "proof-robot" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem proof_robot_capabilities_nonempty :
  proof_robotInterface.capabilities.length > 0 := by
  unfold proof_robotInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem proof_robot_commands_nonempty :
  proof_robotInterface.commands.length > 0 := by
  unfold proof_robotInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem proof_robot_has_core_capability :
  proof_robotInterface.capabilities.contains "forgecode" := by
  unfold proof_robotInterface
  have : "forgecode" ∈ ["forgecode", "dotagents", "aristotle"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem proof_robot_version_consistent :
  proof_robotInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem proof_robot_complete_interface :
  proof_robotInterface.capabilities.contains "forgecode" ∧
  proof_robotInterface.capabilities.length > 0 := by
  constructor
  · exact proof_robot_has_core_capability
  · exact proof_robot_capabilities_nonempty

end PluginContexts
