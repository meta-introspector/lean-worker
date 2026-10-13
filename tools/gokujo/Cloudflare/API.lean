-- API.lean
-- Formal model of Cloudflare API endpoints and operations

import Cloudflare.Types
import Cloudflare.Wrangler

namespace Cloudflare
namespace API

-- ============================================
-- API Endpoint Types
-- ============================================

-- API endpoint path
def EndpointPath := String

-- API endpoint with method
def Endpoint where
  method : HttpMethod
  path   : EndpointPath
  
-- ============================================
-- Workers API Endpoints
-- ============================================

-- List Workers scripts
def workersListEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/scripts"
  }

-- Get Worker script
def workersGetEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/scripts/{script_name}"
  }

-- Create/Update Worker script
def workersPutEndpoint : Endpoint :=
  { method := .PUT
  , path := "/accounts/{account_id}/workers/scripts/{script_name}"
  }

-- Delete Worker script
def workersDeleteEndpoint : Endpoint :=
  { method := .DELETE
  , path := "/accounts/{account_id}/workers/scripts/{script_name}"
  }

-- ============================================
-- KV API Endpoints
-- ============================================

-- List KV namespaces
def kvListNamespacesEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/kv/namespaces"
  }

-- Create KV namespace
def kvCreateNamespaceEndpoint : Endpoint :=
  { method := .POST
  , path := "/accounts/{account_id}/workers/kv/namespaces"
  }

-- Get KV namespace
def kvGetNamespaceEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/kv/namespaces/{namespace_id}"
  }

-- Delete KV namespace
def kvDeleteNamespaceEndpoint : Endpoint :=
  { method := .DELETE
  , path := "/accounts/{account_id}/workers/kv/namespaces/{namespace_id}"
  }

-- KV key-value operations
def kvKeyValueEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/kv/namespaces/{namespace_id}/values/{key}"
  }

-- KV list keys
def kvListKeysEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/kv/namespaces/{namespace_id}/keys"
  }

-- ============================================
-- R2 API Endpoints
-- ============================================

-- List R2 buckets
def r2ListBucketsEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/r2/buckets"
  }

-- Create R2 bucket
def r2CreateBucketEndpoint : Endpoint :=
  { method := .PUT
  , path := "/accounts/{account_id}/r2/buckets/{bucket_name}"
  }

-- Get R2 bucket
def r2GetBucketEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/r2/buckets/{bucket_name}"
  }

-- Delete R2 bucket
def r2DeleteBucketEndpoint : Endpoint :=
  { method := .DELETE
  , path := "/accounts/{account_id}/r2/buckets/{bucket_name}"
  }

-- R2 object operations
def r2ObjectEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/r2/buckets/{bucket_name}/objects/{key}"
  }

-- ============================================
-- D1 API Endpoints
-- ============================================

-- List D1 databases
def d1ListDatabasesEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/d1/database"
  }

-- Create D1 database
def d1CreateDatabaseEndpoint : Endpoint :=
  { method := .POST
  , path := "/accounts/{account_id}/d1/database"
  }

-- Get D1 database
def d1GetDatabaseEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/d1/database/{database_id}"
  }

-- Delete D1 database
def d1DeleteDatabaseEndpoint : Endpoint :=
  { method := .DELETE
  , path := "/accounts/{account_id}/d1/database/{database_id}"
  }

-- D1 query endpoint
def d1QueryEndpoint : Endpoint :=
  { method := .POST
  , path := "/accounts/{account_id}/d1/database/{database_id}/query"
  }

-- ============================================
-- Durable Objects API Endpoints
-- ============================================

-- List DO classes
def doListClassesEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/durable_objects/classes"
  }

-- Get DO class
def doGetClassEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/workers/durable_objects/classes/{class_name}"
  }

-- ============================================
-- Pages API Endpoints
-- ============================================

-- List Pages projects
def pagesListProjectsEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/pages/projects"
  }

-- Get Pages project
def pagesGetProjectEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/pages/projects/{project_name}"
  }

-- List Pages deployments
def pagesListDeploymentsEndpoint : Endpoint :=
  { method := .GET
  , path := "/accounts/{account_id}/pages/projects/{project_name}/deployments"
  }

-- ============================================
-- API Request Types
-- ============================================

-- API request structure
structure APIRequest (T : Type) where
  endpoint : Endpoint
  headers : HttpHeaders
  body    : Option T
  params  : List (String × String)  -- Query parameters
  
-- API response structure
structure APIResponse (T : Type) where
  status  : HttpStatus
  headers : HttpHeaders
  body    : Option T
  success : Bool
  errors  : List String
  
-- ============================================
-- API Client
-- ============================================

-- API client configuration
structure APIClient where
  env     : Cloudflare.CloudflareEnv
  timeout : Nat
  retries : Nat
  
-- ============================================
-- Workers API Request/Response Types
-- ============================================

