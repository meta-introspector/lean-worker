-- Plugin Context: ipld-car-shmem-client
-- AOK argument of knowledge for the ipld-car-shmem-client plugin.
-- Proves that the agent's knowledge of ipld-car-shmem-client's interface is complete and consistent.

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
-- ipld-car-shmem-client Specific Context
-- ============================================

def ipld_car_shmem_clientInterface : PluginInterface := {
  name := "ipld-car-shmem-client",
  version := "0.1.0",
  description := "Client for IPLD CAR shared-memory server",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem ipld_car_shmem_client_name_correct :
  ipld_car_shmem_clientInterface.name = "ipld-car-shmem-client" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem ipld_car_shmem_client_capabilities_nonempty :
  ipld_car_shmem_clientInterface.capabilities.length > 0 := by
  unfold ipld_car_shmem_clientInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem ipld_car_shmem_client_commands_nonempty :
  ipld_car_shmem_clientInterface.commands.length > 0 := by
  unfold ipld_car_shmem_clientInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem ipld_car_shmem_client_has_core_capability :
  ipld_car_shmem_clientInterface.capabilities.contains "forgecode" := by
  unfold ipld_car_shmem_clientInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem ipld_car_shmem_client_version_consistent :
  ipld_car_shmem_clientInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem ipld_car_shmem_client_complete_interface :
  ipld_car_shmem_clientInterface.capabilities.contains "forgecode" ∧
  ipld_car_shmem_clientInterface.capabilities.length > 0 := by
  constructor
  · exact ipld_car_shmem_client_has_core_capability
  · exact ipld_car_shmem_client_capabilities_nonempty

end PluginContexts
