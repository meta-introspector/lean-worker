-- API.lean
-- Formal model of GitHub REST API endpoints

import GitHub.Types

namespace GitHub
namespace API

-- ============================================
-- API Configuration
-- ============================================

-- GitHub API base URL
def baseUrl : String := "https://api.github.com"

-- GitHub API version header
def apiVersionHeader : String := "X-GitHub-Api-Version: 2022-11-28"

-- GitHub API configuration
structure GitHubConfig where
  token     : Option Types.Token
  baseUrl   : String
  userAgent : String
  timeout   : Nat
  
-- ============================================
-- API Endpoint Types
-- ============================================

-- API endpoint path
def EndpointPath := String

-- API endpoint with method
def Endpoint where
  method : Types.HttpMethod
  path   : EndpointPath
  
-- Paginated endpoint
def PaginatedEndpoint where
  endpoint : Endpoint
  per_page : Option Nat
  page     : Option Nat
  
-- ============================================
-- Repository Endpoints
-- ============================================

-- List user repositories
def listUserReposEndpoint : Endpoint :=
  { method := .GET
  , path := "/user/repos"
  }

-- List organization repositories
def listOrgReposEndpoint : String → Endpoint := fun org =>
  { method := .GET
  , path := "/orgs/" ++ org ++ "/repos"
  }

-- Get repository
def getRepoEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .GET
  , path := "/repos/" ++ repo
  }

-- Create repository
def createRepoEndpoint : Endpoint :=
  { method := .POST
  , path := "/user/repos"
  }

-- Update repository
def updateRepoEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .PATCH
  , path := "/repos/" ++ repo
  }

-- Delete repository
def deleteRepoEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .DELETE
  , path := "/repos/" ++ repo
  }

-- ============================================
-- Repository Contents Endpoints
-- ============================================

-- Get repository contents
def getContentsEndpoint : Types.RepoName → String → Endpoint := fun repo path =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/contents/" ++ path
  }

-- Create/update file
def createUpdateFileEndpoint : Types.RepoName → String → Endpoint := fun repo path =>
  { method := .PUT
  , path := "/repos/" ++ repo ++ "/contents/" ++ path
  }

-- Delete file
def deleteFileEndpoint : Types.RepoName → String → Endpoint := fun repo path =>
  { method := .DELETE
  , path := "/repos/" ++ repo ++ "/contents/" ++ path
  }

-- ============================================
-- Branch Endpoints
-- ============================================

-- List branches
def listBranchesEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/branches"
  }

-- Get branch
def getBranchEndpoint : Types.RepoName → Types.BranchName → Endpoint := fun repo branch =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/branches/" ++ branch
  }

-- ============================================
-- Commit Endpoints
-- ============================================

-- List commits
def listCommitsEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/commits"
  }

-- Get commit
def getCommitEndpoint : Types.RepoName → Types.CommitSHA → Endpoint := fun repo sha =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/commits/" ++ sha
  }

-- Compare commits
def compareCommitsEndpoint : Types.RepoName → Types.CommitSHA → Types.CommitSHA → Endpoint :=
  fun repo base head =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/compare/" ++ base ++ "..." ++ head
  }

-- ============================================
-- Pull Request Endpoints
-- ============================================

-- List pull requests
def listPRsEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/pulls"
  }

-- Get pull request
def getPREndpoint : Types.RepoName → Types.PRNumber → Endpoint := fun repo pr_num =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/pulls/" ++ toString pr_num
  }

-- Create pull request
def createPREndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .POST
  , path := "/repos/" ++ repo ++ "/pulls"
  }

-- Update pull request
def updatePREndpoint : Types.RepoName → Types.PRNumber → Endpoint := fun repo pr_num =>
  { method := .PATCH
  , path := "/repos/" ++ repo ++ "/pulls/" ++ toString pr_num
  }

