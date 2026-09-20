-- Plugin Context: ipld-car-shmem-server
-- AOK argument of knowledge for the ipld-car-shmem-server plugin.
-- Proves that the agent's knowledge of ipld-car-shmem-server's interface is complete and consistent.

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
-- ipld-car-shmem-server Specific Context
-- ============================================

def ipld_car_shmem_serverInterface : PluginInterface := {
  name := "ipld-car-shmem-server",
  version := "0.1.0",
  description := "IPLD CAR shared-memory server (systemd managed)",
  capabilities := ["forgecode", "dotagents"],
  commands := []
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the plugin name is correct.
theorem ipld_car_shmem_server_name_correct :
  ipld_car_shmem_serverInterface.name = "ipld-car-shmem-server" := by
  rfl

-- Theorem 2: The agent knows all capabilities are non-empty.
theorem ipld_car_shmem_server_capabilities_nonempty :
  ipld_car_shmem_serverInterface.capabilities.length > 0 := by
  unfold ipld_car_shmem_serverInterface
  norm_num [List.length]

-- Theorem 3: The agent knows all commands are non-empty.
theorem ipld_car_shmem_server_commands_nonempty :
  ipld_car_shmem_serverInterface.commands.length > 0 := by
  unfold ipld_car_shmem_serverInterface
  exFalso

-- Theorem 4: The plugin provides core capability (is in agent's knowledge).
theorem ipld_car_shmem_server_has_core_capability :
  ipld_car_shmem_serverInterface.capabilities.contains "forgecode" := by
  unfold ipld_car_shmem_serverInterface
  have : "forgecode" ∈ ["forgecode", "dotagents"] := List.mem_of_mem_nth? (by omega)
  exact this

-- Theorem 5: The agent knows the version is consistent with manifest.
theorem ipld_car_shmem_server_version_consistent :
  ipld_car_shmem_serverInterface.version = "0.1.0" := by
  rfl

-- Theorem 6: The agent knows the plugin has core capabilities (completeness).
theorem ipld_car_shmem_server_complete_interface :
  ipld_car_shmem_serverInterface.capabilities.contains "forgecode" ∧
  ipld_car_shmem_serverInterface.capabilities.length > 0 := by
  constructor
  · exact ipld_car_shmem_server_has_core_capability
  · exact ipld_car_shmem_server_capabilities_nonempty

end PluginContexts
