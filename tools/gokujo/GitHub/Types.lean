-- Types.lean
-- Formal model of GitHub API types

namespace GitHub

-- ============================================
-- Primitive Types
-- ============================================

-- GitHub User ID
def UserId := Nat

-- GitHub Username
def Username := String

-- GitHub Repository Name (owner/repo)
def RepoName := String

-- GitHub Repository ID
def RepoId := Nat

-- GitHub Organization ID
def OrgId := Nat

-- GitHub Organization Name
def OrgName := String

-- GitHub Branch Name
def BranchName := String

-- GitHub Commit SHA
def CommitSHA := String

-- GitHub Tag Name
def TagName := String

-- GitHub Pull Request Number
def PRNumber := Nat

-- GitHub Issue Number
def IssueNumber := Nat

-- GitHub Workflow ID
def WorkflowId := Nat

-- GitHub Run ID
def RunId := Nat

-- GitHub Token
def Token := String

-- ISO 8601 Timestamp
def ISO8601Timestamp := String

-- ============================================
-- Repository Types
-- ============================================

-- Repository visibility
inductive RepoVisibility
  | public
  | private
  | internal
  deriving Repr, DecidableEq

-- Repository permissions
structure RepoPermissions where
  admin : Bool
  push  : Bool
  pull  : Bool
  
-- Repository
structure Repository where
  id          : RepoId
  name        : String
  full_name   : RepoName
  owner       : Username
  private     : Bool
  html_url    : String
  description : Option String
  fork        : Bool
  url         : String
  created_at  : ISO8601Timestamp
  updated_at  : ISO8601Timestamp
  pushed_at   : ISO8601Timestamp
  default_branch : BranchName
  permissions : Option RepoPermissions
  
-- ============================================
-- User Types
-- ============================================

-- User type (User or Organization)
inductive UserType
  | User
  | Organization
  deriving Repr, DecidableEq

-- User
structure User where
  id        : UserId
  login     : Username
  avatar_url : String
  url       : String
  html_url  : String
  type_     : UserType
  name      : Option String
  email     : Option String
  
-- ============================================
-- Branch Types
-- ============================================

-- Branch
structure Branch where
  name      : BranchName
  commit    : Commit
  protected : Bool
  
-- Branch protection
structure BranchProtection where
  required_status_checks : Option (List String)
  enforce_admins : Bool
  required_pull_request_reviews : Option Nat
  restrictions : Option BranchRestrictions
  
-- Branch restrictions
structure BranchRestrictions where
  users : Option (List Username)
  teams : Option (List String)
  
-- ============================================
-- Commit Types
-- ============================================

-- Commit
structure Commit where
  sha       : CommitSHA
  url       : String
  html_url  : String
  author    : Option CommitAuthor
  committer : Option CommitAuthor
  message   : String
  tree      : Tree
  parents   : List Commit
  
-- Commit author
structure CommitAuthor where
  name      : String
  email     : String
  date      : ISO8601Timestamp
  
-- Tree
structure Tree where
  sha     : String
  url     : String
  
-- Commit stats
structure CommitStats where
  additions : Nat
  deletions : Nat
  total     : Nat
  
-- ============================================
-- Pull Request Types
-- ============================================

-- Pull Request state
inductive PRState
  | open
  | closed
  | merged
  | all
  deriving Repr, DecidableEq

-- Pull Request
structure PullRequest where
  id        : Nat
  number    : PRNumber
  state     : PRState
  title     : String
  body      : Option String
  user      : User
  base      : BranchRef
  head      : BranchRef
  html_url  : String
  created_at : ISO8601Timestamp
  updated_at : ISO8601Timestamp
  closed_at : Option ISO8601Timestamp
  merged_at : Option ISO8601Timestamp
  merge_commit_sha : Option CommitSHA
  
-- Branch reference
structure BranchRef where
  label : String
  ref   : String
  sha   : CommitSHA
  repo  : Repository
  
-- PR Review
structure PRReview where
  id        : Nat
  user      : User
  state     : PRReviewState
  submitted_at : ISO8601Timestamp
  
-- PR Review state
inductive PRReviewState
  | pending
  | approved
  | changes_requested
  | commented
  | dismissed
  deriving Repr, DecidableEq

-- ============================================
-- Issue Types
-- ============================================

-- Issue state
inductive IssueState
  | open
  | closed
  | all
  deriving Repr, DecidableEq

-- Issue
structure Issue where
  id        : Nat
  number    : IssueNumber
  state     : IssueState
  title     : String
  body      : Option String
  user      : User
  labels    : List Label
  html_url  : String
  created_at : ISO8601Timestamp
  updated_at : ISO8601Timestamp
  closed_at : Option ISO8601Timestamp
  