-- List PR reviews
def listPRReviewsEndpoint : Types.RepoName → Types.PRNumber → Endpoint := fun repo pr_num =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/pulls/" ++ toString pr_num ++ "/reviews"
  }

-- Create PR review
def createPRReviewEndpoint : Types.RepoName → Types.PRNumber → Endpoint := fun repo pr_num =>
  { method := .POST
  , path := "/repos/" ++ repo ++ "/pulls/" ++ toString pr_num ++ "/reviews"
  }

-- ============================================
-- Issue Endpoints
-- ============================================

-- List issues
def listIssuesEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/issues"
  }

-- Get issue
def getIssueEndpoint : Types.RepoName → Types.IssueNumber → Endpoint := fun repo issue_num =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/issues/" ++ toString issue_num
  }

-- Create issue
def createIssueEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .POST
  , path := "/repos/" ++ repo ++ "/issues"
  }

-- Update issue
def updateIssueEndpoint : Types.RepoName → Types.IssueNumber → Endpoint := fun repo issue_num =>
  { method := .PATCH
  , path := "/repos/" ++ repo ++ "/issues/" ++ toString issue_num
  }

-- ============================================
-- Workflow Endpoints
-- ============================================

-- List workflows
def listWorkflowsEndpoint : Types.RepoName → Endpoint := fun repo =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/actions/workflows"
  }

-- Get workflow
def getWorkflowEndpoint : Types.RepoName → Types.WorkflowId → Endpoint := fun repo wf_id =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/actions/workflows/" ++ toString wf_id
  }

-- List workflow runs
def listWorkflowRunsEndpoint : Types.RepoName → Types.WorkflowId → Endpoint := fun repo wf_id =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/actions/workflows/" ++ toString wf_id ++ "/runs"
  }

-- Get workflow run
def getWorkflowRunEndpoint : Types.RepoName → Types.RunId → Endpoint := fun repo run_id =>
  { method := .GET
  , path := "/repos/" ++ repo ++ "/actions/runs/" ++ toString run_id
  }

-- Trigger workflow
def triggerWorkflowEndpoint : Types.RepoName → Types.WorkflowId → Endpoint := fun repo wf_id =>
  { method := .POST
  , path := "/repos/" ++ repo ++ "/actions/workflows/" ++ toString wf_id ++ "/dispatches"
  }

-- ============================================
-- User Endpoints
-- ============================================

-- Get authenticated user
def getCurrentUserEndpoint : Endpoint :=
  { method := .GET
  , path := "/user"
  }

-- Get user by username
def getUserEndpoint : Types.Username → Endpoint := fun username =>
  { method := .GET
  , path := "/users/" ++ username
  }

-- ============================================
-- API Request/Response Types
-- ============================================

-- API request structure
structure APIRequest (T : Type) where
  endpoint : Endpoint
  headers : List (String × String)
  body    : Option T
  params  : List (String × String)
  
-- API response structure
structure APIResponse (T : Type) where
  status  : Types.HttpStatus
  headers : List (String × String)
  body    : Option T
  success : Bool
  errors  : List String
  
-- ============================================
-- Repository Request/Response Types
-- ============================================

-- Create repository request
structure CreateRepoRequest where
  name        : String
  description : Option String
  private     : Option Bool
  auto_init   : Option Bool
  
-- Repository response
structure RepoResponse where
  id          : Types.RepoId
  name        : String
  full_name   : Types.RepoName
  owner       : Types.Username
  private     : Bool
  html_url    : String
  
-- ============================================
-- File Request/Response Types
-- ============================================

-- Create/update file request
structure CreateUpdateFileRequest where
  message : String
  content : String
  branch  : Option Types.BranchName
  committer : Option Committer
  
-- Committer
structure Committer where
  name  : String
  email : String
  
-- File response
structure FileResponse where
  type_      : Types.ContentType
  encoding   : String
  size      : Nat
  name      : String
  path      : String
  content   : Option String
  sha       : Types.CommitSHA
  
-- ============================================
-- Pull Request Request/Response Types
-- ============================================

