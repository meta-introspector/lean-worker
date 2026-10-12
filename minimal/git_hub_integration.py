#!/usr/bin/env python3
"""Git and GitHub integration for lean-worker project.

Manages local git operations and GitHub via gh CLI, with MCP/tool-calling support.
"""

import subprocess
import os
import json
import time
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any
import shlex
import sys
import base64

CONFIG_PATH = Path("~/.config/gh_config.json").expanduser()
GIT_CONFIG_PATH = Path(".git_config.json")
PROJECT_ROOT = Path.cwd()
GITHUB_REMOTE = "origin"
WORKTREE_BASE = "refs/heads/feature/gokujo-updates"


class GitHubIntegration:
    """Comprehensive GitHub integration for lean-worker project management."""

    def __init__(self, project_root: str = None):
        self.project_root = Path(project_root) if project_root else PROJECT_ROOT
        self.git_config = self._load_git_config()
        self.gh_config = self._load_gh_config()
        self._validate_environment()

    def _load_git_config(self) -> Dict[str, Any]:
        config_path = self.project_root / ".git_config.json"
        default_config = {
            "user_name": "openhands",
            "user_email": "openhands@all-hands.dev",
            "remote_name": "origin",
            "default_branch": "main",
            "worktree_base": "refs/heads/feature/gokujo-updates",
        }
        if config_path.exists():
            try:
                with open(config_path, "r") as f:
                    user_config = json.load(f)
                    default_config.update(user_config)
            except json.JSONDecodeError:
                print(f"⚠️ Warning: Invalid .git_config.json, using defaults")
        return default_config

    def _load_gh_config(self) -> Dict[str, Any]:
        try:
            result = subprocess.run(
                ["gh", "auth", "status"], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                return {
                    "authenticated": True,
                    "user": "openhands",
                    "repo": "meta-introspector/lean-worker",
                    "token_available": True,
                }
            else:
                return {
                    "authenticated": False,
                    "user": None,
                    "repo": "meta-introspector/lean-worker",
                    "token_available": False,
                }
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return {
                "authenticated": False,
                "user": None,
                "repo": "meta-introspector/lean-worker",
                "token_available": False,
            }

    def _validate_environment(self):
        try:
            subprocess.run(["git", "--version"], capture_output=True, check=True)
            print("✅ Git is available")
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("❌ Git is not available. Please install Git.")
            sys.exit(1)

        try:
            result = subprocess.run(
                ["gh", "--version"], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                print(f"✅ GitHub CLI is available: {result.stdout.strip()}")
            else:
                print("❌ GitHub CLI is not available or not authenticated.")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print("⚠️ Warning: GitHub CLI not available. Some GitHub features will be limited.")

    def execute_command(self, command: str, cwd: str = None) -> Dict[str, Any]:
        """Execute a shell command and return results."""
        try:
            result = subprocess.run(
                shlex.split(command),
                cwd=cwd or self.project_root,
                capture_output=True,
                text=True,
                timeout=300,
                shell=False,
            )
            return {
                "success": result.returncode == 0,
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "error": None if result.returncode == 0 else result.stderr,
                "timestamp": datetime.now().isoformat(),
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "returncode": -1,
                "stdout": "",
                "stderr": "Command timed out after 300 seconds",
                "error": "Command timed out",
                "timestamp": datetime.now().isoformat(),
            }
        except Exception as e:
            return {
                "success": False,
                "returncode": -1,
                "stdout": "",
                "stderr": str(e),
                "error": str(e),
                "timestamp": datetime.now().isoformat(),
            }

    def get_repository_info(self) -> Dict[str, Any]:
        """Get repository information and status."""
        status_result = self.execute_command("git status --porcelain")
        branch_result = self.execute_command("git branch --show-current")
        remote_result = self.execute_command("git remote -v")
        log_result = self.execute_command("git log -1 --oneline")
        return {
            "status": status_result,
            "current_branch": branch_result.get("stdout", "").strip(),
            "remote": remote_result.get("stdout", ""),
            "last_commit": log_result.get("stdout", "").strip(),
            "files_changed": self._count_changed_files(status_result),
            "modified": self._get_modified_files(status_result),
            "untracked": self._get_untracked_files(status_result),
        }

    def _count_changed_files(self, status_result: Dict) -> int:
        if not status_result.get("success"):
            return 0
        stdout = status_result.get("stdout", "")
        return len([line for line in stdout.split("\n") if line.strip()])

    def _get_modified_files(self, status_result: Dict) -> List[str]:
        if not status_result.get("success"):
            return []
        stdout = status_result.get("stdout", "")
        return [
            line.strip().split(" ", 1)[0] + " " + line.strip().split(" ", 1)[1] if len(line.strip().split(" ")) > 1 else line.strip().split(" ")[0]
            for line in stdout.split("\n")
            if line.strip() and line.strip()[0] in "MADRC"
        ]

    def _get_untracked_files(self, status_result: Dict) -> List[str]:
        if not status_result.get("success"):
            return []
        stdout = status_result.get("stdout", "")
        return [
            line.strip().split(" ")[0]
            for line in stdout.split("\n")
            if line.strip() and line.strip()[0] == "??"
        ]

    def push_changes(
        self, branch: str = None, commit_message: str = None, push_tags: bool = True
    ) -> Dict[str, Any]:
        """Push changes to GitHub."""
        current_branch = self.execute_command("git branch --show-current").get("stdout", "").strip()
        target_branch = branch or current_branch
        stage_result = self.execute_command("git add .")
        commit_result = None
        if commit_message:
            commit_result = self.execute_command(f'git commit -m "{commit_message}"')
        push_result = self.execute_command(
            f"git push {self.git_config['remote_name']} {target_branch}"
        )
        tag_result = None
        if push_tags:
            tag_result = self.execute_command("git push --tags")
        return {
            "staged": stage_result,
            "committed": commit_result,
            "pushed": push_result,
            "tags": tag_result,
            "branch": target_branch,
            "remote": self.git_config["remote_name"],
        }

    def create_pr(
        self,
        title: str,
        body: str,
        head: str,
        base: str = None,
        draft: bool = False,
        reviewers: List[str] = None,
    ) -> Dict[str, Any]:
        """Create a pull request on GitHub."""
        if not self.gh_config.get("authenticated"):
            return {
                "success": False,
                "error": "Not authenticated to GitHub. Run 'gh auth login' first.",
                "pr": None,
            }

        base_branch = base or self.git_config["default_branch"]
        pr_cmd = (
            f"gh pr create --title \"{title}\" --body \"{body}\" "
            f"--head {head} --base {base_branch}"
        )
        if draft:
            pr_cmd += " --draft"
        if reviewers:
            pr_cmd += f" --reviewer {','.join(reviewers)}"

        pr_result = self.execute_command(pr_cmd)
        pr_url = None
        if pr_result.get("success"):
            for line in pr_result.get("stdout", "").split("\n"):
                if "https://github.com/" in line and "/pull/" in line:
                    pr_url = line.strip()
                    break

        return {
            "success": pr_result.get("success", False),
            "command": pr_cmd,
            "result": pr_result,
            "pr_url": pr_url,
            "title": title,
            "head": head,
            "base": base_branch,
            "draft": draft,
        }

    def get_pr_info(self, pr_number: int = None, head: str = None) -> Dict[str, Any]:
        """Get pull request information."""
        if pr_number:
            cmd = f"gh pr view {pr_number} --json title,body,state,head_ref,base_ref --jq '. | @base64'"
        elif head:
            cmd = f"gh pr view {head} --json title,body,state,head_ref,base_ref --jq '. | @base64'"
        else:
            return {
                "success": False,
                "error": "Either PR number or head branch required",
                "pr": None,
            }

        result = self.execute_command(cmd)
        if result.get("success"):
            try:
                pr_data = json.loads(base64.b64decode(result.get("stdout", "").strip()).decode())
                return {"success": True, "pr": pr_data}
            except Exception as e:
                return {
                    "success": False,
                    "error": f"Failed to parse PR data: {str(e)}",
                    "pr": None,
                }
        else:
            return {"success": False, "error": "Failed to get PR information", "pr": None}

    def merge_pr(
        self,
        pr_number: int,
        merge_method: str = "squash",
        commit_title: str = None,
        commit_message: str = None,
    ) -> Dict[str, Any]:
        """Merge a pull request."""
        cmd = f"gh pr merge {pr_number} --{merge_method}"
        if commit_title:
            cmd += f" --commit-title \"{commit_title}\""
        if commit_message:
            cmd += f" --commit-message \"{commit_message}\""

        result = self.execute_command(cmd)
        return {
            "success": result.get("success", False),
            "command": cmd,
            "result": result,
            "pr_number": pr_number,
            "merge_method": merge_method,
        }

    def close_pr(self, pr_number: int, reason: str = "completed") -> Dict[str, Any]:
        """Close a pull request."""
        cmd = f"gh pr close {pr_number} --reason {reason}"
        result = self.execute_command(cmd)
        return {
            "success": result.get("success", False),
            "command": cmd,
            "result": result,
            "pr_number": pr_number,
            "reason": reason,
        }

    def create_branch(self, branch_name: str, start_point: str = None) -> Dict[str, Any]:
        """Create a new branch."""
        start = start_point or "HEAD"
        cmd = f"git branch {branch_name} {start}"
        checkout_result = self.execute_command(f"git checkout {branch_name}")
        return {
            "success": checkout_result.get("success", False),
            "command": cmd,
            "result": checkout_result,
            "branch_name": branch_name,
            "start_point": start_point,
        }

    def list_branches(self, all_branches: bool = False) -> Dict[str, Any]:
        """List branches in the repository."""
        cmd = f"git branch {'-a' if all_branches else ''}"
        result = self.execute_command(cmd)
        branches = []
        if result.get("success"):
            for line in result.get("stdout", "").split("\n"):
                line = line.strip()
                if line:
                    branches.append(
                        {
                            "name": line.replace("*", "").strip(),
                            "current": line.startswith("*"),
                            "deleted": line.startswith("-"),
                        }
                    )
        return {
            "success": result.get("success", False),
            "command": cmd,
            "result": result,
            "branches": branches,
        }

    def get_tags(self) -> Dict[str, Any]:
        """Get tags in the repository."""
        cmd = "git tag --list"
        result = self.execute_command(cmd)
        tags = []
        if result.get("success"):
            for line in result.get("stdout", "").split("\n"):
                line = line.strip()
                if line:
                    tags.append(line)
        return {"success": result.get("success", False), "command": cmd, "result": result, "tags": tags}

    def get_commit_history(self, limit: int = 10) -> Dict[str, Any]:
        """Get commit history."""
        cmd = f"git log -{limit} --oneline"
        result = self.execute_command(cmd)
        commits = []
        if result.get("success"):
            for line in result.get("stdout", "").split("\n"):
                line = line.strip()
                if line:
                    commits.append(line)
        return {"success": result.get("success", False), "command": cmd, "result": result, "commits": commits}

    def get_diff(self, ref1: str = None, ref2: str = None) -> Dict[str, Any]:
        """Get diff between commits/branches."""
        ref1 = ref1 or "HEAD~1"
        ref2 = ref2 or "HEAD"
        cmd = f"git diff {ref1}..{ref2}"
        result = self.execute_command(cmd)
        return {
            "success": result.get("success", False),
            "command": cmd,
            "result": result,
            "diff": result.get("stdout", ""),
        }

    def stash_changes(self, message: str = None) -> Dict[str, Any]:
        """Stash current changes."""
        cmd = f"git stash save" + (f" \"{message}\"" if message else "")
        result = self.execute_command(cmd)
        return {"success": result.get("success", False), "command": cmd, "result": result}

    def stash_pop(self) -> Dict[str, Any]:
        """Pop stashed changes."""
        cmd = "git stash pop"
        result = self.execute_command(cmd)
        return {"success": result.get("success", False), "command": cmd, "result": result}

    def checkout(self, ref: str) -> Dict[str, Any]:
        """Checkout a branch or commit."""
        cmd = f"git checkout {ref}"
        result = self.execute_command(cmd)
        return {"success": result.get("success", False), "command": cmd, "result": result, "ref": ref}

    def reset_hard(self, ref: str = "HEAD") -> Dict[str, Any]:
        """Reset to a specific commit."""
        cmd = f"git reset --hard {ref}"
        result = self.execute_command(cmd)
        return {"success": result.get("success", False), "command": cmd, "result": result, "ref": ref}

    def clean_untracked(self) -> Dict[str, Any]:
        """Clean untracked files."""
        cmd = "git clean -fd"
        result = self.execute_command(cmd)
        return {"success": result.get("success", False), "command": cmd, "result": result}

    def pull(self, remote: str = None, branch: str = None) -> Dict[str, Any]:
        """Pull changes from remote."""
        remote_name = remote or self.git_config["remote_name"]
        branch_name = branch or self.execute_command("git branch --show-current").get("stdout", "").strip()
        cmd = f"git pull {remote_name} {branch_name}"
        result = self.execute_command(cmd)
        return {"success": result.get("success", False), "command": cmd, "result": result}


# Create a global instance for convenience
integration = GitHubIntegration()

if __name__ == "__main__":
    # Test the integration
    print("GitHub Integration Test")
    info = integration.get_repository_info()
    print(f"Current branch: {info.get('current_branch')}")
    print(f"Files changed: {info.get('files_changed')}")
    print(f"Modified files: {info.get('modified')}")
    print(f"Untracked files: {info.get('untracked')}")