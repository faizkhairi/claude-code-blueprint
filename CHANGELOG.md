# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and the project uses date-based releases.

## [Unreleased]

## [1.2.0] - 2026-09-26

### Added
- `Wiring (new symbol)` row in `CLAUDE.md`'s Verify-After-Complete table: a new symbol must be imported/registered/called and data must flow end to end, not just pass tests.
- Fresh-angle principle folded into `CLAUDE.md` check 7: cross-check any non-trivial conclusion from outside the context that produced it (cold subagent, whole-tree grep, authoritative source, adversarial pass).
- Stop condition on check 7: two passes on the same artifact with no new finding means stop and escalate to the user, not loop indefinitely.
- A skip-excuse clause on each of the four mandatory `CLAUDE.md` rules, naming and rebutting the rationalization most likely to precede skipping it.
- "A prose rule is not a hook" section in `CLAUDE.md`: if a check must never be skipped and a script can decide it, make it a hook.
- `self-audit` skill (19 total), installed by `full`: runs the `verify-plan` checklist against your own plan before ExitPlanMode.
- `memory-curator` agent (12 total), installed by `full`: audits a memory directory against its index whole-tree and writes a dated health report.
- Three hooks (15 total, from 12), each wired in `examples/settings-template.json`: `protect-claude-settings.sh`, `verify-subagent-findings.sh`, `no-dash-check.sh`.
- `hooks/check-no-dash-file.py`: a manual sanitizer for prose posted to external systems from a shell command, closing the shell-to-network path the Write/Edit hooks can't reach.
- "Scoping a hook to specific projects" section in `hooks/README.md`.
- `tests/count-check.sh` guard and CI job: derives every published component count from the filesystem and asserts each copy agrees.
- Eight further `count-check.sh` bindings covering per-preset file totals (4/10/20/55) in `setup.sh` and the walkthrough deck cards.
- `tests/required-checks.sh` guard and advisory `required-checks` CI job: compares workflow job ids against the branch ruleset's required status checks.
- A fourth `required-checks.sh` section: asserts `docs/ROADMAP.md`'s CI bullet matches the enforcement actually in effect.
- "Why this rule exists" intent preamble on the five path-scoped rule files.
- Advisory `shellcheck` CI job (in Install Test), linting `hooks/*.sh`, `setup.sh`, and `tests/*.sh` on every push and pull request.

### Changed
- `CONTRIBUTING.md` now documents the automated checks: `tests/count-check.sh`, a "Component Counts" section, and the commands to run before opening a PR.
- Link-check CI now runs lychee with `--include-fragments`, validating `#anchor` targets against real headings.
- `post-commit-review.sh` now explains WHY auth/guard/middleware/schema/env files are higher-risk, not just that they are.

### Fixed
- Corrected the CI description in `docs/ROADMAP.md`, which still said checks "do not gate merges" after four had become required status checks.
- Removed the last 15 em-dashes from six tracked files (`docs/SELF-MONITORING.md` and five skills).
- Repaired the sanitization gate in `.github/PULL_REQUEST_TEMPLATE.md`, which scanned the whole repo instead of only the PR's changed files.
- Corrected the preset menu in `setup.sh` ("11 agents, 18 skills" to the actual 12 and 19).
- Updated the visual assets (overview/social cards, architecture card, walkthrough deck) to current component counts.
- Corrected the "43 automated tests" figure to 55 in `README.md`, `docs/ROADMAP.md`, and the three translated READMEs.
- Corrected seven stale component counts across the documentation and translations that the earlier count sweep's pattern could not match.

## [1.1.0] - 2026-07-11

### Added

