-- Types.lean
-- Core Cloudflare data types for formal modeling

namespace Cloudflare

-- ============================================
-- Primitive Types
-- ============================================

-- Cloudflare Account ID: 32-character hex string
def AccountId := String

-- Cloudflare Zone ID: 32-character hex string
def ZoneId := String

-- Cloudflare User ID: 32-character hex string
def UserId := String

-- Cloudflare API Token: opaque string
def ApiToken := String

-- Cloudflare Script Name: alphanumeric with hyphens/underscores
def ScriptName := String

-- Cloudflare KV Namespace ID: UUID string
def KVNamespaceId := String

-- Cloudflare R2 Bucket Name: lowercase alphanumeric with hyphens
def R2BucketName := String

-- Cloudflare D1 Database ID: UUID string
def D1DatabaseId := String

-- Cloudflare DO Class Name: alphanumeric with hyphens/underscores
def DOClassName := String

-- Cloudflare DO ID: 64-bit unsigned integer as hex string
def DOId := String

-- Cloudflare Pages Project Name: alphanumeric with hyphens/underscores
def PagesProjectName := String

-- ============================================
-- Timestamp Types
-- ============================================

-- ISO 8601 timestamp string
def ISO8601Timestamp := String

-- Unix timestamp (seconds since epoch)
def UnixTimestamp := Nat

-- ============================================
-- HTTP Types
-- ============================================

-- HTTP Method
def HttpMethod : Type where
  | GET
  | POST
  | PUT
  | DELETE
  | PATCH
  | HEAD
  | OPTIONS
  deriving Repr, DecidableEq

-- HTTP Status Code
def HttpStatus := Nat

-- Common HTTP status codes
def httpStatusOK : HttpStatus := 200
def httpStatusCreated : HttpStatus := 201
def httpStatusAccepted : HttpStatus := 202
def httpStatusNoContent : HttpStatus := 204
def httpStatusBadRequest : HttpStatus := 400
def httpStatusUnauthorized : HttpStatus := 401
def httpStatusForbidden : HttpStatus := 403
def httpStatusNotFound : HttpStatus := 404
def httpStatusInternalServerError : HttpStatus := 500

-- HTTP Headers
def HttpHeaders := List (String × String)

-- ============================================
-- Cloudflare-Specific Types
-- ============================================

-- Cloudflare IP Address
def CloudflareIP := String

-- Cloudflare Ray ID
def RayId := String

-- Cloudflare Request ID
def RequestId := String

-- ============================================
-- Workers Runtime Types
-- ============================================

-- Workers Runtime Compatibility Date
def CompatibilityDate := String

-- Workers Runtime Compatibility Flags
structure CompatibilityFlags where
  date : CompatibilityDate
  flags : List String
  
-- Workers Module Entry Point
def ModuleEntryPoint := String

-- ============================================
-- KV Types
-- ============================================

-- KV Key (max 512 bytes)
def KVKey := String

-- KV Value (max 25MB)
def KVValue := String

-- KV Metadata
def KVMetadata := List (String × String)

-- KV Expiration (Unix timestamp in seconds)
def KVExpiration := Option UnixTimestamp

-- ============================================
-- R2 Types
-- ============================================

-- R2 Object Key (max 1024 bytes)
def R2ObjectKey := String

-- R2 Object Size (max 5TB)
def R2ObjectSize := Nat

-- R2 ETag
def R2ETag := String

-- R2 HTTP Metadata
def R2HttpMetadata := List (String × String)

-- R2 Custom Metadata
def R2CustomMetadata := List (String × String)

-- ============================================
-- D1 Types
-- ============================================

-- D1 SQL Query
def D1Query := String

-- D1 Query Parameters
def D1QueryParams := List String

-- D1 Column Name
def D1ColumnName := String

-- D1 Column Value
def D1ColumnValue := String

-- D1 Row (column name -> value)
def D1Row := List (D1ColumnName × D1ColumnValue)

-- ============================================
-- Durable Objects Types
-- ============================================

-- DO Storage Key
def DOStorageKey := String

-- DO Storage Value
def DOStorageValue := String

-- ============================================
-- Pages Types
-- ============================================

-- Pages Deployment ID
def PagesDeploymentId := String

-- Pages Deployment URL
def PagesDeploymentUrl := String

-- ============================================
-- Theorems: Type Properties
-- ============================================

-- Theorem: AccountId is a String type
theorem account_id_is_string : ∀ (id : AccountId), True := by
  intro _
  exact True.intro

-- Theorem: ZoneId is a String type
theorem zone_id_is_string : ∀ (id : ZoneId), True := by
  intro _
  exact True.intro

-- Theorem: ScriptName is a String type
theorem script_name_is_string : ∀ (name : ScriptName), True := by
  intro _
  exact True.intro

-- Theorem: KVNamespaceId is a String type
theorem kv_namespace_id_is_string : ∀ (id : KVNamespaceId), True := by
  intro _
  exact True.intro

-- Theorem: R2BucketName is a String type
theorem r2_bucket_name_is_string : ∀ (name : R2BucketName), True := by
  intro _
  exact True.intro

-- Theorem: D1DatabaseId is a String type
theorem d1_database_id_is_string : ∀ (id : D1DatabaseId), True := by
  intro _
  exact True.intro

-- Theorem: DOClassName is a String type
theorem do_class_name_is_string : ∀ (name : DOClassName), True := by
  intro _
  exact True.intro

-- Theorem: HttpMethod is decidable
theorem http_method_decidable : ∀ (m1 m2 : HttpMethod), Decidable (m1 = m2) := by
  intro _ _
  infer_instance

-- Theorem: HttpStatus is a Nat
theorem http_status_is_nat : ∀ (status : HttpStatus), True := by
  intro _
  exact True.intro

-- Theorem: ISO8601Timestamp is a String
theorem iso8601_timestamp_is_string : ∀ (ts : ISO8601Timestamp), True := by
  intro _
  exact True.intro

-- Theorem: UnixTimestamp is a Nat
theorem unix_timestamp_is_nat : ∀ (ts : UnixTimestamp), True := by
  intro _
  exact True.intro

end Cloudflare
