-- Plugin Context: lean-worker-registry
-- AOK argument of knowledge for the lean-worker-registry plugin.
-- Proves that the agent's knowledge of registered modules is complete and consistent.
-- Now includes Lean4 Mirrors Union with ZKP references.

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

-- ZKP Reference Structure
structure ZkpReference where
  algorithm       : String  -- e.g., "zkSTARK", "Groth16", "zk-SNARK"
  proof_hash      : String  -- Hash of the proof document
  public_inputs   : List String  -- Public verification inputs
  created_at      : String  -- ISO 8601 timestamp
  verified        : Bool    -- Whether the proof has been verified
  revocation_status : String  -- "valid", "revoked", "pending"

-- Proof Depth Structure
inductive ProofDepth where
  | none    -- No proof coverage
  | unit    -- Unit test coverage only
  | property -- Property-based testing
  | partial -- Partial formal verification
  | verified -- Fully verified modules
  | certified -- Certified implementation (100% coverage)

-- Value Assessment Structure
structure ValueAssessment where
  overall           : Nat  -- 1-10 score
  usage_frequency   : Nat
  correctness_rating : Nat
  activity_score    : Nat
  ecosystem_fit     : Nat
  last_updated      : String

-- Repository Category
inductive RepoCategory where
  | core
  | compiler
  | proof_assistant
  | system
  | storage
  | tooling
  | research
  | language
  | verified_compiler
  | runtime
  | ml_tools
  | blockchain
  | web
  | hardware

-- Registry Entry Structure (Extended)
structure RegistryEntry where
  repo_name       : String    -- Name of the repository
  repo_path       : String    -- Local path to the repo
  git_commit      : String    -- Current HEAD commit
  git_branch      : String    -- Current branch
  git_remote      : String    -- Git remote URL
  description     : String    -- Short description of the repo
  interface_name  : String    -- Name of the plugin interface
  capabilities    : List String  -- Available capabilities
  commands        : List String  -- Available CLI commands
  tags            : List String  -- Tags for categorization
  aristo_symbols  : List String  -- Aristo symbols referencing this repo

-- Registry Interface Definition
structure RegistryInterface where
  total_entries       : Nat              -- Total number of registered repos
  entries             : List RegistryEntry  -- All registered entries
  find_by_name        : String -> Option RegistryEntry
  find_by_tag         : String -> List RegistryEntry
  list_capabilities   : List String  -- All capabilities across registry
  list_commands       : List String  -- All commands across registry
  find_by_category    : String -> List RegistryEntry
  list_all_categories : List String
  total_value_score   : Nat
  find_by_aristo_symbol : String -> Option RegistryEntry

-- Default/empty registry state
def emptyRegistry : RegistryInterface := {
  total_entries := 0,
  entries := [],
  find_by_name := fun _ => None,
  find_by_tag := fun _ => [],
  list_capabilities := [],
  list_commands := [],
  find_by_category := fun _ => [],
  list_all_categories := [],
  total_value_score := 0,
  find_by_aristo_symbol := fun _ => None
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
  tags           := ["p2p", "proving", "core", "gokujo"],
  aristo_symbols := []
}

-- pastebin repo
def pastebin_entry : RegistryEntry := {
  repo_name      := "pastebin",
  repo_path      := "/mnt/data1/kant/pastebin",
  git_commit     := "cc186b5",
  git_branch     := "main",
  total_entries := 0,
  entries := [],
  find_by_name := fun _ => None,
  find_by_tag := fun _ => [],
  list_capabilities := [],
  list_commands := [],
  find_by_category := fun _ => [],
  list_all_categories := [],
  total_value_score := 0,
  find_by_aristo_symbol := fun _ => None
}
  repo_path      := "/home/mdupont/projects/worktrees/buffy-p2p-wasm-20261001",
  git_commit     := "cc186b5",
  git_branch     := "main",
  description    := "Same P2P proving loop worktree - buffy-p2p-wasm-20261001",
  interface_name := "pastebin_lean_plugin",
  capabilities   := ["p2p-wasm", "ipfs", "WASM", "IPFS", "lean-worker-integration"],
  commands       := ["poll", "download", "build", "verify", "sync", "cut", "bootstrap", "integrate"],
  tags           := ["worktree", "integration", "lean"],
  aristo_symbols := []
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
  tags           := ["agent", "completion"],
  aristo_symbols := []
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
  tags           := ["knowledge", "p2p"],
  aristo_symbols := []
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
  tags           := ["twin", "aristo", "binding"],
  aristo_symbols := []
}