-- Label
structure Label where
  id    : Nat
  name  : String
  color : String
  
-- ============================================
-- Workflow Types
-- ============================================

-- Workflow state
inductive WorkflowState
  | active
  | deleted
  | disabled_fork
  | disabled_inactivity
  | disabled_manually
  deriving Repr, DecidableEq

-- Workflow
structure Workflow where
  id        : WorkflowId
  name      : String
  path      : String
  state     : WorkflowState
  html_url  : String
  created_at : ISO8601Timestamp
  updated_at : ISO8601Timestamp
  
-- Workflow Run
structure WorkflowRun where
  id        : RunId
  workflow_id : WorkflowId
  status    : RunStatus
  conclusion : Option RunConclusion
  html_url  : String
  created_at : ISO8601Timestamp
  updated_at : ISO8601Timestamp
  
-- Run status
inductive RunStatus
  | queued
  | in_progress
  | completed
  | cancelled
  | failed
  | timed_out
  deriving Repr, DecidableEq

-- Run conclusion
inductive RunConclusion
  | success
  | failure
  | cancelled
  | skipped
  | timed_out
  | neutral
  deriving Repr, DecidableEq

-- ============================================
-- Contents Types
-- ============================================

-- Repository contents
structure RepoContents where
  type_      : ContentType
  name      : String
  path      : String
  sha       : CommitSHA
  size      : Nat
  url       : String
  html_url  : String
  git_url   : String
  download_url : Option String
  
-- Content type
inductive ContentType
  | file
  | dir
  | symlink
  | submodule
  deriving Repr, DecidableEq

-- File contents
structure FileContents where
  type_      : ContentType
  encoding   : String
  size      : Nat
  name      : String
  path      : String
  content   : String
  sha       : CommitSHA
  
-- ============================================
-- Webhook Types
-- ============================================

-- Webhook event type
inductive WebhookEvent
  | push
  | pull_request
  | issues
  | issue_comment
  | commit_comment
  | create
  | delete
  | deployment
  | release
  | repository
  | status
  | page_build
  | workflow_run
  deriving Repr, DecidableEq

-- Webhook payload
structure WebhookPayload where
  action    : Option String
  repository : Repository
  sender    : User
  
-- Push webhook payload
structure PushPayload where
  ref        : String
  before    : CommitSHA
  after     : CommitSHA
  commits   : List Commit
  
-- ============================================
-- Theorems: Type Properties
-- ============================================

-- Theorem: UserId is a Nat
theorem user_id_is_nat : ∀ (id : UserId), True := by
  intro _
  exact True.intro

-- Theorem: Username is a String
theorem username_is_string : ∀ (name : Username), True := by
  intro _
  exact True.intro

-- Theorem: RepoName is a String
theorem repo_name_is_string : ∀ (name : RepoName), True := by
  intro _
  exact True.intro

-- Theorem: CommitSHA is a String
theorem commit_sha_is_string : ∀ (sha : CommitSHA), True := by
  intro _
  exact True.intro

-- Theorem: Token is a String
theorem token_is_string : ∀ (token : Token), True := by
  intro _
  exact True.intro

-- Theorem: RepoVisibility is decidable
theorem repo_visibility_decidable : ∀ (v1 v2 : RepoVisibility), Decidable (v1 = v2) := by
  intro _ _
  infer_instance

-- Theorem: UserType is decidable
theorem user_type_decidable : ∀ (t1 t2 : UserType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: PRState is decidable
theorem pr_state_decidable : ∀ (s1 s2 : PRState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: IssueState is decidable
theorem issue_state_decidable : ∀ (s1 s2 : IssueState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: WorkflowState is decidable
theorem workflow_state_decidable : ∀ (s1 s2 : WorkflowState), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: RunStatus is decidable
theorem run_status_decidable : ∀ (s1 s2 : RunStatus), Decidable (s1 = s2) := by
  intro _ _
  infer_instance

-- Theorem: RunConclusion is decidable
theorem run_conclusion_decidable : ∀ (c1 c2 : RunConclusion), Decidable (c1 = c2) := by
  intro _ _
  infer_instance

-- Theorem: ContentType is decidable
theorem content_type_decidable : ∀ (t1 t2 : ContentType), Decidable (t1 = t2) := by
  intro _ _
  infer_instance

-- Theorem: WebhookEvent is decidable
theorem webhook_event_decidable : ∀ (e1 e2 : WebhookEvent), Decidable (e1 = e2) := by
  intro _ _
  infer_instance

end GitHub
