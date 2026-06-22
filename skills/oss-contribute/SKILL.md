---
name: oss-contribute
description: End-to-end open-source contribution flow for GitHub projects (verify issue availability, read CONTRIBUTING, match CI conventions, implement, pre-PR leak + triple-check, submit PR). Triggers on 'contribute to', 'open a PR to', 'OSS contribution', 'submit a PR to <repo>', 'fix an issue in <oss repo>'.
user-invocable: true
argument-hint: "[owner/repo] [issue-number or feature]"
---

A pre-PR executable flow for contributing to an open-source GitHub project. The goal: land a clean PR that respects the maintainer's conventions and never leaks anything private.

## Step 1: Verify availability (BEFORE doing any work)
- Read the issue. Check it is NOT already assigned or claimed: scan comments for "I'll take this", an assignee, or an open PR referencing it.
- If someone is already on it, STOP and pick another -- do not duplicate effort.
- Confirm the issue is still relevant (not closed-as-wontfix, not superseded).

## Step 2: Read the project's own conventions
- Read `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and any `.github/` PR template in the target repo.
- Read the project's CI config (`.github/workflows/`) to learn EXACTLY how they lint/test/build. Each repo has unique conventions -- match theirs, do not impose your own.
- Check for a CLA (Contributor License Agreement) requirement and sign it if needed before submitting.

## Step 3: Implement
- Fork (if not already) + branch with a descriptive name matching the project's convention.
- Implement the fix/feature following the project's existing patterns (read neighboring code first -- match their style, not your own).
- Add/adjust tests per the project's test conventions.

## Step 4: Pre-PR triple-check (the OSS gate -- all three before push)
1. **CI conventions pass locally**: run the project's exact lint + test + build commands (from Step 2). Green locally before pushing.
2. **Leak grep**: grep the diff for anything that should not be public -- your organization's confidential terms (client names, internal domains, project codenames), machine-local paths (`c:/`, `/Users/<you>`, `~/.claude`), personal names, and AI-assistant attribution. ZERO hits before push -- a public PR thread is permanent.
3. **Triple-check**: pre-action (right issue, right approach), post-commit (diff is exactly intended, no debris), post-PR (CI green on the PR, description clean).

## Step 5: Submit PR
- Push the branch.
- Open the PR via `gh pr create` with a clear, humble description: no self-promotion, no AI-assistant attribution. Write it for an external maintainer with ZERO context about you: no process-narration, no insider jargon, and explain in one line any domain term the maintainer would not know. Reference the issue (`Fixes #N`). Follow the repo's PR template.
- Post-submit: confirm CI passes on the PR; respond to maintainer feedback promptly.

## What this skill does NOT do
- It does not skip the availability check -- duplicating a claimed issue wastes everyone's time.
- It does not leak private context into a public thread (Step 4.2 is a hard gate).
