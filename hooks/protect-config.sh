#!/bin/bash
# Hook: PreToolUse (Write|Edit) — Config Protection
# Prevents weakening linter/formatter/build configs by prompting for confirmation.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Block if editing config files that should not be weakened
if echo "$FILE_PATH" | grep -qiE '(eslint\.config|\.eslintrc|prettier\.config|\.prettierrc|tsconfig|biome\.json|vitest\.config|\.stylelintrc|tailwind\.config|next\.config|nuxt\.config|jest\.config|\.npmrc|webpack\.config|rollup\.config)'; then
  echo '{"decision": "ask", "reason": "This is a linter/formatter/build config file. Confirm this edit improves the config rather than weakening rules to suppress errors."}'
  exit 0
fi

# Pass through for all other files
exit 0
