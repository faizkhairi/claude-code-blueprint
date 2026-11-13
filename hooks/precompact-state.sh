#!/bin/bash
# Hook: PreCompact (sync). State Serialization + compaction instructions
# Writes a JSON snapshot of current working state before compaction, then prints
# instructions for the compaction summary on stdout. On PreCompact, a hook's
# plain-text stdout (exit 0) becomes instructions for the summary Claude Code
# writes, so this is where "keep the todo list and the active plan" belongs.
# (A prompt hook is not supported on PreCompact; only command, http and
# mcp_tool hooks run there.)
#
# Requires: python3 or python on PATH
# Exit code: always 0 (never blocks compaction)

# Instructions for the compaction summary. Plain text (not JSON), kept well under
# the 10,000 character cap Claude Code applies to PreCompact stdout. Printed even
# when Python is missing, since only the state snapshot needs Python.
KEEP_LINE="When writing the compaction summary, preserve: the current todo list with each item's status; every file path modified in this session; verification steps not yet run; key decisions and their rationale; the active plan and which step is in progress; any preference or constraint the user stated in this session."

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then
  echo "precompact-state: python not found: state not saved" >&2
  echo "$KEEP_LINE"
  exit 0
fi

export HOOK_STATE_FILE="$HOME/.claude/precompact-state.json"
HOOK_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export HOOK_TIMESTAMP
# shellcheck disable=SC2012 # plan files are simple names; we need mtime order, which `ls -t` gives directly
HOOK_PLAN_FILE=$(ls -t "$HOME/.claude/plans/"*.md 2>/dev/null | head -1)
export HOOK_PLAN_FILE
HOOK_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
export HOOK_BRANCH
HOOK_CWD=$(pwd)
export HOOK_CWD
rm -f "$HOOK_STATE_FILE"

"$PYTHON" -c "
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

echo "$KEEP_LINE"
# Name the snapshot only if this run wrote it (the old file was removed above).
if [ -s "$HOOK_STATE_FILE" ]; then
  echo "A state snapshot (active plan file, branch, working directory) was saved to $HOOK_STATE_FILE. Name that path in the summary so it can be read back after compaction."
fi

exit 0
