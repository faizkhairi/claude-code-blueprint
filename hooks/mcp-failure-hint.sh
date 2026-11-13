#!/bin/bash
# Hook: PostToolUseFailure (mcp__.*) - fallback guidance when an MCP tool fails.
# When an MCP tool call errors, this adds a short checklist to Claude's context:
# retry once, check the usual causes for that server, then fall back to a
# non-MCP route instead of looping on the same failing call.
#
# Why a command hook and not a prompt hook: a prompt hook sends its text to an
# evaluator model that answers {ok, reason}, and on PostToolUseFailure only an
# ok:false reason reaches Claude. Advice text in a prompt hook therefore costs a
# model call per failure and rarely arrives. A command hook that returns
# hookSpecificOutput.additionalContext delivers the same text every time, for
# free.
#
# JSON parsing uses Python (see hooks/README "Why Python"); fail-open if Python
# is unavailable or the input is malformed, so a missing dependency never blocks
# the session. Always exits 0.
# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

printf '%s' "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(d, dict):
    sys.exit(0)
tool = d.get('tool_name', '') or ''
if not isinstance(tool, str) or not tool.startswith('mcp__'):
    sys.exit(0)
server = tool.split('__')[1] if tool.count('__') >= 2 else 'the MCP server'
msg = (
    'MCP tool ' + tool + ' failed. Before retrying in a loop: '
    '1) Retry once; the server may have crashed or timed out. '
    '2) Check the usual cause for ' + server + ': a browser session that closed, '
    'a container runtime that is not running, an expired token, or a server that '
    'needs a restart (run /mcp to see its status). '
    '3) If the retry fails, fall back to a non-MCP route (for example curl for a web '
    'request, the docker CLI for containers, a local test runner for browser checks) '
    'and say in your reply that you switched.'
)
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUseFailure', 'additionalContext': msg}}))
" 2>/dev/null

exit 0