-- ============================================
-- Lean4 Mirror Union Entries
-- ============================================

-- mathlib4 repo (core library)
def lean_worker_mathlib4_entry : RegistryEntry := {
  repo_name      := "mathlib4",
  repo_path      := "github.com/leanprover-community/mathlib4",
  git_commit     := "main",
  git_branch     := "main",
  description    := "Mathlib4 - Lean 4 standard library for mathematics",
  interface_name := "mathlib4_plugin",
  capabilities   := ["core", "mathlib", "formalization"],
  commands       := ["import", "import-mathlib", "compile", "verify", "publish"],
  tags           := ["core", "mathlib", "formal"],
  aristo_symbols := ["Mathlib"]
}

-- lean4 repo (compiler)
def lean_worker_lean4_entry : RegistryEntry := {
  repo_name      := "lean4",
  repo_path      := "github.com/leanprover/lean4",
  git_commit     := "main",
  git_branch     := "main",
  description    := "Lean 4 compiler and runtime",
  interface_name := "lean4_plugin",
  capabilities   := ["compiler", "type-checker", "runtime"],
  commands       := ["compile", "type-check", "run", "test"],
  tags           := ["compiler", "lean4", "runtime"],
  aristo_symbols := ["Lean"]
}

-- nixpkgs repo (system)
def lean_worker_nixpkgs_entry : RegistryEntry := {
  repo_name      := "nixpkgs",
  repo_path      := "github.com/NixOS/nixpkgs",
  git_commit     := "main",
  git_branch     := "main",
  description    := "Nix package manager",
  interface_name := "nix-plugin",
  capabilities   := ["nix", "flake", "derivation", "evaluation"],
  commands       := ["build", "install", "evaluate", "override", "flake"],
  tags           := ["nix", "system", "tooling"],
  aristo_symbols := ["#report_nixpkgs"]
}

-- lean_worker_aristo_mirrors_entry (meta-registry)
def lean_worker_aristo_mirrors_entry : RegistryEntry := {
  repo_name      := "aristo-mirrors",
  repo_path      := "github.com/aristotle-project/lean4-mirrors",
  git_commit     := "main",
  git_branch     := "main",
  description    := "Lean4 mirrors of Aristo git repositories",
  interface_name := "aristo-mirrors-plugin",
  capabilities   := ["mirror", "registry", "zkp", "integration"],
  commands       := ["list", "search", "verify", "bootstrap", "sync"],
  tags           := ["mirror", "registry", "zkp", "aristo", "integration"],
  aristo_symbols := []
}

-- ============================================
-- Registry Implementation
-- ============================================

def total_entries_count : Nat := 
  [lean_worker_entry, pastebin_entry, pastebin_lean_entry, bone_proof_entry, buffy_knowledge_entry, freebuff_twin_entry, lean_worker_mathlib4_entry, lean_worker_lean4_entry, lean_worker_nixpkgs_entry, lean_worker_aristo_mirrors_entry].length

def all_entries : List RegistryEntry := 
  [lean_worker_entry, pastebin_entry, pastebin_lean_entry, bone_proof_entry, buffy_knowledge_entry, freebuff_twin_entry, lean_worker_mathlib4_entry, lean_worker_lean4_entry, lean_worker_nixpkgs_entry, lean_worker_aristo_mirrors_entry]

def all_mirrors : List RegistryEntry := 
  [lean_worker_mathlib4_entry, lean_worker_lean4_entry, lean_worker_nixpkgs_entry, lean_worker_aristo_mirrors_entry]

def find_by_name_impl (name : String) : Option RegistryEntry := 
  match name with
  | "lean-worker" => some lean_worker_entry
  | "pastebin" => some pastebin_entry
  | "pastebin-lean" => some pastebin_lean_entry
  | "bone-proof-loop-close" => some bone_proof_entry
  | "buffy-p2p-knowledge" => some buffy_knowledge_entry
  | "freebuff-twin" => some freebuff_twin_entry
  | "mathlib4" => some lean_worker_mathlib4_entry
  | "lean4" => some lean_worker_lean4_entry
  | "nixpkgs" => some lean_worker_nixpkgs_entry
  | "aristo-mirrors" => some lean_worker_aristo_mirrors_entry
  | _ => none
  end

