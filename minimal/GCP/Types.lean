-- GCP Types
-- Formal model of Google Cloud Platform types
-- Aligned with the AWS model pattern (tools/gokujo/AWS/Types.lean)

namespace GCP

-- ============================================
-- Primitive Types
-- ============================================

-- GCP Project ID
abbrev ProjectId := String

-- GCP Region
abbrev Region := String

-- GCP Access Token
abbrev AccessToken := String

-- GCP API Key
abbrev APIKey := String

-- GCP Request ID
abbrev RequestId := String

-- ISO 8601 Timestamp
abbrev ISO8601Timestamp := String

-- Unix Timestamp
abbrev UnixTimestamp := Nat

-- ============================================
-- GCP Service Types
-- ============================================

-- GCP Service names
inductive Service
  | CloudFunctions
  | CloudRun
  | ComputeEngine
  | Container
  | CloudStorage
  | CloudSQL
  | CloudLogging
  | CloudMonitoring
  | CloudPubSub
  | CloudScheduler
  | CloudSchedulerJob
  | CloudBuild
  | ArtifactRegistry
  | BigQuery
  | CloudSourceRepositories
  deriving Repr, DecidableEq

-- ============================================
-- Cloud Functions Types
-- ============================================

-- Cloud Function Name
abbrev CloudFunctionName := String

-- Cloud Function Entry Point
abbrev CloudFunctionEntryPoint := String

-- Cloud Function Trigger
structure CloudFunctionTrigger where
  triggerType : String  -- "http", "pubsub", "schedule", "event_arc"
  triggerData : String

-- Cloud Function HTTP Trigger
structure CloudFunctionHttpTrigger where
  aliveTimeout : Nat
  uri          : String

-- Cloud Function PubSub Trigger
structure CloudFunctionPubSubTrigger where
  topic : String

-- Cloud Function Schedule Trigger
structure CloudFunctionScheduleTrigger where
  schedule : String

-- Cloud Function Runtime
inductive CloudFunctionRuntime
  | NodeJS18
  | NodeJS20
  | Python311
  | Python312
  | Go121
  | Go122
  | Java17
  | Ruby32
  deriving Repr, DecidableEq

-- Cloud Function Configuration
structure CloudFunctionConfig where
  functionName : CloudFunctionName
  entryPoint   : String
  runtime      : CloudFunctionRuntime
  availableMemory : Nat  -- MB
  timeout      : Nat  -- seconds
  environmentVariables : List (String × String)
  trigger        : Option CloudFunctionTrigger

-- ============================================
-- Cloud Run Types
-- ============================================

-- Cloud Run Service Name
abbrev CloudRunServiceName := String

-- Cloud Run Configuration
structure CloudRunConfig where
  serviceName : CloudRunServiceName
  region      : Region
  cpu         : Nat  -- millicores
  memory      : Nat  -- MB
  maxInstances : Nat
  minInstances : Nat
  timeout     : Nat
  timeoutAction : String  -- "terminate", "continue"

-- Cloud Run Revision
structure CloudRunRevision where
  revisionName : String
  version      : Nat
  state        : String  -- "PREPARING", "RUNNING", "UPDATING", "FAILED"
  url          : String
  instanceCount : Nat

-- ============================================
-- Compute Engine Types
-- ============================================

-- Machine Type
abbrev MachineType := String

-- Disk Size (GB)
abbrev DiskSize := Nat

-- Disk Type
inductive DiskType
  | PD_Standard
  | PD_Balanced
  | PD_SSD
  | LocalSSD

-- Instance Config
abbrev InstanceConfig := String

-- ============================================
-- Container Types
-- ============================================

-- Cluster Name
abbrev ClusterName := String

-- Node Pool Name
abbrev NodePoolName := String

-- ============================================
-- Cloud Storage Types
-- ============================================

-- Bucket Name
abbrev BucketName := String

-- Object Name
abbrev ObjectName := String

-- Object Version
abbrev ObjectVersion := String

-- Bucket Storage Class
inductive StorageClass
  | STANDARD
  | NEARLINE
  | COLDLINE
  | DUAL_REGION
  | REGIONAL

-- ============================================
-- Cloud SQL Types
-- ============================================

-- Database Version
abbrev DatabaseVersion := String

-- Configuration Type
abbrev ConfigurationType := String

-- ============================================
-- Cloud Logging Types
-- ============================================

-- Log Name
abbrev LogName := String

-- Log Entry
structure LogEntry where
  resource  : String
  severity  : String
  textPayload : String
  jsonPayload : String

-- ============================================
-- Cloud Monitoring Types
-- ============================================

-- Metric Name
abbrev MetricName := String

-- Metric Value
abbrev MetricValue := Float

-- ============================================
-- Cloud PubSub Types
-- ============================================

-- Topic Name
abbrev TopicName := String

-- Subscription Name
abbrev SubscriptionName := String

-- ============================================
-- Cloud Scheduler Types
-- ============================================

-- Job Name
abbrev JobName := String

-- Schedule
abbrev Schedule := String

-- ============================================
-- Cloud Build Types
-- ============================================

-- Build ID
abbrev BuildId := String

-- Build Status
inductive BuildStatus
  | QUEUED
  | RUNNING
  | SUCCESS
  | FAILURE
  | TIMEOUT
  | CANCELLED

-- Build Trigger Template
structure BuildTriggerTemplate where
  triggerName : String
  pauseTime   : Nat
  retry       : Bool

-- Build Trigger
structure BuildTrigger where
  triggerId     : String
  triggerTemplate : BuildTriggerTemplate

-- ============================================
-- Artifact Registry Types
-- ============================================

-- Repository Name
abbrev RepositoryName := String

-- Repository Format
inductive RepositoryFormat
  | DOCKER
  | MAVEN
  | NPM
  | PYPI
  | GOLANG

-- ============================================
-- BigQuery Types
-- ============================================

-- Dataset Name
abbrev DatasetName := String

-- Table Name
abbrev TableName := String

-- Schema Field
structure SchemaField where
  name    : String
  type_     : String
  mode      : String  -- "NULLABLE", "REQUIRED", "REPEATED"
  description : String

-- ============================================
-- Cloud Source Repositories Types
-- ============================================

-- Repository ID
abbrev RepositoryId := String