#!/bin/bash
# Hook: PreToolUse (Write|Edit) - Claude settings self-protection.
# Fires only on edits to ~/.claude/settings.json or settings.local.json.
# Prompts (decision:ask) ONLY when the edit touches a SAFETY key that could
# silently weaken the harness: defaultMode (which can enable bypassPermissions),
# the deny or ask permission lists, disableAllHooks, or disableAutoMode. Routine
# edits (adding an allow rule, a theme, an env var) pass through with no prompt.
#
# Why this exists: settings-schema validation rejects INVALID keys, but it does
# not catch VALID-but-dangerous ones. If your permissions allow editing files
# broadly, nothing else gates a settings edit that removes a deny rule or flips
# the harness into a less-guarded mode. A PreToolUse hook fires regardless of the
# allow-list (being on the allow-list skips the PROMPT, not the hook), so this
# restores a mechanical backstop: it protects the config that protects you.
#
# JSON parsing uses Python (see hooks/README "Why Python"); fail-open if Python
# is unavailable, so a missing dependency never blocks an edit.
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Only act on the Claude settings files themselves.
if ! echo "$FILE_PATH" | grep -qiE '\.claude[/\\]settings(\.local)?\.json$'; then
  exit 0
fi

# Gather the text this edit introduces: new_string (Edit) or content (Write),
# plus old_string (Edit) so a removed safety key is caught too.
COMBINED=$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    ti = json.load(sys.stdin).get('tool_input', {})
    print(ti.get('old_string', ''))
    print(ti.get('new_string', ti.get('content', '')))
except:
    print('')
" 2>/dev/null)

# Safety keys whose presence in the edit warrants a confirm.
if echo "$COMBINED" | grep -qE '"(defaultMode|deny|ask|disableAllHooks|disableAutoMode)"' \
   || echo "$COMBINED" | grep -qE 'bypassPermissions'; then
  echo '{"decision": "ask", "reason": "This edit touches a Claude safety setting (defaultMode / deny / ask / disableAllHooks / disableAutoMode / bypassPermissions). Confirm it does not weaken the permission guards or disable hooks. Routine settings edits (allow rules, theme, env) do not trigger this prompt."}'
  exit 0
fi

# All other settings edits pass through.
exit 0