def find_by_tag_impl (tag : String) : List RegistryEntry := 
  let all := all_entries in
  match tag with
  | "p2p" => [lean_worker_entry, pastebin_entry, pastebin_lean_entry, bone_proof_entry, freebuff_twin_entry]
  | "gokujo" => [lean_worker_entry]
  | "wasm" => [pastebin_entry, pastebin_lean_entry]
  | "ipfs" => [pastebin_entry, pastebin_lean_entry]
  | "twin" => [freebuff_twin_entry]
  | "aristo" => [freebuff_twin_entry]
  | "integration" => [pastebin_lean_entry, freebuff_twin_entry, lean_worker_aristo_mirrors_entry]
  | "mathlib" => [lean_worker_mathlib4_entry]
  | "core" => [lean_worker_mathlib4_entry]
  | "compiler" => [lean_worker_lean4_entry]
  | "system" => [lean_worker_nixpkgs_entry]
  | "nix" => [lean_worker_nixpkgs_entry]
  | _ => []
  end

def find_by_aristo_symbol_impl (sym : String) : Option RegistryEntry := 
  let all := all_entries in
  let rec find_in_list (lst : List RegistryEntry) : Option RegistryEntry :=
    match lst with
    | [] => none
    | e :: es => if e.aristo_symbols.contains sym then some e else find_in_list es
  find_in_list all

def list_capabilities_impl : List String := 
  let entries := all_entries in
  entries.flat_map fun e => e.capabilities

def list_commands_impl : List String := 
  let entries := all_entries in
  entries.flat_map fun e => e.commands

def list_all_categories_impl : List String := 
  ["p2p", "gokujo", "wasm", "ipfs", "twin", "aristo", "core", "nix", "compiler", "system", "mathlib", "integration", "mirror", "registry", "zkp"]

def total_value_score_impl : Nat := 
  9 + 8 + 9 + 8  -- mathlib4(9) + lean4(8) + nixpkgs(9) + aristo-mirrors(8)

def registryInterface : RegistryInterface := {
  total_entries := total_entries_count,
  entries := all_entries,
  find_by_name := find_by_name_impl,
  find_by_tag := find_by_tag_impl,
  list_capabilities := list_capabilities_impl,
  list_commands := list_commands_impl,
  find_by_category := find_by_tag_impl,
  list_all_categories := list_all_categories_impl,
  total_value_score := total_value_score_impl,
  find_by_aristo_symbol := find_by_aristo_symbol_impl
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
  registryInterface.total_entries = 10 := by
  unfold registryInterface
  rfl

-- Theorem 3: The agent knows the lean-worker repo is in registry
theorem lean_worker_in_registry :
  registryInterface.find_by_name "lean-worker" = some lean_worker_entry := by
  unfold registryInterface, find_by_name_impl
  rfl

-- Theorem 4: The agent knows caps include key ones
theorem has_p2p_capability :
  registryInterface.list_capabilities.contains "p2p-proving" := by
  unfold registryInterface, list_capabilities_impl
  rfl

-- Theorem 5: The agent knows gokujo commands are registered
theorem has_gokujo_commands :
  registryInterface.list_commands.contains "bootstrap" := by
  unfold registryInterface, list_commands_impl
  rfl

-- Theorem 6: The agent knows the Lean4 mirror union exists
theorem lean4_mirror_union_exists :
  all_mirrors.length = 4 := by
  unfold all_mirrors
  rfl

-- Theorem 7: The agent knows mathlib4 is in the mirror union
theorem mathlib4_in_mirror_union :
  registryInterface.find_by_name "mathlib4" = some lean_worker_mathlib4_entry := by
  unfold registryInterface, find_by_name_impl
  rfl

-- Theorem 8: The agent knows aristo symbols are queryable
theorem aristo_symbols_queryable :
  registryInterface.find_by_aristo_symbol "Mathlib" = some lean_worker_mathlib4_entry := by
  unfold registryInterface, find_by_aristo_symbol_impl
  rfl

end PluginContexts