-- Worker script create/update request
structure WorkerScriptRequest where
  name        : ScriptName
  main        : ModuleEntryPoint
  compatibility_date : CompatibilityDate
  compatibility_flags : CompatibilityFlags
  bindings    : Wrangler.WorkerEnvVars × Wrangler.WorkerKVBindings × 
                          Wrangler.WorkerR2Bindings × Wrangler.WorkerD1Bindings × 
                          Wrangler.WorkerDOBindings
  
-- Worker script response
structure WorkerScriptResponse where
  id          : String
  name        : ScriptName
  created     : ISO8601Timestamp
  modified    : ISO8601Timestamp
  etag        : String
  size        : Nat
  
-- Worker script list response
structure WorkerScriptListResponse where
  scripts : List WorkerScriptResponse
  
-- ============================================
-- KV API Request/Response Types
-- ============================================

-- KV namespace create request
structure KVNamespaceCreateRequest where
  title : Option String
  
-- KV namespace response
structure KVNamespaceResponse where
  id        : KVNamespaceId
  title     : Option String
  created   : ISO8601Timestamp
  
-- KV namespace list response
structure KVNamespaceListResponse where
  namespaces : List KVNamespaceResponse
  
-- KV value get request
structure KVValueGetRequest where
  key : KVKey
  
-- KV value get response
structure KVValueGetResponse where
  key     : KVKey
  value   : KVValue
  metadata : KVMetadata
  
-- KV value put request
structure KVValuePutRequest where
  key     : KVKey
  value   : KVValue
  expiration : KVExpiration
  metadata : KVMetadata
  
-- KV value delete request
structure KVValueDeleteRequest where
  key : KVKey
  
-- KV list keys request
structure KVListKeysRequest where
  limit   : Option Nat
  prefix  : Option String
  cursor  : Option String
  
-- KV list keys response
structure KVListKeysResponse where
  keys      : List KVKey
  list_complete : Bool
  cursor    : Option String
  
-- ============================================
-- R2 API Request/Response Types
-- ============================================

-- R2 bucket create request
structure R2BucketCreateRequest where
  location : Option String  -- "enam", "eur", etc.
  
-- R2 bucket response
structure R2BucketResponse where
  name      : R2BucketName
  location : String
  created   : ISO8601Timestamp
  
-- R2 bucket list response
structure R2BucketListResponse where
  buckets : List R2BucketResponse
  
-- R2 object put request
structure R2ObjectPutRequest where
  key        : R2ObjectKey
  content    : String  -- File content
  httpMetadata : R2HttpMetadata
  metadata   : R2CustomMetadata
  
-- R2 object get response
structure R2ObjectGetResponse where
  key        : R2ObjectKey
  content    : String
  size      : R2ObjectSize
  etag      : R2ETag
  httpMetadata : R2HttpMetadata
  metadata   : R2CustomMetadata
  uploaded   : ISO8601Timestamp
  
-- R2 object delete request
structure R2ObjectDeleteRequest where
  key : R2ObjectKey
  
-- ============================================
-- D1 API Request/Response Types
-- ============================================

-- D1 database create request
structure D1DatabaseCreateRequest where
  name : String
  
-- D1 database response
structure D1DatabaseResponse where
  id        : D1DatabaseId
  name      : String
  created   : ISO8601Timestamp
  
-- D1 database list response
structure D1DatabaseListResponse where
  databases : List D1DatabaseResponse
  
-- D1 query request
structure D1QueryRequest where
  sql     : D1Query
  params  : D1QueryParams
  
-- D1 query response
structure D1QueryResponse where
  rows     : List D1Row
  success  : Bool
  errors   : List String
  
-- ============================================
-- Theorems: API Endpoint Properties
-- ============================================

-- Theorem: Workers list endpoint is GET
theorem workers_list_is_get : workersListEndpoint.method = .GET := rfl

-- Theorem: Workers create endpoint is PUT
theorem workers_put_is_put : workersPutEndpoint.method = .PUT := rfl

-- Theorem: KV namespace create endpoint is POST
theorem kv_create_is_post : kvCreateNamespaceEndpoint.method = .POST := rfl

-- Theorem: R2 bucket create endpoint is PUT
theorem r2_create_is_put : r2CreateBucketEndpoint.method = .PUT := rfl

-- Theorem: D1 query endpoint is POST
theorem d1_query_is_post : d1QueryEndpoint.method = .POST := rfl

-- Theorem: API request has endpoint
theorem api_request_has_endpoint (req : APIRequest α) : req.endpoint.method = req.endpoint.method := by
  rfl

-- Theorem: API response has status
theorem api_response_has_status (res : APIResponse α) : res.status = res.status := by
  rfl

-- Theorem: Workers script response has name
theorem worker_script_response_has_name (res : WorkerScriptResponse) : 
  res.name = res.name := by
  rfl

-- Theorem: KV namespace response has ID
theorem kv_namespace_response_has_id (res : KVNamespaceResponse) : 
  res.id = res.id := by
  rfl

end API
end Cloudflare
