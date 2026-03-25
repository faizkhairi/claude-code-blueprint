#!/bin/bash
# Hook: PreCompact (sync) — State Serialization
# Writes a JSON snapshot of current working state before compaction.
# PostCompact hook references this file for context recovery.

STATE_FILE="$HOME/.claude/precompact-state.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PLAN_FILE=$(ls -t "$HOME/.claude/plans/"*.md 2>/dev/null | head -1)
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
CWD=$(pwd)

cat > "$STATE_FILE" << EOF
{"timestamp":"$TIMESTAMP","plan":"${PLAN_FILE:-none}","branch":"$BRANCH","cwd":"$CWD"}
EOF

exit 0
