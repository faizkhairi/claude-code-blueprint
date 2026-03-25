#!/bin/bash
# PostToolUse hook (async): Delivers a systemMessage reminder after source file edits.
# Runs in the background — Claude sees the systemMessage on the next turn.
# Only triggers for source files (.js, .ts, .vue, .py, .prisma), not docs/config.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

if echo "$FILE_PATH" | grep -qE '\.(js|ts|vue|py|prisma)$' && ! echo "$FILE_PATH" | grep -qE '(\.test\.|\.spec\.|/__tests__/|/tests/|/test/)'; then
  echo '{"systemMessage": "Source file modified. Verify before declaring done: run tests, check types, re-read the edited file to confirm the change landed correctly."}'
fi

exit 0
