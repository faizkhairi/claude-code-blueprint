#!/bin/bash
# Hook: PreToolUse (Write|Edit) - Claude settings self-protection.
# Fires only on edits to ~/.claude/settings.json or settings.local.json.
# Prompts (permissionDecision: ask) ONLY when the edit touches a SAFETY key that could
# silently weaken the harness: defaultMode (which can enable bypassPermissions),
# the deny or ask permission lists, disableAllHooks, or disableAutoMode. Routine
# edits (adding an allow rule, a theme, an env var) pass through with no prompt.
# A subagent cannot answer the prompt, so for a call with a non-empty top-level
# agent_id the same message is a deny that says to ask the user (see emit_ask).
#
# The path is normalised before it is matched: \ becomes /, // and /./ collapse, x/.. is resolved,
# trailing dots and spaces are stripped (Win32 ignores them), an NTFS stream suffix on the file name
# (::$DATA, :$DATA, :name, :name:$DATA) is cut off, case is folded, and an 8.3 short name
# such as .claude/SETTIN~1.JSO counts as settings.json. Scope: this hook sees the Write and Edit tools
# only. A shell command that writes the settings file (sed -i, echo > settings.json) is out of scope here.
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

# The path is normalised before it is matched (see the header), so a different spelling of the same
# file cannot slip past. The normaliser below is the same text in protect-config.sh and
# protect-claude-settings.sh, and hooks/test-hooks.sh diffs the copies.
IFS= read -r -d '' PATH_SRC <<'PYEOF' || true
# BEGIN SHARED NORMPATH (the same text in protect-config.sh and protect-claude-settings.sh; hooks/test-hooks.sh diffs the copies)
import re

def norm_path(p):
    # Spell a path one way before it is matched: \ becomes /, // and /./ collapse, x/.. is
    # resolved, trailing dots and spaces are stripped (Win32 ignores them), and case is folded.
    # An NTFS stream suffix on the last component (::$DATA, :$DATA, :name, :name:$DATA) names the
    # same file, so it is cut off; a leading drive letter (C:) keeps its colon.
    out = []
    parts = p.replace('\\', '/').split('/')
    for k, s in enumerate(parts):
        if k == len(parts) - 1:
            drive = s[:2] if k == 0 and re.match(r'^[A-Za-z]:', s) else ''
            s = drive + s[len(drive):].split(':', 1)[0]
        if s in ('', '.'):
            continue
        if s == '..':
            if out:
                out.pop()
            continue
        out.append((s.rstrip('. ') or s).lower())
    return '/' + '/'.join(out)

def expand_short(seg, names):
    # An 8.3 short name such as settin~1.jso stands for a long file name: if its stem is the first
    # 6 letters of one of names, return that name, else seg unchanged.
    m = re.match(r'^([^~.]{1,6})~\d+(?:\.[^.]{0,3})?$', seg)
    if m:
        for n in names:
            flat = n.lstrip('.').rsplit('.', 1)[0] if '.' in n.lstrip('.') else n.lstrip('.')
            flat = flat.replace('.', '')
            if flat.startswith(m.group(1)) and len(m.group(1)) == min(6, len(flat)):
                return n
    return seg
# END SHARED NORMPATH
import sys, json

try:
    fp = json.load(sys.stdin).get('tool_input', {}).get('file_path', '')
    if not isinstance(fp, str):
        fp = ''
except Exception:
    fp = ''
p = norm_path(fp)
segs = p.split('/')
if len(segs) >= 2:
    if re.match(r'^claude~\d+$', segs[-2]):
        segs[-2] = '.claude'
    segs[-1] = expand_short(segs[-1], ['settings.json', 'settings.local.json'])
p = '/'.join(segs)
sys.stdout.buffer.write(p.encode('utf-8'))
PYEOF
FILE_PATH=$(printf '%s' "$INPUT" | "$PYTHON" -c "$PATH_SRC" 2>/dev/null)

# Only act on the Claude settings files themselves.
if ! echo "$FILE_PATH" | grep -qiE '\.claude[/\\]settings(\.local)?\.json$'; then
  exit 0
fi

# Gather the text this edit introduces: new_string (Edit) or content (Write),
# plus old_string (Edit) so a removed safety key is caught too.
COMBINED=$(echo "$INPUT" | "$PYTHON" -c "
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
ADDED=$(echo "$INPUT" | "$PYTHON" -c "
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
  emit_ask "This edit touches a Claude safety setting (defaultMode / deny / ask / disableAllHooks / disableAutoMode / bypassPermissions). Confirm it does not weaken the permission guards or disable hooks. Routine settings edits (allow rules, theme, env) do not trigger this prompt."
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
  emit_ask "This edit adds an Edit()/Write() allow rule for a path inside the Claude config directory. Those entries have no effect: .claude is a protected path, so the safety check runs before allow rules and the write is routed to the classifier (auto mode) or denied (dontAsk) regardless. See code.claude.com/docs/en/permission-modes#protected-paths. Removing the entry is safe and does not change effective permissions."
  exit 0
fi

# All other settings edits pass through.
exit 0
