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
# a subagent's ask turning into a deny). Section 9 holds the git-guard and path-spelling
# cases: block-git-push, pre-commit-secret-scan (against a fake gitleaks, plus a real-gitleaks
# smoke case that is skipped when gitleaks is absent) and post-commit-review run against
# throwaway git repos, the protect hooks against path spellings, a diff of the shared parser
# and path-normaliser blocks, and a twice-run setup.sh merge into a temp HOME. Section 10
# holds the agent-write-guard read-only gaps (GIT_ variables, fetch and grep options,
# backticks, package runners, download tools, Monitor, PowerShell .NET writes) and its false
# positives (heredoc bodies, $HOME in a path, own-memory-dir rm, cp, touch and mkdir). A
# case labelled "control" passes before and after its fix. The dash-checker fixtures contain
# the pattern they test, on purpose.

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

# 9. PR B: the git guards judge the command that actually runs, and the protect hooks
# judge the file that is actually written. Each case runs a hook against a throwaway git
# repo or a path spelling. A case labelled "control" passes before and after its fix.
echo "--- Regression: git guards judge the command that runs, path spellings ---"
if [ -z "$PYTHON" ]; then
  skip "git guard checks need Python"
elif ! command -v git >/dev/null 2>&1; then
  skip "git guard checks need git"
