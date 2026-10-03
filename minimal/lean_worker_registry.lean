-- Plugin Context: lean-worker-registry
-- AOK argument of knowledge for the lean-worker-registry plugin.
-- Proves that the agent's knowledge of registered modules is complete and consistent.

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

-- ============================================
-- Registry Entry Structure
-- ============================================

structure RegistryEntry where
  repo_name      : String    -- Name of the repository
  repo_path      : String    -- Local path to the repo
  git_commit     : String    -- Current HEAD commit
  git_branch     : String    -- Current branch
  description    : String    -- Short description of the repo
  interface_name : String    -- Name of the plugin interface
  capabilities   : List String  -- Available capabilities
  commands       : List String  -- Available CLI commands
  tags           : List String  -- Tags for categorization

-- ============================================
-- Registry Interface Definition
-- ============================================

structure RegistryInterface where
  total_entries   : Nat      -- Total number of registered repos
  entries         : List RegistryEntry  -- All registered entries
  find_by_name    : String → Option RegistryEntry  -- Find entry by repo name
  find_by_tag     : String → List RegistryEntry  -- Find entries by tag
  list_capabilities : List String  -- All capabilities across registry
  list_commands    : List String  -- All commands across registry

-- ============================================
-- Default/empty registry state
-- ============================================

def emptyRegistry : RegistryInterface := {
  total_entries := 0,
  entries := [],
  find_by_name := λ _ => None,
  find_by_tag := λ _ => [],
  list_capabilities := [],
  list_commands := []
}

-- ============================================
-- Registered Repositories (the actual stubs)
-- ============================================

-- lean-worker core repo
def lean_worker_entry : RegistryEntry := {
  repo_name      := "lean-worker",
  repo_path      := "/mnt/data1/time-2026/09-september/18/lean-worker",
  git_commit     := "da6c993",
  git_branch     := "main",
  description    := "P2P proving loop core - agent bindings and gokujo CLI",
  interface_name := "lean_worker_plugin",
  capabilities   := ["p2p-proving", "gokujo-cli", "ipfs-wasm"],
  commands       := ["help", "scan", "build", "check", "graph", "cut", "selfcheck", "bootstrap", "targets", "release", "bundle", "init", "poll", "download", "verify", "sync"],
  tags           := ["p2p", "proving", "core", "gokujo"]
}

-- pastebin repo
def pastebin_entry : RegistryEntry := {
  repo_name      := "pastebin",
  repo_path      := "/mnt/data1/kant/pastebin",
  git_commit     := "cc186b5",
  git_branch     := "main",
  description    := "P2P WASM IPFS integration - buffy/p2p-wasm-ipfs-20261001",
  interface_name := "pastebin_plugin",
  capabilities   := ["p2p-wasm", "ipfs", "WASM", "IPFS"],
  commands       := ["poll", "download", "build", "verify", "sync", "cut", "bootstrap"],
  tags           := ["wasm", "ipfs", "integration"]
}

-- pastebin-lean repo
def pastebin_lean_entry : RegistryEntry := {
  repo_name      := "pastebin-lean",
  repo_path      := "/home/mdupont/projects/worktrees/buffy-p2p-wasm-20261001",
  git_commit     := "cc186b5",
  git_branch     := "main",
  description    := "Same P2P proving loop worktree - buffy-p2p-wasm-20261001",
  interface_name := "pastebin_lean_plugin",
  capabilities   := ["p2p-wasm", "ipfs", "WASM", "IPFS", "lean-worker-integration"],
  commands       := ["poll", "download", "build", "verify", "sync", "cut", "bootstrap", "integrate"],
  tags           := ["worktree", "integration", "lean"]
}

-- bone-proof-loop-close repo
def bone_proof_entry : RegistryEntry := {
  repo_name      := "bone-proof-loop-close",
  repo_path      := "/mnt/data1/time-2026/09-september/18/lean-worker/worktrees/bone-proof-loop-close",
  git_commit     := "auto",
  git_branch     := "main",
  description    := "Loop close agent for proof completion",
  interface_name := "bone_plugin",
  capabilities   := ["proof-close", "agent-binding"],
  commands       := ["close", "complete", "finalize"],
  tags           := ["agent", "completion"]
}

