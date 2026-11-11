#!/bin/bash
# Smoke test for all hook scripts.
# Verifies: syntax, Python detection, graceful handling of empty/malformed input.
# Run: bash hooks/test-hooks.sh
#
# This script does NOT test hook logic (e.g., whether block-git-push actually blocks).
# It tests that hooks don't crash, always exit 0, and handle bad input gracefully.

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
