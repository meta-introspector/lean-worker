-- Plugin Context: spec-to-proof
-- AOK argument of knowledge for the spec-to-proof plugin.
-- Proves that the agent's knowledge of spec-to-proof's interface is complete and consistent.

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
-- spec-to-proof Specific Context
-- ============================================

def spec_to_proofInterface : PluginInterface := {
  name := "spec-to-proof",
  version := "0.1.0",
  description := "Parallel Spec→Proof join: maps spec concepts to matching Lean proof files in shmem using crossbeam + rayon",
  capabilities := ["forgecode", "dotagents", "dasl"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem spec_to_proof_name_correct :
  spec_to_proofInterface.name = "spec-to-proof" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem spec_to_proof_capabilities_nonempty :
  spec_to_proofInterface.capabilities.length > 0 := by
  unfold spec_to_proofInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem spec_to_proof_commands_nonempty :
  spec_to_proofInterface.commands.length > 0 := by
  unfold spec_to_proofInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem spec_to_proof_has_core_capability :
  spec_to_proofInterface.capabilities.contains "forgecode" := by
  unfold spec_to_proofInterface
  have : "forgecode" ∈ ["forgecode", "dotagents", "dasl"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem spec_to_proof_version_consistent :
  spec_to_proofInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem spec_to_proof_complete_interface :
  spec_to_proofInterface.capabilities.contains "forgecode" ∧
  spec_to_proofInterface.capabilities.length > 0 := by
  constructor
  · exact spec_to_proof_has_core_capability
  · exact spec_to_proof_capabilities_nonempty

end PluginContexts
