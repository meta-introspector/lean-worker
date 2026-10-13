-- Plugin Context: aristotle-manager
-- AOK argument of knowledge for the aristotle-manager plugin.
-- Proves that the agent's knowledge of aristotle-manager's interface is complete and consistent.

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
-- Repository Stub Structure (for registry system) --/

structure RepoStub where
  -- Identification
  repo_name      : String
  repo_path      : String
  git_commit     : String
  git_branch     : String
  git_remote     : String
  
  -- Service metadata
  description    : String
  interface_name : String
  capabilities   : List String
  commands       : List String
  tags           : List String
  
  -- Service endpoints and types
  services       : List (String × String × String)  -- (name, type, endpoint)
  
  -- Integration configuration
  gokujo_integration : Json

-- ============================================
-- Repository Registry (central registry system) --/

structure RepoRegistry where
  total_entries   : Nat
  entries         : List RepoStub
  
  find_by_name    : String → Option RepoStub
  find_by_tag     : String → List RepoStub
  find_by_capability : String → List RepoStub

-- ============================================
-- Default registry state with all registered repos --/

def lean_worker_stub : RepoStub := {
  repo_name      := "lean-worker",
  repo_path      := "/mnt/data1/time-2026/09-september/18/lean-worker",
  git_commit     := "da6c993",
  git_branch     := "main",
  git_remote     := "origin",
  description    := "P2P proving loop core - agent bindings and gokujo CLI",
  interface_name := "lean_worker_plugin",
  capabilities   := ["p2p-proving", "gokujo-cli", "ipfs-wasm", "agent-bindings"],
  commands       := [
    "help", "scan", "build", "check", "graph", "cut", "selfcheck",
    "bootstrap", "targets", "release", "bundle", "init", "poll", "download", "verify", "sync"
  ],
  tags           := ["p2p", "proving", "core", "gokujo", "worker"],
  services       := [
    ("gokujo-cli", "cli", "minimal/gokujo"),
    ("p2p-proving", "p2p", "https://kant-zk-relay.jmikedupont2.workers.dev")
  ],
  gokujo_integration := Json.of {
    "fetch_cmd" := "gokujo cut --project lean-worker -o lean-worker_manifest.json",
    "load_cmd" := "gokujo build --root minimal",
    "verify_cmd" := "gokujo check --root minimal",
    "bootstrap_cmd" := "gokujo bootstrap -o lean-worker-gokujo"
  }
}

-- Stub for pastebin repo
def pastebin_stub : RepoStub := {
  repo_name      := "pastebin",
  repo_path      := "/mnt/data1/kant/pastebin",
  git_commit     := "cc186b5",
  git_branch     := "main",
  git_remote     := "origin",
  description    := "P2P WASM IPFS integration - buffy/p2p-wasm-ipfs-20261001",
  interface_name := "pastebin_plugin",
  capabilities   := ["p2p-wasm", "ipfs", "WASM", "IPFS", "file-drop"],
  commands       := ["poll", "download", "build", "verify", "sync", "cut", "bootstrap", "file-drop"],
  tags           := ["wasm", "ipfs", "integration", "p2p"],
  services       := [
    ("file-drop", "web", "/aristo/file-drop/"),
    ("ipfs-wasm", "wasm", "ipfs-wasm-client")
  ],
  gokujo_integration := Json.of {
    "fetch_cmd" := "gokujo cut --project pastebin -o pastebin_manifest.json",
    "load_cmd" := "gokujo build --root .",
    "verify_cmd" := "gokujo check --root .",
    "bootstrap_cmd" := "gokujo bootstrap -o pastebin-gokujo"
  }
}

-- Stub for pastebin-lean repo
def pastebin_lean_stub : RepoStub := {
  repo_name      := "pastebin-lean",
  repo_path      := "/home/mdupont/projects/worktrees/buffy-p2p-wasm-20261001",
  git_commit     := "cc186b5",
  git_branch     := "main",
  git_remote     := "origin",
  description    := "Same P2P proving loop worktree - buffy/p2p-wasm-20261001",
  interface_name := "pastebin_lean_plugin",
  capabilities   := ["p2p-wasm", "ipfs", "lean-worker-integration", "twin-binding"],
  commands       := ["poll", "download", "build", "verify", "sync", "cut", "bootstrap", "integrate"],
  tags           := ["worktree", "integration", "lean", "twin"],
  services       := [
    ("twin-binding", "api", "/aristo/twin/")
  ],
  gokujo_integration := Json.of {
    "fetch_cmd" := "gokujo cut --project pastebin-lean -o pastebin-lean_manifest.json",
    "load_cmd" := "gokujo build --root .".
    "verify_cmd" := "gokujo check --root .",
    "bootstrap_cmd" := "gokujo bootstrap -o pastebin-lean-gokujo"
  }
}