-- Create PR request
structure CreatePRRequest where
  title   : String
  head    : Types.BranchName
  base    : Types.BranchName
  body    : Option String
  draft   : Option Bool
  
-- PR response
structure PRResponse where
  id        : Nat
  number    : Types.PRNumber
  state     : Types.PRState
  title     : String
  body      : Option String
  html_url  : String
  
-- ============================================
-- Issue Request/Response Types
-- ============================================

-- Create issue request
structure CreateIssueRequest where
  title   : String
  body    : Option String
  labels  : Option (List String)
  
-- Issue response
structure IssueResponse where
  id        : Nat
  number    : Types.IssueNumber
  state     : Types.IssueState
  title     : String
  body      : Option String
  html_url  : String
  
-- ============================================
-- Workflow Request/Response Types
-- ============================================

-- Trigger workflow request
structure TriggerWorkflowRequest where
  ref : String
  inputs : Option (List (String × String))
  
-- Workflow run response
structure WorkflowRunResponse where
  id        : Types.RunId
  workflow_id : Types.WorkflowId
  status    : Types.RunStatus
  html_url  : String
  
-- ============================================
-- Pagination Types
-- ============================================

-- Pagination info
structure PageInfo where
  page      : Nat
  per_page  : Nat
  total     : Nat
  total_pages : Nat
  next_page : Option Nat
  prev_page : Option Nat
  
-- Paginated response wrapper
structure PaginatedResponse (T : Type) where
  items : List T
  page_info : PageInfo
  
-- ============================================
-- Theorems: API Endpoint Properties
-- ============================================

-- Theorem: listUserReposEndpoint is GET
theorem list_user_repos_is_get : listUserReposEndpoint.method = .GET := rfl

-- Theorem: createRepoEndpoint is POST
theorem create_repo_is_post : createRepoEndpoint.method = .POST := rfl

-- Theorem: getContentsEndpoint is GET
theorem get_contents_is_get (repo : Types.RepoName) (path : String) :
  (getContentsEndpoint repo path).method = .GET := rfl

-- Theorem: createUpdateFileEndpoint is PUT
theorem create_update_file_is_put (repo : Types.RepoName) (path : String) :
  (createUpdateFileEndpoint repo path).method = .PUT := rfl

-- Theorem: listBranchesEndpoint is GET
theorem list_branches_is_get (repo : Types.RepoName) :
  (listBranchesEndpoint repo).method = .GET := rfl

-- Theorem: listCommitsEndpoint is GET
theorem list_commits_is_get (repo : Types.RepoName) :
  (listCommitsEndpoint repo).method = .GET := rfl

-- Theorem: listPRsEndpoint is GET
theorem list_prs_is_get (repo : Types.RepoName) :
  (listPRsEndpoint repo).method = .GET := rfl

-- Theorem: createPREndpoint is POST
theorem create_pr_is_post (repo : Types.RepoName) :
  (createPREndpoint repo).method = .POST := rfl

-- Theorem: listIssuesEndpoint is GET
theorem list_issues_is_get (repo : Types.RepoName) :
  (listIssuesEndpoint repo).method = .GET := rfl

-- Theorem: createIssueEndpoint is POST
theorem create_issue_is_post (repo : Types.RepoName) :
  (createIssueEndpoint repo).method = .POST := rfl

-- Theorem: listWorkflowsEndpoint is GET
theorem list_workflows_is_get (repo : Types.RepoName) :
  (listWorkflowsEndpoint repo).method = .GET := rfl

-- Theorem: triggerWorkflowEndpoint is POST
theorem trigger_workflow_is_post (repo : Types.RepoName) (wf_id : Types.WorkflowId) :
  (triggerWorkflowEndpoint repo wf_id).method = .POST := rfl

-- Theorem: getCurrentUserEndpoint is GET
theorem get_current_user_is_get : getCurrentUserEndpoint.method = .GET := rfl

end API
end GitHub