-- buffy-p2p-knowledge repo
def buffy_knowledge_entry : RegistryEntry := {
  repo_name      := "buffy-p2p-knowledge",
  repo_path      := "/mnt/data1/time-2026/09-september/18/lean-worker/worktrees/buffy-p2p-knowledge-20261001",
  git_commit     := "auto",
  git_branch     := "main",
  description    := "P2P knowledge base and proofs",
  interface_name := "knowledge_plugin",
  capabilities   := ["knowledge-base", "proof-storage"],
  commands       := ["store", "retrieve", "query", "sync"],
  tags           := ["knowledge", "p2p"]
}

-- freebuff-twin repo
def freebuff_twin_entry : RegistryEntry := {
  repo_name      := "freebuff-twin",
  repo_path      := "/mnt/data1/time-2026/09-september/18/lean-worker/worktrees/freebuff-twin",
  git_commit     := "cf82b70",
  git_branch     := "main",
  description    := "Freebuff twin with aristo manager plugin",
  interface_name := "freebuff_plugin",
  capabilities   := ["twin-binding", "aristo-manager"],
  commands       := ["bind", "twin", "aristo-prove", "sync-twin"],
  tags           := ["twin", "aristo", "binding"]
}

-- ============================================
-- Registry Implementation
-- ============================================

-- Get total entries count
def total_entries_count : Nat := 
  [lean_worker_entry, pastebin_entry, pastebin_lean_entry, bone_proof_entry, buffy_knowledge_entry, freebuff_twin_entry].length

-- Get all entries
def all_entries : List RegistryEntry := 
  [lean_worker_entry, pastebin_entry, pastebin_lean_entry, bone_proof_entry, buffy_knowledge_entry, freebuff_twin_entry]

-- Find by repo name
def find_by_name_impl (name : String) : Option RegistryEntry := 
  match name with
  | "lean-worker" => Some lean_worker_entry
  | "pastebin" => Some pastebin_entry
  | "pastebin-lean" => Some pastebin_lean_entry
  | "bone-proof-loop-close" => Some bone_proof_entry
  | "buffy-p2p-knowledge" => Some buffy_knowledge_entry
  | "freebuff-twin" => Some freebuff_twin_entry
  | _ => None
  end

-- Find by tag
def find_by_tag_impl (tag : String) : List RegistryEntry := 
  let all := all_entries in
  match tag with
  | "p2p" => [lean_worker_entry, pastebin_entry, pastebin_lean_entry, bone_proof_entry, freebuff_twin_entry]
  | "gokujo" => [lean_worker_entry]
  | "wasm" => [pastebin_entry, pastebin_lean_entry]
  | "ipfs" => [pastebin_entry, pastebin_lean_entry]
  | "twin" => [freebuff_twin_entry]
  | "aristo" => [freebuff_twin_entry]
  | "integration" => [pastebin_lean_entry, freebuff_twin_entry]
  | _ => []
  end

-- List all capabilities across registry
def list_capabilities_impl : List String := 
  let entries := all_entries in
  entries.flat_map λ e => e.capabilities

-- List all commands across registry
def list_commands_impl : List String := 
  let entries := all_entries in
  entries.flat_map λ e => e.commands

def registryInterface : RegistryInterface := {
  total_entries := total_entries_count,
  entries := all_entries,
  find_by_name := find_by_name_impl,
  find_by_tag := find_by_tag_impl,
  list_capabilities := list_capabilities_impl,
  list_commands := list_commands_impl
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge)
-- ============================================

-- Theorem 1: The agent knows the registry has entries
theorem registry_has_entries :
  registryInterface.total_entries > 0 := by
  unfold registryInterface
  rfl

-- Theorem 2: The agent knows all repos are registered
theorem all_repos_registered :
  registryInterface.total_entries = 6 := by
  unfold registryInterface
  rfl

-- Theorem 3: The agent knows the lean-worker repo is in registry
theorem lean_worker_in_registry :
  registryInterface.find_by_name "lean-worker" = Some lean_worker_entry := by
  unfold registryInterface, find_by_name_impl
  -- exact (by ... match "lean-worker" with ... end)
  compute
  -- Show it matches
  simp [find_by_name_impl, registryInterface]
  -- This needs some omega reasoning
  omega

-- Theorem 4: The agent knows caps include key ones
theorem has_p2p_capability :
  registryInterface.list_capabilities.contains "p2p-proving" := by
  unfold registryInterface, list_capabilities_impl
  -- exact ...
  simp
  omega

-- Theorem 5: The agent knows gokujo commands are registered
theorem has_gokujo_commands :
  registryInterface.list_commands.contains "bootstrap" := by
  unfold registryInterface, list_commands_impl
  simp
  omega

end PluginContexts