- A `hook-tests` CI job (in the Install Test workflow) that runs `hooks/test-hooks.sh` on every pull request, so a hook that fails the smoke suite (syntax, or mishandling empty / malformed / missing-field stdin) now blocks merge instead of only being checked when a contributor remembers to run it locally.
- `pr-review` skill: fetches a GitHub or Gitea pull request's diff, runs the same multi-agent analysis as `review-full` plus any project-specific rules the target repo documents, then posts the verdict (approve/request-changes/comment) as a real PR review via the platform's API, with reviewer-identity-aware self-review handling and a mandatory self-verification pass before posting.
- An "When to Use an Agent vs a Skill vs the Main Thread" decision framework in `agents/README.md`, teaching when to reach for each, the "wire it, don't just define it" rule, and how to right-size an agent roster for your own stack. Cross-linked from the architecture diagram and the getting-started glossary. [PR #37]
- `testing-general` rule: framework-agnostic testing conventions (discover-don't-assume, Arrange/Act/Assert, deterministic tests) that complement the stack-specific testing.md. [PR #29]
- `pre-commit-secret-scan.sh` hook, which runs gitleaks on staged content before `git commit` and blocks the commit if a secret is detected (fails open if gitleaks is not installed). [PR #28]
- `instructions-loaded.sh` hook, which logs which CLAUDE.md and rules files load into context and why, making path-scoped rule injection observable. [PR #28]
- `architecture-reviewer` agent, providing structural review (dependency direction, circular deps, god files, dead code, modularity) that complements the line-level code-reviewer. [PR #28]
- `core` install preset: a curated middle tier between `standard` and `full`, adding two review agents (security-reviewer, qa-tester), six broadly-useful skills (review-full, review-diff, test-check, deploy-check, db-check, changelog), and two path-scoped rules (testing, database-schema). [PR #14]
- A token-budget table in the README showing the context cost of each component and when it loads, so you can decide what to copy on a per-token basis. [PR #13]
- A CI link check (lychee) that verifies every Markdown link on each push and pull request. [PR #13]

### Changed

- CLAUDE.md now installs globally to `~/.claude/CLAUDE.md` by default instead of a per-project root copy, so its four behavioral rules apply to every project on your machine. The `setup.sh` installer prompts for the global path and backs up any existing `~/.claude/CLAUDE.md` before writing. The quick-start, SETUP, GETTING-STARTED, FAQ, AGENTS, and cross-tool docs were updated to match; a project-level `CLAUDE.md` remains documented as an optional team-shared, repo-committed convention.
- Made the agent roster framework-agnostic: the "check package.json" convention is now "check the project manifest" across every agent, and database-review guidance no longer hardcodes Prisma (ORM-specific behavior is now shown as examples, with the ORM list covering Eloquent, ActiveRecord, Hibernate/JPA, EF Core, SQLAlchemy, Django ORM, and GORM). [PR #37]
- The `review-full` skill now wires the `architecture-reviewer` agent, spawning up to four review agents by what changed; the architecture diagram was rewritten to mark which agent flows are actually wired versus illustrative. [PR #37]
- The `full` install preset now installs all 12 hooks; it previously omitted `instructions-loaded.sh` and `pre-commit-secret-scan.sh`. [PR #37]
- Consolidated the README calls-to-action into one clear path and fixed remaining "three rules" stragglers so the on-ramp is unambiguous. [PR #34]
- Reworked the on-ramp into a single linear flow (README CTA plus a hands-on-first GETTING-STARTED) so new readers have one obvious starting point. [PR #33]
- Re-encoded the hero walkthrough GIF about 23% smaller (5.6 MB to 4.3 MB) with no visible quality loss; same dimensions and runtime. [PR #15]
- Right-sized the compliance wording: the unmeasured "~80%" figure is replaced with honest qualitative phrasing, while the accurate "hooks fire deterministically" property is kept. [PR #13]
- The two example-only rule files (`api-endpoints`, `testing`) now carry a clear "replace with your own conventions" banner so adopters know they reflect one project's patterns. [PR #13]

### Fixed

- Removed `isolation: worktree` from the four read-only review agents (`verify-plan`, `code-reviewer`, `security-reviewer`, `architecture-reviewer`). Worktree isolation requires a git repository at the workspace root, so these agents failed with "Cannot create agent worktree" for anyone whose Claude Code root is a non-git parent directory (for example, one folder holding several project repos). Because the agents are read-only (`Read`, `Grep`, `Glob`) under `permissionMode: plan`, the isolation guarded against writes they can never make; the unbiased "cold" review they provide comes from each subagent's fresh context window, not from a fresh checkout. The agents now run at any workspace root with no loss of review quality. `agents/README.md` and `docs/WHY.md` were updated to describe worktree isolation as a tool for write-capable agents only.
- Corrected a second identity name, heading casing, and completed gaps in the three translations. [PR #32]
- Fixed consistency drift across component counts, pricing figures, tables, and the translated READMEs so every surface agrees. [PR #31]
- Memory `session.md` and `reminders.md` are no longer tracked by git despite being described as "git-ignored for privacy"; they now ship as `.example` templates that `setup.sh` seeds locally on install. [PR #12]
- Renamed two skills that shadowed built-in slash commands: `review` to `review-full`, and `init-project` to `scaffold-project`. [PR #12]
- Repaired broken relative links across the docs and the three translated READMEs. [PR #12, PR #13]
- Corrected a dead `WHY.md` reference in the installer and the issue template (now `docs/WHY.md`). [PR #12]

### Removed

- Consolidated the `api-documenter` agent into `docs-writer` (which already covered API docs and OpenAPI), bringing the roster from 12 agents to 11. [PR #37]
- Dropped the `release`, `oss-contribute`, and `npm-publish` skills, which were out of scope for a Claude Code configuration reference (they target package publishing and OSS contribution workflows, not harness setup). [PR #30]

## [1.0.0] - 2026-03-25

Initial public release.

### Added

- 11 specialized agents with model tiering (opus / sonnet / haiku) and permission modes.
- 17 natural-language-triggered skills covering code review, testing, deployment, session management, and more.
- 10 lifecycle hooks for deterministic automation across the session lifecycle.
- 5 path-scoped behavioral rules (API endpoints, database schema, testing, session lifecycle, memory).
- A CLAUDE.md template with four behavioral rules: Verify-After-Complete, Diagnose-First, Plan-First, and Verify-Before-Exit-Plan.
- A built-in opt-in memory system template and a full settings template.
- A `setup.sh` installer with minimal, standard, and full presets, cross-platform OS detection, and safe file copying.
- A beginner guide, cross-tool guide, FAQ, troubleshooting guide, and four framework-specific CLAUDE.md examples.
- Battle-story documentation (`docs/WHY.md`) explaining the reasoning behind each component.

[Unreleased]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/faizkhairi/claude-code-blueprint/releases/tag/v1.0.0
