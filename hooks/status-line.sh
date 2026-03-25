#!/bin/bash
# statusLine hook: Displays current project name, git branch, and dirty state.
# Output: "project @ branch" (clean) or "project @ branch*" (uncommitted changes)

BRANCH=$(git -C "$PWD" branch --show-current 2>/dev/null || echo "no-git")
PROJECT=$(basename "$PWD")
DIRTY=""
if [ -n "$(git -C "$PWD" status --porcelain 2>/dev/null)" ]; then
  DIRTY="*"
fi
echo "$PROJECT @ $BRANCH$DIRTY"
