#!/bin/bash
# Hook: PostToolUse (Agent/Task) - treat subagent findings as hypotheses.
# When a subagent finishes, this emits a one-line reminder that its report is a
# set of claims to verify, not facts to act on. A background spawn returns at
# launch, before any report exists (tool_response.status "async_launched"), so it
# gets a short "launched, no report yet" note for Claude instead.
#
# Why this exists: a fresh-context subagent sees a narrow slice of the codebase.
# Findings like "X is missing", "this is a bug", or "[MUST FIX]" often come from
# that limited vantage or from sibling-symmetry guesses, and they routinely
# dissolve when checked against the actual values, a whole-tree grep, the file at
# the real ref, or the test suite. Acting on an unverified finding is how a
# confident-sounding report injects a regression. A deterministic nudge at the
# moment the report lands is more reliable than hoping the reader remembers to
# verify.
#
# JSON parsing uses Python (see hooks/README "Why Python"); fail-open if Python
# is unavailable, so a missing dependency never blocks the session.
# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

# Read the tool name, the subagent type and the launch status in one parse. Empty
# fields print as "-" so the three words stay in their own variables.
read -r TOOL SUBTYPE STATUS <<EOF
$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '')
    sub = d.get('tool_input', {}).get('subagent_type', '')
    resp = d.get('tool_response', {})
    status = resp.get('status', '') if isinstance(resp, dict) else ''
    print(tool or '-', sub or '-', status or '-')
except:
    print('-', '-', '-')
" 2>/dev/null)
EOF

# Only fire for subagent spawns. The harness has used both tool names.
case "$TOOL" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

# Skip pure search/explore agents: their results are locations to look at, not
# verdicts to act on, so the "verify before acting" reminder does not apply.
case "$SUBTYPE" in
  Explore|explore) exit 0 ;;
esac

# A background spawn has no report yet, so "report received" would be false. Tell
# Claude only (additionalContext, no systemMessage), and keep the hypotheses rule.
if [ "$STATUS" = "async_launched" ]; then
  "$PYTHON" -c "
import json
msg = ('Background agent launched, no report yet. Report only when all work has finished, '
       'and treat its report as HYPOTHESES to verify when it arrives.')
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': msg}}))
" 2>/dev/null
  exit 0
fi

# Delivery channel matters. This hook runs synchronously, and a synchronous
# hook's systemMessage is shown to the user only: Claude never reads it. Text
# meant for Claude goes in hookSpecificOutput.additionalContext, which Claude
# Code adds to Claude's context alongside the tool result. Emit both: the
# additionalContext for Claude, the systemMessage so the user sees it fired.
# (An async hook is different: its systemMessage and additionalContext both
# reach Claude on the next turn. See hooks/README "Which output reaches Claude".)
"$PYTHON" -c "
import json
msg = ('SUBAGENT REPORT RECEIVED: treat its findings as HYPOTHESES, not facts. '
       'Before acting on any [MUST FIX], defect, or \'X is missing/wrong/dead\' claim, '
       'verify it against the authoritative source yourself: the actual values (not variable names), '
       'a whole-tree grep (not one file), the file at the real ref, and the test suite. '
       'Findings from a narrow vantage or sibling-symmetry routinely dissolve under verification. '
       'Do NOT edit, fix, or merge on the report alone.')
print(json.dumps({
    'systemMessage': 'Subagent report received: verify its findings before acting on them.',
    'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': msg},
}))
" 2>/dev/null

exit 0
