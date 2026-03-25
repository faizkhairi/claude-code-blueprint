#!/bin/bash
# Stop hook (async): Writes a lightweight checkpoint after every assistant response.
# Used by session-start.sh to detect lost sessions (Reload Window, crash, etc).
# This file is overwritten on every response -- only the latest timestamp matters.

CHECKPOINT_FILE="$HOME/.claude/session-checkpoint.txt"
date '+%Y-%m-%d %H:%M:%S' > "$CHECKPOINT_FILE"
exit 0
