#!/bin/bash
# Hook: PreCompact (sync). State Serialization
# Writes a JSON snapshot of current working state before compaction.
# PostCompact hook references this file for context recovery.
#
# Requires: python3 or python on PATH
# Exit code: always 0 (never blocks compaction)

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "precompact-state: python not found: state not saved" >&2
  exit 0
fi

export HOOK_STATE_FILE="$HOME/.claude/precompact-state.json"
export HOOK_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export HOOK_PLAN_FILE=$(ls -t "$HOME/.claude/plans/"*.md 2>/dev/null | head -1)
export HOOK_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
export HOOK_CWD=$(pwd)

$PYTHON -c "
import os, json
state = {
    'timestamp': os.environ.get('HOOK_TIMESTAMP', ''),
    'plan': os.environ.get('HOOK_PLAN_FILE', 'none') or 'none',
    'branch': os.environ.get('HOOK_BRANCH', 'unknown'),
    'cwd': os.environ.get('HOOK_CWD', '')
}
state_file = os.environ.get('HOOK_STATE_FILE', '')
if state_file:
    try:
        with open(state_file, 'w') as f:
            json.dump(state, f)
    except Exception as e:
        import sys
        print(f'precompact-state: write failed: {e}', file=sys.stderr)
" 2>/dev/null

exit 0
