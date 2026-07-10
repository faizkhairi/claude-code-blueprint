---
name: pr-review
description: "Review and post feedback on a GitHub or Gitea pull request end-to-end: fetch the PR diff, run a multi-agent code review, and auto-post the verdict as a real PR review (approve/request-changes/comment) via the platform's API. Triggers on: 'review this PR', 'review PR #N', 'check this pull request', 'post a PR review', 'do a PR review on <url>'. For local uncommitted changes or a branch diff with no open PR, use review-full instead."
user-invocable: true
argument-hint: "[PR number, PR URL, or empty to detect from the current branch]"
---

This posts a REAL review to GitHub or Gitea (comments, and an approve/request-changes/comment verdict). It fetches a pull request's diff, runs the same multi-agent analysis as `review-full`, applies any project-specific review rules, then submits the review via the platform's API. For reviewing local diffs that aren't an open PR, use `review-full` or `review-diff` instead.

## Step 0: Resolve the PR and detect the platform

- Determine the target PR from `$ARGUMENTS` (a number or URL). If empty, detect the PR for the current branch.
- Detect the git host from `git remote get-url origin`:
  - `github.com` -> **GitHub**. Use the `gh` CLI (assume it is already authenticated).
  - Anything else (self-hosted Gitea/Forgejo/Gogs, e.g. a company git server) -> **Gitea-style REST API** via `curl`.
- For Gitea, locate this project's own credentials rather than asking every time:
  - Check whether the project's `CLAUDE.md` `@import`s a credentials file (commonly `rules/credentials.md`; this mirrors the pattern used in the reference project `nas-pr-review`).
  - If none is found, ask the user for the base URL and a `username:token`, and offer to save them into a **new, gitignored** file (e.g. `rules/credentials.md`). Never write real secrets into a tracked file, an `.example` template, or any file already committed to git.

## Step 1: Load PR context

- Fetch PR metadata (title, author, base/head branch, mergeable state, description) and the unified diff:
  - GitHub: `gh pr view <N> --json title,author,baseRefName,headRefName,mergeable,body`, `gh pr diff <N>`
  - Gitea: `GET /repos/{owner}/{repo}/pulls/{n}` and `GET /repos/{owner}/{repo}/pulls/{n}.diff`
- Count `diff --git` headers in the diff and record the file count (checked again in Step 5).
- **Determine reviewer identity.** Compare the authenticated account against the PR author:
  - GitHub: `gh api user --jq .login`
  - Gitea: the username from the credentials file
  - Record whether this is a **self-review** (author == reviewer). Both platforms reject `APPROVE`/`REQUEST_CHANGES` on your own PR, so a self-review always posts as `COMMENT`.
- **Check for a prior review** from this reviewer account (`gh api repos/{o}/{r}/pulls/{n}/reviews`, or the Gitea equivalent):
  - No prior review -> first-pass review.
  - Prior review exists -> list commits and check for any commit after that review's `submitted_at`.
    - New commits -> re-review mode: only findings still present in the new diff are valid; call out previously-flagged items now fixed.
    - No new commits -> stop and report "No new commits since my last review — nothing to re-review." Do not re-run the full checklist.

## Step 2: Load project-specific review rules (if any)

- Read the target project's `CLAUDE.md`. If it `@import`s rule files (naming conventions, architecture patterns, framework-specific rules, etc.), read those too and apply them in Step 4 alongside the generic checks.
- If the project defines a cross-module impact table (e.g. "field X renamed -> grep the other repo for consumers"), run it: for each matching pattern in the diff, grep the referenced codebase paths, read every hit, and record any broken consumer as a finding.
- If the project has no documented review rules, proceed with the generic checks only. Do not invent stack-specific rules that aren't written down anywhere.

## Step 3: Determine PR scope

Look at the diff's file paths to scope which rules apply (e.g. frontend-only, backend-only, or mixed changes) and skip rules tagged for the side the PR doesn't touch.

## Step 4: Multi-agent analysis

Follow the `review-full` skill's Steps 1-6 (spawn `code-reviewer`, `security-reviewer`, `db-analyst`, and `architecture-reviewer` as applicable) using the fetched PR diff as the change set, plus any project-specific rules loaded in Step 2. Produce the standard findings table:

