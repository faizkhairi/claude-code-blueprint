#!/bin/bash
# Hook: PostToolUse (Agent/Task) - treat subagent findings as hypotheses.
# When a subagent finishes, this emits a one-line reminder that its report is a
# set of claims to verify, not facts to act on.
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
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

# Read the tool name and (if present) the subagent type in one parse.
read -r TOOL SUBTYPE <<EOF
$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tool = d.get('tool_name', '')
    sub = d.get('tool_input', {}).get('subagent_type', '')
    print(tool, sub)
except:
    print('', '')
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

# Delivery channel matters. This hook runs synchronously, and a synchronous
# hook's systemMessage is shown to the user only: Claude never reads it. Text
# meant for Claude goes in hookSpecificOutput.additionalContext, which Claude
# Code adds to Claude's context alongside the tool result. Emit both: the
# additionalContext for Claude, the systemMessage so the user sees it fired.
# (An async hook is different: its systemMessage and additionalContext both
# reach Claude on the next turn. See hooks/README "Which output reaches Claude".)
$PYTHON -c "
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
