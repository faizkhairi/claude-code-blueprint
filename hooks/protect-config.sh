#!/bin/bash
# Hook: PreToolUse (Write|Edit). Config Protection
# Prevents weakening linter/formatter/build configs by prompting for confirmation.
# A subagent cannot answer the prompt, so for a call with a non-empty top-level
# agent_id the same message is a deny that says to ask the user (see emit_ask).

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

# emit_ask <reason>: print the PreToolUse "ask" decision. A subagent (the hook input has
# a non-empty top-level agent_id) cannot answer a permission prompt, and a background one
# waits forever, so for a subagent the same reason goes out as a deny that says to hand
# the change to the user. agent_type alone does not count: it also marks a `claude --agent`
# main thread, which can answer.
emit_ask() {
  local reason="$1" decision=ask sub
  sub=$(printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    a = json.load(sys.stdin).get('agent_id')
    print('1' if isinstance(a, str) and a else '')
except Exception:
    print('')
" 2>/dev/null)
  if [ -n "$sub" ]; then
    decision=deny
    reason="$reason Denied instead of asked: this call came from a subagent, which cannot answer a permission prompt. Ask the user to make this change."
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
}

FILE_PATH=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Block if editing config files that should not be weakened
if echo "$FILE_PATH" | grep -qiE '(eslint\.config|\.eslintrc|prettier\.config|\.prettierrc|tsconfig|biome\.json|vitest\.config|\.stylelintrc|tailwind\.config|next\.config|nuxt\.config|jest\.config|\.npmrc|webpack\.config|rollup\.config)'; then
  emit_ask "This is a linter/formatter/build config file. Confirm this edit improves the config rather than weakening rules to suppress errors."
  exit 0
fi

# Pass through for all other files
exit 0
