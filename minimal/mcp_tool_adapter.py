#!/usr/bin/env python3
"""MCP/tool-calling adapter for lean-worker project.

Exposes git and GitHub operations as MCP-compatible tools.
"""

import json
import argparse
from typing import Dict, Any, List
from git_hub_integration import GitHubIntegration

# Tool schema definitions
TOOLS = [
    {
        "name": "git_status",
        "description": "Get git repository status and current branch.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                }
            },
            "required": [],
        },
    },
    {
        "name": "git_commit",
        "description": "Stage all changes and commit with a message.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "Commit message."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["message"],
        },
    },
    {
        "name": "git_push",
        "description": "Push current branch to remote.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "branch": {
                    "type": "string",
                    "description": "Branch to push."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "gh_pr_create",
        "description": "Create a GitHub pull request via gh CLI.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Pull request title."
                },
                "body": {
                    "type": "string",
                    "description": "Pull request body."
                },
                "head": {
                    "type": "string",
                    "description": "Head branch."
                },
                "base": {
                    "type": "string",
                    "description": "Base branch."
                },
                "draft": {
                    "type": "boolean",
                    "description": "Create as draft PR."
                },
                "reviewers": {
                    "type": "array",
                    "description": "List of reviewers.",
                    "items": {
                        "type": "string"
                    },
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["title", "body", "head"],
        },
    },
    {
        "name": "gh_pr_view",
        "description": "View a GitHub pull request via gh CLI.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "pr_number": {
                    "type": "integer",
                    "description": "Pull request number."
                },
                "head": {
                    "type": "string",
                    "description": "Head branch if PR number is not provided."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "gh_pr_merge",
        "description": "Merge a GitHub pull request via gh CLI.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "pr_number": {
                    "type": "integer",
                    "description": "Pull request number."
                },
                "merge_method": {
                    "type": "string",
                    "description": "Merge method: merge, squash, or rebase."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["pr_number"],
        },
    },
    {
        "name": "gh_pr_close",
        "description": "Close a GitHub pull request via gh CLI.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "pr_number": {
                    "type": "integer",
                    "description": "Pull request number."
                },
                "reason": {
                    "type": "string",
                    "description": "Close reason."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["pr_number"],
        },
    },
    {
        "name": "git_branch_create",
        "description": "Create and checkout a new git branch.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "branch_name": {
                    "type": "string",
                    "description": "New branch name."
                },
                "start_point": {
                    "type": "string",
                    "description": "Start point for the branch."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["branch_name"],
        },
    },
    {
        "name": "git_branch_list",
        "description": "List git branches.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "all_branches": {
                    "type": "boolean",
                    "description": "Include remote branches."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_tags",
        "description": "List git tags.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_log",
        "description": "Show recent commit history.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {
                    "type": "integer",
                    "description": "Number of commits to show."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_diff",
        "description": "Show diff between two refs.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "ref1": {
                    "type": "string",
                    "description": "First ref."
                },
                "ref2": {
                    "type": "string",
                    "description": "Second ref."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_stash",
        "description": "Stash current changes.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "Stash message."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_stash_pop",
        "description": "Pop stashed changes.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_checkout",
        "description": "Checkout a branch or commit.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "ref": {
                    "type": "string",
                    "description": "Branch or commit ref."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["ref"],
        },
    },
    {
        "name": "git_reset_hard",
        "description": "Hard reset to a ref.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "ref": {
                    "type": "string",
                    "description": "Target ref."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": ["ref"],
        },
    },
    {
        "name": "git_clean",
        "description": "Clean untracked files.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
    {
        "name": "git_pull",
        "description": "Pull changes from remote.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "remote": {
                    "type": "string",
                    "description": "Remote name."
                },
                "branch": {
                    "type": "string",
                    "description": "Branch to pull."
                },
                "project_root": {
                    "type": "string",
                    "description": "Optional project root path."
                },
            },
            "required": [],
        },
    },
]