else
  T9=$(mktemp -d)
  # Git Bash rewrites an argument that looks like a POSIX path before a Windows program sees it
  # (it collapses // and /./), which would change the spelling a case is meant to test. The
  # json.dumps calls below therefore run with MSYS2_ARG_CONV_EXCL set (a no-op elsewhere).
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  gq() { git -c commit.gpgsign=false "$@"; }
  # mkrepo <name>: a repo with one commit; prints its path (a path a Windows Python can open).
  mkrepo() {
    local r="$T9/$1"
    mkdir -p "$r"
    gq -C "$r" init -q 2>/dev/null
    echo base > "$r/base.txt"
    gq -C "$r" add base.txt
    gq -C "$r" commit -qm base 2>/dev/null
    winpath "$r"
  }
  # verdict <hook> <cwd> <command> <tool> [VAR=value ...]: block (exit 2), allow (exit 0) or rc=N.
  # The hook's stdout is in $T9/out and its stderr in $T9/err.
  verdict() {
    local hook=$1 cwd=$2 cmd=$3 tool=$4 json rc
    shift 4
    json=$(MSYS2_ARG_CONV_EXCL='*' "$PYTHON" -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[3],"cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$cwd" "$cmd" "$tool")
    (cd "$cwd" 2>/dev/null || cd "$T9" || exit 1; printf '%s' "$json" | env "$@" bash "$HOOKS_DIR/$hook" >"$T9/out" 2>"$T9/err")
    rc=$?
    case $rc in 0) echo allow ;; 2) echo block ;; *) echo "rc=$rc" ;; esac
  }
  has_err() {  # has_err <name> <pattern>: the last hook's stderr matches
    if grep -qi "$2" "$T9/err"; then pass "$1"; else fail "$1 (stderr: $(head -c 200 "$T9/err"))"; fi
  }

  # ---- B1: block-git-push.sh. origin is the blocked host unless a case says otherwise.
  echo "  (B1: block-git-push judges the push that would run)"
  BGP=block-git-push.sh
  INTERNAL=https://git.internal.example.com/team/app.git
  RP=$(mkrepo rp); gq -C "$RP" remote add origin "$INTERNAL"; gq -C "$RP" remote add internal "$INTERNAL"
  gq -C "$RP" remote add gh https://github.com/someone/app.git
  RQ=$(mkrepo rq); gq -C "$RQ" remote add origin https://github.com/someone/app.git
  RN=$(mkrepo rn)
  RD=$(mkrepo rd); gq -C "$RD" remote add origin "$INTERNAL"; gq -C "$RD" checkout -q --detach
  OTHER=$(mkrepo other)
  push() {  # push <name> <expected> <cwd> <command> [tool]
    expect "block-git-push: $1" "$2" "$(verdict $BGP "$3" "$4" "${5:-Bash}")"
  }
  push "control: a push to the blocked origin is blocked" block "$RP" 'git push origin main'
  push "a push to an allowed remote passes while origin is blocked" allow "$RP" 'git push gh main'
  push "control: a default push in a repo whose origin is allowed passes" allow "$RQ" 'git push'
  push "control: a default push follows origin to the blocked host" block "$RP" 'git push'
  push "control: a detached HEAD with no upstream falls back to origin" block "$RD" 'git push'
  push "git -C <repo> push is judged in that repo, not the hook's directory" block "$RQ" "git -C $RP push"
  push "cd <repo> && git push is judged in that repo" block "$RQ" "cd $RP && git push"
  push "a second space before push is still a push" block "$RP" 'git  push origin'
  push "git -c k=v push is still a push" block "$RP" 'git -c push.default=current push origin'
  push "git.exe push is still a push" block "$RP" 'git.exe push origin'
  push "control: FOO=1 git push is still a push" block "$RP" 'FOO=1 git push origin'
  push "control: env git push is still a push" block "$RP" 'env git push origin'
  push "control: sudo git push is still a push" block "$RP" 'sudo git push origin'
  push "control: bash -c with a push to a blocked remote name is blocked" block "$RP" 'bash -c "git push internal main"'
  push "control: a push after && is judged" block "$RP" 'git status && git push origin'
  push "control: git push -o ci.skip origin targets origin" block "$RP" 'git push -o ci.skip origin'
  push "git push -o ci.skip gh targets gh, not the option value" allow "$RP" 'git push -o ci.skip gh'
  push "control: --repo names the target (blocked host)" block "$RP" 'git push --repo internal'
  push "--repo names the target, not origin (allowed host)" allow "$RP" 'git push --repo gh'
  push "a literal blocked URL is blocked" block "$RQ" "git push $INTERNAL main"
  push "a literal allowed URL passes" allow "$RP" 'git push https://github.com/someone/app.git main'
  push "echo \"git push\" is not a push" allow "$RP" 'echo "git push origin"'
  push "a commit message that quotes ; git push is not a push" allow "$RP" 'git commit -m "fix; git push origin"'
  push "control: git status is not a push" allow "$RP" 'git status'
  push "a PowerShell push is judged the same way" block "$RQ" "Set-Location $RP; git push" PowerShell
  RPW=${RP//\//\\}
  if [ "$RPW" != "$RP" ]; then
    push "a quoted Windows backslash path after -C is resolved" block "$RQ" "git -C \"$RPW\" push"
    push "an unquoted Windows backslash path after -C is resolved (PowerShell)" block "$RQ" "git -C $RPW push" PowerShell
  else
    skip "Windows backslash path cases need a Windows path"
  fi
  push "a repo with no remote configured is blocked" block "$RN" 'git push'
  has_err "block-git-push: the no-remote block says which remote is missing" 'no remote named'
  push "cd to a missing directory is blocked" block "$RQ" 'cd /no-such-dir-ccb-test && git push'
  has_err "block-git-push: the missing-directory block says so" 'does not exist'
  # shellcheck disable=SC2016
  push "a target built from a variable is blocked" block "$RQ" 'git push "$REMOTE" main'
  push "xargs git push cannot be resolved and is blocked" block "$RQ" 'ls | xargs git push'
  # ---- Review round 1: assignments, -c pairs, GIT_DIR, env -S, backslashes, ANSI-C quotes, braces.
  RX=$(mkrepo rx); gq -C "$RX" remote add origin https://github.com/someone/app.git
  gq -C "$RX" remote add internal "$INTERNAL"; gq -C "$RX" remote add gh https://github.com/someone/app.git
  # shellcheck disable=SC2016
  {
    push "PowerShell: \$out = git push origin main 2>&1 is a push" block "$RP" '$out = git push origin main 2>&1' PowerShell
    push "PowerShell: \$out=git push origin main 2>&1 is a push" block "$RP" '$out=git push origin main 2>&1' PowerShell
    push "control: PowerShell \$out = git push gh main 2>&1 passes" allow "$RP" '$out = git push gh main 2>&1' PowerShell
    push "PowerShell: \$out=git push gh main 2>&1 resolves gh, not a guessed target" allow "$RP" '$out=git push gh main 2>&1' PowerShell
    push "PowerShell: \$r += git push origin is a push" block "$RP" '$r += git push origin' PowerShell
  }
  push "git -c remote.origin.pushurl=<blocked> push origin is blocked" block "$RQ" \
    'git -c remote.origin.pushurl=https://internal.example.com/z.git push origin'
  push "git -c url.<blocked>.insteadOf=<allowed> push origin is blocked" block "$RQ" \
    'git -c url.https://internal.example.com/.insteadOf=https://github.com/ push origin'
  push "git -c url.<blocked>.insteadOf=<allowed> push <allowed URL> is blocked" block "$RQ" \
    'git -c url.https://internal.example.com/.insteadOf=https://github.com/ push https://github.com/someone/app.git main'
  push "control: a literal allowed URL with an unrelated -c passes" allow "$RQ" \
    'git -c push.default=current push https://github.com/someone/app.git main'
  push "git -c remote.pushDefault=internal push follows the pair" block "$RX" 'git -c remote.pushDefault=internal push'
  push "control: git push in a repo whose origin is allowed passes" allow "$RX" 'git push'
  push "control: git -c push.default=current push origin passes (allowed origin)" allow "$RQ" 'git -c push.default=current push origin'
  push "GIT_DIR=<blocked repo> git push is judged in that repo" block "$RQ" "GIT_DIR=$RP/.git git push origin"
  push "env GIT_DIR=<blocked repo> git push is judged in that repo" block "$RQ" "env GIT_DIR=$RP/.git git push origin"
  push "GIT_DIR and GIT_WORK_TREE together are applied" block "$RQ" "GIT_DIR=$RP/.git GIT_WORK_TREE=$RP git push origin"
  push "GIT_DIR=<allowed repo> git push is judged in that repo, not the cwd" allow "$RP" "GIT_DIR=$RQ/.git git push origin"
  push "env -S 'git push origin' is a push" block "$RP" "env -S 'git push origin'"
  push "env --split-string='git push origin' is a push" block "$RP" "env --split-string='git push origin'"
  push "env -S'git push origin' (glued value) is a push" block "$RP" "env -S'git push origin'"
  push "env -i -S 'FOO=1 git push origin' is a push" block "$RP" "env -i -S 'FOO=1 git push origin'"
  push "control: env -S 'git push gh' passes" allow "$RP" "env -S 'git push gh'"
  # shellcheck disable=SC2016
  {
    push "git pu\sh origin is a push (unquoted backslash dropped)" block "$RP" 'git pu\sh origin'
    push "g\it push origin is a push" block "$RP" 'g\it push origin'
    push "git push g\h names the remote gh" allow "$RP" 'git push g\h'
    push "control: echo pu\sh is not a push" allow "$RP" 'echo pu\sh origin'
    push "ANSI-C quotes holding an escaped quote do not hide a push" block "$RP" "echo \$'\'' ; git push origin ; echo \$'\''"
    push "an allowed push after an ANSI-C escaped quote is judged, not guessed" allow "$RP" "echo \$'\\'' ; git push gh ; echo \$'\\''"
    push "text inside ANSI-C quotes is not a command" allow "$RP" "git commit -m \$'it\'s; git push origin'"
    push "ANSI-C hex escapes build the word push" block "$RP" "git \$'\x70ush' origin"
    push "{ git push gh; } resolves gh" allow "$RX" '{ git push gh; }'
    push "{ git push internal; } resolves internal" block "$RX" '{ git push internal; }'
    push "{ git push } resolves the default remote, not }" allow "$RX" '{ git push }'
    push "{ git push internal } resolves internal" block "$RX" '{ git push internal }'
    push "PowerShell: if (\$ok) { git push gh } resolves gh" allow "$RX" 'if ($ok) { git push gh }' PowerShell
    push "PowerShell: if (\$ok) { git push internal } resolves internal" block "$RX" 'if ($ok) { git push internal }' PowerShell
    push "PowerShell: if (\$ok) { git push } resolves the default remote, not }" allow "$RX" 'if ($ok) { git push }' PowerShell
    push "PowerShell: { git push gh} (} glued to the last word) resolves gh" allow "$RX" 'if ($ok) { git push gh}' PowerShell
    push "PowerShell: both branches are judged" block "$RX" 'if ($ok) { git push gh } else { git push internal }' PowerShell
    push "PowerShell: a script block after a cmdlet is judged" block "$RX" 'Invoke-Command -ScriptBlock { git push internal }' PowerShell
    push "PowerShell: try { git push internal } is judged" block "$RX" 'try { git push internal } catch { }' PowerShell
  }
  # Fail closed (round 2): an error after a push was detected must block, never allow. The fault
  # seam CCB_GUARD_FAULT raises inside the judging loop; a python that dies is shadowed on PATH.
  mkdir -p "$T9/badpy"
  printf '#!/bin/bash\ncat >/dev/null\nexit 1\n' > "$T9/badpy/python3"
  chmod +x "$T9/badpy/python3"
  expect "block-git-push: an unexpected error while judging a detected push blocks (CCB_GUARD_FAULT seam)" block \
    "$(verdict $BGP "$RQ" 'git push' Bash CCB_GUARD_FAULT=1)"
  has_err "block-git-push: the fail-closed message says the guard could not judge the push" 'could not judge'
  expect "block-git-push: control, a command that does not push is allowed even with the fault seam set" allow \
    "$(verdict $BGP "$RQ" 'ls -la' Bash CCB_GUARD_FAULT=1)"
  expect "block-git-push: a parser that dies on a command that mentions push blocks (exit status checked)" block \
    "$(verdict $BGP "$RQ" 'git push' Bash "PATH=$T9/badpy:$PATH")"
  expect "block-git-push: a parser that dies on a command with no push is allowed" allow \
    "$(verdict $BGP "$RQ" 'ls -la' Bash "PATH=$T9/badpy:$PATH")"

  # git not on PATH: a PATH with only python and cat wrappers. The hook cannot resolve a remote
  # name, so it warns and allows (a literal URL still works without git).
  mkdir -p "$T9/nogit"
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$PYTHON" > "$T9/nogit/python"
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$(command -v cat)" > "$T9/nogit/cat"
  chmod +x "$T9/nogit/python" "$T9/nogit/cat"
  BASH_BIN=$(command -v bash)
  json=$(printf '%s' '{"tool_name":"Bash","cwd":"'"$RP"'","tool_input":{"command":"git push origin main"}}')
  printf '%s' "$json" | env "PATH=$T9/nogit" "$BASH_BIN" "$HOOKS_DIR/$BGP" >"$T9/out" 2>"$T9/err"
  expect "block-git-push: control, git not on PATH allows" 0 "$?"
  has_err "block-git-push: git not on PATH warns" 'git not found'

  # ---- B2: pre-commit-secret-scan.sh with a fake gitleaks that flags the text FAKESECRET.
  echo "  (B2: pre-commit-secret-scan scans what the commit would record)"
  PCS_HOOK=pre-commit-secret-scan.sh
  FAKE_GL=$T9/fake-gitleaks
  cat > "$FAKE_GL" <<'FAKEEOF'
#!/bin/bash
# Fake gitleaks: exit 1 when the staged diff holds FAKESECRET. If FAKE_GL_COUNTER names a file,
# the first call reports clean (as gitleaks 8.30.1 has done intermittently) and later calls scan.
if [ -n "$FAKE_GL_COUNTER" ]; then
  n=$(cat "$FAKE_GL_COUNTER" 2>/dev/null || echo 0)
  echo $((n + 1)) > "$FAKE_GL_COUNTER"
  [ "$n" = 0 ] && exit 0
fi
if git diff --cached | grep -q FAKESECRET; then echo "fake leak found"; exit 1; fi
exit 0
FAKEEOF
  chmod +x "$FAKE_GL"
  SCAN_BEFORE=$("$PYTHON" -c "import glob,os,tempfile; print(len(glob.glob(os.path.join(tempfile.gettempdir(),'ccb-scan-*'))))")
  scan() {  # scan <name> <expected> <cwd> <command> [VAR=value ...]
    local name=$1 want=$2 cwd=$3 cmd=$4
    shift 4
    expect "pre-commit-secret-scan: $name" "$want" "$(verdict $PCS_HOOK "$cwd" "$cmd" Bash "GITLEAKS_BIN=$FAKE_GL" "$@")"
  }
  S1=$(mkrepo s1); echo "x FAKESECRET" > "$S1/s.txt"; gq -C "$S1" add s.txt
  S2=$(mkrepo s2); echo "x FAKESECRET" > "$S2/base.txt"
  S3=$(mkrepo s3); echo "x FAKESECRET" > "$S3/new.txt"
  S4=$(mkrepo s4); echo hello > "$S4/h.txt"; gq -C "$S4" add h.txt
  S5=$(mkrepo s5); echo "x FAKESECRET" > "$S5/s.txt"; gq -C "$S5" add s.txt
  scan "a staged secret blocks a plain commit (through the GITLEAKS_BIN seam)" block "$S1" 'git commit -m x'
  scan "control: a clean staged file passes" allow "$S4" 'git commit -m x'
  scan "control: a plain commit with an unstaged secret records nothing, so it passes" allow "$S2" 'git commit -m x'
  scan "control: a plain commit with an untracked secret records nothing, so it passes" allow "$S3" 'git commit -m x'
  scan "control: a message that mentions cd <other repo> scans the real directory" allow "$S4" "git commit -m 'run cd $S1 first'"
  scan "git -C <repo> commit scans that repo" block "$OTHER" "git -C $S1 commit -m x"
  scan "git -c k=v commit is still a commit" block "$S1" 'git -c user.name=z commit -m x'
  scan "a second space before commit is still a commit" block "$S1" 'git  commit -m x'
  scan "cd <repo> && git commit scans that repo" block "$OTHER" "cd $S1 && git commit -m x"
  scan "--no-verify does not skip this scan" block "$S1" 'git commit --no-verify -m x'
  scan "--amend --no-edit does not skip this scan" block "$S1" 'git commit --amend --no-edit'
  scan "-am scans the tracked working-tree change" block "$S2" 'git commit -am x'
  scan "-a -m scans the tracked working-tree change" block "$S2" 'git commit -a -m x'
  scan "a pathspec commit scans that file's working-tree change" block "$S2" 'git commit -m x base.txt'
  scan "git add -A && git commit scans the file the add would stage" block "$S3" 'git add -A && git commit -m x'
  scan "git add <file>; git commit scans that file" block "$S3" 'git add new.txt; git commit -m x'
  expect "pre-commit-secret-scan: control, the real index is untouched by an overlay scan" "?? new.txt" "$(gq -C "$S3" status --short)"
  scan "control: echo \"git commit\" is not a commit" allow "$S1" 'echo "git commit -m x"'
  expect "pre-commit-secret-scan: a PowerShell commit is scanned too" block \
    "$(verdict $PCS_HOOK "$S1" 'git commit -m x' PowerShell "GITLEAKS_BIN=$FAKE_GL")"
  rm -f "$T9/cnt"
  scan "a clean first gitleaks result is re-run and the second call blocks" block "$S5" 'git commit -m x' "FAKE_GL_COUNTER=$T9/cnt"
  expect "pre-commit-secret-scan: the re-run made 2 gitleaks calls" 2 "$(cat "$T9/cnt" 2>/dev/null)"
  has_err "pre-commit-secret-scan: the block message offers the allowlist step" 'gitleaks.toml'
  expect "pre-commit-secret-scan: control, gitleaks missing allows with a note" allow \
    "$(verdict $PCS_HOOK "$S1" 'git commit -m x' Bash GITLEAKS_BIN=/no/such/gitleaks)"
  # Fail closed (round 2): a commit was detected but its scan could not be prepared. CCB_SCAN_TMPDIR
  # points the throwaway scan directory somewhere that cannot be created; a python that dies is
  # shadowed on PATH. Both must block, and neither may leave a scan directory behind.
  S6=$(mkrepo s6); echo "clean change" > "$S6/base.txt"
  scan "a scan directory that cannot be created blocks a commit that needs one (-a)" block "$S6" 'git commit -am x' "CCB_SCAN_TMPDIR=$T9/no/such/dir"
  has_err "pre-commit-secret-scan: the fail-closed message says the scan could not be prepared" 'could not be prepared'
  scan "control: a plain commit of a clean index needs no scan directory, so the bad one is not used" allow "$S4" 'git commit -m x' "CCB_SCAN_TMPDIR=$T9/no/such/dir"
  scan "control: the same -a commit passes when the scan directory is fine" allow "$S6" 'git commit -am x'
  scan "a bad scan directory also blocks a pathspec commit" block "$S6" 'git commit -m x base.txt' "CCB_SCAN_TMPDIR=$T9/no/such/dir"
  scan "a bad scan directory blocks a commit after git add" block "$S6" 'git add base.txt && git commit -m x' "CCB_SCAN_TMPDIR=$T9/no/such/dir"
  mkdir -p "$T9/badpy"
  printf '#!/bin/bash\ncat >/dev/null\nexit 1\n' > "$T9/badpy/python3"
  chmod +x "$T9/badpy/python3"
  scan "a parser that dies on a command that mentions commit blocks (exit status checked)" block "$S4" 'git commit -m x' "PATH=$T9/badpy:$PATH"
  scan "a parser that dies on a command with no commit is allowed" allow "$S4" 'ls -la' "PATH=$T9/badpy:$PATH"
  # git commit options that take a separate value are options, not pathspecs. base.txt in S2 holds the
  # secret as an unstaged change; each command names it as the pathspec after the option and its value.
  scan "--trailer \"k: v\" -m x <file>: the value is not a pathspec, the file's change is scanned" block "$S2" 'git commit --trailer "k: v" -m x base.txt'
  scan "--trailer=k:v -m x <file> is scanned" block "$S2" 'git commit --trailer=k:v -m x base.txt'
  scan "--author \"A <a@b.c>\" -m x <file> is scanned" block "$S2" 'git commit --author "A <a@b.c>" -m x base.txt'
  scan "--date <d> -m x <file> is scanned" block "$S2" 'git commit --date "2020-01-01" -m x base.txt'
  scan "--cleanup strip -m x <file> is scanned" block "$S2" 'git commit --cleanup strip -m x base.txt'
  scan "-C HEAD <file> is scanned" block "$S2" 'git commit -C HEAD base.txt'
  scan "-c HEAD <file> is scanned" block "$S2" 'git commit -c HEAD base.txt'
  scan "-F msg.txt <file> is scanned" block "$S2" 'git commit -F msg.txt base.txt'
  scan "--fixup HEAD <file> is scanned" block "$S2" 'git commit --fixup HEAD base.txt'
  scan "--squash HEAD <file> is scanned" block "$S2" 'git commit --squash HEAD base.txt'
  scan "--template t.txt -m x <file> is scanned" block "$S2" 'git commit --template t.txt -m x base.txt'
  scan "--pathspec-from-file list.txt -m x <file> is scanned" block "$S2" 'git commit --pathspec-from-file list.txt -m x base.txt'
  scan "git stage <file> && git commit stages like git add" block "$S3" 'git stage new.txt && git commit -m x'
  scan "git stage -A; git commit stages like git add -A" block "$S3" 'git stage -A; git commit -m x'
  SCAN_AFTER=$("$PYTHON" -c "import glob,os,tempfile; print(len(glob.glob(os.path.join(tempfile.gettempdir(),'ccb-scan-*'))))")
  expect "pre-commit-secret-scan: control, no throwaway scan directory is left behind" "$SCAN_BEFORE" "$SCAN_AFTER"
  # Real gitleaks smoke: skipped when it is not installed. The token is random, never stored.
  REAL_GL=$(command -v gitleaks 2>/dev/null)
  if [ -n "$REAL_GL" ]; then
    TOK="ghp_$("$PYTHON" -c "import secrets,string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(36)))")"
    SR=$(mkrepo sr); echo "token=$TOK" > "$SR/s.txt"; gq -C "$SR" add s.txt
    SC=$(mkrepo sc); echo "token=$TOK" > "$SC/new.txt"
    expect "pre-commit-secret-scan: control, real gitleaks blocks a staged token" block \
      "$(verdict $PCS_HOOK "$SR" 'git commit -m x' Bash "GITLEAKS_BIN=$REAL_GL")"
    expect "pre-commit-secret-scan: real gitleaks blocks a token an earlier git add would stage" block \
      "$(verdict $PCS_HOOK "$SC" 'git add -A && git commit -m x' Bash "GITLEAKS_BIN=$REAL_GL")"
  else
    skip "real gitleaks smoke: gitleaks is not installed"
  fi

  # ---- B4: post-commit-review.sh reviews the commit that was just made.
  echo "  (B4: post-commit-review reviews the right repo and the right commit)"
  PCR=post-commit-review.sh
  review() {  # review <cwd> <command> [VAR=value ...]: the systemMessage text, or "silent"
    local cwd=$1 cmd=$2 json
    shift 2
    json=$(MSYS2_ARG_CONV_EXCL='*' "$PYTHON" -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$cwd" "$cmd")
    local out
    out=$(cd "$cwd" 2>/dev/null && printf '%s' "$json" | env "$@" bash "$HOOKS_DIR/$PCR" 2>/dev/null | tr -d '\r')
    if [ -z "$out" ]; then echo silent; else json_field "$out" systemMessage | tr '\n' ' '; fi
  }
  contains() {  # contains <name> <text> <needle>
    case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (got: ${2:-<empty>})" ;; esac
  }
  RA=$(mkrepo ra); mkdir -p "$RA/prisma"; echo m > "$RA/prisma/schema.prisma"
  gq -C "$RA" add -A; gq -C "$RA" commit -qm "feat: schema" 2>/dev/null
  # The hook reports only a commit under 120 s old, and a slow runner can take longer than
  # that between here and a later case, so cases far below make a fresh commit first.
  fresh_commit() { echo "$RANDOM" >> "$1/refresh.txt"; gq -C "$1" add -A; gq -C "$1" commit -qm "chore: refresh" 2>/dev/null; }
  RB=$(mkrepo rb); echo m > "$RB/schemaXprisma.txt"
  gq -C "$RB" add -A; gq -C "$RB" commit -qm "feat: lookalike" 2>/dev/null
  contains "post-commit-review: control, a fresh plain commit is reported" "$(review "$RA" 'git commit -m x')" 'Commit created: '
  contains "post-commit-review: schema.prisma is flagged HIGH-RISK" "$(review "$RA" 'git commit -m x')" 'HIGH-RISK'
  out=$(review "$RB" 'git commit -m x')
  case "$out" in *HIGH-RISK*) fail "post-commit-review: control, a file named schemaXprisma.txt is not schema.prisma (got: $out)" ;; *'Commit created'*) pass "post-commit-review: control, a file named schemaXprisma.txt is not schema.prisma" ;; *) fail "post-commit-review: control, a file named schemaXprisma.txt is reported (got: $out)" ;; esac
  contains "post-commit-review: git -C <repo> commit reviews that repo" "$(review "$OTHER" "git -C $RA commit -m x")" 'feat: schema'
  contains "post-commit-review: cd <repo> && git commit reviews that repo" "$(review "$OTHER" "cd $RA && git commit -m x")" 'feat: schema'
  contains "post-commit-review: git -c k=v commit is a commit" "$(review "$RA" 'git -c user.name=z commit -m x')" 'Commit created: '
  expect "post-commit-review: control, an amend is skipped" silent "$(review "$RA" 'git commit --amend --no-edit')"
  expect "post-commit-review: control, echo \"git commit\" is not a commit" silent "$(review "$RA" 'echo "git commit"')"
  RS=$(mkrepo rs); echo s > "$RS/old.txt"; gq -C "$RS" add -A
  GIT_COMMITTER_DATE="2020-01-01T00:00:00 +0000" gq -C "$RS" commit -qm "old commit" 2>/dev/null
  expect "post-commit-review: a stale HEAD (a command that only mentions commit) is not reported" silent "$(review "$RS" 'git commit -m x')"
  RM=$(mkrepo rm); gq -C "$RM" checkout -q -b feat 2>/dev/null
  echo 1 > "$RM/f1.txt"; echo 2 > "$RM/f2.txt"; gq -C "$RM" add -A; gq -C "$RM" commit -qm "feature" 2>/dev/null
  gq -C "$RM" checkout -q - 2>/dev/null; echo 3 > "$RM/m1.txt"; gq -C "$RM" add -A; gq -C "$RM" commit -qm "mainline" 2>/dev/null
  gq -C "$RM" merge --no-ff --no-commit -q feat >/dev/null 2>&1; gq -C "$RM" commit -qm "merge feat" 2>/dev/null
  contains "post-commit-review: a merge commit lists the files it brought in" "$(review "$RM" 'git commit -m x')" '(2 files changed)'

  # ---- B6: review round 3. Command-supplied -c pairs, PowerShell escapes, dynamic subcommands, aliases,
  # PowerShell line endings, the fail-closed text check, an unknown commit directory, no Python.
  echo "  (B6: round 3 hardening)"
  PARSE_BEFORE=$("$PYTHON" -c "import glob,os,tempfile; print(len(glob.glob(os.path.join(tempfile.gettempdir(),'ccb-parse-*'))))")
  FSM=$T9/fsmon.sh; MARK=$T9/fsmon-marker; T2=$T9/trace2.log
  printf '#!/bin/bash\n: > "%s"\nexit 0\n' "$(winpath "$MARK")" > "$FSM"; chmod +x "$FSM"
  FSMC="core.fsmonitor=$(winpath "$FSM")"
  nomark() {  # nomark <name>: the harmless fsmonitor program was not run (it would have created $MARK)
    if [ -e "$MARK" ]; then fail "$1 (the program ran)"; else pass "$1"; fi
    rm -f "$MARK"
  }
  # argv <hook> <cwd> <command>: run a hook with git's trace2 event log on; $T2 then holds every git argv it ran.
  argv() {
    rm -f "$T2"
    verdict "$1" "$2" "$3" Bash "GIT_TRACE2_EVENT=$(winpath "$T2")" "GITLEAKS_BIN=$FAKE_GL" >/dev/null
  }
  rm -f "$MARK"
  scan "git -c core.fsmonitor=<program> commit -a: the hook's own git calls do not run the program" allow "$S6" "git -c $FSMC commit -a -m x"
  nomark "pre-commit-secret-scan: the fsmonitor program was not run by the hook"
  push "git -c core.fsmonitor=<program> push origin is judged as a push" block "$RP" "git -c $FSMC push origin"
  nomark "block-git-push: the fsmonitor program was not run by the hook"
  fresh_commit "$RA"
  contains "post-commit-review: git -c core.fsmonitor=<program> commit is still a commit" "$(review "$RA" "git -c $FSMC commit -m x")" 'Commit created: '
  nomark "post-commit-review: the fsmonitor program was not run by the hook"
  argv $BGP "$RQ" "git -c $FSMC -c Push.Default=current -c remote.origin.pushurl=https://example.org/z.git -c url.https://example.org/.insteadOf=u: push origin"
  if [ -s "$T2" ] && ! grep -q 'core.fsmonitor' "$T2" && grep -q 'Push.Default=current' "$T2" && grep -q 'remote.origin.pushurl=' "$T2" && grep -q 'insteadOf=u:' "$T2"; then
    pass "block-git-push: only remote., url., branch. and push. pairs (any case) reach its git calls"
  else
    fail "block-git-push: only remote., url., branch. and push. pairs (any case) reach its git calls"
  fi
  argv $PCS_HOOK "$S6" "git -c $FSMC -c user.name=zz commit -am x"
  if [ -s "$T2" ] && ! grep -q 'core.fsmonitor\|user.name=zz' "$T2"; then
    pass "pre-commit-secret-scan: no command-supplied -c pair reaches its git calls"
  else
    fail "pre-commit-secret-scan: no command-supplied -c pair reaches its git calls"
  fi
  rm -f "$T2"
  review "$RA" "git -c $FSMC -c user.name=zz commit -m x" "GIT_TRACE2_EVENT=$(winpath "$T2")" >/dev/null
  if [ -s "$T2" ] && ! grep -q 'core.fsmonitor\|user.name=zz' "$T2"; then
    pass "post-commit-review: no command-supplied -c pair reaches its git calls"
  else
    fail "post-commit-review: no command-supplied -c pair reaches its git calls"
  fi
  # PowerShell: a backtick escapes the next character (it is not command substitution), also inside "...",
  # and a backslash is not an escape inside "...".
  # shellcheck disable=SC2016
  {
    push 'PowerShell: git pu`sh origin is a push' block "$RP" 'git pu`sh origin' PowerShell
    push 'PowerShell: "pu`sh" inside double quotes is a push' block "$RP" 'git "pu`sh" origin' PowerShell
    push 'PowerShell: a backtick before a letter in the remote name (git push `gh) names gh' allow "$RP" 'git push `gh' PowerShell
    push 'PowerShell: a backslash before the closing quote does not swallow it' allow "$RP" 'Write-Host "C:\tmp\"; git push gh' PowerShell
    expect 'pre-commit-secret-scan: PowerShell git comm`it -am x is a commit' block \
      "$(verdict $PCS_HOOK "$S2" 'git comm`it -am x' PowerShell "GITLEAKS_BIN=$FAKE_GL")"
  }
  # Dynamic subcommand: a variable, a substitution or a brace expansion as the subcommand is a guess, kept for any subcommand.
  # shellcheck disable=SC2016
  {
    push 'a variable as the subcommand (S=push; git $S origin main) is blocked' block "$RQ" 'S=push; git $S origin main'
    push 'git pu$()sh origin main is blocked' block "$RQ" 'git pu$()sh origin main'
    push 'git {push,pull} origin main is blocked' block "$RQ" 'git {push,pull} origin main'
    push 'control: git status $(date) is not a push' allow "$RP" 'git status $(date)'
    scan 'a variable as the subcommand (S=commit; git $S -m x) is scanned as a commit' block "$S1" 'S=commit; git $S -m x'
    fresh_commit "$RA"
    contains 'post-commit-review: a variable as the subcommand is reviewed as a commit' "$(review "$RA" 'S=commit; git $S -m x')" 'Commit created: '
  }
  # Aliases defined on the command line.
  push "git -c 'alias.x=!git push origin main' x is blocked" block "$RQ" "git -c 'alias.x=!git push origin main' x"
  push "control: git -c alias.p=push p gh resolves the alias and judges gh" allow "$RP" 'git -c alias.p=push p gh'
  push "an unknown subcommand while an alias is defined is blocked" block "$RQ" 'git -c alias.a=push foo origin main'
  scan "git -c 'alias.c=!git commit -am x' c scans the commit it runs" block "$S2" "git -c 'alias.c=!git commit -am x' c"
  fresh_commit "$RA"
  contains "post-commit-review: git -c 'alias.c=!git commit -am x' c is reviewed as a commit" "$(review "$RA" "git -c 'alias.c=!git commit -am x' c")" 'Commit created: '
  # PowerShell: a trailing backslash is part of a path, not a line continuation.
  NL=$'\n'; CRNL=$'\r\n'
  push "PowerShell: cd <dir>\\ then a newline then git push is two commands" block "$RQ" "cd ${RP}\\${NL}git push internal main" PowerShell
  push "PowerShell: the same with a CRLF line ending" block "$RQ" "cd ${RP}\\${CRNL}git push internal main" PowerShell
  push "control: in Bash a backslash and a newline is a continuation" allow "$RQ" "cd ${RP}\\${NL}git push internal main"
  # Fail closed: the fallback checks the text without quotes, backslashes and backticks.
  expect "block-git-push: a parser fault plus git pu\"\"sh internal still blocks" block \
    "$(verdict $BGP "$RP" 'git pu""sh internal' Bash "PATH=$T9/badpy:$PATH")"
  expect "block-git-push: a parser fault plus git pu\\sh internal still blocks" block \
    "$(verdict $BGP "$RP" 'git pu\sh internal' Bash "PATH=$T9/badpy:$PATH")"
  scan 'a parser fault plus git comm""it -m x still blocks' block "$S4" 'git comm""it -m x' "PATH=$T9/badpy:$PATH"
  scan "control: a parser fault on a command with no commit is allowed" allow "$S4" 'git status' "PATH=$T9/badpy:$PATH"
  # Secret scan: a commit whose directory cannot be resolved is blocked, not scanned in the payload directory.
  # shellcheck disable=SC2016
  scan 'cd "$OTHER" && git commit -m x is blocked (unknown directory)' block "$S4" 'cd "$OTHER" && git commit -m x'
  has_err "pre-commit-secret-scan: the unknown-directory block says so" 'directory'
  # shellcheck disable=SC2016
  scan 'git -C "$OTHER" commit -m x is blocked (unknown directory)' block "$S4" 'git -C "$OTHER" commit -m x'
  scan "cd ~no-such-user-ccb && git commit -m x is blocked (unknown directory)" block "$S4" 'cd ~no-such-user-ccb && git commit -m x'
  scan "cd - && git commit -m x is blocked (unknown directory)" block "$S4" 'cd - && git commit -m x'
  scan "control: cd <known repo> && git commit scans that repo and passes" allow "$S4" "cd $S4 && git commit -m x"
  # No Python: the secret scan warns on stderr and allows, like block-git-push.
  mkdir -p "$T9/nopy"
  printf '#!/bin/bash\nexec "%s" "$@"\n' "$(command -v cat)" > "$T9/nopy/cat"
  chmod +x "$T9/nopy/cat"
  printf '%s' '{"tool_name":"Bash","cwd":"/","tool_input":{"command":"git commit -m x"}}' | env "PATH=$T9/nopy" "$BASH_BIN" "$HOOKS_DIR/$PCS_HOOK" >"$T9/out" 2>"$T9/err"
  expect "pre-commit-secret-scan: control, no Python allows" 0 "$?"
  has_err "pre-commit-secret-scan: no Python warns on stderr" 'python not found'
  # The parser runs from a temp file (python -I FILE); with no usable temp directory it falls back to python -c.
  expect "block-git-push: control, with no usable temp directory the parser falls back to python -c and still blocks" block     "$(verdict $BGP "$RP" 'git push origin' Bash "TMPDIR=$T9/no/such/dir")"
  scan "control: with no usable temp directory the secret scan falls back to python -c and still blocks" block "$S1" 'git commit -m x' "TMPDIR=$T9/no/such/dir"
  PARSE_AFTER=$("$PYTHON" -c "import glob,os,tempfile; print(len(glob.glob(os.path.join(tempfile.gettempdir(),'ccb-parse-*'))))")
  expect "control: no parser temp file is left behind" "$PARSE_BEFORE" "$PARSE_AFTER"

  # ---- B3: the protect hooks normalise the path before matching it.
  echo "  (B3: path spellings)"
  spell() {  # spell <hook> <name> <expected> <path> [old new]
    local json
    json=$(MSYS2_ARG_CONV_EXCL='*' "$PYTHON" -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":"a","new_string":sys.argv[2]}}))' "$4" "${6:-b}")
    expect "$1: $2" "$3" "$(guard_decision "$1" "$json")"
  }
  SAFE='"disableAllHooks": true'
  PCS_=protect-claude-settings.sh
  PCF_=protect-config.sh
  json_sub() { MSYS2_ARG_CONV_EXCL='*' "$PYTHON" -c 'import json,sys; print(json.dumps({"tool_name":"Edit","agent_id":"a1","tool_input":{"file_path":sys.argv[1],"old_string":"a","new_string":sys.argv[2]}}))' "$1" "$2"; }
  spell $PCS_ "control: the plain settings.json path asks" ask '/home/u/.claude/settings.json' a "$SAFE"
  spell $PCS_ "a doubled slash still asks" ask '/home/u/.claude//settings.json' a "$SAFE"
  spell $PCS_ "a /./ segment still asks" ask '/home/u/.claude/./settings.json' a "$SAFE"
  spell $PCS_ "an x/.. segment still asks" ask '/home/u/.claude/x/../settings.json' a "$SAFE"
  spell $PCS_ "a trailing dot still asks" ask '/home/u/.claude/settings.json.' a "$SAFE"
  spell $PCS_ "a trailing space still asks" ask '/home/u/.claude/settings.json ' a "$SAFE"
  spell $PCS_ "control: a Windows backslash path asks" ask 'C:\Users\u\.claude\settings.json' a "$SAFE"
  spell $PCS_ "a mixed slash path with doubled backslashes asks" ask 'C:\Users\u/.claude\\settings.local.json' a "$SAFE"
  spell $PCS_ "control: a different case asks" ask '/home/u/.CLAUDE/Settings.JSON' a "$SAFE"
  spell $PCS_ "the 8.3 short name SETTIN~1.JSO asks" ask 'C:\Users\u\.claude\SETTIN~1.JSO' a "$SAFE"
  spell $PCS_ "an 8.3 parent CLAUDE~1 asks" ask 'C:\Users\u\CLAUDE~1\settings.json' a "$SAFE"
  spell $PCS_ "control: a path that resolves away from settings.json stays silent" silent '/home/u/.claude/settings.json/../notes.txt' a "$SAFE"
  spell $PCS_ "control: settings.json.bak stays silent" silent '/home/u/.claude/settings.json.bak' a "$SAFE"
  expect "protect-claude-settings: a subagent with a spelled-differently path is denied" deny \
    "$(guard_decision $PCS_ "$(json_sub '/home/u/.claude//settings.json' "$SAFE")")"
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCS_ "an NTFS ::\$DATA stream on settings.json asks" ask 'C:\Users\u\.claude\settings.json::$DATA' a "$SAFE"
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCS_ "an NTFS :\$DATA stream on settings.json asks" ask 'C:\Users\u\.claude\settings.json:$DATA' a "$SAFE"
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCS_ "a named stream :name:\$DATA on settings.local.json asks" ask '/home/u/.claude/settings.local.json:x:$DATA' a "$SAFE"
  spell $PCS_ "a named stream :name on settings.json asks" ask '/home/u/.claude/settings.json:x' a "$SAFE"
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCS_ "a stream on the 8.3 short name asks" ask 'C:\Users\u\.claude\SETTIN~1.JSO::$DATA' a "$SAFE"
  spell $PCS_ "control: the drive-letter colon is kept (C: path still asks)" ask 'C:/Users/u/.claude/settings.json' a "$SAFE"
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCS_ "control: a stream on a different file stays silent" silent 'C:\Users\u\.claude\notes.txt::$DATA' a "$SAFE"
  spell $PCS_ "control: a colon in a parent directory is not cut" silent '/home/u/.claude:x/settings.json' a "$SAFE"
  spell $PCF_ "control: the plain tsconfig.json path asks" ask '/w/proj/tsconfig.json'
  spell $PCF_ "control: a doubled slash still asks (the config match is a substring match)" ask '/w/proj//tsconfig.json'
  spell $PCF_ "control: a /./ segment still asks (the config match is a substring match)" ask '/w/proj/./eslint.config.js'
  spell $PCF_ "control: an x/.. segment still asks (the config match is a substring match)" ask '/w/proj/src/../tsconfig.json'
  spell $PCF_ "control: a trailing dot still asks (the config match is a substring match)" ask '/w/proj/tsconfig.json.'
  spell $PCF_ "control: a Windows backslash path asks" ask 'C:\w\proj\biome.json'
  spell $PCF_ "control: a different case asks" ask '/w/proj/TSCONFIG.JSON'
  spell $PCF_ "the 8.3 short name TSCONF~1.JSO asks" ask 'C:\w\proj\TSCONF~1.JSO'
  spell $PCF_ "a path that resolves away from the config stays silent" silent '/w/proj/tsconfig.json/../app.ts'
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCF_ "an NTFS ::\$DATA stream on tsconfig.json asks (the substring match already covered it: control)" ask 'C:\w\proj\tsconfig.json::$DATA'
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCF_ "a stream on the 8.3 short name TSCONF~1.JSO::\$DATA asks" ask 'C:\w\proj\TSCONF~1.JSO::$DATA'
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCF_ "a named stream on the 8.3 short name asks" ask 'C:\w\proj\TSCONF~1.JSO:s:$DATA'
  # shellcheck disable=SC2016 # a literal $DATA stream name, not an expansion
  spell $PCF_ "control: a stream on an unrelated file stays silent" silent 'C:\w\proj\app.ts::$DATA'
  expect "protect-config: control, a subagent with a spelled-differently path is denied" deny \
    "$(guard_decision $PCF_ "$(json_sub '/w/proj//tsconfig.json' b)")"

  # ---- Drift: the shared parser and the shared path normaliser are one text in each hook.
  echo "  (drift: shared blocks are identical)"
  grab() {  # grab <hook> <marker>: the lines from BEGIN <marker> to END <marker>, CR removed
    sed -n "/^# BEGIN SHARED $2/,/^# END SHARED $2/p" "$HOOKS_DIR/$1" | tr -d '\r'
  }
  for h in block-git-push.sh pre-commit-secret-scan.sh post-commit-review.sh; do
    grab $h CMDPARSE > "$T9/parse-$h.py"
    n=$(grep -c '^# BEGIN SHARED CMDPARSE' "$HOOKS_DIR/$h")
    expect "$h: holds exactly one shared parser block" 1 "$n"
    # A source passed to python -c stays under 24000 bytes (a Windows command line tops out near 32 KB). A hook whose
    # source is longer runs it from a temp file (python -I FILE) and keeps -c only as the fallback when mktemp fails.
    sz=$(sed -n "/<<'PYEOF' || true/,/^PYEOF\$/p" "$HOOKS_DIR/$h" | wc -c | tr -d ' ')
    if grep -q 'PYARGS=(-I ' "$HOOKS_DIR/$h" && grep -q 'PYARGS=(-c ' "$HOOKS_DIR/$h"; then
      if [ "$sz" -gt 100 ] && [ "$sz" -le 31000 ]; then
        pass "$h: the python source is $sz bytes and runs from a temp file, with -c as the fallback (limit 31000)"
      else
        fail "$h: the python source is $sz bytes (limit 31000, it also has to fit -c as the fallback)"
      fi
    elif [ "$sz" -gt 100 ] && [ "$sz" -le 24000 ]; then
      pass "$h: the python -c source is $sz bytes (limit 24000)"
    else
      fail "$h: the python -c source is $sz bytes (limit 24000)"
    fi
  done
  for h in pre-commit-secret-scan.sh post-commit-review.sh; do
    if cmp -s "$T9/parse-block-git-push.sh.py" "$T9/parse-$h.py" && [ -s "$T9/parse-$h.py" ]; then
      pass "$h: the shared parser is identical to block-git-push.sh's"
    else
      fail "$h: the shared parser differs from block-git-push.sh's"
    fi
  done
  grab protect-config.sh NORMPATH > "$T9/norm-a.py"; grab protect-claude-settings.sh NORMPATH > "$T9/norm-b.py"
  if cmp -s "$T9/norm-a.py" "$T9/norm-b.py" && [ -s "$T9/norm-a.py" ]; then
    pass "protect-config.sh and protect-claude-settings.sh share one path normaliser"
  else
    fail "protect-config.sh and protect-claude-settings.sh share one path normaliser"
  fi
  # One case table through every copy of the parser: sub|dir|args per git call, ! marks a guess.
  IFS= read -r -d '' PT_SRC <<'PYEOF' || true
import sys
exec(open(sys.argv[1]).read())
B = '/B'
def r(cmd, sub, ps=False):
    out = []
    for c in (git_calls(cmd, B, sub, True) if ps else git_calls(cmd, B, sub)):
        out.append('%s|%s|%s%s' % (c['sub'], c['dir'], ' '.join(c['args']), '!' if c['fuzzy'] else ''))
    return ';'.join(out)
cases = [
 ('git push origin main', 'push', 'push|/B|origin main'),
 ('git  push origin', 'push', 'push|/B|origin'),
 ('git -C /r push origin', 'push', 'push|/r|origin'),
 ('git -C "C:\\Repo\\x" push origin', 'push', 'push|C:/Repo/x|origin'),
 ('cd /r && git push', 'push', 'push|/r|'),
 ('cd /r; cd sub && git push', 'push', 'push|/r/sub|'),
 ('(cd /r && git push); git push o', 'push', 'push|/r|;push|/B|o'),
 ('echo "git push"', 'push', ''),
 ('git commit -m "a; git push"', 'push', ''),
 ('git commit -m "a; git push"', 'commit', 'commit|/B|-m a; git push'),
 ('FOO=1 git push o', 'push', 'push|/B|o'),
 ('env -i FOO=1 git push o', 'push', 'push|/B|o'),
 ('sudo -u x git push o', 'push', 'push|/B|o'),
 ('command git push o', 'push', 'push|/B|o'),
 ('nohup git push o &', 'push', 'push|/B|o'),
 ('time git push o', 'push', 'push|/B|o'),
 ('bash -c "git push o"', 'push', 'push|/B|o'),
 ("sh -lc 'cd /r && git push'", 'push', 'push|/r|'),
 ('eval "git push o"', 'push', 'push|/B|o'),
 ('echo $(git push o)', 'push', 'push|/B|o'),
 ('echo `git push o`', 'push', 'push|/B|o'),
 ('git.exe push o', 'push', 'push|/B|o'),
 ('/usr/bin/git push o', 'push', 'push|/B|o'),
 ('"/c/Program Files/Git/bin/git.exe" push o', 'push', 'push|/B|o'),
 ('xargs git push', 'push', 'push|/B|!'),
 ('ls | xargs -n1 git -C /r push', 'push', 'push|/r|!'),
 ('cat <<EOF\ngit push o\nEOF', 'push', ''),
 ('bash <<EOF\ngit push o\nEOF', 'push', 'push|/B|o'),
 ('git commit -m "$(cat <<\'EOF\'\nit\'s done; git push x\nEOF\n)"', 'push', ''),
 ('git -c core.x=1 push -o ci.skip origin', 'push', 'push|/B|-o ci.skip origin'),
 ('git push 2>&1 | tail -3', 'push', 'push|/B|'),
 ('git push > out.txt origin', 'push', 'push|/B|origin'),
 ('$GIT push origin', 'push', 'push|/B|origin!'),
 ('git push "unterminated', 'push', 'push|/B|unterminated;push|/B|!'),
 ('git --no-pager -C a -C b push', 'push', 'push|/B/a/b|'),
 ('cd "$(mktemp -d)" && git push', 'push', 'push|None|'),
 ('git -c alias.p=push p origin', 'push', 'push|/B|origin'),
 ('for r in a b; do git push $r; done', 'push', 'push|/B|$r'),
 ('{ git push o; }', 'push', 'push|/B|o'),
 ('$out = git push o 2>&1', 'push', 'push|/B|o'),
 ('$out=git push o', 'push', 'push|/B|o'),
 ("env -S 'git push o'", 'push', 'push|/B|o'),
 ('git pu\\sh o', 'push', 'push|/B|o'),
 ('g\\it push o', 'push', 'push|/B|o'),
 ("echo $'\\'' ; git push o ; echo $'\\''", 'push', 'push|/B|o'),
 ('{ git push o }', 'push', 'push|/B|o'),
 ('if ($ok) { git push o }', 'push', 'push|/B|o'),
 ('git push o}', 'push', 'push|/B|o'),
 ('if true; then git push o; fi', 'push', 'push|/B|o'),
 ('echo a # git push', 'push', ''),
 ('echo a#b; git push', 'push', 'push|/B|'),
 ('git add -A && git commit -m x', 'commit', 'commit|/B|-m x'),
 ('Set-Location C:\\Repo\\x; git push origin', 'push', 'push|C:/Repo/x|origin', True),
 ('Set-Location C:\\Repo\\x; git push origin', 'push', 'push|/B/C:Repox|origin'),
 ('if ($ok) { git push gh } else { git push internal }', 'push', 'push|/B|gh;push|/B|internal', True),
 ('Invoke-Command -ScriptBlock { git push internal }', 'push', 'push|/B|internal', True),
 ('pwsh -Command "git push origin"', 'push', 'push|/B|origin'),
 ('cmd /c "git push origin"', 'push', 'push|/B|origin'),
 ('& "C:\\Program Files\\Git\\bin\\git.exe" push origin', 'push', 'push|/B|origin'),
 ('env -C /z git push', 'push', 'push|/z|'),
 ('git --git-dir=/g --work-tree /w push', 'push', 'push|/B|'),
 ('S=push; git $S origin main', 'push', '$S|/B|origin main!'),
 ('git pu$()sh origin main', 'push', 'pu$()sh|/B|origin main!'),
 ('git {push,pull} origin main', 'push', '{push,pull}|/B|origin main!'),
 ("git -c 'alias.x=!git push origin main' x", 'push', 'x|/B|!;push|/B|origin main'),
 ('git -c alias.a=b foo origin', 'push', 'foo|/B|origin!'),
 ('git -c alias.p=push p origin', 'status', ''),
 ('git pu`sh o', 'push', 'push|/B|o', True),
 ('git "pu`sh" o', 'push', 'push|/B|o', True),
 ('git comm`it -am x', 'commit', 'commit|/B|-am x', True),
 ('Write-Host "C:\\tmp\\"; git push o', 'push', 'push|/B|o', True),
 ('cd C:\\x\\\ngit push o', 'push', 'push|C:/x/|o', True),
 ('cd C:\\x\\\r\ngit push o', 'push', 'push|C:/x/|o', True),
 ('cd /x\\\ngit push o', 'push', ''),
 ('cd ~bob && git push o', 'push', 'push|None|o'),
]
bad = 0
for case in cases:
    cmd, sub, exp = case[:3]
    got = r(cmd, sub, len(case) > 3)
    if got != exp:
        bad += 1
        print('BAD', repr(cmd), 'expected', repr(exp), 'got', repr(got))
print('bad=%d' % bad)
PYEOF
  for h in block-git-push.sh pre-commit-secret-scan.sh post-commit-review.sh; do
    res=$("$PYTHON" -I -c "$PT_SRC" "$(winpath "$T9/parse-$h.py")" 2>&1)
    last=$(printf '%s\n' "$res" | tail -1)
    if [ "$last" = "bad=0" ]; then
      pass "$h: its parser copy handles the whole case table"
    else
      fail "$h: its parser copy handles the whole case table ($(printf '%s' "$res" | head -c 400))"
    fi
  done

  # ---- B5: setup.sh wires block-git-push and pre-commit-secret-scan under a PowerShell
  # matcher too, and a second run adds nothing.
  echo "  (B5: setup.sh merge, run twice)"
  SETUP_SH="$HOOKS_DIR/../setup.sh"
  if [ ! -f "$SETUP_SH" ]; then
    skip "setup.sh not found next to hooks/"
  else
    H5="$T9/home5"; mkdir -p "$H5"
    for run in 1 2; do
      HOME="$H5" bash "$SETUP_SH" --preset=full --yes </dev/null >"$T9/setup$run.out" 2>&1
      expect "setup.sh --preset=full --yes run $run exits 0" 0 "$?"
    done
    res=$("$PYTHON" -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    pre = d["hooks"]["PreToolUse"]
except Exception as e:
    print("unreadable: %s" % e); sys.exit(0)
want = ["block-git-push.sh", "pre-commit-secret-scan.sh"]
bad = []
for m in ("Bash", "PowerShell"):
    blocks = [b for b in pre if b.get("matcher") == m]
    if len(blocks) != 1:
        bad.append("%d %s blocks" % (len(blocks), m)); continue
    cmds = [h.get("command", "") for h in blocks[0].get("hooks", [])]
    for w in want:
        n = sum(1 for c in cmds if w in c)
        if n != 1:
            bad.append("%s holds %s %d times" % (m, w, n))
print("ok" if not bad else "; ".join(bad))
' "$(winpath "$H5/.claude/settings.json")" 2>&1)
    expect "setup.sh: Bash and PowerShell PreToolUse blocks each hold both git guards once, after two runs" ok "$res"
  fi

  rm -rf "$T9"
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
fi
echo ""

# 10. PR C: agent-write-guard read-only gaps and false positives. Each case replays one
# command (none of it is executed) as the read-only code-reviewer and checks the decision:
# deny, or silent for an allowed call. A case labelled "control" passes before and after
# the fix and pins behaviour that must not change. Written as one named case per channel.
echo "--- Regression: agent-write-guard read-only gaps and false positives ---"
# The $ in the single-quoted commands below must reach the hook unexpanded.
# shellcheck disable=SC2016 # literal $HOME and $(...) text is the input under test
if [ -z "$PYTHON" ]; then
  skip "agent-write-guard gap checks need Python"
else
  c10() {  # c10 <name> <expected> <tool> <command>
    local json
    json=$("$PYTHON" -c 'import json,sys; print(json.dumps({"agent_type":"code-reviewer","tool_name":sys.argv[1],"cwd":"/work/proj","tool_input":{"command":sys.argv[2]}}))' "$3" "$4")
    expect "agent-write-guard: $1" "$2" "$(guard_decision "$AWG" "$json" "${GENV[@]}")"
  }
  c10u() {  # like c10, but the payload is raw UTF-8 JSON (no \u escapes); @UXXXX@ in the command is that code point
    local json
    json=$("$PYTHON" -c 'import json,re,sys
cmd = re.sub(r"@U([0-9A-Fa-f]{4})@", lambda m: chr(int(m.group(1), 16)), sys.argv[2])
sys.stdout.buffer.write(json.dumps({"agent_type":"code-reviewer","tool_name":sys.argv[1],"cwd":"/work/proj","tool_input":{"command":cmd}}, ensure_ascii=False).encode("utf-8"))' "$3" "$4")
    expect "agent-write-guard: $1" "$2" "$(guard_decision "$AWG" "$json" "${GENV[@]}")"
  }
  c10h() {  # like c10, but HOME is a path with a space (a Windows profile such as C:/Users/dev user)
    local json
    json=$("$PYTHON" -c 'import json,sys; print(json.dumps({"agent_type":"code-reviewer","tool_name":sys.argv[1],"cwd":"/work/proj","tool_input":{"command":sys.argv[2]}}))' "$3" "$4")
    expect "agent-write-guard: $1" "$2" "$(guard_decision "$AWG" "$json" "${GENV[@]}" "HOME=C:/Users/dev user")"
  }
  # c10n: like c10, with HOME pinned to a path without spaces, for cases that use an unquoted $HOME.
  case "$PY_HOME" in [A-Za-z]:*) NOSP_HOME=C:/Users/dev ;; *) NOSP_HOME=/home/dev ;; esac
  c10n() {
    local json
    json=$("$PYTHON" -c 'import json,sys; print(json.dumps({"agent_type":"code-reviewer","tool_name":sys.argv[1],"cwd":"/work/proj","tool_input":{"command":sys.argv[2]}}))' "$3" "$4")
    expect "agent-write-guard: $1" "$2" "$(guard_decision "$AWG" "$json" "${GENV[@]}" "HOME=$NOSP_HOME")"
  }

  # a. A GIT_ variable makes read-only git run a program.
  c10 "GIT_EXTERNAL_DIFF prefix before git diff is denied" deny Bash 'GIT_EXTERNAL_DIFF=touch git diff'
  c10 "quoted GIT_PAGER prefix before git log is denied" deny Bash 'GIT_PAGER="touch pwn" git log'
  c10 "env GIT_PAGER before git log is denied" deny Bash 'env GIT_PAGER=touch git log'
  c10 "env -S with a GIT_ variable is denied" deny Bash 'env -S "GIT_PAGER=touch git log"'
  c10 "env -S with a write is denied" deny Bash 'env -S "rm x"'
  c10 "export GIT_PAGER is denied" deny Bash 'export GIT_PAGER=touch; git log'
  c10 "PowerShell \$env:GIT_PAGER assignment is denied" deny PowerShell '$env:GIT_PAGER = "touch pwn"; git log'
  c10 "a non-GIT variable prefix before git log (control)" silent Bash 'FOO=1 git log'
  c10 "the text GIT_PAGER as an argument (control)" silent Bash 'echo GIT_PAGER=x'

  # b. git fetch and ls-remote can run a program through --upload-pack.
  c10 "git fetch --upload-pack=<cmd> is denied" deny Bash 'git fetch --upload-pack="touch pwn" origin'
  c10 "git fetch --upload-pack <cmd> (separate value) is denied" deny Bash 'git fetch --upload-pack touch origin'
  c10 "git fetch --recurse-submodules is denied" deny Bash 'git fetch --recurse-submodules origin'
  c10 "git fetch --recurse-submodules=on-demand is denied" deny Bash 'git fetch --recurse-submodules=on-demand'
  c10 "git ls-remote --upload-pack is denied" deny Bash 'git ls-remote --upload-pack=touch origin'
  c10 "plain git fetch (control)" silent Bash 'git fetch origin'
  c10 "git fetch --prune (control)" silent Bash 'git fetch --prune origin'

  # c. git grep -O runs a pager program.
  c10 "git grep -O<cmd> is denied" deny Bash 'git grep -O"touch pwn" foo'
  c10 "git grep -O <cmd> is denied" deny Bash 'git grep -O touch foo'
  c10 "git grep -nO<cmd> in a cluster is denied" deny Bash 'git grep -nOtouch foo'
  c10 "git grep --open-files-in-pager=<cmd> is denied" deny Bash 'git grep --open-files-in-pager=touch foo'
  c10 "plain git grep -n (control)" silent Bash 'git grep -n foo -- src'

  # d. Leading git global options that run programs.
  c10 "git --exec-path=<dir> status is denied" deny Bash 'git --exec-path=/x status'
  c10 "git --exec-path status is denied" deny Bash 'git --exec-path status'
  c10 "git --config-env status is denied (control)" deny Bash 'git --config-env=core.pager=X status'
  c10 "git --no-pager status (control)" silent Bash 'git --no-pager status'
  c10 "git -C <dir> status (control)" silent Bash 'git -C /work/proj status'

  # e. Backticks are command substitution, like $(...), also inside double quotes.
  c10 "a backtick substitution is judged" deny Bash 'echo `touch pwned.txt`'
  c10 "a backtick substitution inside double quotes is judged" deny Bash 'echo "`touch pwned.txt`"'
  c10 "a quoted \$(...) substitution is judged" deny Bash 'echo "$(touch pwned.txt)"'
  c10 "a backtick inside single quotes is text (control)" silent Bash 'echo '\''`touch pwned.txt`'\'''
  c10 "a read-only backtick substitution (control)" silent Bash 'echo `date`'
  c10 "a PowerShell backtick is an escape, not a substitution (control)" silent PowerShell 'Write-Output "a`nb"'

  # f. Package runners fetch and run registry code.
  c10 "npx is a package runner" deny Bash 'npx cowsay hi'
  c10 "bunx is a package runner" deny Bash 'bunx cowsay hi'
  c10 "pnpm dlx is a package runner" deny Bash 'pnpm dlx cowsay'
  c10 "yarn dlx is a package runner" deny Bash 'yarn dlx cowsay'
  c10 "npm exec is a package runner" deny Bash 'npm exec cowsay'
  c10 "npm run build is not a runner (control)" silent Bash 'npm run build'

  # g. Package-manager subcommand parsing.
  c10 "npm --prefix . install skips the option value" deny Bash 'npm --prefix . install lodash'
  c10 "pnpm --filter web add skips the option value" deny Bash 'pnpm --filter web add lodash'
  c10 "npm version changes package.json" deny Bash 'npm version patch'
  c10 "npm pkg set changes package.json" deny Bash 'npm pkg set a=b'
  c10 "npm publish is denied" deny Bash 'npm publish'
  c10 "npm init is denied" deny Bash 'npm init -y'
  c10 "python -m pip install is denied" deny Bash 'python -m pip install requests'
  c10 "python3 -m pip install is denied" deny Bash 'python3 -m pip install requests'
  c10 "uv pip install is denied (control)" deny Bash 'uv pip install requests'
  c10 "npm install (control)" deny Bash 'npm install'
  c10 "bare yarn (control)" deny Bash 'yarn'
  c10 "npm view <pkg> version is a read (control)" silent Bash 'npm view lodash version'
  c10 "npm ls (control)" silent Bash 'npm ls --depth=0'
  c10 "npm run test with args (control)" silent Bash 'npm run test -- --watch=false'
  c10 "pip list (control)" silent Bash 'pip list'
  c10 "python -m pytest (control)" silent Bash 'python -m pytest -q'
  c10 "cargo test (control)" silent Bash 'cargo test'

  # h. Download and output options that write a file. A target in the agent own memory
  # dir stays allowed.
  c10 "curl -o <file> is a write" deny Bash 'curl -o x.txt https://example.com'
  c10 "curl -sSLo <file> in a cluster is a write" deny Bash 'curl -sSLo x.txt https://example.com'
  c10 "curl -O is a write" deny Bash 'curl -O https://example.com/a.tgz'
  c10 "curl --output <file> is a write" deny Bash 'curl --output x.txt https://example.com'
  c10 "curl -D <file> is a write" deny Bash 'curl -D h.txt https://example.com'
  c10 "wget <url> is a write" deny Bash 'wget https://example.com/a.tgz'
  c10 "wget -O <file> is a write" deny Bash 'wget -O out.txt https://example.com'
  c10 "sort -o <file> is a write" deny Bash 'sort -o out.txt in.txt'
  c10 "sort --output=<file> is a write" deny Bash 'sort in.txt --output=out.txt'
  c10 "sort --compress-program runs a program" deny Bash 'sort --compress-program=touch in.txt'
  c10 "curl -o outside the memory dir is denied" deny Bash "curl -o $MEM/../x.txt https://example.com"
  c10 "curl -s with no output option (control)" silent Bash 'curl -s https://example.com'
  c10 "curl -sI (control)" silent Bash 'curl -sI https://example.com'
  c10 "curl -o /dev/null (control)" silent Bash 'curl -s -o /dev/null https://example.com'
  c10 "curl -o into the memory dir (control)" silent Bash "curl -s -o $MEM/page.html https://example.com"
  c10 "wget -qO- to stdout (control)" silent Bash 'wget -qO- https://example.com'
  c10 "wget -O into the memory dir (control)" silent Bash "wget -O $MEM/page.html https://example.com"
  c10 "sort -o into the memory dir (control)" silent Bash "sort -o $MEM/sorted.txt in.txt"
  c10 "sort without -o (control)" silent Bash 'sort -k2 -t, in.txt'

  # i. The Monitor tool carries a shell command in tool_input.command.
  c10 "Monitor with rm is denied" deny Monitor 'rm -rf x'
  c10 "Monitor with a redirect into a file is denied" deny Monitor 'echo a > x.txt'
  c10 "Monitor with a read-only command (control)" silent Monitor 'tail -n 5 log.txt'

  # j. PowerShell .NET file calls.
  c10 "[IO.File]::WriteAllText is a write" deny PowerShell "[IO.File]::WriteAllText('x.txt','a')"
  c10 "[System.IO.File]::AppendAllText is a write" deny PowerShell "[System.IO.File]::AppendAllText('x.txt','a')"
  c10 "[System.IO.File]::WriteAllBytes is a write" deny PowerShell "[System.IO.File]::WriteAllBytes('x.bin',\$b)"
  c10 "[IO.File]::WriteAllText inside pwsh -Command is a write" deny Bash 'pwsh -Command "[IO.File]::WriteAllText(\"x.txt\",\"a\")"'
  c10 "[IO.File]::ReadAllText is a read (control)" silent PowerShell "[IO.File]::ReadAllText('x.txt')"

  # FP1. A heredoc body is data. Redirects and shells on the command line still count.
  c10 "a heredoc body with rm is data" silent Bash $'cat <<EOF\nrm -rf foo\nEOF'
  c10 "a quoted-delimiter heredoc body with \$(...) is data" silent Bash $'cat <<\'EOF\'\n$(touch x)\nEOF'
  c10 "a <<- heredoc with tab-indented body and end is data" silent Bash $'cat <<-EOF\n\trm x\n\tEOF'
  c10 "a heredoc body with # and an apostrophe is data" silent Bash $'cat <<EOF\n# it\'s rm time\nrm x\nEOF'
  c10 "a heredoc into the memory dir is allowed" silent Bash "cat > $MEM/n.md <<EOF"$'\nrm x\nEOF'
  c10 "a heredoc redirected to a file outside memory is a write (control)" deny Bash $'cat <<EOF > out.txt\nhello\nEOF'
  c10 "a command after the heredoc is still judged (control)" deny Bash $'cat <<EOF\ntext\nEOF\nrm x'
  c10 "an unquoted heredoc runs \$(...) in its body (control)" deny Bash $'cat <<EOF\n$(touch x)\nEOF'
  c10 "a heredoc fed to bash runs its body (control)" deny Bash $'bash <<EOF\nrm -rf x\nEOF'
  c10 "a heredoc piped to sh runs its body (control)" deny Bash $'cat <<EOF | sh\nrm x\nEOF'
  c10 "a heredoc fed to pwsh runs its body as PowerShell" deny Bash $'pwsh -Command - <<EOF\nRemove-Item x\nEOF'
  c10 "\$((1<<3)) arithmetic does not hide the next line (control)" deny Bash $'echo $((1<<3))\nrm x'
  c10 "a here-string is not a heredoc (control)" deny Bash $'cat <<<abc\nrm x'

  # FP2. $HOME, ${HOME} and ~ expand in a redirect target.
  c10n "a redirect to \$HOME/.claude/agent-memory/<agent> is allowed" silent Bash 'cat x > $HOME/.claude/agent-memory/code-reviewer/n.md'
  c10 "a redirect to \${HOME}/... memory is allowed" silent Bash 'cat x > ${HOME}/.claude/agent-memory/code-reviewer/n.md'
  c10 "a redirect to \"\$HOME/...\" memory is allowed" silent Bash 'cat x > "$HOME/.claude/agent-memory/code-reviewer/n.md"'
  c10 "a redirect to ~/... memory is allowed (control)" silent Bash 'cat x > ~/.claude/agent-memory/code-reviewer/n.md'
  c10 "a redirect to \$HOME/.claude/settings.json is denied (control)" deny Bash 'cat x > $HOME/.claude/settings.json'
  c10 "a redirect to \$HOME memory of another agent is denied (control)" deny Bash 'cat x > $HOME/.claude/agent-memory/security-reviewer/n.md'
  c10 "a redirect to \$HOME memory with .. is denied (control)" deny Bash 'cat x > $HOME/.claude/agent-memory/code-reviewer/../../settings.json'
  c10 "a single-quoted \$HOME is literal and denied (control)" deny Bash 'cat x > '\''$HOME/.claude/agent-memory/code-reviewer/n.md'\'''
  c10 "an unknown variable in a target is denied (control)" deny Bash 'cat x > $OTHER/.claude/agent-memory/code-reviewer/n.md'
  c10 "a brace list that escapes the memory dir is denied" deny Bash 'cat x > ~/.claude/agent-memory/code-reviewer/{../../x,y}'

  # FP3. mkdir, cp, touch and rm are judged by target: the agent own memory dir is allowed.
  c10 "mkdir -p inside the memory dir is allowed" silent Bash "mkdir -p $MEM/notes"
  c10 "touch inside the memory dir is allowed" silent Bash "touch $MEM/n.md"
  c10 "cp into the memory dir is allowed" silent Bash "cp /work/proj/a.md $MEM/a.md"
  c10 "cp -t into the memory dir is allowed" silent Bash "cp -t $MEM /work/proj/a.md"
  c10 "rm inside the memory dir is allowed" silent Bash "rm $MEM/old.md"
  c10 "rm -rf inside the memory dir is allowed" silent Bash "rm -rf $MEM/old"
  c10 "rm of a glob inside the memory dir is denied (a glob is not resolved)" deny Bash "rm $MEM/*.md"
  c10n "rm through \$HOME inside the memory dir is allowed" silent Bash 'rm $HOME/.claude/agent-memory/code-reviewer/old.md'
  c10 "mkdir then touch, both in the memory dir, is allowed" silent Bash "mkdir -p $MEM/a && touch $MEM/a/b.md"
  c10 "rm -rf build outside memory is denied (control)" deny Bash 'rm -rf build'
  c10 "mkdir outside memory is denied (control)" deny Bash 'mkdir newdir'
  c10 "touch with one target outside memory is denied (control)" deny Bash "touch $MEM/a.md /work/proj/b.md"
  c10 "cp out of the memory dir is denied (control)" deny Bash "cp $MEM/a.md /work/proj/a.md"
  c10 "cp -t outside the memory dir is denied (control)" deny Bash "cp -t /work/proj $MEM/a.md"
  c10 "rm with .. out of the memory dir is denied (control)" deny Bash "rm $MEM/../x"
  c10 "rm in another agent memory dir is denied (control)" deny Bash 'rm $HOME/.claude/agent-memory/security-reviewer/old.md'
  c10 "rm with an unknown option is denied (control)" deny Bash "rm --no-such-flag $MEM/old.md"
  c10 "rm of a variable path is denied (control)" deny Bash 'rm $X/old.md'
  c10 "rm of a path built by command substitution is denied (control)" deny Bash "rm \$(echo /work/proj/a.md)"
  c10 "xargs rm with operands from stdin is denied (control)" deny Bash 'ls | xargs rm'
  c10 "rm with no operand is denied (control)" deny Bash 'rm -rf'
  c10 "mv inside the memory dir stays denied (control)" deny Bash "mv $MEM/a $MEM/b"
  c10 "tee into the memory dir stays denied (control)" deny Bash "echo x | tee $MEM/n.md"

  # Round 2. Cases from a cold review. Red on the previous hook unless marked "control".
  # A1. The memory-dir allowance never applies under a wrapper that adds operands.
  c10 "find | xargs rm with a memory path is denied" deny Bash "find / -name '*.pyc' | xargs rm -f $MEM/x"
  c10 "xargs cp with a memory path is denied" deny Bash "echo /etc/hosts | xargs cp $MEM/a"
  c10 "find -exec rm is denied" deny Bash "find /work -name x -exec rm {} +"
  c10 "find -execdir rm with a memory path is denied" deny Bash "find /work -execdir rm $MEM/x ';'"
  c10 "find -ok rm is denied" deny Bash "find /work -ok rm {} ';'"
  c10 "parallel rm is denied" deny Bash "parallel rm ::: $MEM/a"
  c10 "xargs -I{} rm is denied" deny Bash "ls | xargs -I{} rm $MEM/{}"
  c10 "sudo rm inside the memory dir is judged by target (control)" silent Bash "sudo rm $MEM/old.md"

  # A2. A memory-dir operand must be a plain path.
  c10 "rm with ..'' components is denied" deny Bash "rm $MEM/..''/..''/settings.json"
  c10 "cp with .\\./ components is denied" deny Bash "cp $MEM/p $MEM/.\\./.\\./settings.json"
  c10 "rm with a quote inside the operand is denied" deny Bash "rm $MEM/a'b'/../../x"
  c10 "rm with a backslash in the operand is denied" deny Bash "rm $MEM/a\\ b"
  c10 "rm with a variable in the operand is denied" deny Bash "rm $MEM/\$X"
  c10 "rm with a ? glob is denied" deny Bash "rm $MEM/?.md"
  c10 "rm with a [ glob is denied" deny Bash "rm $MEM/[a].md"
  c10 "rm with a brace list is denied" deny Bash "rm $MEM/{a,b}"
  c10 "rm with a .. in the middle is denied" deny Bash "rm $MEM/sub/../old.md"
  c10 "PowerShell rm with a comma list is denied" deny PowerShell "rm $MEM/a,C:\\Users\\x\\f.txt"
  c10 "redirect with a .. component is denied" deny Bash "echo x > $MEM/sub/../../x.md"
  c10 "rm of a quoted memory path (a space in it) is not judged, so it is denied" deny Bash "rm \"$MEM/old note.md\""

  # A3. cp links and other options.
  c10 "cp -s is denied" deny Bash "cp -s ~/.claude/settings.json $MEM/s"
  c10 "cp -l is denied" deny Bash "cp -l /work/proj/a $MEM/a"
  c10 "cp --symbolic-link is denied" deny Bash "cp --symbolic-link /work/proj/a $MEM/a"
  c10 "cp --link is denied" deny Bash "cp --link /work/proj/a $MEM/a"
  c10 "cp -a is denied" deny Bash "cp -a /work/proj/a $MEM/a"
  c10 "ln -s into the memory dir is denied (control)" deny Bash "ln -s /etc/hosts $MEM/h"
  c10 "cp -rp into the memory dir (control)" silent Bash "cp -rp /work/proj/a $MEM/a"
  c10 "cp -n into the memory dir (control)" silent Bash "cp -n /work/proj/a $MEM/a"

  # A5, A6. A heredoc body is text only for a plain reader with nothing piping it on.
  c10 "a quoted sh receiver runs the body" deny Bash $'\'sh\' <<EOF\nrm x\nEOF'
  c10 "an escaped bash receiver runs the body" deny Bash $'\\bash <<EOF\nrm x\nEOF'
  c10 "a \$SHELL receiver runs the body" deny Bash $'$SHELL <<EOF\nrm x\nEOF'
  c10 "a pipe on the next line after the heredoc line runs the body" deny Bash $'cat <<EOF |\nrm x\nEOF\nsh'
  c10 "an interpreter receiver is judged as commands" deny Bash $'python <<EOF\nrm x\nEOF'
  c10 "\$[1<<3] is not a heredoc" deny Bash $'echo $[1<<3]\nrm x'
  c10 "a[1<<3]= is not a heredoc" deny Bash $'a[1<<3]=1\nrm x'
  c10 "cat<<EOF (no space) is the same plain heredoc as cat <<EOF (round 5)" silent Bash $'cat<<EOF\nrm x\nEOF'
  c10 "an unclosed delimiter judges the body as commands" deny Bash $'cat <<EOF\nrm x'
  c10 "a different closing line leaves the heredoc unclosed" deny Bash $'cat <<EOF\nrm x\nEOF2'
  c10 "a quoted cat receiver is not a reader (round 4)" deny Bash $'\'cat\' <<EOF\nrm x\nEOF'
  c10 "grep with a heredoc body (control)" silent Bash $'grep -c x <<EOF\nrm -rf y\nEOF'
  c10 "sort with a heredoc body (control)" silent Bash $'sort <<EOF\nb\na\nEOF'
  c10 ": <<'EOF' comment block (control)" silent Bash $': <<\'EOF\'\nrm x\nEOF'
  c10 "cat <<EOF into /dev/null (control)" silent Bash $'cat <<EOF > /dev/null\nrm x\nEOF'
  c10 "cat <<EOF appended to a memory file (control)" silent Bash "cat <<EOF >> $MEM/n.md"$'\nrm x\nEOF'
  c10 "bash <(cat <<EOF) runs the body" deny Bash $'bash <(cat <<EOF\nrm x\nEOF\n)'
  c10 "sh -c \"\$(cat <<EOF)\" runs the body" deny Bash $'sh -c "$(cat <<EOF\nrm x\nEOF\n)"'
  c10 "eval \"\$(cat <<'EOF')\" runs the body" deny Bash $'eval "$(cat <<\'EOF\'\nrm x\nEOF\n)"'

  # A7, D. The checker fails closed.
  DEEP=$("$PYTHON" -c 'print("echo " + "$(" * 1200 + "rm x" + ")" * 1200)')
  c10 "1200 nested \$( levels are denied, not allowed by a crash" deny Bash "$DEEP"
  expect "agent-write-guard: no temp dir still denies a write (control: the -c fallback works here)" deny \
    "$(guard_decision "$AWG" '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"rm -rf build"}}' "${GENV[@]}" TMPDIR=/nonexistent/awg-none)"
  expect "agent-write-guard: no temp file and no working Python is a deny for a guarded agent" deny \
    "$(guard_decision "$AWG" '{"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"git log"}}' "${GENV[@]}" TMPDIR=/nonexistent/awg-none AGENT_WRITE_GUARD_TEST_NO_CHECKER=1)"
  expect "agent-write-guard: no working Python leaves an unguarded agent alone (control)" silent \
    "$(guard_decision "$AWG" '{"agent_type":"general-purpose","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"rm -rf build"}}' "${GENV[@]}" AGENT_WRITE_GUARD_TEST_NO_CHECKER=1)"

  # B. False positives.
  c10 "git grep -eOpen is a pattern, not -O" silent Bash 'git grep -eOpen foo'
  c10 "git grep -e Open (control)" silent Bash 'git grep -e Open foo'
  c10 "git grep -nA3 -e <pat> (control)" silent Bash 'git grep -nA3 -e foo'
  c10 "git grep -e <pat> -O<cmd> is still denied (control)" deny Bash 'git grep -e foo -Otouch'
  c10 "npm pkg get is a read" silent Bash 'npm pkg get name'
  c10 "npm pkg get with two keys is a read" silent Bash 'npm pkg get name version'
  c10 "bare npm version is a read" silent Bash 'npm version'
  c10 "npm version --json is a read" silent Bash 'npm version --json'
  c10 "npm version patch is a write (control)" deny Bash 'npm version patch'
  c10 "npm version 1.2.3 is a write (control)" deny Bash 'npm version 1.2.3'
  c10 "npm pkg set is a write (control)" deny Bash 'npm pkg set name=x'
  c10 "npm pkg delete is a write (control)" deny Bash 'npm pkg delete scripts'
  c10 "npm pkg fix is a write (control)" deny Bash 'npm pkg fix'
  c10 "GIT_TERMINAL_PROMPT=0 git fetch stays denied (control)" deny Bash 'GIT_TERMINAL_PROMPT=0 git fetch'
  reason=$("$PYTHON" -c 'import json,sys; print(json.dumps({"agent_type":"code-reviewer","tool_name":"Bash","cwd":"/work/proj","tool_input":{"command":"GIT_TERMINAL_PROMPT=0 git fetch"}}))' | env "${GENV[@]}" bash "$HOOKS_DIR/$AWG" 2>/dev/null)
  case "$reason" in
    *"harmless ones"*"Set it in the environment"*) pass "agent-write-guard: the GIT_ deny message says why and what to do instead" ;;
    *) fail "agent-write-guard: the GIT_ deny message says why and what to do instead (got: ${reason:-<empty>})" ;;
  esac

  # C. Gaps that were already there.
  c10 "env -S with an attached quoted command is denied" deny Bash "env -S'rm x'"
  c10 "env -iS with a command is denied" deny Bash 'env -iS "rm x"'
  c10 "env --split-string=<cmd> is denied" deny Bash "env --split-string='rm x'"
  c10 "python -mpip install is denied" deny Bash 'python -mpip install x'
  c10 "python -Im pip install is denied" deny Bash 'python -Im pip install x'
  c10 "uv pip install is denied" deny Bash 'uv pip install x'
  c10 "python -m uv pip install is denied" deny Bash 'python -m uv pip install x'
  for a in in i inst isntall add ci un uninstall rm r update up link ln; do
    c10 "npm $a is a package change" deny Bash "npm $a x"
  done
  c10 "yarn global add is denied" deny Bash 'yarn global add x'
  c10 "yarn global remove is denied" deny Bash 'yarn global remove x'
  for a in "i" "add -g x" "up" "rm x" "un x" "remove x" "install" "update" "link"; do
    c10 "pnpm $a is a package change" deny Bash "pnpm $a"
  done
  for a in "add x" "i" "install" "remove x" "update" "link" "a x"; do
    c10 "bun $a is a package change" deny Bash "bun $a"
  done
  c10 "an unknown option value does not hide npm install" deny Bash 'npm --maxsockets 5 install x'
  c10 "an unknown option value does not hide npm i" deny Bash 'npm --foo bar i x'
  c10 "yarn --cwd <dir> add is denied" deny Bash 'yarn --cwd /work/proj add x'
  c10 "npm view <pkg> install is a read (control)" silent Bash 'npm view lodash install'
  c10 "yarn global list (control)" silent Bash 'yarn global list'
  c10 "yarn test (control)" silent Bash 'yarn test'
  c10 "bun test (control)" silent Bash 'bun test'
  c10 "git grep --op=<cmd> is denied" deny Bash 'git grep --op=touch foo'
  c10 "git grep --ope <cmd> is denied" deny Bash 'git grep --ope touch foo'
  c10 "git grep --only-matching (control)" silent Bash 'git grep --only-matching foo'
  c10 "git grep -e a --or -e b (control)" silent Bash 'git grep -e a --or -e b'
  c10 "git fetch --u=<cmd> is denied" deny Bash 'git fetch --u=touch origin'
  c10 "git fetch --up=<cmd> is denied" deny Bash 'git fetch --up=touch origin'
  c10 "git fetch --upl=<cmd> is denied" deny Bash 'git fetch --upl=touch origin'
  c10 "git ls-remote --up=<cmd> is denied" deny Bash 'git ls-remote --up=touch origin'
  c10 "git fetch --unshallow (control)" silent Bash 'git fetch --unshallow'
  c10 "curl -w with %output{} is denied" deny Bash "curl -w '%output{x.txt}hi' https://example.com"
  c10 "curl --write-out with %output{} is denied" deny Bash "curl --write-out '%output{x.txt}' https://example.com"
  c10 "curl --write-out=%output{} is denied" deny Bash "curl --write-out=%output{x.txt} https://example.com"
  c10 "curl -w %{http_code} (control)" silent Bash "curl -s -o /dev/null -w '%{http_code}' https://example.com"
  c10 "[IO.File]::Open is a write" deny PowerShell "[IO.File]::Open('x','Create')"
  c10 "[IO.File]::OpenWrite is a write" deny PowerShell "[IO.File]::OpenWrite('x')"
  c10 "[IO.File]::OpenOrCreate is a write" deny PowerShell "[IO.File]::OpenOrCreate('x')"
  c10 "New-Object IO.FileStream is a write" deny PowerShell "New-Object IO.FileStream('x','Create')"
  c10 "New-Object System.IO.FileStream is a write" deny PowerShell "New-Object System.IO.FileStream('x','Create')"
  c10 "[IO.FileInfo] .Create() is a write" deny PowerShell "[IO.FileInfo]::new('x').Create()"
  c10 "[IO.FileInfo] .CreateText() is a write" deny PowerShell "([IO.FileInfo]'x').CreateText()"
  c10 "New-Object IO.FileInfo .AppendText() is a write" deny PowerShell "(New-Object IO.FileInfo 'x').AppendText()"
  c10 "[IO.File]::OpenText is a read (control)" silent PowerShell "[IO.File]::OpenText('x')"
  c10 "[IO.File]::OpenRead is a read (control)" silent PowerShell "[IO.File]::OpenRead('x')"
  c10 "[IO.FileInfo] .Length is a read (control)" silent PowerShell "([IO.FileInfo]'x').Length"
  c10 "an unquoted heredoc \$(...) after an apostrophe is judged" deny Bash $'cat <<EOF\nit\'s $(touch pwn)\nEOF'
  c10 "an unquoted heredoc backtick after an apostrophe is judged" deny Bash $'cat <<EOF\nit\'s `touch pwn`\nEOF'
  c10 "an unquoted heredoc \${x:-\$(...)} is judged" deny Bash $'cat <<EOF\n${x:-$(touch y)}\nEOF'
  c10 "an escaped \\\$(...) in an unquoted heredoc is text (control)" silent Bash $'cat <<EOF\n\\$(touch x)\nEOF'
  c10 "a quoted-delimiter heredoc keeps an apostrophe and \$(...) as data (control)" silent Bash $'cat <<\'EOF\'\nit\'s $(touch pwn)\nEOF'
  c10 "a quoted \"\$HOME\"/... memory redirect is allowed" silent Bash 'cat x > "$HOME"/.claude/agent-memory/code-reviewer/n.md'
  c10 "a quoted \"\$HOME\"/... redirect with .. is denied (control)" deny Bash 'cat x > "$HOME"/.claude/agent-memory/code-reviewer/../../x'
  c10 "a quoted \"\$HOME\"/.claude/settings.json redirect is denied (control)" deny Bash 'cat x > "$HOME"/.claude/settings.json'
  c10u "a raw UTF-8 comment (bytes C4 81) does not hide the command (control)" deny Bash 'rm x # @U0101@'
  c10u "a raw UTF-8 comment (byte C1 as U+00C1) does not hide the command (control)" deny Bash 'rm -rf x # @U00C1@'
  c10u "a raw UTF-8 comment on a harmless command stays allowed (control)" silent Bash 'git log # @U0101@'
  c10 "a non-ASCII comment through escaped JSON does not hide the command (control)" deny Bash $'rm x # \xc4\x81'

  # ---- Round 3 ----
  # R3a. The heredoc-as-data rule is strict: only the plain one-line shape is data.
  c10 "decoy )) and \$(( before a nested heredoc: the body runs" deny Bash $'echo "))" $((cat <<3))\nrm -rf x\n3'
  c10 "decoy quote and paren before a heredoc in <(...): the body runs" deny Bash $'bash <(echo ")" >&2; cat <<EOF\nrm x\nEOF\n)'
  c10 "a pipe behind a backslash-newline after the delimiter: the body runs" deny Bash $'cat <<EOF \\\n| sh\nrm x\nEOF'
  c10 "a backslash-newline before the heredoc line is not the plain shape (control)" deny Bash $'echo a \\\ncat <<EOF\nrm x\nEOF'
  c10 "a command before ; on the heredoc line is not the plain shape" deny Bash $'ls; cat <<EOF\nrm x\nEOF'
  c10 "a second command after the delimiter is not the plain shape" deny Bash $'cat <<EOF; sh\nrm x\nEOF'
  c10 "a quoted argument before << is not the plain shape" deny Bash $'cat "a" <<EOF\nrm x\nEOF'
  c10 "cat <<EOF then an fd redirect is not the plain shape" deny Bash $'cat <<EOF 2>&1\nrm x\nEOF'
  c10 "plain cat <<EOF is data (control)" silent Bash $'cat <<EOF\nrm x\nEOF'
  c10 "plain cat <<-EOF with tabs is data (control)" silent Bash $'cat <<-EOF\n\trm x\n\tEOF'
  c10 'cat <<"EOF" is data (control)' silent Bash $'cat <<"EOF"\nrm x\nEOF'
  c10 "cat > /dev/null <<EOF is data (control)" silent Bash $'cat > /dev/null <<EOF\nrm x\nEOF'
  c10 "FOO=1 cat <<EOF is not the plain shape (round 4)" deny Bash $'FOO=1 cat <<EOF\nrm x\nEOF'

  # R3b. A string method on a FileInfo is not a file write.
  c10 "\$f.Name.Replace after a [IO.FileInfo] cast is a read" silent PowerShell $'$f=[IO.FileInfo]\'x\'; $f.Name.Replace(\'a\',\'b\')'
  c10 "\$f.Name.Substring after a [IO.FileInfo] cast is a read" silent PowerShell $'$f=[IO.FileInfo]\'x\'; $f.Name.Substring(1)'
  c10 "[IO.FileInfo] .Open( is a write (control)" deny PowerShell $'([IO.FileInfo]\'x\').Open(\'Create\')'
  c10 "[IO.FileInfo] .Delete() is a write (control)" deny PowerShell $'([IO.FileInfo]\'x\').Delete()'

  # R3c. Names: directory, backslash and quotes are removed before a command is matched.
  c10 "/usr/bin/xargs rm is denied" deny Bash 'ls | /usr/bin/xargs rm -rf'
  c10 "\\xargs rm is denied" deny Bash "\\xargs rm $MEM/x"
  c10 "a quoted xargs wrapper is still a wrapper (control)" deny Bash "ls | 'xargs' rm $MEM/x"
  c10 "/bin/sudo rm is denied" deny Bash 'true && /bin/sudo rm x'
  c10 "/usr/bin/env -S is judged" deny Bash "true && /usr/bin/env -S 'rm x'"
  c10 "/usr/bin/git log is a read (control)" silent Bash 'true && /usr/bin/git log'

  # R3c. env -S judges the split string together with the remaining words.
  c10 "env -S 'bash -c' 'rm x' is judged" deny Bash "env -S 'bash -c' 'rm x'"
  c10 "env --split 'rm x' is judged" deny Bash "env --split 'rm x'"
  c10 "env --split-s 'rm x' (a prefix) is judged" deny Bash "env --split-s 'rm x'"
  c10 "env -S '-i FOO=1' rm x is judged (control)" deny Bash "env -S '-i FOO=1' rm x"
  c10 "env -S 'git log' is a read (control)" silent Bash "env -S 'git log'"
  c10 "env -S 'FOO=1' git log is a read (control)" silent Bash "env -S 'FOO=1' git log"

  # R3c. Process substitution bodies are commands.
  c10 "cat <(rm -rf build) runs the body" deny Bash 'cat <(rm -rf build)'
  c10 "ls >(rm x) runs the body" deny Bash 'ls >(rm x)'
  c10 "diff <(git log) <(git log -1) is a read (control)" silent Bash 'diff <(git log) <(git log -1)'
  c10 "a quoted <(rm x) is text (control)" silent Bash 'echo "<(rm x)" ">(rm y)"'
  c10 "a single-quoted <(rm x) is text (control)" silent Bash "echo '<(rm x)'"

  # R3c. stdbuf, watch, script, flock and the other launchers.
  c10 "stdbuf -o L rm is denied" deny Bash 'stdbuf -o L rm -rf x'
  c10 "stdbuf -oL rm is denied (control)" deny Bash 'stdbuf -oL rm x'
  c10 "stdbuf --output=L rm is denied (control)" deny Bash 'stdbuf --output=L rm x'
  c10 "stdbuf --output L rm is denied" deny Bash 'stdbuf --output L rm x'
  c10 "stdbuf -i0 -o L -e0 rm is denied" deny Bash 'stdbuf -i0 -o L -e0 rm x'
  c10 "stdbuf -oL git log is a read (control)" silent Bash 'stdbuf -oL git log'
  c10 "watch -n1 'rm x' is judged" deny Bash "watch -n1 'rm x'"
  c10 "watch -n 1 rm x is judged" deny Bash 'watch -n 1 rm x'
  c10 "watch --interval 2 rm x is judged" deny Bash 'watch --interval 2 rm x'
  c10 "watch git log is a read (control)" silent Bash 'watch git log'
  c10 "watch -n 2 'git status' is a read (control)" silent Bash "watch -n 2 'git status'"
  c10 "script -qc 'rm x' /dev/null is judged" deny Bash "script -qc 'rm x' /dev/null"
  c10 "script --command 'rm x' /dev/null is judged" deny Bash "script --command 'rm x' /dev/null"
  c10 "script -c without a file writes typescript" deny Bash "script -c 'git log'"
  c10 "script -c into a file writes it" deny Bash "script -qc 'git log' out.txt"
  c10 "script -O writes a log" deny Bash "script -O out.txt -c 'git log' /dev/null"
  c10 "script -qc 'git log' /dev/null is a read (control)" silent Bash "script -qc 'git log' /dev/null"
  c10 "flock creates its lock file" deny Bash 'flock /tmp/x.lock git log'
  c10 "timeout 5 rm is denied (control)" deny Bash 'timeout 5 rm x'
  c10 "nice -n 5 rm is denied (control)" deny Bash 'nice -n 5 rm x'
  c10 "ionice -c 3 rm is denied (control)" deny Bash 'ionice -c 3 rm x'
  c10 "chrt -f 10 rm is denied" deny Bash 'chrt -f 10 rm x'
  c10 "taskset -c 0 rm is denied" deny Bash 'taskset -c 0 rm x'
  c10 "taskset 0x1 rm is denied" deny Bash 'taskset 0x1 rm x'
  c10 "busybox rm is denied" deny Bash 'busybox rm x'
  c10 "busybox xargs rm is denied" deny Bash 'busybox xargs rm x'
  c10 "nice -n 5 git log is a read (control)" silent Bash 'nice -n 5 git log'
  c10 "taskset -c 0 git log is a read (control)" silent Bash 'taskset -c 0 git log'
  c10 "chrt -f 10 git log is a read (control)" silent Bash 'chrt -f 10 git log'
  c10 "busybox ls is a read (control)" silent Bash 'busybox ls'

  # R3c. ripgrep can run a preprocessor.
  c10 "rg --pre <cmd> is denied" deny Bash 'rg --pre rm . .'
  c10 "rg --pre=<cmd> is denied" deny Bash 'rg --pre=rm foo .'
  c10 "rg --hostname-bin is denied" deny Bash 'rg --hostname-bin x foo'
  c10 "rg -n foo src is a read (control)" silent Bash 'rg -n foo src'

  # R3c. Package manager config, cache and pack subcommands.
  c10 "npm --audit-level info install is an install" deny Bash 'npm --audit-level info install x'
  c10 "npm --audit-level high audit is a read (control)" silent Bash 'npm --audit-level high audit'
  c10 "npm config set is a write" deny Bash 'npm config set registry x'
  c10 "npm config delete is a write" deny Bash 'npm config delete registry'
  c10 "npm config edit is a write" deny Bash 'npm config edit'
  c10 "npm config get is a read (control)" silent Bash 'npm config get registry'
  c10 "npm config list is a read (control)" silent Bash 'npm config list'
  c10 "yarn config set is a write" deny Bash 'yarn config set x y'
  c10 "pnpm config delete is a write" deny Bash 'pnpm config delete x'
  c10 "pip config set is a write" deny Bash 'pip config set global.x y'
  c10 "npm cache clean is a write" deny Bash 'npm cache clean --force'
  c10 "pip cache purge is a write" deny Bash 'pip cache purge'
  c10 "pip cache dir is a read (control)" silent Bash 'pip cache dir'
  c10 "npm pack writes a tarball" deny Bash 'npm pack'
  c10 "npm pack --dry-run is a read (control)" silent Bash 'npm pack --dry-run'
  c10 "cargo fmt rewrites files" deny Bash 'cargo fmt'
  c10 "cargo fmt --check is a read (control)" silent Bash 'cargo fmt --check'
  c10 "cargo clippy --fix rewrites files" deny Bash 'cargo clippy --fix'
  c10 "cargo clippy is a read (control)" silent Bash 'cargo clippy'
  c10 "cargo package writes an archive" deny Bash 'cargo package'
  c10 "cargo package --list is a read (control)" silent Bash 'cargo package --list'

  # R3c. PowerShell and Windows file commands.
  c10 "(Get-Item f).Delete() is a write" deny PowerShell '(Get-Item f).Delete()'
  c10 "\$d.MoveTo( is a write" deny PowerShell '$d.MoveTo("x")'
  c10 "\$f.CopyTo( is a write" deny PowerShell '$f.CopyTo("y")'
  c10 "Expand-Archive is a write" deny PowerShell 'Expand-Archive a.zip out'
  c10 "Compress-Archive is a write" deny PowerShell 'Compress-Archive a b.zip'
  c10 "robocopy in PowerShell is a write" deny PowerShell 'robocopy a b'
  c10 "xcopy in PowerShell is a write" deny PowerShell 'xcopy a b'
  c10 "robocopy in bash is a write" deny Bash 'robocopy a b'
  c10 "\$s.Replace on a string is a read (control)" silent PowerShell $'$s.Replace(\'a\',\'b\')'

  # R3d. cp keeps the mode of its source with --preserve.
  c10 "cp --preserve=mode is denied" deny Bash "cp --preserve=mode /work/proj/a $MEM/a"
  c10 "cp --preserve (all defaults) is denied" deny Bash "cp --preserve /work/proj/a $MEM/a"
  c10 "cp --preserve=timestamps is allowed (control)" silent Bash "cp --preserve=timestamps /work/proj/a $MEM/a"
  c10 "cp of an executable into the memory dir is the documented allowance (control)" silent Bash "cp /bin/rm $MEM/r"
  c10 "GIT_PAGER=cat git log stays denied by design (control)" deny Bash 'GIT_PAGER=cat git log'

  # ---- Round 4 ----
  # A cold adversarial run found that the round-3 allowances were too wide. They are narrowed:
  # a heredoc body is data only for a bare reader name that starts the line, in a command that
  # defines no function or alias; the memory-dir allowance needs an absolute or $HOME-rooted
  # path and a command that changes neither directory nor HOME; links are denied outright.
  # R4a. A heredoc receiver that is not a bare reader name runs the body.
  c10 "a ./cat receiver is not a reader" deny Bash $'./cat <<EOF\nrm x\nEOF'
  c10 "a path-qualified cat in the memory dir is not a reader" deny Bash "$MEM/cat <<EOF"$'\nrm x\nEOF'
  c10 "a /tmp/x/cat receiver is not a reader" deny Bash $'echo hi\n/tmp/x/cat <<EOF\nrm x\nEOF'
  c10 "a \$HOME/cat receiver is not a reader (control)" deny Bash $'$HOME/cat <<EOF\nrm x\nEOF'
  c10 "a quoted cat receiver is not a reader" deny Bash $'\'cat\' <<EOF\nrm x\nEOF'
  c10 "a double-quoted cat receiver is not a reader" deny Bash $'"cat" <<EOF\nrm x\nEOF'
  c10 "a backslash cat receiver is not a reader (control)" deny Bash $'\\cat <<EOF\nrm x\nEOF'
  c10 "a ! before cat is not the plain shape" deny Bash $'! cat <<EOF\nrm x\nEOF'
  c10 "a FOO=1 prefix before cat is not the plain shape" deny Bash $'FOO=1 cat <<EOF\nrm x\nEOF'
  c10 "PATH=/tmp/x before cat is not the plain shape (control)" deny Bash $'PATH=/tmp/x:/usr/bin cat <<EOF\nrm x\nEOF'
  c10 "PATH= pointing into the memory dir before cat is not the plain shape" deny Bash "PATH=$MEM cat <<EOF"$'\nrm x\nEOF'
  c10 "less is not a reader (-o writes)" deny Bash $'less -o /tmp/log <<EOF\nrm x\nEOF'
  c10 "less is not a reader (+! runs a command)" deny Bash $'less +!rm <<EOF\nrm x\nEOF'
  c10 "less is not a reader (--log-file writes)" deny Bash $'less --log-file=/tmp/l <<EOF\nrm x\nEOF'
  c10 "more is not a reader" deny Bash $'more +/x <<EOF\nrm x\nEOF'
  c10 "a function named cat makes the heredoc body commands" deny Bash $'function cat { bash; }\ncat <<EOF\nrm x\nEOF'
  c10 "a cat() function makes the heredoc body commands" deny Bash $'cat() { ash; }\ncat <<EOF\nrm x\nEOF'
  c10 "an alias for cat makes the heredoc body commands" deny Bash $'shopt -s expand_aliases\nalias cat=ash\ncat <<EOF\nrm x\nEOF'
  c10 "an alias for grep makes the heredoc body commands" deny Bash $'alias grep=ash\ngrep x <<EOF\nrm x\nEOF'
  c10 "a cd then a path-qualified cat runs the body" deny Bash "cd $MEM"$'\n./cat <<EOF\nrm x\nEOF'
  c10 "Set-Alias in PowerShell makes the heredoc body commands" deny PowerShell $'Set-Alias cat bash\ncat <<EOF\nrm x\nEOF'
  c10 "a PowerShell function named cat makes the heredoc body commands" deny PowerShell $'function cat { bash }\ncat <<EOF\nrm x\nEOF'
  c10 "plain cat <<EOF stays data (control)" silent Bash $'cat <<EOF\nplain text\nEOF'
  c10 "plain head -n 1 <<EOF stays data (control)" silent Bash $'head -n 1 <<EOF\nrm x\nEOF'
  c10 "plain wc -l <<EOF stays data (control)" silent Bash $'wc -l <<EOF\nrm x\nEOF'

  # R4b. The memory-dir allowance is off in a command that changes the directory.
  c10 "cd then rm of a relative memory path is denied" deny Bash 'cd /tmp && rm .claude/agent-memory/code-reviewer/x'
  c10 "cd on its own line then touch of a relative memory path is denied" deny Bash $'cd /\ntouch .claude/agent-memory/code-reviewer/x'
  c10 "pushd then rm -rf of a relative memory path is denied" deny Bash 'pushd /etc; rm -rf ./.claude/agent-memory/code-reviewer'
  c10 "cd then mkdir -p of a relative memory path is denied" deny Bash 'cd /tmp; mkdir -p .claude/agent-memory/code-reviewer/x'
  c10 "cd then cp to a relative memory path is denied" deny Bash 'cd /tmp; cp a .claude/agent-memory/code-reviewer/x'
  c10 "cd then rm of an absolute memory path is denied (allowance off)" deny Bash "cd /tmp && rm $MEM/x"
  c10 "cd then a redirect into \$HOME memory is denied (allowance off)" deny Bash 'cd /tmp; echo x > $HOME/.claude/agent-memory/code-reviewer/f'
  c10 "env -C then rm of a relative memory path is denied" deny Bash 'env -C /tmp rm .claude/agent-memory/code-reviewer/x'
  c10 "env --chdir= then rm of a relative memory path is denied" deny Bash 'env --chdir=/tmp rm .claude/agent-memory/code-reviewer/x'
  c10 "env --chdir then touch of a relative memory path is denied" deny Bash 'env --chdir /tmp touch .claude/agent-memory/code-reviewer/x'
  c10 "sudo -D then rm of a relative memory path is denied" deny Bash 'sudo -D /tmp rm .claude/agent-memory/code-reviewer/x'
  c10 "a relative memory path in rm is denied even without a cd" deny Bash 'rm .claude/agent-memory/code-reviewer/x'
  c10 "PowerShell cd then rm of a relative memory path is denied" deny PowerShell 'cd C:\tmp; rm .claude\agent-memory\code-reviewer\x'
  c10 "PowerShell Set-Location then cp to a relative memory path is denied" deny PowerShell 'Set-Location C:\tmp; cp a .claude\agent-memory\code-reviewer\x'
  c10 "PowerShell sl then mkdir of a relative memory path is denied" deny PowerShell 'sl C:\tmp; mkdir .claude\agent-memory\code-reviewer\x'
  c10 "PowerShell Push-Location then rm of an absolute memory path is denied" deny PowerShell "Push-Location C:\\tmp; rm $MEM/x"

  # R4c. The memory-dir allowance is off in a command that changes HOME.
  c10 "export HOME then touch under \$HOME is denied" deny Bash 'export HOME=/tmp/q; touch $HOME/.claude/agent-memory/code-reviewer/f'
  c10 "HOME= on its own line then rm -rf under \$HOME is denied" deny Bash $'HOME=/tmp/q\nrm -rf $HOME/.claude/agent-memory/code-reviewer'
  c10 "HOME=; then mkdir -p under \$HOME is denied" deny Bash 'HOME=/tmp/q; mkdir -p $HOME/.claude/agent-memory/code-reviewer/d'
  c10 "HOME= before bash -c touch is denied" deny Bash "HOME=/tmp/q bash -c 'touch \$HOME/.claude/agent-memory/code-reviewer/f'"
  c10 "env HOME= before sh -c rm is denied" deny Bash "env HOME=/tmp/q sh -c 'rm -rf \$HOME/.claude/agent-memory/code-reviewer'"
  c10 "declare -x HOME then cp under \$HOME is denied" deny Bash 'declare -x HOME=/tmp/q; cp a $HOME/.claude/agent-memory/code-reviewer/x'
  c10 "export HOME then a redirect under \$HOME is denied" deny Bash 'export HOME=/tmp/q; echo x > $HOME/.claude/agent-memory/code-reviewer/f'
  c10 "PowerShell \$HOME assignment then rm is denied" deny PowerShell '$HOME=''C:\tmp''; rm $HOME/.claude/agent-memory/code-reviewer/x'
  c10 "PowerShell \$env:HOME assignment then rm is denied" deny PowerShell '$env:HOME=''C:\tmp''; rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "PowerShell Set-Variable HOME then rm is denied" deny PowerShell 'Set-Variable HOME C:\tmp; rm $HOME/.claude/agent-memory/code-reviewer/x'

  # R4d. A quoted or non-absolute memory path is not judged.
  c10 "a single-quoted absolute memory path in rm is denied" deny Bash "rm '$MEM/x'"
  c10 "a double-quoted absolute memory path in rm is denied" deny Bash "rm \"$MEM/x\""
  c10 "a backslash-escaped memory path in rm is denied (control)" deny Bash 'rm C:\Users\dev\.claude\agent-memory\code-reviewer\x'

  # R4e. Links are denied everywhere: a link into the memory dir reaches any file.
  c10 "mklink is denied" deny Bash 'mklink /J C:\Users\dev\.claude\agent-memory\code-reviewer\l C:\Windows'
  c10 "cmd /c mklink is denied" deny Bash 'cmd /c mklink C:\Users\dev\.claude\agent-memory\code-reviewer\l C:\Windows\x'
  c10 "cmd /c mklink /J is denied" deny Bash 'cmd /c mklink /J C:\Users\dev\.claude\agent-memory\code-reviewer\l C:\Windows'
  c10 "mklink in PowerShell is denied" deny PowerShell 'mklink /J C:\Users\dev\.claude\agent-memory\code-reviewer\l C:\Windows'
  c10 "cmd /c mklink /D in PowerShell is denied" deny PowerShell 'cmd /c mklink /D C:\Users\dev\.claude\agent-memory\code-reviewer\l C:\Windows'
  c10 "fsutil hardlink create is denied" deny Bash 'fsutil hardlink create C:\Users\dev\.claude\agent-memory\code-reviewer\h C:\Windows\x'
  c10 "fsutil reparsepoint is denied" deny Bash 'fsutil reparsepoint set C:\x'
  c10 "junction is denied" deny Bash 'junction C:\Users\dev\.claude\agent-memory\code-reviewer\j C:\Windows'
  c10 "ln -s into the memory dir is denied (control)" deny Bash "ln -s /etc/hosts $MEM/h"
  c10 "New-Item -ItemType SymbolicLink is denied (control: New-Item is a write already)" deny PowerShell "New-Item -ItemType SymbolicLink -Path $MEM/l -Target C:/Windows"
  c10 "New-Item -ItemType Junction is denied (control: New-Item is a write already)" deny PowerShell "New-Item -ItemType Junction -Path $MEM/j -Target C:/Windows"
  c10 "New-Item -ItemType HardLink is denied (control: New-Item is a write already)" deny PowerShell "New-Item -ItemType HardLink -Path $MEM/h -Target C:/Windows/x"
  c10 "ni -it sym (abbreviated) is denied (control: New-Item is a write already)" deny PowerShell "ni -it sym -Path $MEM/l -Target C:/Windows"

  # R4f. Allow controls: the plain, documented forms still pass.
  c10 "mkdir -p under ~/.claude/agent-memory/<agent> is allowed (control)" silent Bash 'mkdir -p ~/.claude/agent-memory/code-reviewer/x'
  c10 "cp into \"\$HOME\"/.claude/agent-memory/<agent>/ is allowed (control)" silent Bash 'cp a.txt "$HOME"/.claude/agent-memory/code-reviewer/'
  c10 "rm of an absolute memory path is allowed (control)" silent Bash "rm $MEM/old.md"
  c10 "touch of an absolute memory path is allowed (control)" silent Bash "touch $MEM/n.md"
  c10 "PowerShell mkdir of an absolute memory path is allowed (control)" silent PowerShell "mkdir $MEM/x"
  c10 "cat <<EOF with a plain body is data (control)" silent Bash $'cat <<EOF\nrm x\nplain text\nEOF'
  c10 "a command with cd but no memory path is judged as before (control)" silent Bash 'cd /work/proj && git log'

  # ---- Round 5 ----
  # A cross-check found that a file written into the memory dir could be run, that HOME could
  # be changed by words other than an assignment, that a here-string or trap runs text, and
  # that PowerShell has exec primitives. Red on the round-4 hook unless marked "control".
  # R5a. Nothing in the agent memory dir is run: not as the command, not sourced, not as the
  # program file of an interpreter, not as its stdin.
  c10 "a memory-dir file as the command is denied" deny Bash "$MEM/b -c 'rm x'"
  c10 "cp of a binary into memory, then running it, is denied" deny Bash "cp /usr/bin/bash $MEM/b && $MEM/b -c 'rm x'"
  c10 "a script written into memory, then run with bash, is denied" deny Bash "echo hi > $MEM/s.sh; bash $MEM/s.sh"
  c10 "source of a memory-dir file is denied" deny Bash "source $MEM/s.sh"
  c10 ". of a memory-dir file is denied" deny Bash ". $MEM/s.sh"
  c10 "sh with a memory-dir file as stdin is denied" deny Bash "sh < $MEM/s.sh"
  c10 "bash with a memory-dir file as its program is denied" deny Bash "bash $MEM/s.sh"
  c10 "bash -x with a memory-dir file is denied (option skipped)" deny Bash "bash -x $MEM/s.sh"
  c10 "bash -O extglob with a memory-dir file is denied (option value skipped)" deny Bash "bash -O extglob $MEM/s.sh"
  c10 "python with a memory-dir file is denied" deny Bash "python $MEM/s.py"
  c10 "python3.12 -W ignore with a memory-dir file is denied" deny Bash "python3.12 -W ignore $MEM/s.py"
  c10 "node with a memory-dir file is denied" deny Bash "node $MEM/s.js"
  c10 "perl with a memory-dir file is denied" deny Bash "perl $MEM/s.pl"
  c10 "deno run with a memory-dir file is denied" deny Bash "deno run $MEM/s.ts"
  c10 "pwsh -File with a memory-dir file is denied" deny Bash "pwsh -File $MEM/s.ps1"
  c10 "zsh with a memory-dir file is denied" deny Bash "zsh $MEM/s.sh"
  # shellcheck disable=SC2088  # a literal ~ is the spelling under test
  c10 "a ~ spelling as the command is denied" deny Bash '~/.claude/agent-memory/code-reviewer/b -c x'
  c10 "a \$HOME spelling as the command is denied" deny Bash '$HOME/.claude/agent-memory/code-reviewer/b -c x'
  c10 "a \"\$HOME\" spelling as the command is denied" deny Bash 'true && "$HOME"/.claude/agent-memory/code-reviewer/b -c x'
  c10 "a backslash spelling as the command is denied" deny Bash 'C:\Users\dev\.claude\agent-memory\code-reviewer\b -c x'
  c10 "a /c/ spelling as the command is denied" deny Bash 'true && /c/Users/dev/.claude/agent-memory/code-reviewer/b -c x'
  c10 "a relative spelling run with sh is denied" deny Bash 'sh .claude/agent-memory/code-reviewer/s.sh'
  c10 "a .. detour into memory run with bash is denied" deny Bash 'bash ~/.claude/x/../agent-memory/code-reviewer/s.sh'
  c10 "a memory-dir file under env is denied" deny Bash "env FOO=1 $MEM/b"
  c10 "a memory-dir file under sudo is denied" deny Bash "sudo $MEM/b"
  c10 "a memory-dir file under nohup is denied" deny Bash "nohup $MEM/b"
  c10 "a memory-dir file under xargs is denied" deny Bash "ls | xargs $MEM/b"
  c10 "a memory-dir file under find -exec is denied" deny Bash "find . -exec $MEM/b {} \\;"
  c10 "PowerShell & with a memory-dir file is denied" deny PowerShell "& $MEM/s.ps1"
  c10 "PowerShell dot-sourcing a memory-dir file is denied" deny PowerShell ". $MEM/s.ps1"
  c10 "PowerShell with a memory-dir path as the command is denied" deny PowerShell "$MEM/s.ps1"
  c10 "PowerShell & with a quoted backslash memory path is denied" deny PowerShell "& 'C:\\Users\\dev\\.claude\\agent-memory\\code-reviewer\\s.ps1'"
  c10 "PowerShell pwsh -File with a memory-dir file is denied" deny PowerShell "pwsh -File $MEM/s.ps1"
  c10 "bash hooks/test-hooks.sh is a read of a repo file (control)" silent Bash 'bash hooks/test-hooks.sh'
  c10 "python -m json.tool on a memory file is a read (control)" silent Bash "python -m json.tool $MEM/data.json"
  c10 "cat of a memory file is a read (control)" silent Bash "cat $MEM/n.md"
  c10 "grep reading a memory file on stdin is a read (control)" silent Bash "grep x < $MEM/n.md"
  c10 "< file before the command is a read (control)" silent Bash "< $MEM/n.md cat"
  c10 "ls of the memory dir is a read (control)" silent Bash "ls $MEM"
  c10 "cat > memory file with a quoted heredoc is allowed (control)" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\n# notes\nrm is only text here\nEOF'

  # R5b. HOME is judged by word: any use of the name that is not a $HOME expansion turns the
  # memory-dir allowance off for the command.
  c10 "for HOME in then rm under \$HOME is denied" deny Bash 'for HOME in /tmp; do rm $HOME/.claude/agent-memory/code-reviewer/a; done'
  c10 "read HOME then rm under \$HOME is denied" deny Bash $'read HOME < /tmp/f\nrm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "unset HOME then rm under \$HOME is denied" deny Bash 'unset HOME; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "printf -v HOME then rm under \$HOME is denied" deny Bash 'printf -v HOME /tmp; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "getopts HOME then rm under \$HOME is denied" deny Bash 'getopts a HOME; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "mapfile HOME then rm under ~ is denied" deny Bash 'mapfile -t HOME < /tmp/f; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "unset USERPROFILE then rm under ~ is denied" deny Bash 'unset USERPROFILE; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "PowerShell Remove-Variable HOME then rm is denied" deny PowerShell 'Remove-Variable HOME -Force; rm $HOME/.claude/agent-memory/code-reviewer/x'
  c10 "PowerShell lower-case remove-variable home then rm is denied" deny PowerShell 'remove-variable home; rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "pwsh -c with a lower-case home assignment then rm is denied (control)" deny Bash 'pwsh -c "$home=1"; rm ~/.claude/agent-memory/code-reviewer/x'
  c10n "rm \$HOME/... memory with no HOME word is allowed (control)" silent Bash 'rm $HOME/.claude/agent-memory/code-reviewer/x'
  c10 "rm \${HOME}/... memory with no HOME word is allowed (control)" silent Bash 'rm ${HOME}/.claude/agent-memory/code-reviewer/x'
  c10 "a /home/ path word does not turn the allowance off (control)" silent PowerShell 'ls /home/x; rm ~/.claude/agent-memory/code-reviewer/x'

  # R5c. A here-string or a trap runs text.
  c10 "bash <<< 'rm x' is denied" deny Bash "bash <<< 'rm x'"
  c10 "sh <<<\"rm x\" is denied" deny Bash 'sh <<<"rm x"'
  c10 "zsh <<< text is denied" deny Bash 'zsh <<< "rm x"'
  c10 "python <<< text is denied" deny Bash "python <<< 'print(1)'"
  c10 "a pwsh here-string is denied" deny Bash "pwsh -Command - <<< 'Remove-Item x'"
  c10 "a here-string piped on to sh is denied" deny Bash "cat <<< 'rm x' | sh"
  c10 "a VAR= prefix before a here-string receiver is denied" deny Bash "FOO=1 cat <<< 'rm x'"
  c10 "a function named cat makes a here-string a shell input" deny Bash $'cat() { sh; }\ncat <<< \'rm x\''
  c10 "trap 'rm x' EXIT is denied" deny Bash "trap 'rm x' EXIT"
  c10 "trap with a double-quoted action is denied" deny Bash 'trap "ls" ERR'
  c10 "trap with an empty action is denied" deny Bash "trap '' INT"
  c10 "trap in the second command is denied" deny Bash "ls; trap 'touch x' EXIT"
  c10 "cat <<< text is a read (control)" silent Bash "cat <<< 'rm x'"
  c10 "grep <<< text is a read (control)" silent Bash "grep -c x <<< 'rm x'"
  c10 "read x <<< text is a read (control)" silent Bash 'read -r a b <<< "x y"'
  c10 "a bare trap is a read (control)" silent Bash 'trap'
  c10 "trap -l is a read (control)" silent Bash 'trap -l'
  c10 "trap -p is a read (control)" silent Bash 'trap -p'

  # R5d. PowerShell commands that run a program or text as code.
  c10 "iex is denied" deny PowerShell "iex 'rm x'"
  c10 "Invoke-Expression is denied" deny PowerShell "Invoke-Expression 'rm x'"
  c10 "Start-Process is denied" deny PowerShell "Start-Process cmd -ArgumentList '/c del x'"
  c10 "saps is denied" deny PowerShell "saps cmd '/c del x'"
  c10 "start is denied in PowerShell" deny PowerShell 'start notepad'
  c10 "start is denied in Bash" deny Bash 'start notepad'
  c10 "cmd /c start is denied" deny Bash 'cmd /c start notepad'
  c10 "Invoke-Command is denied" deny PowerShell "Invoke-Command -ScriptBlock { ls }"
  c10 "icm is denied" deny PowerShell "icm { ls }"
  c10 "Start-Job is denied" deny PowerShell "Start-Job { ls }"
  c10 "sajb is denied" deny PowerShell "sajb { ls }"
  c10 "Start-ThreadJob is denied" deny PowerShell "Start-ThreadJob { ls }"
  c10 "Invoke-Item is denied" deny PowerShell 'Invoke-Item x.exe'
  c10 "ii is denied" deny PowerShell 'ii x.exe'
  c10 "[scriptblock]::Create is denied" deny PowerShell "[scriptblock]::Create('rm x')"
  c10 "New-Object -ComObject is denied" deny PowerShell 'New-Object -ComObject WScript.Shell'
  c10 "New-Object -com (abbreviated) is denied" deny PowerShell 'New-Object -com Shell.Application'
  c10 "Invoke-WmiMethod is denied" deny PowerShell 'Invoke-WmiMethod -Class Win32_Process -Name Create'
  c10 "iex inside pwsh -Command is denied" deny Bash "pwsh -Command \"iex 'rm x'\""
  c10 "Get-Process is a read (control)" silent PowerShell 'Get-Process'
  c10 "New-Object System.Text.StringBuilder is a read (control)" silent PowerShell 'New-Object System.Text.StringBuilder'
  c10 "echo start is text (control)" silent Bash 'echo start'
  c10 "git log is a read (control)" silent PowerShell 'git log --oneline'

  # R5e. cat<<EOF with no space is the same heredoc as cat <<EOF.
  c10 "cat<<EOF with a plain body is data" silent Bash $'cat<<EOF\nrm x\nplain text\nEOF'
  c10 "cat<<'EOF' with a quoted delimiter is data" silent Bash $'cat<<\'EOF\'\n$(touch x)\nEOF'
  c10 "cat<<-EOF with tabs is data" silent Bash $'cat<<-EOF\n\trm x\n\tEOF'
  c10 "cat<<EOF with an unquoted \$(...) body is judged (control)" deny Bash $'cat<<EOF\n$(touch x)\nEOF'
  c10 "cat<<EOF with a command after the delimiter is judged (control)" deny Bash $'cat<<EOF\nx\nEOF\nrm y'
  c10 "cat<<EOF | sh runs the body (control)" deny Bash $'cat<<EOF | sh\nrm x\nEOF'
  c10 "sh<<EOF runs the body (control)" deny Bash $'sh<<EOF\nrm x\nEOF'
  c10 "echo<<EOF is not a reader, so the body is judged as commands (control)" deny Bash $'echo<<EOF\nrm x\nEOF'

  # R6a. A backslash at the end of a body line of an unquoted heredoc can join lines, so the
  # delimiter may be reached early and the lines after it run.
  c10 "an unquoted heredoc whose delimiter is split by backslash-newline is judged" deny Bash $'cat <<EOF\nbody\nEO\\\nF\nrm x\nEOF'
  c10 "an unquoted heredoc body line that ends in a backslash joins the next one, which stays text (control)" silent Bash $'cat <<EOF\nabc\\\nrm x\nEOF'
  c10 "an unquoted heredoc body line that ends in three backslashes is judged" deny Bash $'cat <<EOF\nabc\\\\\\\nrm x\nEOF'
  c10 "an unquoted <<-EOF delimiter split by backslash-newline is judged" deny Bash $'cat <<-EOF\nx\nEO\\\nF\nrm y\nEOF'
  c10 "a split delimiter with a memory-dir redirect is judged" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<EOF\nEO\\\nF\nrm x\nEOF'
  c10 "a body line that ends in two backslashes is data (control)" silent Bash $'cat <<EOF\nabc\\\\\nrm x\nEOF'
  c10 "a quoted delimiter body line that ends in a backslash is data (control)" silent Bash $'cat <<\'EOF\'\nabc\\\nrm x\nEOF'
  c10 "a quoted delimiter body line that ends in two backslashes is data (control)" silent Bash $'cat <<\'EOF\'\nabc\\\\\nrm x\nEOF'
  c10 "a split delimiter under a quoted delimiter is data (control)" silent Bash $'cat <<\'EOF\'\nbody\nEO\\\nF\nEOF'
  c10 "a plain cat <<EOF with a plain body is data (control)" silent Bash $'cat <<EOF\nrm x\nplain text\nEOF'
  c10 "a plain memory-dir redirect with a quoted heredoc is allowed (control)" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nnotes about the review\nEOF'
  c10 "a plain memory-dir redirect with an unquoted heredoc is allowed (control)" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<EOF\nnotes about the review\nEOF'

  # R6b. A function or alias keyword split by quotes, or anything inside eval, is not seen as
  # text, so the flattened copy and an eval word are judged as well.
  c10 "eval of a function definition split by quotes then cat <<EOF is judged" deny Bash $'eval "fun""ction cat { sh; }"\ncat <<EOF\nrm x\nEOF'
  c10 "eval of a split function name then cat <<EOF is judged (control)" deny Bash $'eval \'ca\'\'t(){ sh; }\'\ncat <<EOF\nrm x\nEOF'
  c10 "any eval turns heredoc data off" deny Bash $'eval "echo hi"\ncat <<EOF\nrm x\nEOF'
  c10 "a quoted eval word turns heredoc data off" deny Bash $'ev""al "echo hi"\ncat <<EOF\nrm x\nEOF'
  c10 "a split alias keyword then cat <<EOF is judged" deny Bash $'ali\'\'as cat=sh\ncat <<EOF\nrm x\nEOF'
  c10 "a backslash-split function keyword then cat <<EOF is judged" deny Bash $'fun\\ction cat { sh; }\ncat <<EOF\nrm x\nEOF'
  c10 "a split PATH assignment then cat <<EOF is judged" deny Bash $'PA""TH=/tmp\ncat <<EOF\nrm x\nEOF'
  c10 "eval turns the memory-dir allowance off" deny Bash 'eval "echo hi"; rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "an eval word turns the allowance off for a redirect" deny Bash 'eval "x=1"; echo hi > ~/.claude/agent-memory/code-reviewer/n.md'
  c10 "the word evaluate is not eval (control)" silent Bash 'echo evaluate; rm ~/.claude/agent-memory/code-reviewer/x'

  # R6c. The name HOME split or built indirectly, and indirect assignments.
  c10 "export HO''ME then rm under ~ is denied" deny Bash $'export HO\'\'ME=/tmp; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "export HO\"\"ME then rm under \$HOME is denied" deny Bash 'export HO""ME=/tmp; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "a backslash-split HO\\ME assignment then rm under ~ is denied" deny Bash 'HO\ME=/tmp; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "a line-continuation split HOME assignment then rm is denied" deny Bash $'HO\\\nME=/tmp; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "eval of a split HOME assignment then rm is denied" deny Bash $'eval \'HO\'\'ME=/tmp\'; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "printf -v with an indirect name then rm is denied" deny Bash 'n=HO; printf -v ${n}ME /tmp; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "declare -n with a split name then rm is denied" deny Bash 'declare -n r=HO"ME"; r=/tmp; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "declare -rn then rm is denied" deny Bash 'declare -rn r=x; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "typeset -n then rm is denied" deny Bash 'typeset -n r=x; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "local -n then rm is denied" deny Bash 'f() { local -n r=x; }; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "a \${!name} indirection then rm is denied" deny Bash 'n=x; echo ${!n}; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "export of an indirect name then rm is denied" deny Bash 'n=HO; export ${n}ME=/tmp; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "env with an indirect name, then rm under ~, is denied" deny Bash 'n=HO; env ${n}ME=/tmp true && rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "read then rm under ~ is denied" deny Bash 'read x < /tmp/f; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "mapfile then rm under ~ is denied" deny Bash 'mapfile -t a < /tmp/f; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "readarray then a memory redirect is denied" deny Bash 'readarray a < /tmp/f; echo x > ~/.claude/agent-memory/code-reviewer/n.md'
  c10 "PowerShell Set-Variable with a built name then rm is denied" deny PowerShell "Set-Variable -Name ('HO'+'ME') -Value C:/tmp; rm \$HOME/.claude/agent-memory/code-reviewer/a"
  c10 "PowerShell sv with a built name then rm is denied" deny PowerShell "sv -Name ('HO'+'ME') C:/tmp; rm ~/.claude/agent-memory/code-reviewer/a"
  c10 "PowerShell New-Variable then rm is denied" deny PowerShell 'New-Variable -Name x -Value 1; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "PowerShell nv then rm is denied" deny PowerShell 'nv x 1; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "PowerShell Set-Item variable: then rm is denied (control)" deny PowerShell "Set-Item -Path ('variable:HO'+'ME') C:/tmp; rm ~/.claude/agent-memory/code-reviewer/a"
  c10 "PowerShell si env: then rm is denied" deny PowerShell 'si env:x 1; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "PowerShell SetEnvironmentVariable with a built name then rm is denied" deny PowerShell $'[Environment]::SetEnvironmentVariable((\'HO\'+\'ME\'),\'C:/tmp\'); rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "PowerShell backtick-split \$env:HOME assignment then rm is denied" deny PowerShell '$env:HO`ME=''C:\tmp''; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "PowerShell backtick-split Set-Variable HOME then rm is denied" deny PowerShell 'Set-Variable HO`ME C:/tmp; rm $HOME/.claude/agent-memory/code-reviewer/a'
  c10 "pwsh -c with a split HOME assignment then rm is denied" deny Bash $'pwsh -c "Set-Variable HO\'\'ME x"; rm ~/.claude/agent-memory/code-reviewer/a'
  c10 "rm under ~ with no variable word is allowed (control)" silent Bash 'rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "a redirect under ~ with no variable word is allowed (control)" silent Bash 'echo hi > ~/.claude/agent-memory/code-reviewer/n.md'
  c10 "PowerShell rm under ~ is allowed (control)" silent PowerShell 'rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "PowerShell Get-Variable is a read (control)" silent PowerShell 'Get-Variable x; rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "the word printf without -v is not an assignment (control)" silent Bash 'printf "%s" hi > ~/.claude/agent-memory/code-reviewer/n.md'
  c10 "declare -x of a plain name is not a nameref (control)" silent Bash 'declare -x FOO=1; rm ~/.claude/agent-memory/code-reviewer/x'
  c10 "bash hooks/test-hooks.sh is a run of the test script (control)" silent Bash 'bash hooks/test-hooks.sh'

  # R6d. An unquoted $HOME or ${HOME} is word-split and globbed by bash: with a HOME that has a
  # space (common on Windows) or a glob character it is not one path. ~ and "$HOME" are safe.
  c10h "rm -r under an unquoted \$HOME is denied when HOME has a space" deny Bash 'rm -r $HOME/.claude/agent-memory/code-reviewer/x'
  c10h "rm under an unquoted \${HOME} is denied when HOME has a space" deny Bash 'rm ${HOME}/.claude/agent-memory/code-reviewer/x'
  c10h "a redirect to an unquoted \$HOME memory path is denied when HOME has a space" deny Bash 'echo hi > $HOME/.claude/agent-memory/code-reviewer/n.md'
  c10h "cp into an unquoted \$HOME memory dir is denied when HOME has a space" deny Bash 'cp a $HOME/.claude/agent-memory/code-reviewer/'
  c10h "rm under \"\$HOME\"/... is allowed when HOME has a space (control)" silent Bash 'rm "$HOME"/.claude/agent-memory/code-reviewer/x'
  c10h "rm under \"\$HOME/...\" is allowed when HOME has a space (control)" silent Bash 'rm "$HOME/.claude/agent-memory/code-reviewer/x"'
  c10h "rm under \"\${HOME}\"/... is allowed when HOME has a space (control)" silent Bash 'rm "${HOME}"/.claude/agent-memory/code-reviewer/x'
  c10h "rm under ~ is allowed when HOME has a space (control)" silent Bash 'rm ~/.claude/agent-memory/code-reviewer/x'
  c10h "a redirect under ~ is allowed when HOME has a space (control)" silent Bash 'echo hi > ~/.claude/agent-memory/code-reviewer/n.md'
  c10h "PowerShell does not split \$HOME, so rm under it is allowed (control)" silent PowerShell 'rm $HOME/.claude/agent-memory/code-reviewer/x'
  c10h "rm under \$HOME in another agent memory dir is denied (control)" deny Bash 'rm "$HOME"/.claude/agent-memory/security-reviewer/x'
  c10n "rm under an unquoted \$HOME is allowed when HOME has no space (control)" silent Bash 'rm -r $HOME/.claude/agent-memory/code-reviewer/x'
  c10 "rm under \"\$HOME\"/... with a .. is denied (control)" deny Bash 'rm "$HOME"/.claude/agent-memory/code-reviewer/../../x'

  # R7. Words in the body of a quoted-delimiter heredoc do not count: bash never expands or runs
  # it, so a memory note that mentions cd, HOME or eval stays allowed. Anything outside it counts.
  c10 "a quoted-delimiter note that mentions read and cd is allowed" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\n# notes\nread the config first, then cd into src\nEOF'
  c10 "a quoted-delimiter note that mentions HOME and eval is allowed" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nHOME page uses eval\nEOF'
  c10 "a quoted-delimiter note that mentions alias and function is allowed (control)" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nuse an alias or a function for it\nEOF'
  c10 "a quoted-delimiter note that defines cat() as text is allowed" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nfunction cat() { sh; }\nHOME=/tmp\nEOF'
  c10 "a double-quoted delimiter note that mentions cd is allowed" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<"EOF"\ncd into src, read the config, HOME, eval\nEOF'
  c10 "a backslash-quoted delimiter note that mentions cd is allowed" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\\EOF\ncd into src, read the config, HOME, eval\nEOF'
  c10 "a <<-'EOF' note with tabbed lines that mention cd is allowed" silent Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<-\'EOF\'\n\tcd into src\n\tEOF'
  c10 "a PowerShell-tool note with a quoted heredoc that mentions cd is allowed" silent PowerShell $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\ncd into src, HOME\nEOF'
  c10 "an unquoted-delimiter note that says \$(cd /tmp) is denied (control)" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<EOF\n# notes\n$(cd /tmp)\nEOF'
  c10 "an unquoted-delimiter note that mentions read and cd keeps the allowance off (control)" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<EOF\nread the config first, then cd into src\nEOF'
  c10 "a quoted-delimiter note followed by a real cd line is denied (control)" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nnote\nEOF\ncd /tmp'
  c10 "a quoted-delimiter note followed by eval is denied (control)" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nnote\nEOF\neval x'
  c10 "a quoted-delimiter note followed by a HOME assignment is denied (control)" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nnote\nEOF\nHOME=/tmp'
  c10 "a quoted-delimiter note after a cd line is denied (control)" deny Bash $'cd /tmp\ncat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nnote\nEOF'
  c10 "a quoted-delimiter note with cat() defined before it is denied (control)" deny Bash $'cat() { sh; }\ncat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nrm x\nEOF'
  c10 "a quoted-delimiter note with cat() defined before it and a plain body is denied (control)" deny Bash $'cat() { sh; }\ncat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nread the config first, then cd into src\nEOF'
  c10 "a quoted-delimiter note with an alias defined before it and a cd in the body is denied (control)" deny Bash $'alias cat=sh\ncat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nread the config first, then cd into src\nEOF'
  c10 "a quoted-delimiter note into tee (not a bare reader) that mentions cd is denied (control)" deny Bash $'tee ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\ncd into src\nEOF'
  c10 "a quoted-delimiter note that never closes is denied (control)" deny Bash $'cat > ~/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\ncd into src\nread x'
  c10 "a quoted-delimiter note into another file than memory is still denied (control)" deny Bash $'cat > /tmp/n.md <<\'EOF\'\ncd into src\nEOF'
  # R8. A here-string feeds text to a reader or a plain text filter (not sed or awk, which can
  # run it), also along a pipe of them;
  # a preload, an rc file or a -f program file in the memory dir is run; code given with -c or
  # -e makes < input data; and $HOME in a note's redirect target keeps the heredoc plain.
  c10 "tr <<< text is a read" silent Bash 'tr a-z A-Z <<< "$x"'
  c10 "cut <<< text is a read" silent Bash 'cut -d, -f1 <<< "$x"'
  c10 "sed e <<< text is denied (sed runs text)" deny Bash "sed e <<< 'rm x'"
  c10 "awk system() <<< text is denied (awk runs text)" deny Bash "awk '{system(\$0)}' <<< 'rm x'"
  c10 "a here-string piped on to (sh) is denied" deny Bash "cat <<< 'rm x' | (sh)"
  c10 "a here-string piped on to sh on the next line is denied" deny Bash $'cat <<< \'rm x\' |\nsh'
  c10 "cat <<< text; then a separate sh is not fed the text (control)" silent Bash 'cat <<< x; sh'
  c10 "grep <<< text piped to wc is a read" silent Bash 'grep a <<< "$x" | wc -l'
  c10 "cut <<< text piped through sort to wc is a read" silent Bash 'cut -c1 <<< "$x" | sort | wc -l'
  c10 "tr <<< text piped to bash is denied (control)" deny Bash "tr a b <<< 'rm x' | bash"
  c10 "cut <<< text piped through sort to sh is denied (control)" deny Bash "cut -c1 <<< 'rm x' | sort | sh"
  c10 "awk -f /dev/stdin <<< text is denied" deny Bash "awk -f /dev/stdin <<< 'BEGIN{print 1}'"
  c10 "sed -f - <<< text is denied" deny Bash "sed -f - in.txt <<< 'w out'"
  c10 "sed -nf - <<< text is denied" deny Bash "sed -nf - in.txt <<< 'w out'"
  c10 "a loop fed by done <<< is denied (control)" deny Bash 'while read l; do echo "$l"; done <<< "$x"'
  c10 "node -r with a memory-dir module is denied" deny Bash 'node -r ~/.claude/agent-memory/code-reviewer/p.js app.js'
  c10 "node --require= with a memory-dir module is denied" deny Bash 'node --require=~/.claude/agent-memory/code-reviewer/p.js app.js'
  c10 "node --import with a memory-dir module is denied" deny Bash 'node --import ~/.claude/agent-memory/code-reviewer/p.mjs app.js'
  c10 "bash --rcfile from the memory dir is denied" deny Bash 'bash --rcfile ~/.claude/agent-memory/code-reviewer/rc -i'
  c10 "sed -f with a memory-dir script is denied" deny Bash 'sed -f ~/.claude/agent-memory/code-reviewer/s.sed in.txt'
  c10 "awk -f<file> from the memory dir is denied" deny Bash 'awk -f~/.claude/agent-memory/code-reviewer/a.awk in.txt'
  c10 "make --file= from the memory dir is denied" deny Bash 'make --file=~/.claude/agent-memory/code-reviewer/Mk'
  c10 "bash --init-file from the memory dir is denied" deny Bash 'bash --init-file ~/.claude/agent-memory/code-reviewer/rc'
  c10 "node --experimental-loader from the memory dir is denied" deny Bash 'node --experimental-loader ~/.claude/agent-memory/code-reviewer/l.mjs app.js'
  c10 "sed --file from the memory dir is denied" deny Bash 'sed --file ~/.claude/agent-memory/code-reviewer/s.sed in'
  c10 "gawk -E from the memory dir is denied" deny Bash 'gawk -E ~/.claude/agent-memory/code-reviewer/a.awk in'
  c10 "gawk -i from the memory dir is denied" deny Bash "gawk -i ~/.claude/agent-memory/code-reviewer/a.awk '{print}' in"
  c10 "ruby -r from the memory dir is denied" deny Bash 'ruby -r ~/.claude/agent-memory/code-reviewer/x.rb -e 1'
  c10 "awk -f /dev/stdin with a memory-dir file on < is denied" deny Bash 'awk -f /dev/stdin < ~/.claude/agent-memory/code-reviewer/p.awk'
  c10 "sed -f - with a memory-dir file on < is denied" deny Bash 'sed -f - in.txt < ~/.claude/agent-memory/code-reviewer/s.sed'
  c10 "make -f - with a memory-dir file on < is denied" deny Bash 'make -f - < ~/.claude/agent-memory/code-reviewer/Mk'
  c10 "ruby -rset with a memory-dir program on < is denied" deny Bash 'ruby -rset < ~/.claude/agent-memory/code-reviewer/x.rb'
  c10 "perl -MEnv with a memory-dir program on < is denied" deny Bash 'perl -MEnv < ~/.claude/agent-memory/code-reviewer/x.pl'
  c10 "python -m code with a memory-dir file on < is denied" deny Bash 'python3 -m code < ~/.claude/agent-memory/code-reviewer/x.py'
  c10 "pwsh -c - with a memory-dir file on < is denied" deny Bash 'pwsh -c - < ~/.claude/agent-memory/code-reviewer/x.ps1'
  c10 "perl -le reads a memory-dir file on stdin as data" silent Bash "perl -le 'print 1' < ~/.claude/agent-memory/code-reviewer/d.txt"
  c10 "a here-string piped on to |(sh) written together is denied" deny Bash "cat <<< 'rm x' |(sh)"
  c10 "a subshell here-string piped on to sh is denied" deny Bash "(cat <<< 'rm x') | sh"
  c10 "a subshell here-string then a separate sh is not fed the text (control)" silent Bash '(cat <<< x); sh'
  c10 "a here-string inside a subshell is a read (control)" silent Bash '(cat <<< x)'
  c10 "cat f piped into a subshell grep is a read (control)" silent Bash 'cat f | (grep x)'
  c10 "gawk -i inplace edits files in place" deny Bash "gawk -i inplace '{print}' f"
  c10 "gawk --include=inplace edits files in place" deny Bash "gawk --include=inplace '{print}' f"
  c10 "ruby -pi edits files in place" deny Bash "ruby -pi -e 'x' f"
  c10 "sed -bi edits files in place" deny Bash "sed -bi 's/a/b/' f"
  c10 "a subshell here-string through 2>&1 into sh is denied" deny Bash "(cat <<< 'rm x') 2>&1 | sh"
  c10 "awk -f /proc/self/fd/0 with a memory-dir file on < is denied" deny Bash 'awk -f /proc/self/fd/0 < ~/.claude/agent-memory/code-reviewer/p.awk'
  c10 "gawk -i with another include file is a read (control)" silent Bash "gawk -i lib.awk '{print}' f"
  c10 "perl -Ilib is not perl -i (control)" silent Bash "perl -Ilib -e 'print 1'"
  c10 "perl -MList::Util is not perl -i (control)" silent Bash "perl -MList::Util=sum -e 'print sum(1,2)'"
  c10 "perl -ne, -lane and -pe are reads (control)" silent Bash "perl -ne 'print if /x/' f; perl -lane 'print \$F[0]' f; perl -pe 's/a/b/' f"
  c10 "ruby -e and python -m pytest are reads (control)" silent Bash 'ruby -e "puts 1"; python -m pytest tests'
  c10 "python -m json.tool with a non-memory file on < is a read (control)" silent Bash 'python -m json.tool < other.json'
  c10 "awk -v with a program is a read (control)" silent Bash "awk -v x=1 '{print}' f"
  c10 "a memory-dir file as a script argument is data (control)" silent Bash 'python3 tool.py ~/.claude/agent-memory/code-reviewer/d.json'
  c10 "sed -e with a memory-dir input file is a read (control)" silent Bash 'sed -e s/f/g/ ~/.claude/agent-memory/code-reviewer/d.txt'
  c10 "python -c reads a memory-dir file on stdin as data" silent Bash "python3 -c 'import sys; print(sys.stdin.read())' < ~/.claude/agent-memory/code-reviewer/d.json"
  c10 "node -e reads a memory-dir file on stdin as data" silent Bash "node -e 'x' < ~/.claude/agent-memory/code-reviewer/d.json"
  c10 "python with a memory-dir file as stdin program is denied (control)" deny Bash 'python3 < ~/.claude/agent-memory/code-reviewer/d.py'
  c10 "bash with a memory-dir file as stdin program is denied (control)" deny Bash 'bash < ~/.claude/agent-memory/code-reviewer/s.sh'
  c10n "a \$HOME note that mentions read and cd is allowed" silent Bash $'cat > $HOME/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nread the cd docs\nEOF'
  c10h "a \"\$HOME\" note that mentions read and cd is allowed" silent Bash $'cat > "$HOME"/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nread the cd docs\nEOF'
  c10n "a \${HOME} note that mentions read and cd is allowed" silent Bash $'cat > ${HOME}/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nread the cd docs\nEOF'
  c10n "a \$HOMEX note is denied (control)" deny Bash $'cat > $HOMEX/.claude/agent-memory/code-reviewer/n.md <<\'EOF\'\nread the cd docs\nEOF'
  c10n "a \$HOME note with \$(...) in the target is denied (control)" deny Bash $'cat > $HOME$(touch y)/n.md <<\'EOF\'\nhi\nEOF'
  c10n "an unquoted \$HOME note body with \$(...) is denied (control)" deny Bash $'cat > $HOME/.claude/agent-memory/code-reviewer/n.md <<EOF\n$(touch y)\nEOF'
  c10n "a \$HOME note outside the memory dir is denied (control)" deny Bash $'cat > $HOME/notes.md <<\'EOF\'\nhi\nEOF'
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