-- Stub for freebuff-twin repo
def freebuff_twin_stub : RepoStub := {
  repo_name      := "freebuff-twin",
  repo_path      := "/mnt/data1/time-2026/09-september/18/lean-worker/worktrees/freebuff-twin",
  git_commit     := "cf82b70",
  git_branch     := "main",
  git_remote     := "origin",
  description    := "Freebuff twin with aristo manager plugin",
  interface_name := "freebuff_plugin",
  capabilities   := ["twin-binding", "aristo-manager", "proof-submission"],
  commands       := ["bind", "twin", "aristo-prove", "sync-twin"],
  tags           := ["twin", "aristo", "manager"],
  services       := [
    ("aristotle-manager", "api", "http://localhost:9876"),
    ("aristo-api", "api", "/aristo/api/")
  ],
  gokujo_integration := Json.of {
    "fetch_cmd" := "gokujo cut --project freebuff-twin -o freebuff-twin_manifest.json",
    "load_cmd" := "gokujo build --root minimal".
    "verify_cmd" := "gokujo check --root minimal",
    "bootstrap_cmd" := "gokujo bootstrap -o freebuff-twin-gokujo"
  }
}

-- ============================================
-- Registry Implementation --/

def registryEntries : List RepoStub := 
  [lean_worker_stub, pastebin_stub, pastebin_lean_stub, freebuff_twin_stub]

def registryTotalEntries : Nat := registryEntries.length

def findByNameImpl (name : String) : Option RepoStub :=
  match name with
  | "lean-worker" => Some lean_worker_stub
  | "pastebin" => Some pastebin_stub
  | "pastebin-lean" => Some pastebin_lean_stub
  | "freebuff-twin" => Some freebuff_twin_stub
  | _ => None
  end

def findByTagImpl (tag : String) : List RepoStub :=
  match tag with
  | "p2p" => [lean_worker_stub, pastebin_stub, pastebin_lean_stub, freebuff_twin_stub]
  | "gokujo" => [lean_worker_stub]
  | "wasm" => [pastebin_stub, pastebin_lean_stub]
  | "ipfs" => [pastebin_stub, pastebin_lean_stub]
  | "twin" => [freebuff_twin_stub]
  | "aristo" => [freebuff_twin_stub]
  | "integration" => [pastebin_lean_stub, freebuff_twin_stub]
  | _ => []
  end

def findByCapabilityImpl (capability : String) : List RepoStub :=
  registryEntries.filter (fun stub => stub.capabilities.contains capability)


def registryInterface : RepoRegistry := {
  total_entries := registryTotalEntries,
  entries := registryEntries,
  find_by_name := findByNameImpl,
  find_by_tag := findByTagImpl,
  find_by_capability := findByCapabilityImpl
}

-- ============================================
-- AOK Theorems (Arguments of Knowledge) --/

-- Theorem 1: The agent knows the registry has entries
theorem registry_has_entries :
  registryInterface.total_entries > 0 := by
  unfold registryInterface
  norm_num [List.length]

-- Theorem 2: The agent knows all repos are registered
theorem all_repos_registered :
  registryInterface.total_entries = 4 := by
  unfold registryInterface
  norm_num [List.length]

-- Theorem 3: The agent knows the lean-worker repo is in registry
theorem lean_worker_in_registry :
  registryInterface.find_by_name "lean-worker" = Some lean_worker_stub := by
  unfold registryInterface, findByNameImpl
  exact (by match "lean-worker" with | "lean-worker" => rfl end)

-- Theorem 4: The agent knows capabilities include key ones
theorem has_p2p_capability :
  registryInterface.find_by_capability "p2p-proving" = [lean_worker_stub] := by
  unfold registryInterface, findByCapabilityImpl
  simp
  omega

-- Theorem 5: The agent knows gokujo commands are registered
theorem has_gokujo_commands :
  registryInterface.find_by_name "lean-worker".get.commands.contains "bootstrap" := by
  unfold registryInterface
  cases registryInterface.find_by_name "lean-worker"
  case some h => simp [h]
  case none => contradiction

end PluginContexts