```
| # | Severity | File:Line | Finding | Recommendation |
```

## Step 5: Mandatory self-verification (before posting — do not skip)

1. **Grep verification.** For every project-specific "must fix"-style rule with a greppable pattern, re-run the grep against the diff and confirm every match is either included as a finding or explicitly justified as not a violation.
2. **Rule/agent coverage line.** State which agents ran and which project rules were checked, e.g. "checked code-reviewer, security-reviewer, rules A1-A2, G1-G8 — N rules/checks in scope, M findings raised."
3. **Sanity check.** If the diff touches 5+ files and zero findings were raised, write one sentence justifying why (e.g. "pure rename refactor", "config-only change"). Zero findings on a large diff is suspicious and must be justified, not assumed clean.
4. **File coverage check.** Confirm the number of files examined equals the `diff --git` count recorded in Step 1.

## Step 6: Build the review payload and pick the verdict

| Reviewer vs. author | Findings | `event` |
|---|---|---|
| Self-review (author == reviewer) | Any | `COMMENT` (always — platform rejects APPROVE/REQUEST_CHANGES on your own PR) |
| Reviewer != author | Any CRITICAL/HIGH | `REQUEST_CHANGES` |
| Reviewer != author | Only MEDIUM/LOW | `COMMENT` ("LGTM with notes") |
| Reviewer != author | None | `APPROVE` |

If a POST with `event: APPROVE` or `REQUEST_CHANGES` fails with 403/422 (some Gitea instances permission-block certain accounts from approving), retry the same payload with `event: COMMENT` and say so explicitly in the summary — do not silently swallow the failure.

**Review body** (top-level summary, opens every review body):

```
<severity emoji + count summary, e.g. "CRITICAL 2, HIGH 3, MEDIUM 1">

<DO NOT MERGE -- N blocking item(s), only if any CRITICAL/HIGH present>

Blocking:
1. path/to/file.ts:47 -- <short description>
...

See inline comments for full detail per finding.
```

**Inline comment format** (one per finding that has a specific line):

```
<emoji> [SEVERITY] <Module/symbol> -- <what is wrong>. <Concrete suggested fix>.
```

Severity emoji: CRITICAL, HIGH, MEDIUM, LOW map to plain-language tags in the body; use these emoji inline: ❌ CRITICAL, ⚠️ HIGH, 🔍 MEDIUM ("verify"), 💡 LOW ("minor"), ✅ OK (previously-flagged issue now fixed), ℹ️ NOTE (informational, non-blocking).

**Positioning:** a finding on a line in the new file goes in `comments` with that line number; a finding only on a deleted line uses the old-file line number instead; a PR-level finding with no specific line is omitted from `comments` and goes in `body` only.

## Step 7: Post the review

- **GitHub**: `gh api repos/{owner}/{repo}/pulls/{n}/reviews -X POST --input payload.json` with body `{"body": "...", "event": "...", "comments": [{"path": "...", "line": N, "body": "..."}]}`.
- **Gitea**: `curl -u "${AUTH}" -X POST -H "Content-Type: application/json" -d @payload.json "${BASE_URL}/api/v1/repos/{owner}/{repo}/pulls/{n}/reviews"` with the same payload shape, except inline comments use `new_position`/`old_position` instead of `line`.
- Before posting, re-check for existing reviews from this account against the current head commit, to avoid double-posting if this workflow already ran for the same commit.

## Step 8: Verify

1. Confirm the response contains a valid review `id`. A missing/null `id` means the POST failed silently — read the error body and report the real failure, do not report success.
2. Confirm file coverage matches the count recorded in Step 1.
3. Re-read each cited finding's lines to confirm the finding text still matches the actual code before declaring the review posted.
4. Never say "review posted" without having confirmed a valid `id`.

## Review discipline

- Finish the current PR before moving to the next one flagged in conversation.
- Pre-existing issues outside the PR's own diff get an ℹ️ NOTE, not a blocking finding, unless the PR's changes directly break them.
- If the PR description claims something was tested and the change is non-trivial, look for evidence (screenshots, test output, added tests). If none is provided, flag with 🔍 SHOULD VERIFY.
- Read the full diff before forming any finding — never post a review based on a partial read.
