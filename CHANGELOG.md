# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and the project uses date-based releases.

## [Unreleased]

### Added
- A `Wiring (new symbol)` row in the `CLAUDE.md` Verify-After-Complete table, and a pointer to it from the `Code / feature` and `API / server route` rows. Green tests prove the code works, not that anything reaches it, and a route can answer curl while being registered only in a test harness. The row verifies goal-backward (the symbol exists, is not a stub, something imports/registers/calls it, data flows end to end) and treats zero call sites as dead code. Extends the `agents/README.md` rule "an agent you never invoke is dead weight" from agents to code.
- A fresh-angle principle folded into `CLAUDE.md` check 7, generalizing it from "review the plan" to "cross-check any non-trivial conclusion from outside the context that produced it", with four concrete angles (cold subagent, whole-tree grep, authoritative source, adversarial pass) and the rule that self-assessments and subagent summaries are hypotheses to verify. Folded into the existing check rather than added as a fifth behavioral rule, so the "four rules" count published across the docs and translations stays accurate.
- A stop condition on check 7, so doubt-driven verification cannot become an unbounded loop: counted per artifact, two passes with no new substantive finding means stop and escalate to the user. Explicitly cannot cancel a mandatory first check, and a high-stakes two-pass stop escalates rather than self-clears.
- A *skip-excuse* clause on each of the four mandatory rules, naming the rationalization most likely to precede skipping that rule and rebutting it in the same line, so the excuse arrives pre-answered.
- An "A prose rule is not a hook" section in `CLAUDE.md`, contrasting probabilistic prose guidance with deterministic hook enforcement and stating the promotion rule: if a check must never be skipped and a script can decide it, make it a hook. Writing "ALWAYS" in bold is not enforcement.

