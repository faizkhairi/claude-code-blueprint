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

echo '{"systemMessage": "SUBAGENT REPORT RECEIVED - treat its findings as HYPOTHESES, not facts. Before acting on any [MUST FIX] / defect / \"X is missing/wrong/dead\" claim, verify it against the authoritative source yourself: the actual values (not variable names), a whole-tree grep (not one file), the file at the real ref, and the test suite. Findings from a narrow vantage or sibling-symmetry routinely dissolve under verification. Do NOT edit, fix, or merge on the report alone."}'

exit 0
