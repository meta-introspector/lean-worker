/-! GokujoInfra — Infrastructure generation for lean-worker
-/

namespace Infra

/-- The complete lean-worker project. -/
def project : String := "lean-worker"

/-- The version of the project. -/
def projectVersion : String := "0.1.0"

/-- The mathlib version used by the project. -/
def mathlibVersion : String := "v4.28.0"

/-- The Lean toolchain version. -/
def leanVersion : String := "v4.28.0"

/-- Generate the full lakefile.toml content for the project. -/
def lakefile : String :=
  "name = \"" ++ project ++ "\"\n" +
  "version = \"" ++ projectVersion ++ "\"\n" +
  "defaultTargets = [" ++ "RequestProject" ++ "]\n\n" +
  "[[require]]\n" +
  "name = \"mathlib4\"\n" +
  "revision = \"" ++ mathlibVersion ++ "\"\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject\"\n" +
  "dir = \"RequestProject\"\n" +
  "roots = [" ++
  "Agent, APICapabilities, CommandExecution, CreditUsage, ExecutionTrace, ToolProvenance, Twin, Main, ProxyReport" ++
  "]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject.Proxy\"\n" +
  "roots = [" ++
  "Concrete, Core, Dashboard, Example, Export, Interop, Monitor" ++
  "]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject.Protocol\"\n" +
  "roots = [" ++
  "Client, Core, Example, Server, Soundness" ++
  "]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject.PluginContexts\"\n" +
  "deps = [\"RequestProject\"]\n" +
  "roots = [" ++
  "activity_profile, aristotle_manager, aristotle_tools, cid_index_lean, dir_to_shmem, eco_research, emacs_search, erdfa_publish, forgecode, forgecode_extras, forge_plugin_tantivy, git_tools, harbor, hive_driver, index_to_shmem, ipld_car_shmem_client, ipld_car_shmem_server, lean4_block_server, lean4_cbor_bridge, lean4_repl, lean4_twin, leta_ipld_memory, monster_hecke, monster_voa, observer_qa, omnisearch, omnisearch_config, parquet_index, proof_robot, repo_headers, shard_tools, shmem_dedup, shmem_optimize, shmem_warm, spec_to_proof, spool, spool_source, tantivy_indexer, task_manager, test_tag_42, tokenizer, zombie_driver, zos_a11y_gui, zos_github_manager, zos_noc_manager, zos_plugin_generators" ++
  "]\n\n" +
  "[[lean_exe]]\n" +
  "name = \"proxy_report\"\n" +
  "root = \"ProxyReport\"\n\n" +
  "# gokujo integration\n" +
  "depends = [\"Gokujo\"]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"Gokujo\"\n" +
  "roots = [\"Gokujo.lean\", \"GokujoMain.lean\"]\n\n" +
  "# Execution scripts\n" +
  "depends = [\"ExecScript\"]\n\n" +
  "[[lean_exe]]\n" +
  "name = \"agent-c\"\n" +
  "root = \"AgentC/main\"\n\n" +
  "# Test suite\n" +
  "depends = [\"TestSuite\"]\n\n" +
  "[[lean_exe]]\n" +
  "name = \"test-suite\"\n" +
  "root = \"tests/run\"\n\n" +
  "cache = { enabled = true, directory = \".lake/cache\" }\n"

/-- Generate the fast-lakefile.toml content (no mathlib). -/
def fastLakefile : String :=
  "name = \"" ++ project ++ "\"\n" +
  "version = \"" ++ projectVersion ++ "\"\n" +
  "defaultTargets = [" ++ "RequestProject" ++ "]\n\n" +
  "# NO [[require]] = no mathlib, no network, fast for CI\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject\"\n" +
  "dir = \"RequestProject\"\n" +
  "roots = [" ++
  "Agent, APICapabilities, CommandExecution, CreditUsage, ExecutionTrace, ToolProvenance, Twin, Main, ProxyReport" ++
  "]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject.Proxy\"\n" +
  "roots = [" ++
  "Concrete, Core, Dashboard, Example, Export, Interop, Monitor" ++
  "]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject.Protocol\"\n" +
  "roots = [" ++
  "Client, Core, Example, Server, Soundness" ++
  "]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"RequestProject.PluginContexts\"\n" +
  "deps = [\"RequestProject\"]\n" +
  "roots = [" ++
  "activity_profile, aristotle_manager, aristotle_tools, cid_index_lean, dir_to_shmem, eco_research, emacs_search, erdfa_publish, forgecode, forgecode_extras, forge_plugin_tantivy, git_tools, harbor, hive_driver, index_to_shmem, ipld_car_shmem_client, ipld_car_shmem_server, lean4_block_server, lean4_cbor_bridge, lean4_repl, lean4_twin, leta_ipld_memory, monster_hecke, monster_voa, observer_qa, omnisearch, omnisearch_config, parquet_index, proof_robot, repo_headers, shard_tools, shmem_dedup, shmem_optimize, shmem_warm, spec_to_proof, spool, spool_source, tantivy_indexer, task_manager, test_tag_42, tokenizer, zombie_driver, zos_a11y_gui, zos_github_manager, zos_noc_manager, zos_plugin_generators" ++
  "]\n\n" +
  "[[lean_exe]]\n" +
  "name = \"proxy_report\"\n" +
  "root = \"ProxyReport\"\n\n" +
  "# Add gokujo to the project\n" +
  "depends = [\"Gokujo\"]\n\n" +
  "[[lean_lib]]\n" +
  "name = \"Gokujo\"\n" +
  "roots = [\"Gokujo.lean\", \"GokujoMain.lean\"]\n\n" +
  "# Add execution scripts for agent-c and testing\n" +
  "depends = [\"ExecScript\"]\n\n" +
  "[[lean_exe]]\n" +
  "name = \"agent-c\"\n" +
  "root = \"AgentC/main\"\n\n" +
  "# Add test suite scripts\n" +
  "depends = [\"TestSuite\"]\n\n" +
  "[[lean_exe]]\n" +
  "name = \"test-suite\"\n" +
  "root = \"tests/run\"\n\n" +
  "# Cache configuration for fast builds\n" +
  "cache = { enabled = true, directory = \".lake/cache\" }\n"

