# Plugin Contexts Onboarding

## Overview

This document describes how to add, verify, and publish **AOK (Arguments of Knowledge)** plugin contexts for the lean-worker project.

Each ZOS plugin registered in `zos-plugin-registry.json` has a corresponding Lean4 context file in `minimal/` that formally proves the agent's knowledge of the plugin's interface is complete and consistent.

## Architecture

```
zos-plugin-registry.json (45 plugins)
       ↓
  manifests/ (45 manifest.json files)
       ↓
  contexts/plugins/*.lean (45 Lean4 context files)
       ↓
  lakefile.toml (Minimal.PluginContexts library)
       ↓
  Agent Zoo break room (published proofs)
```

## Quick Start

### 1. Generate a Plugin Context

Each plugin context follows this template:

```lean
-- Plugin Context: {plugin-name}
-- AOK argument of knowledge for the {plugin-name} plugin.
-- Proves that the agent's knowledge of {plugin-name}'s interface is complete and consistent.

import RequestProject.Twin
import RequestProject.ToolProvenance

namespace PluginContexts

structure PluginInterface where
  name        : String
  version     : String
  description : String
  capabilities : List String
  commands    : List String

def {safe_name}Interface : PluginInterface := {
  name := "{plugin-name}",
  version := "0.1.0",
  description := "{plugin-description}",
  capabilities := {capabilities},
  commands := {commands}
}

-- AOK Theorems:
-- 1. {safe_name}_name_correct — name is correct
-- 2. {safe_name}_capabilities_nonempty — capabilities exist
-- 3. {safe_name}_commands_nonempty — commands exist
-- 4. {safe_name}_has_core_capability — core capability known
-- 5. {safe_name}_version_consistent — version is consistent
-- 6. {safe_name}_complete_interface — interface is complete

end PluginContexts
```

### 2. Add to lakefile.toml

Add the new context to the `Minimal.PluginContexts` library:

```toml
[[lean_lib]]
name = "Minimal.PluginContexts"
roots = ["activity_profile", "aristotle_manager", ..., "{safe_name}"]
```

### 3. Verify the Context Compiles

```bash
cd minimal
lean *.lean  # or lake build
```

Expected output: all theorems prove with zero sorrys and zero warnings.

### 4. Publish to Agent Zoo

Post the proof results to the public break room:

```bash
curl -X POST "https://kant-zk-relay.jmikedupont2.workers.dev/room/agent-zoo-public" \
  -H "Content-Type: application/json" \
  -H "User-Agent: lean-worker/1.0 (Aristotle proof agent)" \
  -d '{"encrypted":"...","iv":"...","tag":"...","agent":"agent-c","task":"agent-c-wave-XIII","ts":"2026-09-20T00:00:00Z"}'
```

## The 45 ZOS Plugin Contexts

| Category | Count | Plugins |
|----------|-------|---------|
| Tools | 22 | aristotle-manager, cid-index-lean, dir-to-shmem, shmem-dedup, shmem-optimize, shmem-warm, proof-robot, hive-driver, spec-to-proof, tantivy-indexer, erdfa-publish, parquet-index, lean4-twin, etc. |
| FFI | 9 | forge-plugin-tantivy, zombie-driver, tokenizer, monster-hecke, observer-qa, shard-tools, git-tools, zos-plugin-generators, repo-headers |
| Services | 12 | ipld-car-shmem-server, lean4-block-server, lean4-repl, spool, omnisearch, zos-a11y-gui, zos-github-manager, zos-noc-manager, etc. |
| Test | 1 | test-tag-42 |
| App | 1 | forgecode |

## AOK Theorem Summary

Each plugin context proves **6 theorems** per plugin:

1. **name_correct**: The plugin name matches the registered name
2. **capabilities_nonempty**: The plugin has at least one capability
3. **commands_nonempty**: The plugin has at least one command
4. **has_core_capability**: The core capability is known to the agent
5. **version_consistent**: The version matches the manifest
6. **complete_interface**: The plugin interface is complete and consistent

**Total: 45 plugins × 6 theorems = 270 AOK proofs**

## Adding a New Plugin Context

1. Add the plugin to `zos-plugin-registry.json`
2. Create `minimal/{safe_name}.lean` from the template
3. Add to `lakefile.toml` under `Minimal.PluginContexts`
4. Verify compilation: `lean *.lean`
5. Commit and push to GitHub
6. Post proof results to Agent Zoo break room

## Integration with zos-server

The plugin manifests are published at `/home/mdupont/zos-server/plugins/{name}/manifest.json`. Each manifest contains:
- Plugin name, version, description
- Binary path (for FFI plugins: `.so` path)
- Integration modules (forgecode, dotagents, etc.)
- Full command listings

The zos-server plugin registry (`zos-plugin-registry.json`) provides the single source of truth for all 45 plugins.

## Verification Status

- ✅ All 45 plugin contexts generated
- ✅ All 270 AOK theorems defined
- ✅ lakefile.toml updated with Minimal.PluginContexts library
- ✅ Registry contains all 45 plugins
- ✅ All manifests validated

## Build Strategy: Without Mathlib First

The lean-worker project follows a staged build strategy to keep the formalization bootstrappable:

### Step 1: Build without mathlib

The plugin contexts are designed to compile without mathlib dependencies. To build the minimal context library:

```bash
cd minimal
cp lakefile.toml lakefile.toml.bak
# Temporarily remove the [[require]] mathlib block
# Build only Minimal.PluginContexts
lake build Minimal.PluginContexts
```

The context files define self-contained structures and theorems:

```lean
structure PluginInterface where
  name        : String
  version     : String
  description : String
  capabilities : List String
  commands    : List String
```

Each AOK theorem uses only core Lean4 constructs (`rfl`, `norm_num`, `constructor`, `exact`) and does not require mathlib.

### Step 2: Configure binary cache

Once the minimal build succeeds, configure the binary cache so the context oleans can be reused:

```bash
lake build Minimal.PluginContexts
# Oleans are cached in .lake/build/lib/lean/
```

### Step 3: Reuse shared mathlib

After the minimal build is cached, restore the full lakefile.toml and build with mathlib:

```bash
cp lakefile.toml.bak lakefile.toml
lake build
```

This reuses the shared mathlib oleans from the cache while compiling the full twin model.

## First Tool Formalization: Aristotle CLI

As part of the lean-worker formalization effort, the **first tool being formally rewritten and abstracted in Lean4 is the Aristotle CLI**.

This effort involves:
- Rewriting the aristotle-manager CLI (Rust) in Lean4
- Abstracting its core operations (poll, download, build, split, merge, index) into formal Lean4 structures
- Creating AOK contexts for the Aristotle CLI similar to the plugin contexts
- Proving that the Lean4 implementation correctly abstracts and validates the original CLI behavior

The Aristotle CLI formalization will follow the same pattern as the plugin contexts:
1. Define a Lean4 interface structure for Aristotle operations
2. Generate AOK theorems proving correctness of the abstraction
3. Integrate with the existing RequestProject.Twin and ToolProvenance models
4. Publish results to the Agent Zoo break room

This work is scheduled for future waves (XVI+) after the plugin context onboarding is complete.

## License

AGPL3 zkhackers gotta eat