#!/bin/bash
# Smoke test for all hook scripts.
# Verifies: syntax, Python detection, graceful handling of empty/malformed input.
# Run: bash hooks/test-hooks.sh
#
# Sections 1 to 6 test that hooks don't crash, always exit 0, and handle bad input
# gracefully. Section 7 also tests decisions: what the two PreToolUse guards
# (agent-write-guard, guard-exit-plan) deny and allow, one named case per edge case.
# Section 8 holds regression cases (Windows Store python3 stub, async subagent launch,
# cost-tracker fields, log rotation, MCP sync with no Cursor, the two dash checkers, and
# a subagent's ask turning into a deny). A case labelled "control" passes before and
# after its fix. The dash-checker fixtures contain the pattern they test, on purpose.

PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Hook Smoke Tests ==="
echo "Directory: $HOOKS_DIR"
echo ""

# 1. Syntax check
echo "--- Syntax Check ---"
for f in "$HOOKS_DIR"/*.sh; do
  name=$(basename "$f")
  [ "$name" = "test-hooks.sh" ] && continue
  if bash -n "$f" 2>/dev/null; then
    pass "$name syntax"
  else
    fail "$name syntax"
  fi
done
echo ""

# 2. Python detection (should not crash if Python missing)
echo "--- Python Detection ---"
# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -n "$PYTHON" ]; then
  pass "Python found: $PYTHON"
else
  skip "Python not found: hooks will skip JSON parsing (expected behavior)"
fi
echo ""

# 3. Empty input test (every hook should exit 0 on empty stdin)
echo "--- Empty Input (exit 0 expected) ---"
for f in "$HOOKS_DIR"/*.sh; do
  name=$(basename "$f")
  [ "$name" = "test-hooks.sh" ] && continue
  [ "$name" = "status-line.sh" ] && continue  # status-line reads no stdin
  [ "$name" = "verify-mcp-sync.sh" ] && continue  # reads files, not stdin
  echo "" | bash "$f" > /dev/null 2>&1
  code=$?
  if [ $code -eq 0 ]; then
    pass "$name empty input (exit $code)"
  else
    fail "$name empty input (exit $code, expected 0)"
  fi
done
echo ""

# 4. Malformed JSON input test
echo "--- Malformed JSON Input (exit 0 expected) ---"
for f in "$HOOKS_DIR"/*.sh; do
  name=$(basename "$f")
  [ "$name" = "test-hooks.sh" ] && continue
  [ "$name" = "status-line.sh" ] && continue
  [ "$name" = "verify-mcp-sync.sh" ] && continue
  echo "not valid json {{{" | bash "$f" > /dev/null 2>&1
  code=$?
  if [ $code -eq 0 ]; then
    pass "$name malformed JSON (exit $code)"
  else
    fail "$name malformed JSON (exit $code, expected 0)"
  fi
done
echo ""

# 5. Valid JSON but missing fields
echo "--- Valid JSON, Missing Fields (exit 0 expected) ---"
for f in "$HOOKS_DIR"/*.sh; do
  name=$(basename "$f")
  [ "$name" = "test-hooks.sh" ] && continue
  [ "$name" = "status-line.sh" ] && continue
  [ "$name" = "verify-mcp-sync.sh" ] && continue
  echo '{"tool_input":{}}' | bash "$f" > /dev/null 2>&1
  code=$?
  if [ $code -eq 0 ]; then
    pass "$name missing fields (exit $code)"
  else
    fail "$name missing fields (exit $code, expected 0)"
  fi
done
echo ""

# 6. Output contract for hooks whose output must reach Claude.
# A synchronous hook's systemMessage is shown to the user only; Claude sees
# hookSpecificOutput.additionalContext (PostToolUse, PostToolUseFailure) or plain
# stdout (SessionStart, and PreCompact, where stdout becomes instructions for the
# compaction summary). These cases assert the channel, not just the exit code.
echo "--- Output Contract (what reaches Claude) ---"
if [ -z "$PYTHON" ]; then
  skip "output contract checks need Python"
else
  # json_field <json> <dotted.path>: prints the value at the path, or nothing.
  json_field() {
    printf '%s' "$1" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for k in sys.argv[1].split('.'):
        d = d[k]
    print(d)
except Exception:
    pass
" "$2" 2>/dev/null
  }

  # verify-subagent-findings.sh: synchronous, so its warning must travel as additionalContext.
  out=$(echo '{"tool_name":"Agent","tool_input":{"subagent_type":"code-reviewer"}}' | bash "$HOOKS_DIR/verify-subagent-findings.sh" 2>/dev/null)
  if [ "$(json_field "$out" hookSpecificOutput.hookEventName)" = "PostToolUse" ] \
     && [ -n "$(json_field "$out" hookSpecificOutput.additionalContext)" ]; then
    pass "verify-subagent-findings.sh sends additionalContext to Claude"
  else
    fail "verify-subagent-findings.sh sends additionalContext to Claude (got: ${out:-<no output>})"
  fi
  if [ -n "$(json_field "$out" systemMessage)" ]; then
    pass "verify-subagent-findings.sh keeps systemMessage for the user"
  else
    fail "verify-subagent-findings.sh keeps systemMessage for the user"
  fi
  out=$(echo '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}}' | bash "$HOOKS_DIR/verify-subagent-findings.sh" 2>/dev/null)
  if [ -z "$out" ]; then
    pass "verify-subagent-findings.sh stays silent for Explore"
  else
    fail "verify-subagent-findings.sh stays silent for Explore (got: $out)"
  fi

  # mcp-failure-hint.sh: PostToolUseFailure on an MCP tool returns fallback guidance.
  if [ -f "$HOOKS_DIR/mcp-failure-hint.sh" ]; then
    out=$(echo '{"hook_event_name":"PostToolUseFailure","tool_name":"mcp__playwright__browser_click","error":"server disconnected"}' | bash "$HOOKS_DIR/mcp-failure-hint.sh" 2>/dev/null)
    if [ "$(json_field "$out" hookSpecificOutput.hookEventName)" = "PostToolUseFailure" ] \
       && [ -n "$(json_field "$out" hookSpecificOutput.additionalContext)" ]; then
      pass "mcp-failure-hint.sh sends additionalContext on an MCP failure"
    else
      fail "mcp-failure-hint.sh sends additionalContext on an MCP failure (got: ${out:-<no output>})"
    fi
    out=$(echo '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","error":"exit 1"}' | bash "$HOOKS_DIR/mcp-failure-hint.sh" 2>/dev/null)
    if [ -z "$out" ]; then
      pass "mcp-failure-hint.sh stays silent for a non-MCP tool"
    else
      fail "mcp-failure-hint.sh stays silent for a non-MCP tool (got: $out)"
    fi
  else
    fail "mcp-failure-hint.sh exists"
  fi

  # precompact-state.sh: plain-text stdout (compaction instructions) plus the state file.
  TMP_HOME=$(mktemp -d)
  mkdir -p "$TMP_HOME/.claude"
  out=$(echo '{"hook_event_name":"PreCompact","trigger":"auto"}' | HOME="$TMP_HOME" bash "$HOOKS_DIR/precompact-state.sh" 2>/dev/null)
  case "$out" in
    "") fail "precompact-state.sh prints compaction instructions (got no stdout)" ;;
    "{"*) fail "precompact-state.sh prints plain text, not JSON (got: $out)" ;;
    *) pass "precompact-state.sh prints compaction instructions" ;;
  esac
  if [ -s "$TMP_HOME/.claude/precompact-state.json" ]; then
    pass "precompact-state.sh still writes its state file"
  else
    fail "precompact-state.sh still writes its state file"
  fi
  rm -rf "$TMP_HOME"
fi
echo ""

# 7. Guard decisions: what a PreToolUse guard decides, one named case per edge case.
# A guard file that does not exist reports MISSING, so every case below fails (red)
# until the hook is written, including the cases that expect silence.
echo "--- Guard Decisions (PreToolUse deny or silence) ---"
if [ -z "$PYTHON" ]; then
  skip "guard decision checks need Python"
else
  # guard_decision <hook> <json> [VAR=value ...]: prints the permissionDecision,
  # "silent" when the hook prints nothing, or MISSING when the hook does not exist.
  guard_decision() {
    local hook="$HOOKS_DIR/$1" json="$2"; shift 2
    [ -f "$hook" ] || { echo MISSING; return; }
    local out
    out=$(printf '%s' "$json" | env "$@" bash "$hook" 2>/dev/null)
    if [ -z "$out" ]; then echo silent; return; fi
    json_field "$out" hookSpecificOutput.permissionDecision
  }
  expect() {  # expect <name> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected $2, got ${3:-<empty>})"; fi
  }

  # agent-write-guard.sh. HOME and cwd are fixed strings: the hook only compares paths,
  # it never touches the filesystem, so no real directory is needed.
  AWG=agent-write-guard.sh
  # The memory path is built from HOME exactly as the hook's Python sees it (Git Bash
  # on Windows hands a Windows Python HOME as C:/...). An empty AGENT_WRITE_GUARD_AGENTS
  # means the default list, so a list set in your own environment does not leak in.
  GENV=(AGENT_WRITE_GUARD_AGENTS=)
  PY_HOME=$("$PYTHON" -c "import os; print((os.environ.get('HOME') or os.path.expanduser('~')).replace(chr(92), '/'))")
  MEM=$PY_HOME/.claude/agent-memory/code-reviewer
  expect "agent-write-guard: subagent not in the read-only list may write" silent \
    "$(guard_decision $AWG '{"agent_type":"backend-specialist","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"/work/proj/src/app.ts","content":"x"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent writes its own memory dir" silent \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"'"$MEM"'/MEMORY.md","content":"x"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent writes its project memory dir" silent \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Edit","cwd":"/work/proj","tool_input":{"file_path":".claude/agent-memory/code-reviewer/notes.md","old_string":"a","new_string":"b"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent edits source code" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Edit","cwd":"/work/proj","tool_input":{"file_path":"/work/proj/src/app.ts","old_string":"a","new_string":"b"}}' "${GENV[@]}")"
  expect "agent-write-guard: memory-dir traversal (..) is denied" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"'"$MEM"'/../../settings.json","content":"x"}}' "${GENV[@]}")"
  expect "agent-write-guard: another agent's memory dir is denied" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"'"$PY_HOME"'/.claude/agent-memory/security-reviewer/x.md","content":"x"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent runs git status" silent \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"git status && git diff --stat"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent greps with a quoted > and 2>/dev/null" silent \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"grep -rn \"a > b\" src 2>/dev/null | head -5; ls 2>&1"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent runs cat > file" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"cat > src/app.ts"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent appends with >>" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"echo x >> notes.txt"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent runs sed -i" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"sed -i s/a/b/ src/app.ts"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent pipes into tee" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"echo x | tee out.txt"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent runs git commit" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"git -C /work/proj commit -m x"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent hides a write inside bash -c" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"bash -c \"rm -rf build\""}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent redirects into its own memory dir" silent \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"date > '"$MEM"'/last-run.txt"}}' "${GENV[@]}")"
  expect "agent-write-guard: read-only agent uses a PowerShell write cmdlet" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"PowerShell","cwd":"/work/proj","tool_input":{"command":"Set-Content -Path app.ts -Value x"}}' "${GENV[@]}")"
  expect "agent-write-guard: main thread without agent_type may write" silent \
    "$(guard_decision $AWG '{"tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"cat > src/app.ts"}}' "${GENV[@]}")"
  # Under `claude --agent <name>`, agent_type is set on the main thread too, so the
  # guard applies to the whole session. Intended: the session IS that agent.
  expect "agent-write-guard: --agent session with a read-only name is guarded" deny \
    "$(guard_decision $AWG '{"agent_type":"security-reviewer","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"/work/proj/README.md","content":"x"}}' "${GENV[@]}")"
  expect "agent-write-guard: the list is configurable (AGENT_WRITE_GUARD_AGENTS)" deny \
    "$(guard_decision $AWG '{"agent_type":"my-auditor","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"/work/proj/a.md","content":"x"}}' "${GENV[@]}" "AGENT_WRITE_GUARD_AGENTS=my-auditor other")"
  expect "agent-write-guard: malformed input exits silently" silent \
    "$(guard_decision $AWG 'not json {{{' "${GENV[@]}")"

  # Shell parsing edge cases. cmd_case builds the hook input with json.dumps, so each
  # command below is the literal text the agent would send (none of it is executed).
  cmd_case() {  # cmd_case <name> <expected> <tool> <command>
    local json
    json=$("$PYTHON" -c 'import json,sys; print(json.dumps({"agent_type":"code-reviewer","tool_name":sys.argv[1],"cwd":"/work/proj","tool_input":{"command":sys.argv[2]}}))' "$3" "$4")
    expect "agent-write-guard: $1" "$2" "$(guard_decision $AWG "$json" "${GENV[@]}")"
  }
  cmd_case "a leading comment line does not hide the next line" deny Bash $'# step 1\nrm -rf build'
  cmd_case "a # inside a word is not a comment" deny Bash 'echo a#b >out.txt'
  # The next three commands are literal text on purpose: the $ must reach the hook.
  # shellcheck disable=SC2016
  cmd_case "a separator glued to ) still splits (;)" deny Bash 'echo $(date);rm x'
  # shellcheck disable=SC2016
  cmd_case "a separator glued to ) still splits (&&)" deny Bash 'ls $(pwd)&&rm x'
  cmd_case "a write after if/then is seen" deny Bash 'if true; then rm y; fi'
  # shellcheck disable=SC2016
  cmd_case "a write inside a for loop is seen" deny Bash 'for f in *.tmp; do rm "$f"; done'
  cmd_case "a write inside a { } group is seen" deny Bash '{ rm x; }'
  cmd_case "bash -lc is checked like bash -c" deny Bash 'bash -lc "rm -rf build"'
  cmd_case "pwsh -Command is checked" deny Bash 'pwsh -Command "Remove-Item x"'
  cmd_case "cmd /c is checked" deny Bash 'cmd /c del x.txt'
  cmd_case "an apostrophe in heredoc text does not hide the redirect" deny Bash $'cat <<EOF >out.txt\nit\'s here\nEOF'
  cmd_case "an unbalanced quote still sees the redirect" deny Bash $'cat <<EOF >out.txt\n\'tis here\nEOF'
  cmd_case "an apostrophe in a comment does not hide the next line" deny Bash $'# don\'t stop\nrm -rf build'
  cmd_case "a ; inside a comment is not a command" silent Bash 'ls # list (all) files; rm is slow'
  # A # that bash keeps as text must not be stripped as a comment, or the rm after it hides.
  # shellcheck disable=SC2016
  cmd_case "\$# is not a comment" deny Bash 'echo $#; rm x'
  # shellcheck disable=SC2016
  cmd_case "\${#VAR} is not a comment" deny Bash 'echo ${#PATH}; rm x'
  cmd_case "a # mid-word is not a comment" deny Bash 'echo a#b; rm x'
  cmd_case "a # inside quotes is not a comment" deny Bash 'echo "a #b"; rm x'
  cmd_case "a # after an escaped space is not a comment" deny Bash 'echo a\ #b; rm x'
  # shellcheck disable=SC2016
  cmd_case "a # right after \$(...) is not a comment" deny Bash 'echo $(date)#t; rm x'
  cmd_case "a # after a line continuation is not a comment" deny Bash $'echo foo\\\n#x; rm y'
  cmd_case "xargs --max-chars <n> rm is seen" deny Bash 'ls | xargs --max-chars 100 rm'
  cmd_case "xargs -i rm (attached optional value) is seen" deny Bash 'ls | xargs -i rm {}'
  cmd_case "git config get reads a key" silent Bash 'git config get user.name'
  cmd_case "git config <key> reads a key" silent Bash 'git config user.name'
  cmd_case "git config --file <path> <key> reads a key" silent Bash 'git config --file .gitmodules submodule.x.url'
  cmd_case "git config <key> <value> writes" deny Bash 'git config user.name someone'
  cmd_case "git submodule status is read-only" silent Bash 'git submodule status'
  cmd_case "bare git submodule lists" silent Bash 'git submodule'
  cmd_case "git diff --output-indicator-new is read-only" silent Bash 'git diff --output-indicator-new=+'
  cmd_case "xargs -I {} rm is seen" deny Bash 'ls | xargs -I {} rm {}'
  cmd_case "timeout <duration> rm is seen" deny Bash 'timeout 5 rm x'
  cmd_case "env -u NAME rm is seen" deny Bash 'env -u FOO rm x'
  cmd_case "eval of a write is seen" deny Bash 'eval "rm x"'
  cmd_case "find -delete is denied" deny Bash 'find . -name "*.tmp" -delete'
  cmd_case "find -exec rm is denied" deny Bash 'find . -name "*.tmp" -exec rm {} \;'
  cmd_case "command -v rm only looks the name up" silent Bash 'command -v rm'
  cmd_case "a quoted > after = is not a redirect" silent Bash 'git log --grep="x > y" --oneline'
  cmd_case "git diff-tree is read-only" silent Bash 'git diff-tree --no-commit-id -r HEAD'
  cmd_case "git diff --output writes a file" deny Bash 'git diff --output=patch.txt'
  cmd_case "a redirect to /dev/stderr is allowed" silent Bash 'echo done > /dev/stderr'
  cmd_case "npm audit fix changes packages" deny Bash 'npm audit fix'
  cmd_case "a PowerShell redirect into a file is denied" deny PowerShell 'Get-Process > procs.txt'
  cmd_case "Export-Csv writes a file" deny PowerShell 'Get-Process | Export-Csv procs.csv'
  cmd_case "a test run with 2>&1 stays allowed" silent Bash 'npm test 2>&1 | tail -20'
  expect "agent-write-guard: a Windows drive path outside memory is denied" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Edit","cwd":"C:\\work\\proj","tool_input":{"file_path":"C:\\work\\proj\\src\\a.ts","old_string":"a","new_string":"b"}}' "${GENV[@]}")"
  expect "agent-write-guard: a ~/ path into its own memory dir is allowed" silent \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"Write","cwd":"/work/proj","tool_input":{"file_path":"~/.claude/agent-memory/code-reviewer/notes.md","content":"x"}}' "${GENV[@]}")"
  expect "agent-write-guard: NotebookEdit outside memory is denied" deny \
    "$(guard_decision $AWG '{"agent_type":"code-reviewer","tool_name":"NotebookEdit","cwd":"/work/proj","tool_input":{"notebook_path":"/work/proj/a.ipynb","new_source":"x"}}' "${GENV[@]}")"

  # guard-exit-plan.sh: the plan text arrives in tool_input.plan (injected by Claude Code).
  GEP=guard-exit-plan.sh
  expect "guard-exit-plan: no plan text stays silent" silent \
    "$(guard_decision $GEP '{"tool_name":"ExitPlanMode","tool_input":{}}')"
  expect "guard-exit-plan: plan without the audit marker is denied" deny \
    "$(guard_decision $GEP '{"tool_name":"ExitPlanMode","tool_input":{"plan":"## Plan\n1. Edit the file."}}')"
  expect "guard-exit-plan: plan with AUDIT CLEAN stays silent" silent \
    "$(guard_decision $GEP '{"tool_name":"ExitPlanMode","tool_input":{"plan":"## Plan\n1. Edit.\n\n| Check | Status |\n\nAUDIT CLEAN: safe to ExitPlanMode"}}')"
  expect "guard-exit-plan: a trivial plan that says so stays silent" silent \
    "$(guard_decision $GEP '{"tool_name":"ExitPlanMode","tool_input":{"plan":"Fix one typo.\nself-audit: not required (trivial)"}}')"
  expect "guard-exit-plan: deny carries a reason" yes \
    "$([ -f "$HOOKS_DIR/$GEP" ] && printf '%s' '{"tool_name":"ExitPlanMode","tool_input":{"plan":"x"}}' | bash "$HOOKS_DIR/$GEP" 2>/dev/null | grep -q 'self-audit' && echo yes)"

  # protect-config.sh and protect-claude-settings.sh prompt (permissionDecision "ask").
  # The documented PreToolUse shape is hookSpecificOutput.permissionDecision; a top-level
  # {"decision":"ask"} is not, so these cases read the decision through that path.
  PCF=protect-config.sh
  expect "protect-config: a linter config edit asks" ask \
    "$(guard_decision $PCF '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/eslint.config.js","old_string":"a","new_string":"b"}}')"
  expect "protect-config: a tsconfig edit asks" ask \
    "$(guard_decision $PCF '{"tool_name":"Write","tool_input":{"file_path":"/work/proj/tsconfig.json","content":"{}"}}')"
  expect "protect-config: an ordinary source file stays silent" silent \
    "$(guard_decision $PCF '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/src/app.ts","old_string":"a","new_string":"b"}}')"
  expect "protect-config: malformed input exits silently" silent \
    "$(guard_decision $PCF 'not json {{{')"

  PCS=protect-claude-settings.sh
  SET=/home/u/.claude/settings.json
  expect "protect-claude-settings: editing defaultMode asks" ask \
    "$(guard_decision $PCS '{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'","old_string":"\"defaultMode\": \"default\"","new_string":"\"defaultMode\": \"bypassPermissions\""}}')"
  expect "protect-claude-settings: editing the deny list asks" ask \
    "$(guard_decision $PCS '{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'","old_string":"\"deny\": [\"Bash(rm -rf *)\"]","new_string":"\"deny\": []"}}')"
  expect "protect-claude-settings: adding an Edit() allow rule inside .claude asks" ask \
    "$(guard_decision $PCS '{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'","old_string":"\"allow\": []","new_string":"\"allow\": [\"Edit(~/.claude/**)\"]"}}')"
  expect "protect-claude-settings: adding a Write() allow rule inside .claude asks" ask \
    "$(guard_decision $PCS '{"tool_name":"Write","tool_input":{"file_path":"'"$SET"'","content":"{\"permissions\":{\"allow\":[\"Write(/home/u/.claude/**)\"]}}"}}')"
  expect "protect-claude-settings: a theme-only edit stays silent" silent \
    "$(guard_decision $PCS '{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'","old_string":"\"theme\": \"dark\"","new_string":"\"theme\": \"light\""}}')"
  expect "protect-claude-settings: an edit to another file stays silent" silent \
    "$(guard_decision $PCS '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/settings.json","old_string":"a","new_string":"\"defaultMode\""}}')"
  expect "protect-claude-settings: malformed input exits silently" silent \
    "$(guard_decision $PCS 'not json {{{')"
  expect "protect-config and protect-claude-settings: ask output parses and carries a reason" yes \
    "$(for h in "$PCF" "$PCS"; do
        if [ "$h" = "$PCF" ]; then p='{"tool_name":"Edit","tool_input":{"file_path":"/w/biome.json","old_string":"a","new_string":"b"}}'
        else p='{"tool_name":"Edit","tool_input":{"file_path":"'"$SET"'","old_string":"a","new_string":"\"disableAllHooks\": true"}}'; fi
        printf '%s' "$p" | bash "$HOOKS_DIR/$h" 2>/dev/null | "$PYTHON" -c "
import sys, json
d = json.load(sys.stdin)['hookSpecificOutput']
assert d['hookEventName'] == 'PreToolUse' and d['permissionDecisionReason']
print('ok')" 2>/dev/null
      done | tr -d '\r' | paste -sd, | sed 's/^ok,ok$/yes/')"

  # Missing Python: both guards warn on stderr and exit 0 without a decision.
  BASH_BIN=$(command -v bash)
  for g in $AWG $GEP; do
    if [ ! -f "$HOOKS_DIR/$g" ]; then fail "$g exists"; continue; fi
    out=$(printf '%s' '{"agent_type":"code-reviewer","tool_name":"Write","tool_input":{"file_path":"/x","plan":"x"}}' | PATH=/nonexistent "$BASH_BIN" "$HOOKS_DIR/$g" 2>/dev/null)
    code=$?
    expect "$g without Python exits 0 with no decision" "0:" "$code:$out"
  done
fi
echo ""

# 8. Regressions: each group below was red before its fix and names the script it targets.
# Cases labelled "control" pass before and after the fix: they pin the behaviour that
# must not change. Everything runs in one temp dir, removed at the end of the section.
echo "--- Regression: Windows Store python3 stub, dash checkers, subagent ask, small fixes ---"
if [ -z "$PYTHON" ]; then
  skip "regression checks need Python"
else
  T8=$(mktemp -d)
  # winpath <path>: a path a Windows Python can open (identity on Linux and macOS).
  winpath() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
  # hook_out <hook> <json> [VAR=value ...]: the hook's stdout, CR removed.
  hook_out() {
    local hook="$HOOKS_DIR/$1" json="$2"; shift 2
    printf '%s' "$json" | env "$@" bash "$hook" 2>/dev/null | tr -d '\r'
  }

  # D9. On Windows, python3 can be the Microsoft Store stub: it sits under WindowsApps and
  # exits 49 without running anything. Every hook used to take it, run nothing, and let the
  # call through. The stub is faked here: a python3 under a directory named WindowsApps that
  # exits 49, and a python wrapper that runs the real interpreter, found before PATH changes.
  echo "  (D9: Store stub)"
  mkdir -p "$T8/WindowsApps" "$T8/pybin"
  printf '#!/bin/bash\necho "Python was not found; run without arguments to install from the Microsoft Store." >&2\nexit 49\n' > "$T8/WindowsApps/python3"
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$PYTHON" > "$T8/pybin/python"
  chmod +x "$T8/WindowsApps/python3" "$T8/pybin/python"
  STUB_PATH="$T8/WindowsApps:$T8/pybin:$PATH"
  expect "guard-exit-plan: an unaudited plan is still denied when python3 is the Store stub" deny \
    "$(guard_decision guard-exit-plan.sh '{"tool_name":"ExitPlanMode","tool_input":{"plan":"## Plan\n1. Edit the file."}}' "PATH=$STUB_PATH")"
  expect "agent-write-guard: rm -rf by a read-only agent is still denied when python3 is the Store stub" deny \
    "$(guard_decision agent-write-guard.sh '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"rm -rf x"}}' "${GENV[@]}" "PATH=$STUB_PATH")"
  expect "protect-config: a linter config edit still asks when python3 is the Store stub" ask \
    "$(guard_decision protect-config.sh '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/eslint.config.js","old_string":"a","new_string":"b"}}' "PATH=$STUB_PATH")"
  # control: a python3 under WindowsApps that runs is used as before.
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$PYTHON" > "$T8/WindowsApps/python3"
  expect "guard-exit-plan: control, a working python3 under WindowsApps is still used" deny \
    "$(guard_decision guard-exit-plan.sh '{"tool_name":"ExitPlanMode","tool_input":{"plan":"## Plan\n1. Edit the file."}}' "PATH=$STUB_PATH")"
  # Every script that detects Python carries the same guard, so a new copy cannot skip it.
  for f in "$HOOKS_DIR"/*.sh; do
    name=$(basename "$f")
    [ "$name" = "test-hooks.sh" ] && continue
    grep -q 'PYTHON=' "$f" || continue
    if grep -q 'WindowsApps' "$f"; then
      pass "$name guards against the Store python3 stub"
    else
      fail "$name guards against the Store python3 stub (no WindowsApps check)"
    fi
  done
  # The same snippet is copied into the installer and the two test scripts: keep them in step.
  for f in "$HOOKS_DIR/../setup.sh" "$HOOKS_DIR/../tests/judge-eval.sh" "$HOOKS_DIR/../tests/install-matrix.sh"; do
    name=$(basename "$f")
    if grep -q '[Ww]indows[Aa]pps' "$f" 2>/dev/null; then
      pass "$name carries the Store python3 stub guard"
    else
      fail "$name carries the Store python3 stub guard (no WindowsApps check)"
    fi
  done
  # These grep the docs, they do not run anything: they only keep the snippet text in step.
  for f in "$HOOKS_DIR/README.md" "$HOOKS_DIR/../TROUBLESHOOTING.md" "$HOOKS_DIR/../GETTING-STARTED.md"; do
    name=$(basename "$f")
    if grep -qi 'windowsapps' "$f" 2>/dev/null; then
      pass "docs sync: $name mentions the Store python3 stub"
    else
      fail "docs sync: $name mentions the Store python3 stub (no WindowsApps text)"
    fi
  done

  # Item: the interpreter path is quoted at every call site. A path with a space (for
  # example under "Program Files") would otherwise split into words and the hook would
  # run nothing and fail open.
  echo "  (quoted interpreter path)"
  mkdir -p "$T8/Program Files/py"
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$PYTHON" > "$T8/Program Files/py/python3"
  chmod +x "$T8/Program Files/py/python3"
  SP_PATH="$T8/Program Files/py:$PATH"
  expect "guard-exit-plan: an unaudited plan is denied when python lives under a path with a space" deny \
    "$(guard_decision guard-exit-plan.sh '{"tool_name":"ExitPlanMode","tool_input":{"plan":"## Plan\n1. Edit the file."}}' "PATH=$SP_PATH")"
  expect "agent-write-guard: rm -rf by a read-only agent is denied when python lives under a path with a space" deny \
    "$(guard_decision agent-write-guard.sh '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"rm -rf x"}}' "${GENV[@]}" "PATH=$SP_PATH")"
  expect "protect-config: a linter config edit asks when python lives under a path with a space" ask \
    "$(guard_decision protect-config.sh '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/eslint.config.js","old_string":"a","new_string":"b"}}' "PATH=$SP_PATH")"
  expect "protect-claude-settings: a safety edit asks when python lives under a path with a space" ask \
    "$(guard_decision protect-claude-settings.sh '{"tool_name":"Edit","tool_input":{"file_path":"/home/u/.claude/settings.json","old_string":"a","new_string":"\"disableAllHooks\": true"}}' "PATH=$SP_PATH")"
  out=$(hook_out verify-subagent-findings.sh '{"tool_name":"Agent","tool_input":{"subagent_type":"code-reviewer"}}' "PATH=$SP_PATH")
  expect "verify-subagent-findings: the reminder is sent when python lives under a path with a space" PostToolUse \
    "$(json_field "$out" hookSpecificOutput.hookEventName | tr -d '\r')"
  for f in "$HOOKS_DIR"/*.sh; do
    name=$(basename "$f")
    [ "$name" = "test-hooks.sh" ] && continue
    # shellcheck disable=SC2016 # the pattern is literal text, not an expansion
    if grep -nE '(^|[^"])\$PYTHON( |$)' "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -q .; then
      fail "$name quotes the interpreter at every call site (found an unquoted \$PYTHON)"
    else
      pass "$name quotes the interpreter at every call site"
    fi
  done

  # Item: the Store stub path is matched case-insensitively (Windows paths are).
  echo "  (case-insensitive WindowsApps match)"
  mkdir -p "$T8/ci/windowsapps"
  printf '#!/bin/bash\necho "Python was not found" >&2\nexit 49\n' > "$T8/ci/windowsapps/python3"
  chmod +x "$T8/ci/windowsapps/python3"
  expect "guard-exit-plan: a lower-case windowsapps stub is skipped" deny \
    "$(guard_decision guard-exit-plan.sh '{"tool_name":"ExitPlanMode","tool_input":{"plan":"## Plan\n1. Edit the file."}}' "PATH=$T8/ci/windowsapps:$T8/pybin:$PATH")"

  # D10. verify-subagent-findings.sh: a background spawn returns at launch, before any
  # report exists, so "report received" would be false.
  echo "  (D10: async_launched)"
  VSF=verify-subagent-findings.sh
  out=$(hook_out $VSF '{"tool_name":"Agent","tool_input":{"subagent_type":"code-reviewer"},"tool_response":{"status":"async_launched"}}')
  ctx=$(json_field "$out" hookSpecificOutput.additionalContext)
  case "$ctx" in
    *"no report yet"*) pass "verify-subagent-findings: an async launch says no report yet" ;;
    *) fail "verify-subagent-findings: an async launch says no report yet (got: ${out:-<no output>})" ;;
  esac
  if printf '%s' "$out" | grep -qi 'report received'; then
    fail "verify-subagent-findings: an async launch must not claim a report was received (got: $out)"
  else
    pass "verify-subagent-findings: an async launch does not claim a report was received"
  fi
  out=$(hook_out $VSF '{"tool_name":"Agent","tool_input":{"subagent_type":"code-reviewer"},"tool_response":{"status":"completed"}}')
  case "$(json_field "$out" hookSpecificOutput.additionalContext)" in
    *"REPORT RECEIVED"*) pass "verify-subagent-findings: control, a completed agent still says report received" ;;
    *) fail "verify-subagent-findings: control, a completed agent still says report received (got: ${out:-<no output>})" ;;
  esac

  # D13. cost-tracker.sh: session_id comes from stdin, the model from the transcript.
  echo "  (D13: cost-tracker)"
  CT_HOME="$T8/cthome"; mkdir -p "$CT_HOME"
  TR="$T8/transcript.jsonl"
  printf '%s\n' \
    '{"type":"user","message":{"role":"user","content":"hi"}}' \
    '{"type":"assistant","message":{"model":"claude-old-model","role":"assistant"}}' \
    'not json {{{' \
    '{"type":"assistant","message":{"model":"claude-test-model-2","role":"assistant"}}' \
    '{"type":"system","subtype":"x"}' > "$TR"
  printf '{"hook_event_name":"Stop","session_id":"abc-123","transcript_path":"%s"}' "$(winpath "$TR")" \
    | env HOME="$CT_HOME" bash "$HOOKS_DIR/cost-tracker.sh" >/dev/null 2>&1
  last=$(tail -n 1 "$CT_HOME/.claude/metrics/costs.jsonl" 2>/dev/null)
  expect "cost-tracker: session_id comes from the stdin JSON" abc-123 "$(json_field "$last" session_id | tr -d '\r')"
  expect "cost-tracker: model comes from the last transcript entry that has one" claude-test-model-2 "$(json_field "$last" model | tr -d '\r')"
  printf '{"hook_event_name":"Stop"}' | env HOME="$CT_HOME" bash "$HOOKS_DIR/cost-tracker.sh" >/dev/null 2>&1
  last=$(tail -n 1 "$CT_HOME/.claude/metrics/costs.jsonl" 2>/dev/null)
  expect "cost-tracker: control, no session_id and no transcript logs unknown" unknown:unknown \
    "$(json_field "$last" session_id | tr -d '\r'):$(json_field "$last" model | tr -d '\r')"
  # Truncation: over 10 MB keeps the newest half and leaves no temp file behind.
  CT_BIG="$T8/ctbig"; mkdir -p "$CT_BIG/.claude/metrics"
  MONTH=$(date -u +%Y-%m)
  "$PYTHON" -c "
import sys
with open(sys.argv[1], 'w') as f:
    for i in range(110000):
        f.write('{\"session_id\": \"old\", \"model\": \"m\", \"timestamp\": \"' + sys.argv[2] + '-01T00:00:00Z\", \"event\": \"stop\", \"pad\": \"' + 'x' * 60 + '\"}\n')
" "$CT_BIG/.claude/metrics/costs.jsonl" "$MONTH" 2>/dev/null
  before=$(wc -c < "$CT_BIG/.claude/metrics/costs.jsonl" | tr -d ' ')
  printf '{"hook_event_name":"Stop","session_id":"big-1"}' | env HOME="$CT_BIG" bash "$HOOKS_DIR/cost-tracker.sh" >/dev/null 2>&1
  after=$(wc -c < "$CT_BIG/.claude/metrics/costs.jsonl" | tr -d ' ')
  leftover=0
  for f in "$CT_BIG/.claude/metrics"/* "$CT_BIG/.claude/metrics"/.[!.]*; do
    [ -e "$f" ] && [ "$(basename "$f")" != costs.jsonl ] && leftover=$((leftover + 1))
  done
  if [ "$before" -gt 10485760 ] && [ "$after" -lt "$before" ] && [ "$leftover" = 0 ] \
     && tail -n 1 "$CT_BIG/.claude/metrics/costs.jsonl" | grep -q '"event": "stop"' \
     && ! tail -n 1 "$CT_BIG/.claude/metrics/costs.jsonl" | grep -q '"pad"'; then
    pass "cost-tracker: control, an oversize log is cut, ends with the new entry and leaves no temp file"
  else
    fail "cost-tracker: control, an oversize log is cut, ends with the new entry and leaves no temp file (before=$before after=$after leftover=$leftover)"
  fi

  # A placeholder model such as <synthetic> is skipped and the search goes on backwards.
  printf '%s\n' \
    '{"type":"assistant","message":{"model":"claude-real-model","role":"assistant"}}' \
    '{"type":"assistant","message":{"model":"<synthetic>","role":"assistant"}}' > "$T8/transcript2.jsonl"
  printf '{"hook_event_name":"Stop","session_id":"syn-1","transcript_path":"%s"}' "$(winpath "$T8/transcript2.jsonl")" \
    | env HOME="$CT_HOME" bash "$HOOKS_DIR/cost-tracker.sh" >/dev/null 2>&1
  last=$(tail -n 1 "$CT_HOME/.claude/metrics/costs.jsonl" 2>/dev/null)
  expect "cost-tracker: a <synthetic> model is skipped for the real one before it" claude-real-model "$(json_field "$last" model | tr -d '\r')"
  # The cut keeps the log's file mode. Only meaningful where chmod works (not Windows).
  CT_MODE="$T8/ctmode"; mkdir -p "$CT_MODE/.claude/metrics"
  cat "$CT_BIG/.claude/metrics/costs.jsonl" "$CT_BIG/.claude/metrics/costs.jsonl" > "$CT_MODE/.claude/metrics/costs.jsonl" 2>/dev/null
  chmod 664 "$CT_MODE/.claude/metrics/costs.jsonl" 2>/dev/null
  mode_before=$(stat -c %a "$CT_MODE/.claude/metrics/costs.jsonl" 2>/dev/null)
  printf '{"hook_event_name":"Stop","session_id":"mode-1"}' | env HOME="$CT_MODE" bash "$HOOKS_DIR/cost-tracker.sh" >/dev/null 2>&1
  mode_after=$(stat -c %a "$CT_MODE/.claude/metrics/costs.jsonl" 2>/dev/null)
  if [ -z "$mode_before" ]; then
    skip "cost-tracker: the cut keeps the log file mode (stat -c unavailable)"
  else
    expect "cost-tracker: the cut keeps the log file mode" "$mode_before" "$mode_after"
  fi

  # D11. instructions-loaded.sh: rotate its log at 1 MB, keeping one .1 generation.
  echo "  (D11: instructions-loaded log rotation)"
  IL_HOME="$T8/ilhome"; mkdir -p "$IL_HOME/.claude/logs"
  IL_LOG="$IL_HOME/.claude/logs/instructions-loaded.log"
  IL_IN='{"hook_event_name":"InstructionsLoaded","file_path":"/work/proj/CLAUDE.md","load_reason":"session_start","memory_type":"Project"}'
  yes "old log line padding padding padding padding" 2>/dev/null | head -c 1100000 > "$IL_LOG"
  printf '%s' "$IL_IN" | env HOME="$IL_HOME" bash "$HOOKS_DIR/instructions-loaded.sh" >/dev/null 2>&1
  if [ -f "$IL_LOG.1" ] && [ "$(wc -c < "$IL_LOG.1" | tr -d ' ')" -gt 1000000 ] \
     && [ "$(wc -c < "$IL_LOG" | tr -d ' ')" -lt 2000 ] && grep -q 'session_start' "$IL_LOG"; then
    pass "instructions-loaded: a log over 1 MB is rotated to .1 and a fresh log starts"
  else
    fail "instructions-loaded: a log over 1 MB is rotated to .1 and a fresh log starts"
  fi
  rm -f "$IL_LOG.1"; printf 'one old line\n' > "$IL_LOG"
  printf '%s' "$IL_IN" | env HOME="$IL_HOME" bash "$HOOKS_DIR/instructions-loaded.sh" >/dev/null 2>&1
  if [ ! -f "$IL_LOG.1" ] && [ "$(wc -l < "$IL_LOG" | tr -d ' ')" = 2 ]; then
    pass "instructions-loaded: control, a small log is appended to and not rotated"
  else
    fail "instructions-loaded: control, a small log is appended to and not rotated"
  fi

  # D12. verify-mcp-sync.sh: an absent Cursor config means "not installed", not "drifted".
  echo "  (D12: verify-mcp-sync)"
  MS_HOME="$T8/mshome"; mkdir -p "$MS_HOME"
  printf '{"mcpServers":{"a":{},"b":{}}}' > "$MS_HOME/.claude.json"
  out=$(env HOME="$MS_HOME" USERPROFILE="$MS_HOME" bash "$HOOKS_DIR/verify-mcp-sync.sh" 2>/dev/null | tr -d '\r')
  case "$out" in
    *"Cursor not installed, comparison skipped"*) pass "verify-mcp-sync: a missing Cursor file says it is not installed" ;;
    *) fail "verify-mcp-sync: a missing Cursor file says it is not installed (got: $out)" ;;
  esac
  case "$out" in
    *"OUT OF SYNC"*) fail "verify-mcp-sync: a missing Cursor file is not reported as OUT OF SYNC" ;;
    *) pass "verify-mcp-sync: a missing Cursor file is not reported as OUT OF SYNC" ;;
  esac
  mkdir -p "$MS_HOME/.cursor"; printf '{"mcpServers":{"a":{},"b":{}}}' > "$MS_HOME/.cursor/mcp.json"
  out=$(env HOME="$MS_HOME" USERPROFILE="$MS_HOME" bash "$HOOKS_DIR/verify-mcp-sync.sh" 2>/dev/null | tr -d '\r')
  case "$out" in
    *"Status: IN SYNC"*) pass "verify-mcp-sync: control, two matching files are IN SYNC" ;;
    *) fail "verify-mcp-sync: control, two matching files are IN SYNC (got: $out)" ;;
  esac
  printf '{"mcpServers":{"a":{}}}' > "$MS_HOME/.cursor/mcp.json"
  out=$(env HOME="$MS_HOME" USERPROFILE="$MS_HOME" bash "$HOOKS_DIR/verify-mcp-sync.sh" 2>/dev/null | tr -d '\r')
  case "$out" in
    *"Status: OUT OF SYNC"*) pass "verify-mcp-sync: control, a real difference is still OUT OF SYNC" ;;
    *) fail "verify-mcp-sync: control, a real difference is still OUT OF SYNC (got: $out)" ;;
  esac

  # D8. check-no-dash-file.py: the gate blocks a post, so a code span or a fenced block
  # that quotes a command must not trip it. Banned characters are still checked everywhere.
  echo "  (D8: check-no-dash-file.py)"
  CND="$HOOKS_DIR/check-no-dash-file.py"
  # nd_file_rc <content>: exit code of the checker on a file holding the content.
  nd_file_rc() {
    printf '%s\n' "$1" > "$T8/nd.md"
    "$PYTHON" "$CND" "$(winpath "$T8/nd.md")" >/dev/null 2>&1
    echo $?
  }
  # shellcheck disable=SC2016 # backticks in the fixture are Markdown, not command substitution
  expect "check-no-dash-file: a code span holding a double-dash is clean" 0 "$(nd_file_rc 'Run `git log -- path` now.')"
  expect "check-no-dash-file: a fenced block holding a double-dash is clean" 0 "$(nd_file_rc $'Before:\n```\ngit diff -- f\n```\nAfter.')"
  expect "check-no-dash-file: a ~~~ fenced block holding a double-dash is clean" 0 "$(nd_file_rc $'Before:\n~~~\ngit diff -- f\n~~~\nAfter.')"
  expect "check-no-dash-file: control, a prose double-dash is flagged" 1 "$(nd_file_rc 'Wait -- then run it.')"
  # shellcheck disable=SC2016 # backticks in the fixture are Markdown, not command substitution
  expect "check-no-dash-file: control, a prose double-dash next to a code span is flagged" 1 "$(nd_file_rc 'Use `ls` to list files and wait -- then run it.')"
  expect "check-no-dash-file: control, prose after a closed fence is flagged" 1 "$(nd_file_rc $'```\ngit diff -- f\n```\nWait -- then run it.')"
  expect "check-no-dash-file: control, an em-dash is flagged" 1 "$(nd_file_rc "a $(printf '\342\200\224') b")"
  expect "check-no-dash-file: control, an em-dash inside a code span is still flagged" 1 "$(nd_file_rc "x \`a $(printf '\342\200\224') b\` y")"
  # Fences close only on the same marker with at least the opener's length; one left open
  # at the end of the file is not a fence, so its lines are judged as prose.
  expect "check-no-dash-file: an unclosed fence does not hide a prose double-dash" 1 "$(nd_file_rc $'```\nWait -- then run it.')"
  expect "check-no-dash-file: a 4-backtick fence holding a 3-backtick line still skips its body" 0 "$(nd_file_rc $'````\n```\ngit diff -- f\n````\nAfter.')"
  expect "check-no-dash-file: a ~~~ fence is not closed by a backtick line" 0 "$(nd_file_rc $'~~~\n```\ngit diff -- f\n~~~\nAfter.')"

  # D7. no-dash-check.sh: judge each occurrence in prose files instead of excluding whole lines.
  echo "  (D7: no-dash-check.sh)"
  # nd_hook <file-name> <content>: "flagged" when the hook warns, else "clean".
  nd_hook() {
    printf '%s\n' "$2" > "$T8/$1"
    local out
    out=$(hook_out no-dash-check.sh '{"tool_input":{"file_path":"'"$(winpath "$T8/$1")"'"}}')
    case "$out" in *"double-dash"*) echo flagged ;; "") echo clean ;; *) echo "other:$out" ;; esac
  }
  expect "no-dash-check: a prose double-dash on a line that also has a flag is flagged" flagged \
    "$(nd_hook a.md 'npm test --coverage then wait -- retry')"
  expect "no-dash-check: the same line in a .markdown file is flagged" flagged \
    "$(nd_hook a.markdown 'npm test --coverage then wait -- retry')"
  # shellcheck disable=SC2016 # backticks in the fixture are Markdown, not command substitution
  expect "no-dash-check: control, a prose double-dash on a line that also has a code span is flagged" flagged \
    "$(nd_hook b.md 'Use `ls` to list files and wait -- then run it.')"
  expect "no-dash-check: a fenced block holding a double-dash is clean" clean \
    "$(nd_hook c.md $'Before:\n```\ngit log -- path\n```\nAfter.')"
  # shellcheck disable=SC2016 # backticks in the fixture are Markdown, not command substitution
  expect "no-dash-check: control, a code span holding a double-dash is clean" clean \
    "$(nd_hook d.md 'Use `git log -- path` to see history.')"
  expect "no-dash-check: control, a double-dash followed by another flag is clean" clean \
    "$(nd_hook e.md 'Run npm test -- --coverage for a report.')"
  expect "no-dash-check: a .txt file is judged per occurrence" flagged \
    "$(nd_hook f.txt 'npm test --coverage then wait -- retry')"
  expect "no-dash-check: control, a plain prose double-dash is flagged" flagged \
    "$(nd_hook g.md 'A plain sentence -- with a dash.')"
  expect "no-dash-check: control, a shell file keeps the coarse rule (a git pathspec is clean)" clean \
    "$(nd_hook h.sh 'git diff --cached -- file')"
  expect "no-dash-check: control, a shell file with a prose double-dash is flagged" flagged \
    "$(nd_hook i.sh '# wait -- then retry')"
  # A non-ASCII line must not crash the checker on a pipe that is not UTF-8 (cp1252 here).
  printf 'caf\303\251 \346\227\245\346\234\254 wait -- then\n' > "$T8/u.md"
  out=$(hook_out no-dash-check.sh '{"tool_input":{"file_path":"'"$(winpath "$T8/u.md")"'"}}' PYTHONIOENCODING=cp1252)
  case "$out" in
    *"double-dash"*) pass "no-dash-check: a non-ASCII prose line is still flagged on a cp1252 pipe" ;;
    *) fail "no-dash-check: a non-ASCII prose line is still flagged on a cp1252 pipe (got: ${out:-<no output>})" ;;
  esac
  # Fences close only on the same marker with at least the opener's length; one left open
  # at the end of the file is not a fence, so its lines are judged as prose.
  expect "no-dash-check: an unclosed fence does not hide a prose double-dash" flagged \
    "$(nd_hook j.md $'```\nWait -- then run it.')"
  expect "no-dash-check: a 4-backtick fence holding a 3-backtick line still skips its body" clean \
    "$(nd_hook k.md $'````\n```\ngit log -- path\n````\nAfter.')"
  expect "no-dash-check: a ~~~ fence is not closed by a backtick line" clean \
    "$(nd_hook l.md $'~~~\n```\ngit log -- path\n~~~\nAfter.')"
  expect "no-dash-check: control, a closed fence still skips its body" clean \
    "$(nd_hook m.md $'```\ngit log -- path\n```\nAfter.')"

  # Item 7. protect-config.sh and protect-claude-settings.sh ask the user. A subagent
  # (non-empty top-level agent_id) cannot answer a prompt and would hang, so it gets a deny.
  echo "  (subagent ask becomes deny)"
  PC_IN='{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/eslint.config.js","old_string":"a","new_string":"b"}'
  PS_SAFE='"tool_name":"Edit","tool_input":{"file_path":"/home/u/.claude/settings.json","old_string":"a","new_string":"\"disableAllHooks\": true"}'
  PS_ALLOW='"tool_name":"Edit","tool_input":{"file_path":"/home/u/.claude/settings.json","old_string":"\"allow\": []","new_string":"\"allow\": [\"Edit(~/.claude/**)\"]"}'
  expect "protect-config: a main-thread edit still asks (control)" ask "$(guard_decision protect-config.sh "$PC_IN}")"
  expect "protect-config: a subagent edit is denied" deny "$(guard_decision protect-config.sh "$PC_IN"',"agent_id":"a1b2c3"}')"
  expect "protect-config: an empty agent_id still asks (control)" ask "$(guard_decision protect-config.sh "$PC_IN"',"agent_id":""}')"
  expect "protect-config: an agent_id nested in tool_input does not count (control)" ask \
    "$(guard_decision protect-config.sh '{"tool_name":"Edit","tool_input":{"file_path":"/work/proj/eslint.config.js","old_string":"a","new_string":"b","agent_id":"x"}}')"
  expect "protect-claude-settings: a main-thread safety edit still asks (control)" ask "$(guard_decision protect-claude-settings.sh "{$PS_SAFE}")"
  expect "protect-claude-settings: a subagent safety edit is denied" deny "$(guard_decision protect-claude-settings.sh "{$PS_SAFE"',"agent_id":"a1b2c3"}')"
  expect "protect-claude-settings: a main-thread Edit() allow rule still asks (control)" ask "$(guard_decision protect-claude-settings.sh "{$PS_ALLOW}")"
  expect "protect-claude-settings: a subagent Edit() allow rule is denied" deny "$(guard_decision protect-claude-settings.sh "{$PS_ALLOW"',"agent_id":"a1b2c3"}')"
  for pair in "protect-config.sh|$PC_IN"',"agent_id":"a1b2c3"}' "protect-claude-settings.sh|{$PS_SAFE"',"agent_id":"a1b2c3"}'; do
    h=${pair%%|*}; p=${pair#*|}
    reason=$(json_field "$(hook_out "$h" "$p")" hookSpecificOutput.permissionDecisionReason)
    if printf '%s' "$reason" | grep -qi 'ask the user to make this change'; then
      pass "$h: the subagent deny tells it to ask the user to make the change"
    else
      fail "$h: the subagent deny tells it to ask the user to make the change (got: ${reason:-<no reason>})"
    fi
  done

  rm -rf "$T8"
fi
echo ""

# Summary
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
echo ""

if [ $FAIL -gt 0 ]; then
  echo "Some tests failed. Check the output above."
  exit 1
else
  echo "All tests passed."
  exit 0
fi
