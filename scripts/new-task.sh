#!/usr/bin/env bash
# new-task.sh — create a task dir + worktree + branch in one shot.
# Usage: bash scripts/new-task.sh <name> ["task description"]
#   Creates:
#     tracker/tasks/<name>/SYSTEM.md      — task description, status
#     worktrees/<name>                    — git worktree on branch agent/<name>
#     updates tracker/current-task.md     — active pointer
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:?usage: new-task.sh <name> [description]}"
DESC="${2:-Task $NAME — see tracker/tasks/$NAME/SYSTEM.md}"
BRANCH="agent/${NAME}"

# refuse to clobber
[ -e "tracker/tasks/$NAME" ] && { echo "task tracker/tasks/$NAME exists"; exit 1; }
[ -e "worktrees/$NAME" ] && { echo "worktree worktrees/$NAME exists"; exit 1; }
git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null && { echo "branch $BRANCH exists"; exit 1; }

# 1. task dir
mkdir -p "tracker/tasks/$NAME"
cat > "tracker/tasks/$NAME/SYSTEM.md" <<SYS
# Task: $NAME

- **Name:** $NAME
- **Priority:** P2
- **Area:** lean-worker
- **Status:** in_progress
- **Branch:** $BRANCH
- **Worktree:** worktrees/$NAME
- **Created:** $(date +%F)

## Description
$DESC

## Done
(append commits here as you land them)

## Verification
(state the exit-0 command that proves this task done)

## Next
SYS

# 2. worktree + branch (base: current HEAD)
git worktree add -b "$BRANCH" "worktrees/$NAME" HEAD

# 3. commit the task dir on the CURRENT branch (tracker lives on main branch)
git add "tracker/tasks/$NAME/SYSTEM.md"
git commit -m "docs(tracker): new task $NAME — $DESC" >/dev/null

# 4. update current-task pointer
cat > tracker/current-task.md <<CUR
# Current Task — lean-worker

- **Task:** $NAME
- **Branch:** $BRANCH
- **Worktree:** worktrees/$NAME
- **Status:** in_progress
- **Updated:** $(date +%F)

## Description
$DESC

Enter: cd worktrees/$NAME
CUR
git add tracker/current-task.md
git commit -m "docs(tracker): current-task -> $NAME" >/dev/null

echo "task:   tracker/tasks/$NAME/SYSTEM.md"
echo "branch: $BRANCH"
echo "enter:  cd worktrees/$NAME"
