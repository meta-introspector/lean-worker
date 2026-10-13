# GitHub API Integration for Gokujo

This directory contains formal Lean 4 models of GitHub's REST API for integration with the Gokujo build system.

## Structure

```
tools/gokujo/GitHub/
├── Types.lean          # Core GitHub primitive types
├── API.lean            # GitHub REST API endpoints and types
├── Integration.lean    # Gokujo-GitHub integration for build pipelines
└── README.md           # This file
```

## Types Modeled

### Primitive Types (`Types.lean`)
- **Identifiers**: `UserId`, `RepoId`, `OrgId`, `PRNumber`, `IssueNumber`, `WorkflowId`, `RunId`
- **Names**: `Username`, `RepoName`, `OrgName`, `BranchName`, `CommitSHA`, `TagName`
- **Tokens**: `Token`
- **Timestamps**: `ISO8601Timestamp`
- **Enums**: `RepoVisibility`, `UserType`, `PRState`, `IssueState`, `WorkflowState`, `RunStatus`, `RunConclusion`, `ContentType`, `WebhookEvent`

### Data Structures
- **Repository**: `Repository`, `RepoPermissions`
- **User**: `User`
- **Branch**: `Branch`, `BranchProtection`, `BranchRestrictions`
- **Commit**: `Commit`, `CommitAuthor`, `Tree`, `CommitStats`
- **Pull Request**: `PullRequest`, `BranchRef`, `PRReview`, `PRReviewState`
- **Issue**: `Issue`, `Label`
- **Workflow**: `Workflow`, `WorkflowRun`, `RunStatus`, `RunConclusion`
- **Contents**: `RepoContents`, `FileContents`
- **Webhook**: `WebhookPayload`, `PushPayload`

### API Types (`API.lean`)
- **Endpoints**: All major GitHub REST API endpoints modeled as `Endpoint` records
- **Request/Response**: `APIRequest`, `APIResponse`, `PaginatedEndpoint`, `PaginatedResponse`
- **Repository Operations**: Create, get, update, delete repos
- **Contents Operations**: Get, create, update, delete files
- **Branch Operations**: List, get branches
- **Commit Operations**: List, get, compare commits
- **Pull Request Operations**: List, get, create, update PRs and reviews
- **Issue Operations**: List, get, create, update issues
- **Workflow Operations**: List, get workflows and runs, trigger workflows
- **User Operations**: Get current user, get user by username

### Integration Types (`Integration.lean`)
- **Configuration**: `GokujoGitHubConfig`
- **Operations**: `GokujoGitHubOperation`
- **Workflow**: `GokujoGitHubWorkflow`, `GokujoGitHubStep`
- **Project**: `GokujoGitHubProject`
- **Commands**: `GokujoGitHubCloneCommand`, `GokujoGitHubPushCommand`, `GokujoGitHubPRCommand`, `GokujoGitHubIssueCommand`, `GokujoGitHubWorkflowCommand`
- **Results**: `GokujoGitHubResult`, `GokujoGitHubCloneResult`, `GokujoGitHubPushResult`, `GokujoGitHubPRResult`, `GokujoGitHubIssueResult`, `GokujoGitHubWorkflowResult`
- **Webhook**: `GokujoGitHubWebhookConfig`, `GokujoGitHubWebhookHandler`

## Usage

### Import the GitHub module

```lean
import GitHub.Types
import GitHub.API
import GitHub.GokujoIntegration
```

### Create a GitHub project

```lean
open GitHub

def myProject : GokujoIntegration.GokujoGitHubProject :=
  { projectName := "my-project"
  , repoName := "my-org/my-repo"
  , owner := "my-org"
  , defaultBranch := "main"
  , workflows := []
  }
```

### Create API endpoints

```lean
open GitHub API

-- Get repository endpoint
def repoEndpoint := getRepoEndpoint "my-org/my-repo"

-- List branches endpoint
def branchesEndpoint := listBranchesEndpoint "my-org/my-repo"

-- Get commit endpoint
def commitEndpoint := getCommitEndpoint "my-org/my-repo" "abc123"
```

