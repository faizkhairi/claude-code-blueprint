#!/bin/bash
# Hook: PreToolUse (ExitPlanMode) - a plan must carry its self-audit before it leaves
# plan mode.
#
# Why this exists: CLAUDE.md asks for the verify-plan checklist before every
# non-trivial ExitPlanMode, and the self-audit skill runs it, but both are prose. Under
# pressure the audit is the step that gets skipped, and nothing records the skip.
# Claude Code injects the plan text (`plan`) and its path (`planFilePath`) into this
# tool's hook input (code.claude.com/docs/en/hooks, ExitPlanMode tool input), so a
# hook can check that the plan carries the self-audit result.
#
# What it checks: the plan text must contain the marker the self-audit skill writes
# into the plan file, `AUDIT CLEAN`, or, for a genuinely trivial plan, the line
# `self-audit: not required (trivial)`. Otherwise the call is denied with a reason
# that tells Claude to run the skill. When a marker is present the hook stays silent
# (it never answers "allow", which would skip the plan-approval prompt).
#
# Limit: this proves the plan quotes an audit, not that the audit was done well. It
# makes skipping the audit a deliberate act instead of an oversight.
#
# Pairing: installed only by the `full` preset, which also installs the self-audit
# skill, so no preset gets this guard without the skill that satisfies it.
#
# Fail-open trade-off: no plan text at all (an older Claude Code, or an empty plan
# file), missing Python, or input that is not valid JSON all exit 0 with no decision,
# so the plan goes to the normal approval prompt. A guard that blocked every plan
# whenever its input looked unusual would be disabled within a day. The missing-Python
# case prints a warning on stderr.
# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then
  echo "guard-exit-plan: Python not found, plans are NOT checked for a self-audit" >&2
  exit 0
fi

"$PYTHON" -c '
import json, sys

try:
    data = json.load(sys.stdin)
    tin = data.get("tool_input") or {}
except Exception:
    sys.exit(0)
if not isinstance(tin, dict):
    sys.exit(0)

plan = tin.get("plan") or ""
if not isinstance(plan, str) or not plan.strip():
    path = tin.get("planFilePath") or ""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            plan = f.read()
    except Exception:
        plan = ""
if not plan.strip():
    sys.exit(0)

if "AUDIT CLEAN" in plan or "self-audit: not required (trivial)" in plan.lower():
    sys.exit(0)

reason = ("guard-exit-plan: this plan carries no finished self-audit. Run the self-audit "
          "skill (the verify-plan checklist, including the fresh-context review), fix the "
          "plan until it passes, and write its Check | Status | Finding table and the line "
          "AUDIT CLEAN into the plan file. For a genuinely trivial plan, add the line "
          "self-audit: not required (trivial) instead.")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
    "permissionDecision": "deny", "permissionDecisionReason": reason}}))
' 2>/dev/null
exit 0
