# Cloudflare Wrangler Integration for Gokujo

This directory contains formal Lean 4 models of Cloudflare's Wrangler API and Cloudflare data types for integration with the Gokujo build system.

## Structure

```
tools/gokujo/Cloudflare/
├── Types.lean          # Core Cloudflare primitive types
├── Wrangler.lean       # Wrangler CLI command and configuration types
├── API.lean            # Cloudflare API endpoints and request/response types
├── WranglerAPI.lean    # Wrangler CLI integration with Cloudflare API
└── Integration.lean    # Gokujo-Wrangler integration for build pipelines
```

## Types Modeled

### Primitive Types (`Types.lean`)
- `AccountId`, `ZoneId`, `UserId`, `ApiToken`
- `ScriptName`, `KVNamespaceId`, `R2BucketName`, `D1DatabaseId`
- `DOClassName`, `DOId`, `PagesProjectName`
- `ISO8601Timestamp`, `UnixTimestamp`
- `HttpMethod`, `HttpStatus`, `HttpHeaders`

### Wrangler Types (`Wrangler.lean`)
- `WorkerConfig`, `WorkerEnv`, `WorkerKVBinding`, `WorkerR2Binding`
- `WorkerD1Binding`, `WorkerDOBinding`, `Worker`
- `Constraint`, `Environment`, `MemoryRecord`, `Skill`
- `AgentState`

### API Types (`API.lean`)
- `Endpoint`, `APIRequest`, `APIResponse`
- All Cloudflare API endpoints (Workers, KV, R2, D1, DO, Pages)
- Request/Response types for each service

### Integration Types (`WranglerAPI.lean`, `Integration.lean`)
- `WranglerCommandCategory`, `WranglerCLIConfig`
- `WranglerDevCommand`, `WranglerPublishCommand`, etc.
- `GokujoWranglerConfig`, `GokujoWranglerTarget`
- `GokujoWorkerProject`, `BuildPipeline`, `BuildPipelineStage`

## Usage

### Import the Cloudflare module

```lean
import Cloudflare.Types
import Cloudflare.Wrangler
import Cloudflare.API
import Cloudflare.WranglerAPI
import Cloudflare.GokujoIntegration
```

### Create a Worker configuration

```lean
open Cloudflare Wrangler

def myWorker : Worker :=
  { name := "my-worker"
  , config := 
      { name := "my-worker"
      , main := "index.js"
      , compatibility_date := "2024-01-01"
      , compatibility_flags := { date := "2024-01-01", flags := [] }
      }
  , env := []
  , kv := []
  , r2 := []
  , d1 := []
  , do_ := []
  }
```

### Create a Wrangler TOML configuration

```lean
open Cloudflare Wrangler

def myWranglerTOML : WranglerTOML :=
  { name := "my-worker"
  , main := "index.js"
  , compatibility_date := "2024-01-01"
  , kv_namespaces := [("MY_KV", "namespace-id-123")]
  , r2_buckets := [("MY_BUCKET", "my-bucket")]
  , d1_databases := [("MY_DB", "database-id-456")]
  , vars := []
  }
```

### Create a Gokujo Worker Project

```lean
open Cloudflare GokujoIntegration

def myProject : GokujoWorkerProject :=
  { projectName := "my-project"
  , workerName := "my-worker"
  , entryPoint := "index.js"
  , wranglerTOML := myWranglerTOML
  , buildPipeline := createBuildPipeline myWranglerTOML
  }
```

### Create deploy and test commands

```lean
open Cloudflare GokujoIntegration

def deployCmd := createDeployCommand myProject
def testCmd := createTestCommand myProject
```

## Cloudflare API Endpoints

All major Cloudflare API endpoints are modeled:

### Workers
- `workersListEndpoint` - GET /accounts/{account_id}/workers/scripts
- `workersGetEndpoint` - GET /accounts/{account_id}/workers/scripts/{script_name}
- `workersPutEndpoint` - PUT /accounts/{account_id}/workers/scripts/{script_name}
- `workersDeleteEndpoint` - DELETE /accounts/{account_id}/workers/scripts/{script_name}

### KV
- `kvListNamespacesEndpoint` - GET /accounts/{account_id}/workers/kv/namespaces
- `kvCreateNamespaceEndpoint` - POST /accounts/{account_id}/workers/kv/namespaces
- `kvKeyValueEndpoint` - GET /accounts/{account_id}/workers/kv/namespaces/{namespace_id}/values/{key}
- `kvListKeysEndpoint` - GET /accounts/{account_id}/workers/kv/namespaces/{namespace_id}/keys

### R2
- `r2ListBucketsEndpoint` - GET /accounts/{account_id}/r2/buckets
- `r2CreateBucketEndpoint` - PUT /accounts/{account_id}/r2/buckets/{bucket_name}
- `r2ObjectEndpoint` - GET /accounts/{account_id}/r2/buckets/{bucket_name}/objects/{key}

### D1
- `d1ListDatabasesEndpoint` - GET /accounts/{account_id}/d1/database
- `d1CreateDatabaseEndpoint` - POST /accounts/{account_id}/d1/database
- `d1QueryEndpoint` - POST /accounts/{account_id}/d1/database/{database_id}/query

### Durable Objects
- `doListClassesEndpoint` - GET /accounts/{account_id}/workers/durable_objects/classes
- `doGetClassEndpoint` - GET /accounts/{account_id}/workers/durable_objects/classes/{class_name}

### Pages
- `pagesListProjectsEndpoint` - GET /accounts/{account_id}/pages/projects
- `pagesGetProjectEndpoint` - GET /accounts/{account_id}/pages/projects/{project_name}
- `pagesListDeploymentsEndpoint` - GET /accounts/{account_id}/pages/projects/{project_name}/deployments

## Theorems

Each module includes theorems proving type safety and invariants:

- Type properties (e.g., `account_id_is_string`)
- Configuration validity (e.g., `worker_config_has_name`)
- API endpoint correctness (e.g., `workers_list_is_get`)
- Integration properties (e.g., `gokujo_worker_project_has_name`)

## Compilation

```bash
# Compile the Cloudflare module
cd /workspace/github__meta-introspector__lean-worker
. ~/.elan/env
LEAN_PATH=tools/gokujo/Cloudflare lean -R tools/gokujo/Cloudflare Types.lean
LEAN_PATH=tools/gokujo/Cloudflare lean -R tools/gokujo/Cloudflare Wrangler.lean
LEAN_PATH=tools/gokujo/Cloudflare lean -R tools/gokujo/Cloudflare API.lean
LEAN_PATH=tools/gokujo/Cloudflare lean -R tools/gokujo/Cloudflare WranglerAPI.lean
LEAN_PATH=tools/gokujo/Cloudflare lean -R tools/gokujo/Cloudflare Integration.lean
```

## Next Steps

1. Fill in the `sorry` placeholders with actual proofs
2. Add more detailed API response/request types
3. Integrate with actual Wrangler CLI via FFI
4. Add examples of complete build pipelines
5. Add validation theorems for Cloudflare configurations
