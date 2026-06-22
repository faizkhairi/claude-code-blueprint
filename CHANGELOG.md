# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and the project uses date-based releases.

## [Unreleased]

### Added

- `pre-commit-secret-scan.sh` hook -- runs gitleaks on staged content before `git commit` and blocks the commit if a secret is detected (fails open if gitleaks is not installed). [PR #28]
- `instructions-loaded.sh` hook -- logs which CLAUDE.md and rules files load into context and why, making path-scoped rule injection observable. [PR #28]
- `architecture-reviewer` agent -- structural review (dependency direction, circular deps, god files, dead code, modularity) that complements the line-level code-reviewer. [PR #28]
- `core` install preset -- a curated middle tier between `standard` and `full`, adding two review agents (security-reviewer, qa-tester), six broadly-useful skills (review-full, review-diff, test-check, deploy-check, db-check, changelog), and two path-scoped rules (testing, database-schema). [PR #14]
- A token-budget table in the README showing the context cost of each component and when it loads, so you can decide what to copy on a per-token basis. [PR #13]
- A CI link check (lychee) that verifies every Markdown link on each push and pull request. [PR #13]

### Changed

- Re-encoded the hero walkthrough GIF about 23% smaller (5.6 MB to 4.3 MB) with no visible quality loss; same dimensions and runtime. [PR #15]
- Right-sized the compliance wording: the unmeasured "~80%" figure is replaced with honest qualitative phrasing, while the accurate "hooks fire deterministically" property is kept. [PR #13]
- The two example-only rule files (`api-endpoints`, `testing`) now carry a clear "replace with your own conventions" banner so adopters know they reflect one project's patterns. [PR #13]

### Fixed

- Memory `session.md` and `reminders.md` are no longer tracked by git despite being described as "git-ignored for privacy"; they now ship as `.example` templates that `setup.sh` seeds locally on install. [PR #12]
- Renamed two skills that shadowed built-in slash commands: `review` to `review-full`, and `init-project` to `scaffold-project`. [PR #12]
- Repaired broken relative links across the docs and the three translated READMEs. [PR #12, PR #13]
- Corrected a dead `WHY.md` reference in the installer and the issue template (now `docs/WHY.md`). [PR #12]

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

[Unreleased]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/faizkhairi/claude-code-blueprint/releases/tag/v1.0.0