/-- Generate the flake.nix content. -/
def flakeNix : String :=
  "# Lean 4 project with gokujo integration\n" +
  "# Generated by gokujo " ++ version ++ "\n\n" +
  "{ inputs = {\n" +
  "  nixpkgs.url = \"github:NixOS/nixpkgs/nixos-unstable\";\n" +
  "  flake-utils.url = \"github:numtide/flake-utils\";\n" +
  "  lean4.url = \"github:leanprover/lean4\";\n" +
  "};\n\n" +
  "outputs = { self, nixpkgs, flake-utils, lean4 }:\n" +
  "let\n" +
  "  system = flake-utils.lib.system;\n" +
  "  pkgs = nixpkgs.legacyPackages.${system};\n" +
  "  leanPkgs = lean4.packages.${system};\n" +
  "in\n" +
  "{\n" +
  "  devShells =\n" +
  "    flake-utils.lib.eachDefaultSystem\n" +
  "      (system: import ./devshell.nix { inherit system pkgs leanPkgs });\n\n" +
  "  packages =\n" +
  "    flake-utils.lib.eachDefaultSystem\n" +
  "      (system: {\n" +
  "        default = leanPkgs.leanBuildProject {\n" +
  "          src = ./.;\n" +
  "          leanVersion = \"" ++ leanVersion ++ "\";\n" +
  "          mathlibVersion = \"" ++ mathlibVersion ++ "\";\n" +
  "        };\n" +
  "        gokujo = leanPkgs.leanBuildProject {\n" +
  "          src = ./.;\n" +
  "          leanVersion = \"" ++ leanVersion ++ "\";\n" +
  "          mathlibVersion = \"" ++ mathlibVersion ++ "\";\n" +
  "        };\n" +
  "      });\n\n" +
  "  checks =\n" +
  "    flake-utils.lib.eachDefaultSystem\n" +
  "      (system: {\n" +
  "        stage1 = leanPkgs.leanBuildProject {\n" +
  "          src = ./.;\n" +
  "          leanVersion = \"" ++ leanVersion ++ "\";\n" +
  "          mathlibVersion = \"" ++ mathlibVersion ++ "\";\n" +
  "          targets = [\"RequestProject\"];\n" +
  "        };\n" +
  "        stage2 = leanPkgs.leanBuildProject {\n" +
  "          src = ./.;\n" +
  "          leanVersion = \"" ++ leanVersion ++ "\";\n" +
  "          mathlibVersion = \"" ++ mathlibVersion ++ "\";\n" +
  "          targets = [\"RequestProject\"] ++ [\"Gokujo\"] ++ [\"ExecScript\"];\n" +
  "        };\n" +
  "      });\n" +
  "}\n\n" +
  "# Two-stage build: stage1 (no mathlib) → stage2 (full)\\n" +
  "# Stage 1: fast iteration, ~5s\\n" +
  "# Stage 2: full verification, ~30s\\n" +
  "# Caching: shared .lake/ directory across stages\\n" +
  "# Mathlib: shared cache via .lake/packages/mathlib4\\n\\n" +
  "# pipelight.dev integration\\n" +
  "# stage1-fast, stage2-full, stage3-gokujo\\n" +
  "# CI: matrix builds for all backends\\n" +
  "# Agent workflows: agent-a, agent-b, agent-c\n"
/-- Generate the GitHub Actions workflow content. -/
def githubWorkflow : String :=
  "name: Lean 4 CI\n" +
  "on:\n" +
  "  push:\n" +
  "    branches: [ main ]\n" +
  "  pull_request:\n" +
  "    branches: [ main ]\n\n" +
  "jobs:\n" +
  "  build-and-test:\n" +
  "    runs-on: ubuntu-latest\n" +
  "    strategy:\n" +
  "      matrix:\n" +
  "        backend: [standalone, bundled, system, elan, lake, nix]\n" +
  "    steps:\n" +
  "      - uses: actions/checkout@v4\n" +
  "      - name: Setup environment\n" +
  "        run: echo \"Ready for gokujo build\"\n" +
  "      - name: Run comprehensive verification\n" +
  "        run: ./minimal/Gokujo.lean check minimal/RequestProject\n" +
  "      - name: Build native artifacts\n" +
  "        run: ./minimal/Gokujo.lean bootstrap -o lean-worker --backend ${{ matrix.backend }}\n"

/-- Generate the pipelight.yml content. -/
def pipelightYml : String :=
  "stages:\n" +
  "  - name: stage1-fast\n" +
  "    description: Fast iteration build (no mathlib)\n" +
  "    duration: ~5s\n" +
  "    targets: [RequestProject]\n" +
  "    cache: .lake/cache\n" +
  "  - name: stage2-full\n" +
  "    description: Full verification (with mathlib)\n" +
  "    duration: ~30s\n" +
  "    targets: [RequestProject, Gokujo, ExecScript]\n" +
  "    cache: .lake/cache\n" +
  "    mathlib: v4.28.0\n" +
  "  - name: stage3-gokujo\n" +
  "    description: Single-file verification gate\n" +
  "    duration: ~10s\n"
end Infra