- A `self-audit` skill (bringing the total to 19), installed by the `full` preset. It runs the `verify-plan` checklist against your own plan before ExitPlanMode, so the same checks that would review someone else's plan now review yours, with extra weight on the consumer audit (grep both the repo and your own global config for every shared value the plan changes). It turns a passive plan-verification rule into an active gate at the decision point. Has a `docs/WHY.md` entry.
- A `memory-curator` agent (bringing the roster to 12), installed by the `full` preset. It audits a memory directory against its index file whole-tree: orphans, phantom references, section-count drift, broken wiki-links, stale entries, and near-duplicates, then writes a dated health report. Report-only (its one Write is the report), with a conservative compaction-safety analysis that never recommends dropping the sole pointer to a note. Has a `docs/WHY.md` entry.
- Three hooks bringing the total to 15 (from 12), each installed by the `full` preset and wired in `examples/settings-template.json`: `protect-claude-settings.sh` (a `PreToolUse` guard that confirms edits to safety keys in your own `settings.json`, and flags added allow rules for paths inside `.claude`, which have no effect because protected-path writes bypass `permissions.allow` entirely; a sibling to `protect-config.sh`); `verify-subagent-findings.sh` (a `PostToolUse` hook on the Agent/Task tool that reminds Claude to treat a subagent's findings as hypotheses to verify, not facts to act on); and `no-dash-check.sh` (a warn-only `PostToolUse` style gate, shipped configured for em-dashes as a worked example of a deterministic prose-consistency nudge). All three parse JSON with Python to match the existing hooks; each has a `docs/WHY.md` entry.
- A companion tool `hooks/check-no-dash-file.py`: a manual sanitizer gate for prose about to be POSTed to an external system (a PR comment, a webhook) from a shell command, which bypasses the Write/Edit hooks. Paired with `no-dash-check.sh` to close both the editor path and the shell-to-network path. Not counted in the hook total.
- A "Scoping a hook to specific projects" section in `hooks/README.md`, documenting two patterns for running a hook in some projects but not others: a working-directory allowlist inside a shared hook (no-op outside the allowlist), or wiring the hook in a project's own `.claude/settings.json`. Also clarifies when to reach for a path-scoped rule instead of a hook.
- A `tests/count-check.sh` guard and a matching `count-check` CI job, which derive every component total from the filesystem (agent files, skill directories, hook scripts, rule files, `### ` headings in `docs/WHY.md`, hook keys in the settings template, `model:` frontmatter) and assert that each published copy agrees. Stale counts have now been fixed four separate times in this release cycle alone (the assets, `setup.sh`, the test total, and the seven below), so the class is being closed mechanically rather than by another manual sweep. Adding a thirteenth agent fails seventeen bindings across thirteen files, naming each one, which is the checklist a contributor previously had to reconstruct by hand in four languages. Implemented as a registry of explicit `(file, anchor, expected)` bindings rather than a prose sweep: the sweep was built first and measured, and it produced seven false positives (per-preset deltas like "Add 4 hooks + 2 agents", adoption rows, and card markup where the digit and its label sit in separate divs) while missing four real bugs that no `<digit> <noun>` pattern can reach ("11 reusable agent templates", a bare "**11**", and the CJK counter forms). Bindings are per-line, not per-file, because a file is not a trust boundary: `i18n/README.ko.md` states our agent count on one line and Project-AI-MemoryCore's feature-extension count in the same counter form on another. A missing anchor is reported distinctly from a stale value, so a reworded document fails loudly instead of silently checking nothing.
- A "Why this rule exists" intent preamble at the top of the five path-scoped rule files (`api-endpoints`, `database-schema`, `memory-session`, `testing-general`, `testing`), so the reasoning travels with the file when it is copied out of the repo, instead of living only in `docs/WHY.md`. Matches the existing design-rationale note in `session-lifecycle.md`.

### Changed
- The link-check CI now runs lychee with `--include-fragments`, so `#anchor` targets are validated against real headings, not just that the target file exists. This catches broken heading-slug links that the previous config could not detect.
- The post-commit review hook (`post-commit-review.sh`) now explains WHY auth/guard/middleware/schema/env files are higher-risk (a bug there changes access control, request handling, or data shape, so its blast radius is wider than an ordinary file) instead of only flagging them as high-risk.

### Fixed
- Removed the last 15 em-dashes from six tracked files (`docs/SELF-MONITORING.md`, and the `elicit-requirements`, `save-diary`, `save-session`, `session-end`, and `tech-radar` skills), in a repo that advertises being dash-free and ships a hook to enforce it. All were inside output-format templates rather than prose, so the substitutes were chosen to keep the generated headings readable, and the diary-title and decisions-heading formats (each defined in two skills) were changed identically so the skills cannot disagree about the format they produce. The one remaining occurrence, in `hooks/check-no-dash-file.py`, is the pattern definition itself.
- Repaired the sanitization gate in `.github/PULL_REQUEST_TEMPLATE.md`, which could never pass. It told contributors that a whole-repo grep for the placeholder strings must return 0 hits, but four tracked files carry those strings deliberately (the template itself, `.lycheeignore`, `docs/SETTINGS-GUIDE.md`, and `hooks/block-git-push.sh`), so every contributor who ran the documented command saw hits and learned to ignore the check. The gate now scans only the files the PR changes and names the intentional occurrences. Two failure modes are closed by construction: `xargs -r` stops an empty file list from falling back to a whole-repo recursive grep, and the template filters itself out, since a file that defines the search patterns would otherwise always match itself.
- Corrected the preset menu in `setup.sh`, which offered "all 11 agents, 18 skills" when the `full` preset installs 12 and 19. Verified against the installer's own arrays rather than against the docs: `STANDARD_AGENTS` (2) plus `FULL_AGENTS` (10) is 12 agents, and skills and rules are enumerated dynamically. This was the last stale component count outside markdown, which is why the earlier count-fix passes did not catch it.
- Updated the visual assets to the current component counts. The overview and social-preview cards, the architecture card footer, and the walkthrough deck (slides 2 and 5) showed stale figures (11 agents / 17 skills / 12 hooks / 16 battle stories / 48-file full preset); their HTML sources were corrected to 12 agents / 19 skills / 15 hooks / 21 battle stories / 55-file full preset, and the `card-*.png` images and `walkthrough.gif` were regenerated to match.
- Corrected the "43 automated tests" figure to 55 in `README.md`, `docs/ROADMAP.md`, and the three translated READMEs, matching the current `hooks/test-hooks.sh` suite after the three new hooks were added.
- Corrected seven stale component counts still shipping in the documentation: `AGENTS.md` described 11 agent templates and 18 skill templates (12 and 19), the "we give you 11" comparison line in `README.md` and all three translated READMEs undersold the roster by one, and `docs/SETTINGS-GUIDE.md` said the template configures hooks across 8 lifecycle events when it wires 9. The four comparison lines are one bug replicated in four languages, which is exactly the failure mode the new count guard exists to catch: a contributor who fixes the English line has three translated copies to remember, in scripts they may not read. These survived the earlier count sweeps because that sweep matched `<digit> <category>` and none of the seven is written that way.

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

[Unreleased]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/faizkhairi/claude-code-blueprint/releases/tag/v1.0.0