class MCPToolAdapter:
    """MCP-compatible tool calling adapter."""

    def __init__(self, project_root: str = None):
        self.integration = GitHubIntegration(project_root=project_root)

    def list_tools(self) -> Dict[str, Any]:
        return {"tools": TOOLS}

    def call_tool(self, name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        try:
            if name == "git_status":
                return self.integration.get_repository_info()
            elif name == "git_commit":
                return self.integration.push_changes(commit_message=arguments["message"])
            elif name == "git_push":
                return self.integration.push_changes(branch=arguments.get("branch"))
            elif name == "gh_pr_create":
                return self.integration.create_pr(
                    title=arguments["title"],
                    body=arguments["body"],
                    head=arguments["head"],
                    base=arguments.get("base"),
                    draft=arguments.get("draft", False),
                    reviewers=arguments.get("reviewers"),
                )
            elif name == "gh_pr_view":
                return self.integration.get_pr_info(
                    pr_number=arguments.get("pr_number"),
                    head=arguments.get("head"),
                )
            elif name == "gh_pr_merge":
                return self.integration.merge_pr(
                    pr_number=arguments["pr_number"],
                    merge_method=arguments.get("merge_method", "squash"),
                )
            elif name == "gh_pr_close":
                return self.integration.close_pr(
                    pr_number=arguments["pr_number"],
                    reason=arguments.get("reason", "completed"),
                )
            elif name == "git_branch_create":
                return self.integration.create_branch(
                    branch_name=arguments["branch_name"],
                    start_point=arguments.get("start_point"),
                )
            elif name == "git_branch_list":
                return self.integration.list_branches(
                    all_branches=arguments.get("all_branches", False)
                )
            elif name == "git_tags":
                return self.integration.get_tags()
            elif name == "git_log":
                return self.integration.get_commit_history(
                    limit=arguments.get("limit", 10)
                )
            elif name == "git_diff":
                return self.integration.get_diff(
                    ref1=arguments.get("ref1"),
                    ref2=arguments.get("ref2"),
                )
            elif name == "git_stash":
                return self.integration.stash_changes(
                    message=arguments.get("message")
                )
            elif name == "git_stash_pop":
                return self.integration.stash_pop()
            elif name == "git_checkout":
                return self.integration.checkout(arguments["ref"])
            elif name == "git_reset_hard":
                return self.integration.reset_hard(arguments["ref"])
            elif name == "git_clean":
                return self.integration.clean_untracked()
            elif name == "git_pull":
                return self.integration.pull(
                    remote=arguments.get("remote"),
                    branch=arguments.get("branch"),
                )
            else:
                return {
                    "success": False,
                    "error": f"Unknown tool: {name}",
                }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def handle_request(self, request: Dict[str, Any]) -> Dict[str, Any]:
        """Handle MCP-style request."""
        method = request.get("method")
        if method == "tools/list":
            return {"result": self.list_tools()}
        elif method == "tools/call":
            name = request.get("params", {}).get("name")
            arguments = request.get("params", {}).get("arguments", {})
            result = self.call_tool(name, arguments)
            return {"result": {"content": [{"type": "text", "text": json.dumps(result)}]}}
        else:
            return {"error": "Unsupported method"}


def main():
    parser = argparse.ArgumentParser(description="MCP/tool-calling adapter for lean-worker")
    parser.add_argument("--project-root", default=None, help="Project root path")
    parser.add_argument("--list-tools", action="store_true", help="List available tools")
    parser.add_argument("--tool", default=None, help="Tool name to call")
    parser.add_argument("--args", default="{}", help="JSON arguments for the tool")
    args = parser.parse_args()

    adapter = MCPToolAdapter(project_root=args.project_root)

    if args.list_tools:
        print(json.dumps(adapter.list_tools(), indent=2))
        return

    if args.tool:
        result = adapter.call_tool(args.tool, json.loads(args.args))
        print(json.dumps(result, indent=2))
        return

    print(json.dumps(adapter.handle_request({"method": "tools/list"}), indent=2))


if __name__ == "__main__":
    main()
