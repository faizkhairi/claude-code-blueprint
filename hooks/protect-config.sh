#!/bin/bash
# Hook: PreToolUse (Write|Edit). Config Protection
# Prevents weakening linter/formatter/build configs by prompting for confirmation.
# A subagent cannot answer the prompt, so for a call with a non-empty top-level
# agent_id the same message is a deny that says to ask the user (see emit_ask).
#
# The path is normalised before it is matched: \ becomes /, // and /./ collapse, x/.. is resolved,
# trailing dots and spaces are stripped (Win32 ignores them), an NTFS stream suffix on the file name
# (::$DATA, :$DATA, :name, :name:$DATA) is cut off, case is folded, and an 8.3 short name
# such as TSCONF~1.JSO counts as tsconfig.json. Scope: this hook sees the Write and Edit tools only.
# A shell command that writes the same file (sed -i, echo > file) is out of scope here.

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
head, _, last = p.rpartition('/')
names = ['eslint.config.js', '.eslintrc', 'prettier.config.js', '.prettierrc', 'tsconfig.json', 'biome.json',
         'vitest.config.ts', '.stylelintrc', 'tailwind.config.js', 'next.config.js', 'nuxt.config.ts',
         'jest.config.js', '.npmrc', 'webpack.config.js', 'rollup.config.js']
p = head + '/' + expand_short(last, names)
sys.stdout.buffer.write(p.encode('utf-8'))
PYEOF
FILE_PATH=$(printf '%s' "$INPUT" | "$PYTHON" -c "$PATH_SRC" 2>/dev/null)

# Block if editing config files that should not be weakened
if echo "$FILE_PATH" | grep -qiE '(eslint\.config|\.eslintrc|prettier\.config|\.prettierrc|tsconfig|biome\.json|vitest\.config|\.stylelintrc|tailwind\.config|next\.config|nuxt\.config|jest\.config|\.npmrc|webpack\.config|rollup\.config)'; then
  emit_ask "This is a linter/formatter/build config file. Confirm this edit improves the config rather than weakening rules to suppress errors."
  exit 0
fi

# Pass through for all other files
exit 0
