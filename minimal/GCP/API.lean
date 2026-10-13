-- GCP API
-- Formal model of Google Cloud Platform API endpoints
-- Aligned with the AWS API model pattern (tools/gokujo/AWS/API.lean)

import GCP.Types

namespace GCP
namespace API

-- ============================================
-- API Configuration
-- ============================================

def getServiceUrl : Service → String
  | .CloudFunctions => "https://cloudfunctions.googleapis.com"
  | .CloudRun       => "https://cloudrun.googleapis.com"
  | .ComputeEngine  => "https://compute.googleapis.com"
  | .Container      => "https://container.googleapis.com"
  | .CloudStorage   => "https://storage.googleapis.com"
  | .CloudSQL       => "https://cloudsql.googleapis.com"
  | .CloudLogging   => "https://logging.googleapis.com"
  | .CloudMonitoring=> "https://monitoring.googleapis.com"
  | .CloudPubSub    => "https://pubsub.googleapis.com"
  | .CloudScheduler => "https://cloudscheduler.googleapis.com"
  | .CloudBuild     => "https://cloudbuild.googleapis.com"
  | .ArtifactRegistry=> "https://artificateregistry.googleapis.com"
  | .BigQuery       => "https://bigquery.googleapis.com"
  | .CloudSourceRepositories=> "https://sourcerepo.googleapis.com"
  | .CloudSchedulerJob => "https://cloudscheduler.googleapis.com"
  
-- GCP API configuration
structure GCPConfig where
  region      : Region
  accessToken : Option AccessToken
  apiKey      : Option APIKey
  
-- ============================================
-- API Endpoint Types
-- ============================================

-- API endpoint path
def EndpointPath := String

-- API endpoint with method
structure Endpoint where
  method : String  -- "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD"
  path   : EndpointPath
  service : Service

-- ============================================
-- Cloud Functions API Endpoints
-- ============================================

-- Deploy function
def cloudFunctionsDeployEndpoint : Region → CloudFunctionConfig → Endpoint := fun region config =>
  { method := "POST"
  , path := "/v2/" ++ region ++ "/functions"
  , service := .CloudFunctions
  }

-- Get function
def cloudFunctionsGetEndpoint : CloudFunctionName → String → Endpoint := fun name region =>
  { method := "GET"
  , path := "/v2/" ++ region ++ "/functions/" ++ name
  , service := .CloudFunctions
  }

-- List functions
def cloudFunctionsListEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/v2/" ++ region ++ "/functions"
  , service := .CloudFunctions
  }

-- ============================================
-- Cloud Run API Endpoints
-- ============================================

-- Deploy service
def cloudRunDeployEndpoint : Region → CloudRunConfig → Endpoint := fun region config =>
  { method := "POST"
  , path := "/v2/" ++ region ++ "/services"
  , service := .CloudRun
  }

-- Get revision
def cloudRunGetRevisionEndpoint : Region → CloudRunRevision → Endpoint := fun region revision =>
  { method := "GET"
  , path := "/v2/" ++ region ++ "/services/" ++ revision.revisionName ++ "/revisions/" ++ (Nat.repr revision.version)
  , service := .CloudRun
  }

-- List revisions
def cloudRunListRevisionsEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/v2/" ++ region ++ "/services"
  , service := .CloudRun
  }

-- ============================================
-- Compute Engine API Endpoints
-- ============================================

-- List machines
def computeListMachinesEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .ComputeEngine
  }

-- ============================================
-- Container API Endpoints
-- ============================================

-- List clusters
def containerListClustersEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .Container
  }

-- ============================================
-- Cloud Storage API Endpoints
-- ============================================

-- List objects
def cloudStorageListObjectsEndpoint : BucketName → Option ObjectName → Endpoint :=
  fun bucket objPrefix =>
  { method := "GET"
  , path := "/"
  , service := .CloudStorage
  }

-- ============================================
-- Cloud SQL API Endpoints
-- ============================================

-- List databases
def cloudSQLListDatabasesEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudSQL
  }

-- ============================================
-- Cloud Logging API Endpoints
-- ============================================

-- List log entries
def cloudLoggingListLogEntriesEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudLogging
  }

-- ============================================
-- Cloud Monitoring API Endpoints
-- ============================================

-- List metrics
def cloudMonitoringListMetricsEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudMonitoring
  }

-- ============================================
-- Cloud PubSub API Endpoints
-- ============================================

-- List topics
def cloudPubSubListTopicsEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudPubSub
  }

-- ============================================
-- Cloud Scheduler API Endpoints
-- ============================================

-- List jobs
def cloudSchedulerListJobsEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudScheduler
  }

-- ============================================
-- Cloud Build API Endpoints
-- ============================================

-- List builds
def cloudBuildListBuildsEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudBuild
  }

-- ============================================
-- Artifact Registry API Endpoints
-- ============================================

-- List repositories
def artifactRegistryListRepositoriesEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .ArtifactRegistry
  }

-- ============================================
-- BigQuery API Endpoints
-- ============================================

-- List datasets
def bigQueryListDatasetsEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .BigQuery
  }

-- ============================================
-- Cloud Source Repositories API Endpoints
-- ============================================

-- List repositories
def cloudSourceRepositoriesListRepositoriesEndpoint : Region → Endpoint := fun region =>
  { method := "GET"
  , path := "/"
  , service := .CloudSourceRepositories
  }