#!/bin/bash
# PostToolUse hook (async): After a git commit, remind Claude to review changes.
# Only triggers on actual git commit commands, not amend/help/dry-run.
# Pattern: same stdin JSON parsing as notify-file-changed.sh

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only trigger on git commit commands at command boundaries
# Matches: "git commit ...", "git add . && git commit ...", "cd /path ; git commit ..."
# Rejects: "echo git commit is nice", "grep 'git commit' file"
if ! echo "$COMMAND" | grep -qE '(^|[;&|]\s*)git\s+commit\b'; then
  exit 0
fi

# Skip amend, help, dry-run (not new commits worth reviewing)
if echo "$COMMAND" | grep -qE '\-\-amend|\-\-help|\-h\b|\-\-dry-run'; then
  exit 0
fi

# Get the latest commit info (runs AFTER commit succeeded)
COMMIT_MSG=$(git log -1 --oneline 2>/dev/null)
# Use diff-tree with --root — works for all commits including root (initial) commits
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r --root HEAD 2>/dev/null)

# If no commit info, the commit may have failed — skip silently
if [ -z "$COMMIT_MSG" ]; then
  exit 0
fi

# Count files (guard against empty string giving wc -l = 1)
if [ -z "$CHANGED_FILES" ]; then
  FILE_COUNT=0
else
  FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
fi
HIGH_RISK=""
if echo "$CHANGED_FILES" | grep -qiE '(guard|middleware|auth|prisma\.schema|\.env)'; then
  HIGH_RISK=" HIGH-RISK FILES DETECTED (auth/guard/middleware/schema/env) -- review is strongly recommended."
fi

# Build file list (truncate if >10 files)
if [ "$FILE_COUNT" -gt 10 ]; then
  FILE_LIST=$(echo "$CHANGED_FILES" | head -10)
  FILE_LIST="$FILE_LIST
... and $((FILE_COUNT - 10)) more files"
else
  FILE_LIST="$CHANGED_FILES"
fi

# Escape strings for JSON output
FILE_LIST_ESCAPED=$(echo "$FILE_LIST" | python -c "
import sys, json
print(json.dumps(sys.stdin.read().strip())[1:-1])
" 2>/dev/null)

COMMIT_ESCAPED=$(echo "$COMMIT_MSG" | python -c "
import sys, json
print(json.dumps(sys.stdin.read().strip())[1:-1])
" 2>/dev/null)

echo "{\"systemMessage\": \"POST-COMMIT REVIEW REMINDER: Commit created: $COMMIT_ESCAPED ($FILE_COUNT files changed).${HIGH_RISK} Changed files:\\n$FILE_LIST_ESCAPED\\n\\nConsider running /review-diff for quick anti-pattern scan or /review for comprehensive analysis.\"}"

exit 0
