.PHONY: help build test infra verify clean git_status git_commit git_push gh_pr_create gh_pr_view git_branch_create git_branch_list git_tags git_log git_diff git_stash git_stash_pop git_checkout git_reset_hard git_clean git_pull mcp_list_tools mcp_call

help:
	@echo "Available targets:"
	@echo "  make build     - Build the project"
	@echo "  make test      - Run tests"
	@echo "  make infra     - Generate infrastructure files"
	@echo "  make verify    - Run comprehensive verification"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make git_status     - Show git repository status"
	@echo "  make git_commit MESSAGE=\"Your message\" - Stage and commit changes"
	@echo "  make git_push [branch] - Push current branch to remote"
	@echo "  make gh_pr_create TITLE=\"...\" BODY=\"...\" HEAD=... [BASE=...] [DRAFT=0] [REVIEWERS=\"...] - Create GitHub PR"
	@echo "  make gh_pr_view [PR_NUMBER] - View a GitHub PR"
	@echo "  make gh_pr_merge [PR_NUMBER] [METHOD=...] - Merge a GitHub PR"
	@echo "  make gh_pr_close [PR_NUMBER] [REASON=...] - Close a GitHub PR"
	@echo "  make git_branch_create NAME=... [START=...] - Create and checkout new branch"
	@echo "  make git_branch_list [ALL] - List all git branches"
	@echo "  make git_tags - List git tags"
	@echo "  make git_log [COUNT] - Show recent commit history"
	@echo "  make git_diff [REF1] [REF2] - Show diff between refs"
	@echo "  make git_stash [MESSAGE] - Stash current changes"
	@echo "  make git_stash_pop - Pop stashed changes"
	@echo "  make git_checkout [REF] - Checkout a branch or commit"
	@echo "  make git_reset_hard [REF] - Hard reset to a ref"
	@echo "  make git_clean - Clean untracked files"
	@echo "  make git_pull [REMOTE] [BRANCH] - Pull changes from remote"
	@echo "  make mcp_list_tools - List available MCP tools"
	@echo "  make mcp_call NAME=\"...\" [ARGS=\"...] - Call an MCP tool"
	@echo ""
	@echo "Example git workflow:"
	@echo "  make git_commit MESSAGE=\"Fix bug\""
	@echo "  make git_push"
	@echo "  make gh_pr_create TITLE=\"New feature\" BODY=\"Description\" HEAD=main"
	@echo "  make gh_pr_view 1 - View PR #1"
	@echo "  make gh_pr_merge 1 squash - Merge PR #1 using squash"

build:
	./gokujo bootstrap -o lean-worker --backend system

test:
	./gokujo check minimal/RequestProject

infra:
	./gokujo infra

verify:
	./gokujo check minimal/RequestProject --stage full

clean:
	rm -rf .lake build

git_status:
	@./mcp_tool_adapter.py --list-tools

git_commit:
	@echo "Usage: make git_commit MESSAGE=\"Your message\""

git_push:
	@echo "Usage: make git_push [branch]"

gh_pr_create:
	@echo "Usage: make gh_pr_create TITLE=\"...\" BODY=\"...\" HEAD=... [BASE=...] [DRAFT=0] [REVIEWERS=\"...]"

gh_pr_view:
	@echo "Usage: make gh_pr_view [PR_NUMBER]"

gh_pr_merge:
	@echo "Usage: make gh_pr_merge [PR_NUMBER] [METHOD=...]"

gh_pr_close:
	@echo "Usage: make gh_pr_close [PR_NUMBER] [REASON=...]"

git_branch_create:
	@echo "Usage: make git_branch_create NAME=... [START=...]"

git_branch_list:
	@echo "Usage: make git_branch_list [ALL]"

git_tags:
	@./mcp_tool_adapter.py --list-tools

git_log:
	@echo "Usage: make git_log [COUNT=10]"

git_diff:
	@echo "Usage: make git_diff [REF1] [REF2]"

git_stash:
	@echo "Usage: make git_stash [MESSAGE]"

git_stash_pop:
	@echo "Usage: make git_stash_pop"

git_checkout:
	@echo "Usage: make git_checkout [REF]"

git_reset_hard:
	@echo "Usage: make git_reset_hard [REF]"

git_clean:
	@echo "Usage: make git_clean"

git_pull:
	@echo "Usage: make git_pull [REMOTE] [BRANCH]"

mcp_list_tools:
	@./mcp_tool_adapter.py --list-tools

mcp_call:
	@./mcp_tool_adapter.py --tool \"$(NAME)\" --args \"$(ARGS)\"