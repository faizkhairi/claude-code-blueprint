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

# The introduced text ONLY, without old_string. The protected-path check below must
# not fire when you are REMOVING one of these entries, which is the usual cleanup.
ADDED=$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    ti = json.load(sys.stdin).get('tool_input', {})
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

# Self-referential allow rules for the Claude config directory, which have no effect.
#
# `permissions.allow` does not pre-approve writes to protected paths. The safety check
# runs BEFORE allow rules are evaluated, and the docs name this exact entry shape:
# "an entry such as Edit(.claude/**) ... does not change the per-mode outcome"
# (code.claude.com/docs/en/permission-modes#protected-paths). `.claude` is on the
# protected-directory list, so in auto mode these writes route to the classifier no
# matter what is listed, and in dontAsk mode they are denied outright.
#
# They accumulate on their own: the prompt for a `.claude/` write offers to allow Claude
# to edit its own settings for the SESSION, and that grant gets written into settings.json.
# The write comes from the permission system rather than a tool call, so a PreToolUse hook
# cannot prevent it being created. What it can do is flag the entry before it is committed
# and starts looking like a permission someone deliberately granted.
#
# Matches the introduced text only, so removing an entry is never blocked.
if echo "$ADDED" | grep -qE '"(Edit|Write)\((~|[A-Za-z]:)?[/\\]?[^"]*\.claude[/\\][^"]*\)"'; then
  echo '{"decision": "ask", "reason": "This edit adds an Edit()/Write() allow rule for a path inside the Claude config directory. Those entries have no effect: .claude is a protected path, so the safety check runs before allow rules and the write is routed to the classifier (auto mode) or denied (dontAsk) regardless. See code.claude.com/docs/en/permission-modes#protected-paths. Removing the entry is safe and does not change effective permissions."}'
  exit 0
fi

# All other settings edits pass through.
exit 0