### Create workflow

```lean
open GitHub GokujoIntegration

def workflow := createGitHubWorkflow myProject
```

### Create commands

```lean
open GitHub GokujoIntegration

-- Create PR command
def prCmd := createPRCommand "my-org/my-repo" "Fix bug" "feature-branch" "main"

-- Create push command
def pushCmd := createPushCommand "my-org/my-repo" "main"

-- Create workflow trigger command
def workflowCmd := createWorkflowCommand "my-org/my-repo" 12345
```

## API Endpoints Covered

### Repositories
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/user/repos` | List user repositories |
| GET | `/orgs/{org}/repos` | List organization repositories |
| GET | `/repos/{repo}` | Get repository |
| POST | `/user/repos` | Create repository |
| PATCH | `/repos/{repo}` | Update repository |
| DELETE | `/repos/{repo}` | Delete repository |

### Repository Contents
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/repos/{repo}/contents/{path}` | Get contents |
| PUT | `/repos/{repo}/contents/{path}` | Create/update file |
| DELETE | `/repos/{repo}/contents/{path}` | Delete file |

### Branches
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/repos/{repo}/branches` | List branches |
| GET | `/repos/{repo}/branches/{branch}` | Get branch |

### Commits
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/repos/{repo}/commits` | List commits |
| GET | `/repos/{repo}/commits/{sha}` | Get commit |
| GET | `/repos/{repo}/compare/{base}...{head}` | Compare commits |

### Pull Requests
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/repos/{repo}/pulls` | List PRs |
| GET | `/repos/{repo}/pulls/{pr}` | Get PR |
| POST | `/repos/{repo}/pulls` | Create PR |
| PATCH | `/repos/{repo}/pulls/{pr}` | Update PR |
| GET | `/repos/{repo}/pulls/{pr}/reviews` | List PR reviews |
| POST | `/repos/{repo}/pulls/{pr}/reviews` | Create PR review |

### Issues
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/repos/{repo}/issues` | List issues |
| GET | `/repos/{repo}/issues/{issue}` | Get issue |
| POST | `/repos/{repo}/issues` | Create issue |
| PATCH | `/repos/{repo}/issues/{issue}` | Update issue |

### Workflows
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/repos/{repo}/actions/workflows` | List workflows |
| GET | `/repos/{repo}/actions/workflows/{wf}` | Get workflow |
| GET | `/repos/{repo}/actions/workflows/{wf}/runs` | List workflow runs |
| GET | `/repos/{repo}/actions/runs/{run}` | Get workflow run |
| POST | `/repos/{repo}/actions/workflows/{wf}/dispatches` | Trigger workflow |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/user` | Get authenticated user |
| GET | `/users/{user}` | Get user by username |

## Integration with Gokujo

The GitHub integration allows Gokujo to:

1. **Clone repositories** - Checkout code for building
2. **Push changes** - Deploy built artifacts
3. **Create PRs** - Submit changes for review
4. **Trigger workflows** - Run CI/CD pipelines
5. **Handle webhooks** - Respond to GitHub events

## Compilation

```bash
# Compile the GitHub module
cd /workspace/github__meta-introspector__lean-worker
. ~/.elan/env
LEAN_PATH=tools/gokujo/GitHub lean -R tools/gokujo/GitHub Types.lean
LEAN_PATH=tools/gokujo/GitHub lean -R tools/gokujo/GitHub API.lean
LEAN_PATH=tools/gokujo/GitHub lean -R tools/gokujo/GitHub Integration.lean
```

## Next Steps

1. Fill in the `sorry` placeholders with actual proofs
2. Add more detailed API response/request types
3. Add rate limiting and pagination handling
4. Add examples of complete GitHub workflows
5. Add validation theorems for GitHub configurations
