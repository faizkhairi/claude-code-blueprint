#!/bin/bash
# SessionStart hook: Injects workspace context at session start.
# Also detects stale sessions (from IDE restart, crash, etc.)
# by comparing session checkpoint timestamp against session.md date.
#
# Configure: Set SESSION_FILE to your memory system's session file path.
#            Set WORKSPACE_CONTEXT to describe your workspace layout.

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "session-start: python not found -- session context not injected" >&2
  exit 0
fi

# Path to your session memory file (set to your memory repo path)
SESSION_FILE="${MEMORY_PATH:-$HOME/memory-core}/core/session.md"
CHECKPOINT_FILE="$HOME/.claude/session-checkpoint.txt"

# Detect stale session (session.md older than last checkpoint)
STALE_WARNING=""
if [ -f "$CHECKPOINT_FILE" ] && [ -f "$SESSION_FILE" ]; then
  CHECKPOINT_DATE=$(head -1 "$CHECKPOINT_FILE" | cut -d' ' -f1)
  SESSION_DATE=$(grep -m1 'Last Updated' "$SESSION_FILE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')

  if [ -n "$CHECKPOINT_DATE" ] && [ -n "$SESSION_DATE" ]; then
    # Use POSIX-compatible test (bash 3.2+, also dash/ash). YYYY-MM-DD format sorts lexically.
    if [ "$CHECKPOINT_DATE" \> "$SESSION_DATE" ]; then
      export STALE_WARNING="STALE SESSION DETECTED: Last checkpoint was $CHECKPOINT_DATE but session.md was last updated $SESSION_DATE. A previous session may have ended abruptly. Check recent plan files and git status to recover context."
    fi
  fi
fi

# Configure: Describe your workspace layout and critical rules here
export WORKSPACE_CONTEXT="Active workspace: $(pwd). Always verify after completing work: run tests, check types, hit live endpoints."

$PYTHON -c "
import os, json
stale = os.environ.get('STALE_WARNING', '')
workspace = os.environ.get('WORKSPACE_CONTEXT', '')
prefix = (stale + ' ') if stale else ''
context = prefix + workspace
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context
    }
}))
" 2>/dev/null

exit 0
