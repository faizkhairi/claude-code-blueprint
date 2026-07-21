---
name: self-audit
description: "Run the verify-plan checklist against YOUR OWN plan before finalizing it (before ExitPlanMode), with special emphasis on the consumer audit. Triggers on: 'audit yourself', 'self-audit', 'check your own plan', 'did you check everything', 'verify before exit plan', or automatically before any non-trivial ExitPlanMode. Catches the gap where a rule exists but was not applied at the decision point."
user-invocable: true
argument-hint: "[empty = audit the current plan file]"
---

Self-audit YOUR OWN plan before ExitPlanMode. This is an attention-gap backstop: the verify-plan checklist already exists in this blueprint (the `verify-plan` agent), but knowing a check and applying it at the right moment are different things. This skill forces the full checklist to run against the plan you just wrote, catching blind spots you missed while heads-down in planning.

## When this runs

- **Automatically**: before every non-trivial `ExitPlanMode` (per the Plan-First rule in CLAUDE.md). A plan is non-trivial if it touches more than one file, changes behavior, or modifies config or a shared resource.
- **On demand**: when the user says "audit yourself", "did you check everything", and similar.

Skip only for genuinely trivial plans (a single-line typo fix).

## What it does

1. **Read the current plan**: the plan file named in the plan-mode system message.
2. **Run the verify-plan checklist against the plan, IN ORDER.** Do not re-derive it: spawn the `verify-plan` agent (or read `agents/verify-plan.md` and follow its checklist) so the same checks that would review someone else's plan now review yours. Report a table: Check | Status (PASS / FAIL / UNCLEAR) | Finding.
3. **Emphasis on the Consumer Audit, the highest-value and most-missed check:**
   - Identify every SHARED RESOURCE the plan changes: a token or credential, an env key, a file path, a DB table, an API field, or any string referenced from more than one place.
   - For each, grep BOTH the target repo AND your own global config, because a repo-only search misses consumers that live in your personal setup:
     ```bash
     # Repo:
     grep -rn "<resource>" .
     # Your own global config (adjust to your layout):
     grep -rn "<resource>" ~/.claude/skills ~/.claude/agents ~/.claude/hooks ~/.claude/rules
     ```
   - Every hit is a consumer. Ask: "does the plan repoint or update this, or will it break silently?" If a consumer is not handled in the plan, that is a FAIL: add it to the plan before exiting.
   - This is the exact class of miss where a plan updates a shared value in the repo but leaves stale references in the user's own global config (a repo-only audit reports "zero consumers" while several live outside the repo).
4. **On any FAIL**: fix the plan file first, then re-run the failed checks. Only proceed to ExitPlanMode when the audit is clean, or the remaining items are explicitly accepted or deferred with a reason.

## Output

A Check | Status | Finding table, then one line: **AUDIT CLEAN: safe to ExitPlanMode**, or **N FINDINGS: fixing plan before exit** (with the fixes applied to the plan file).

## What this does NOT do

- It does not review a code diff (a diff review is a separate concern, after the plan is executed).
- It does not run tests (that is post-execution verification).
- It does not duplicate the checklist: it runs the `verify-plan` checks as-is.
