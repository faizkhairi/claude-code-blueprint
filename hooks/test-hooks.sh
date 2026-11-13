#!/bin/bash
# Smoke test for all hook scripts.
# Verifies: syntax, Python detection, graceful handling of empty/malformed input.
# Run: bash hooks/test-hooks.sh
#
# Sections 1 to 6 test that hooks don't crash, always exit 0, and handle bad input
# gracefully. Section 7 also tests decisions: what the two PreToolUse guards
# (agent-write-guard, guard-exit-plan) deny and allow, one named case per edge case.

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
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -n "$PYTHON" ]; then
  pass "Python found: $PYTHON"
else
  skip "Python not found -- hooks will skip JSON parsing (expected behavior)"
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
