# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-05-25 (late late night)

### Audit bundle: memory/ docs reframe + cross-tool currency + community-standards verification

**Verified**
- **GitHub Community Standards: 100% health.** `gh api repos/faizkhairi/claude-code-blueprint/community/profile` returned `health_percentage: 100`. CODE_OF_CONDUCT.md, SECURITY.md, CONTRIBUTING.md, .github/PULL_REQUEST_TEMPLATE.md, and 3 issue templates (battle_story, bug_report, feature_request) all in place and current. Repo description, license (MIT), homepage, and 15 well-chosen topics (`agents`, `ai-coding`, `claude`, `claude-code`, `codex`, `cursor`, `developer-tools`, `gemini-cli`, `hooks`, `mcp`, `productivity`, `reference-architecture`, `windsurf`, `beginner-friendly`, `framework-agnostic`) all confirmed.
- **Cross-tool currency claims WebFetch-verified** before applying any edit. Sources: TechCrunch (Windsurf-OpenAI deal status, 2025-07-11), AWS DevOps Blog (Amazon Q end-of-support, 2026-04-30), GitHub Changelog (Copilot Memory default-on, 2026-03-04). Each verified claim is now cited in the file's footer.

**Fixed (memory/README.md surgical fixes for 3 HIGH audit findings)**
- **HIGH-1 (opening framing)**: Reframed from pre-Path-A "Git-Backed Persistent Memory" + "external memory system" + "Fork this template, or create a new private repo" to "Built-in Opt-in Persistent Memory" + "enabled via `./setup.sh` -- no separate repo required". Brings memory/README.md in line with GETTING-STARTED.md and AGENTS.md framing.
- **HIGH-2 (setup instructions duplicated setup.sh)**: Rewrote Setup section to lead with "The easy way: `./setup.sh`" (single Y/n prompt handles everything). Moved the path-scoped-rule and skills-wiring instructions to a labelled "Advanced: manual setup (skip if you used `setup.sh`)" subsection. Added an "Optional: cross-machine sync" section for users who want a separate private memory repo.
- **HIGH-3 (.gitignore guidance contradicted actual file)**: Removed the "Recommended .gitignore" section that listed IDE/OS artifacts (`.DS_Store`, `.vscode/`, `.tmp`, etc.). The shipped `memory/.gitignore` covers only personal content (`core/session.md`, `core/preferences.md`, `core/reminders.md`, `core/identity.md`, `diary/`, `projects/active/`). Replaced with a 2-line clarification: machine-level patterns belong at project-root or global `.gitignore`, not in memory's.

**Fixed (docs/CROSS-TOOL-GUIDE.md currency: 2 CRITICAL + 1 HIGH, all WebFetch-verified)**
- **CRITICAL: Windsurf ownership status (factual error).** Was "Note: Windsurf was acquired by OpenAI in 2025." Now reflects the verified reality: OpenAI's $3B acquisition (announced May 2025) fell through in July 2025; Google then hired Windsurf's CEO and key researchers via a ~$2.4B license deal (no ownership stake). Windsurf operates independently.
- **CRITICAL: Amazon Q Developer sunset callout.** Added a prominent blockquote callout right after the main capability table: Amazon Q Developer IDE plugins reach end-of-support April 30, 2027; new signups have been blocked since May 15, 2026; AWS is transitioning to Kiro. Visitors comparing tools today would otherwise have evaluated Amazon Q without knowing they can't actually sign up.
- **HIGH: Copilot Memory status updated** from "public preview" generic to "Public preview, enabled by default for Copilot Pro and Pro+ users as of March 2026" (per GitHub's official Changelog).
- **HIGH-4 (Cursor v3): DROPPED.** The doc never mentioned any specific Cursor version, so there was no factual error to fix. Adding a v3 mention would be new content, not a fix. Skipped per honest-scope principle.
- **Verification footer** added at the bottom: "Last verified: 2026-05-25" + citation list + invitation to open a PR or Discussion if anything is stale. Makes future rot-audits easier and sets reader expectations.

**Did NOT**
- Restructure memory/README.md (surgical edits only per scope; existing structure preserved).
- Apply unverified cross-tool claims. The audit's Cursor v3 finding was dropped because the doc never claimed any Cursor version.
- Add new community-standards files (all already present, health already 100%; no edits expected per plan).
- Modify CHANGELOG history.

**Personal memory state (NOT in this repo; written to `~/.claude/projects/c--Repo/memory/`)**:
- New: `project_claude_code_blueprint.md` (identity, Not-Planned boundaries, conventions, community surfaces)
- New: `project_blueprint_memory_path_a.md` (Path A migration details, skill paths, Kiyoraka attribution)
- New: `feedback_subagent_audit_verification.md` (parallel-grep pattern for subagent audit false negatives)
- Updated: `MEMORY.md` index with 3 new entries (now 204 lines — pre-existing condition flagged for a future memory-curator pass; the over-limit lines are external-reference index entries which are read-on-demand anyway).

## 2026-05-25 (late night)

### Post-cleanup health pass

**Verified**
- All 35 hook smoke tests pass via `bash hooks/test-hooks.sh`. Since CI was removed earlier today, this manual run is the only safety net for hook regressions. Result: 35 PASS / 0 FAIL / 0 SKIP.
- AGENTS.md content quality + WHY.md architectural freshness audit returned GREEN (Explore subagent). Counts accurate (11 agents / 17 skills / 10 hooks / 5 rules), mission-aligned, no rot.
- Adjacent files (setup.sh, TROUBLESHOOTING.md, CONTRIBUTING.md) audit returned CLEAN. No broken references to deleted files from the earlier cleanup pass.

**Fixed**
- `skills/README.md`: removed vestigial `./memory` row from the placeholder-variables table. The row showed stale `~/memory-core` example paths from before the Path A migration, and conceptually `./memory/` is the built-in folder, not a substitutable placeholder. Added a clarifying note that skills referencing `./memory/` use the built-in folder directly (no replacement needed). Updated the grep-for-unreplaced-variables command to only check `{NAME}`-style placeholders.
- `skills/init-project/SKILL.md`: line 8 instruction "Replace `{PROJECTS_ROOT}`, `{BOILERPLATE_NAME}`, and `./memory` with your actual paths" updated to drop the `./memory` substitution (it's the built-in folder, not a placeholder).
- `README.md` hero (first-impression audit MED finding): rewrote to lead with value-prop before description. Was "A library of ready-to-copy files... to make Claude Code more reliable." Now "Prevent the most common AI coding mistakes — a library of ready-to-copy files..." The "library of files" identity is preserved; the value-prop just front-loads.
- `README.md` safety warning (first-impression audit MED finding): softened wording while keeping the above-Quick-Start position. Was "**Before you start:** This is a reference repo, not a project template. Do **not** run Claude Code inside this repository..." Now "**Heads up before you copy:** This is a reference repo, not a project template — you'll copy files OUT of it into your own project. Don't run Claude Code inside this repository..." Same protection against the #1 newcomer mistake (running Claude in the blueprint repo), warmer entry tone.

**Added (GitHub state, not repo state)**
- Seeded Discussions tab with 3 starter posts authored under the maintainer account: [#9 Welcome](https://github.com/faizkhairi/claude-code-blueprint/discussions/9) (Announcements), [#10 sample Q&A](https://github.com/faizkhairi/claude-code-blueprint/discussions/10) (Q&A category, pre-answered to demonstrate the "marked as answer" pattern), [#11 sample Show & Tell](https://github.com/faizkhairi/claude-code-blueprint/discussions/11). Helps visitors see the templates we shipped working end-to-end and avoids the "empty Discussions tab signals abandoned project" impression.

**Drafted (delivered for user to apply via UI — Sponsors profile content)**
- GitHub Sponsors profile (github.com/sponsors/faizkhairi) is active but has default placeholder content: shortDescription and fullDescription are both the GitHub-generated default "Support faizkhairi's open source work", and **0 tiers are configured** (critical gap — visitors clicking the Sponsor button have no actual way to support). Drafted replacement content for shortDescription (3 options), fullDescription (markdown), 3 recommended monthly tiers + 1 optional one-time tier, optional activeGoal, and featured-items pinning guidance. User applies via the Sponsors dashboard UI (profile editing is UI-only; not API-doable).

**Did NOT**
- Apply the LOW-severity README findings from the audit (stat-line context, comparison-table tone) — both flagged as optional / "no change required" by the audit itself.
- Modify the Sponsors profile content directly (API can only read; editing is UI-only).
- Touch CHANGELOG history.

## 2026-05-25 (night)

### Mission realignment + doc audit + community-engagement scaffold

**Removed (mission realignment toward framework-agnostic Claude Harness)**
- Deleted `examples/claude-md-{python,react,go,rails}.md` — framework-specific CLAUDE.md templates contradicted the "configures Claude Code, not your stack" identity. `examples/settings-template.json` is kept since it's framework-agnostic.
- Deleted `.github/workflows/ci.yml` — CI for hook tests + link checks is misaligned with a reference-config repo. Hook tests still work locally via `bash hooks/test-hooks.sh` (35 automated tests).
- Removed `docs/PRESETS.md` "Stack Rule Templates" section — same reason. PRESETS.md continues to cover solo/team/CI-CD adoption presets (how much of the blueprint to use, not what framework).
- ROADMAP.md rewritten: cleared "In Progress", trimmed "Planned", added explicit "Not Planned" entries for framework recipes, CLI scaffolder, GitHub Actions CI, video walkthrough, SVG/Mermaid diagrams — each with rationale anchoring back to the "Claude Harness" identity.
- README.md Deep Dives table: replaced `[Examples](examples/)` row with `[Case Studies](docs/CASE-STUDIES.md)`.
- AGENTS.md `examples/` row description updated to reflect what's left (`settings.json` template only).
- FAQ.md: removed line linking to `PRESETS.md#stack-rule-templates` (target section deleted).

**Fixed (stale references the polish-pass missed because it only checked i18n)**
- `memory-template/` → `memory/` across: README.md, GETTING-STARTED.md (3 refs), docs/CROSS-TOOL-GUIDE.md (4 refs), docs/ARCHITECTURE.md (ASCII art), docs/PRESETS.md (2 refs).
- `memorycore-session` → `memory-session` in README.md Rules table and rules/README.md.
- `**/memory-core/**` glob → `**/memory/**` in rules/memory-session.md frontmatter (the rule was scoped to a path that no longer exists — it wasn't actually firing).
- README.md Deep Dives cross-tool count: clarified "and 5 more (10 tools total)" to remove ambiguity.
- docs/README.md (deep-dives index): added Case Studies entry, fixed cross-tool count.
- 3 i18n READMEs: Deep Dives Examples cell → Case Studies cell.

**Added (community engagement)**
- `.github/FUNDING.yml` — GitHub Sponsors button config (`github: faizkhairi`). Honest disclosure: this file enables the Sponsor link on the repo, but the button lands on "X isn't accepting sponsorships yet" until the user completes the manual GitHub Sponsors enrollment at github.com/sponsors/accounts (tax/identity verification — cannot be done via API).
- `.github/DISCUSSION_TEMPLATE/q-and-a.yml` + `show-and-tell.yml` — structured templates for the 2 discussion categories. Native GitHub format.
- `docs/CASE-STUDIES.md` — adopter-stories landing page with submission template. Honest framing: "no case studies yet — be the first." We don't fabricate case studies, and we don't list ourselves as the canonical example.

**Did NOT**
- Touch CHANGELOG history (entries referencing the removed items stay; they're a true record of what was built/decided).
- Modify the i18n Acknowledgements Kiyoraka credit (preserved verbatim).
- Convert ASCII diagrams to SVG/Mermaid (ASCII is intentional).
- Enroll user in GitHub Sponsors (manual UI step required separately at github.com/sponsors/accounts).

## 2026-05-25 (late evening)

### Editorial polish pass on ja/ko/zh translations + PR #5 merge

**Polished**
- All 3 translated READMEs (`i18n/README.ja.md`, `README.ko.md`, `README.zh.md`) given an editor-pass to fix mechanical defects an editor (not native speaker) can catch.
- **Section headers normalized to English across all 3 translations.** zh's previously-translated headers (`## 快速开始`, `## 哲学`, `## 致谢`, etc.) reverted to English. ja/ko headers were already English. Reason: avoids in-file anchor-link breakage; all 3 translations now reference the same English-derived anchor slugs as the source (`#recommended-adoption-path`, `#who-is-this-for`) — cross-translation anchor parity achieved.
- **Calques and forced English-as-transliteration fixed.** ja: `セーフティ優先` → `安全性優先`, `ビルトイン opt-in` → `組み込みのオプトイン式`, `グローバルブロート` → `グローバルな肥大化`. ko: `Safety-first:` → `안전 우선:`, `내장 opt-in` → `내장 옵트인`, awkward `전역 복잡성 아니오` → `전역적 비대화가 아닌`. zh: minor brevity polish `你将其混合到自己的项目中` → `你可以混入自己的项目`.
- **Hero block rhythm refinement** in ja and ko — restructured to put the noun phrase (library) first and the benefit second, matching the English rhythm. zh hero already read naturally; light touch only.
- **Terminology rule applied with judgment, not blanket replacement.** Product-term references in tables and headers (e.g., `スキル` table header → `Skill`) switched to English. General-Japanese/Korean phrasings like `スキルレベル` (skill level, user's general skill) and `ルール` in non-product contexts kept as-is. Same rule applied across all 3 languages.
- **Punctuation normalized** to `--` for emphasis dashes (matches English source). Em-dash (`—`) count in all 3 translations is now 0.
- **Sub-agent** kept in English (was `サブエージェント` in ja and `서브 에이전트` in ko) for terminology consistency with `agent`.

**Honest disclosure** — this is editor-pass quality, NOT native-speaker authorship. I am not a native ja/ko/zh speaker. Community issues #6/#7/#8 remain open as lower-priority — native-speaker PRs still very welcome.

**Translation style policy logged as ADR** in personal memory (decisions.md, AI-MemoryCore commit `443070e`).

**Merged**
- [PR #5](https://github.com/faizkhairi/claude-code-blueprint/pull/5) (@liziyuan10): expanded `skills/review/SKILL.md` description with output-shape metadata (GO/NO-GO + severity-grouped findings). Author corrected `MODERATE` → `MEDIUM` per review feedback to stay consistent with the skill body's severity ladder. Squash-merged as `4949a05`.

**Issue housekeeping**
- Issues #6/#7/#8 body trimmed: removed redundant attribution-requirement reminder line (contributors already understand not to remove credit).

## 2026-05-25 (evening)

### i18n Translation Sync (ja/ko/zh → parity with restructured English README)

**Synced**
- All 3 translation READMEs (`i18n/README.ja.md`, `README.ko.md`, `README.zh.md`) updated to match the restructured English README from the same-day afternoon entry.
- New hero framing translated: "library of ready-to-copy files (CLAUDE.md, hooks, agents)" wording in all 3 languages, replacing the older aspirational "smarter / safer / more consistent" tagline.
- "Before You Start" safety warning moved ABOVE Quick Start in all 3 (was a sub-section after Quick Start). Wording rewritten as a blockquote matching the English version. Stale `{MEMORYCORE_PATH}` / `{PROJECTS_ROOT}` placeholder mention removed (placeholders no longer exist).
- `memory-template/` → `memory/` references updated across What's Inside table and adoption-path step. Adoption-path memory step rewritten to reflect Path A opt-in framing ("answer Y during `./setup.sh`").
- `memorycore-session` rule filename → `memory-session` in What's Inside Rules table; glob `**/memory-core/**` → `**/memory/**`; description updated to "memory repository session management".
- Memory System row description updated: "dual: auto memory + external git-based persistence" → "built-in opt-in: Claude remembers preferences and session context across runs (git-ignored for privacy)".
- AGENTS.md cross-reference added to all 3 translations (links to `../AGENTS.md`), placed in the safety-warning blockquote so AI assistants reading translated entry points find it immediately.
- Acknowledgements wording adjusted from "minimal scaffold" / "lightweight scaffold" → "lean built-in version"; clarified that this blueprint now ships built-in opt-in memory in `memory/`. Kiyoraka credit + Project-AI-MemoryCore link preserved verbatim.
- Language-switcher English link corrected from `README.md` → `../README.md` (translations now live in `i18n/`).

**Parity verification**
- All 3 translations have identical `##` section count (16, matching English).
- Zero stale references (`memory-template`, `memorycore-session`, `MEMORYCORE_PATH`) remain in any translation.
- Safety warning at line 25 / Quick Start at line 31 across all 3 (structural parity preserved).

**Honest disclosure**: translations were produced by mirroring established patterns in the existing high-quality translation content + careful word choice against the new English source. They are functionally accurate but may not match native-speaker quality. Opening 3 community issues (one per language) inviting native speakers to polish wording via PRs (labels: `good first issue`, `documentation`, `help wanted`, `i18n`).

**Not translated yet** (deferred to community contribution): AGENTS.md, docs/README.md, GETTING-STARTED.md additions ("How Memory Works" section). These are larger separate efforts.

## 2026-05-25 (afternoon)

### Structural Optimization for Newcomers and AI Assistants + Built-in Memory (Path A)

**Restructured**
- Moved 8 deep-reference docs to `docs/` (ARCHITECTURE, BENCHMARKS, CROSS-TOOL-GUIDE, PRESETS, ROADMAP, SELF-MONITORING, SETTINGS-GUIDE, WHY)
- Moved 3 translation READMEs to `i18n/` (ja, ko, zh). English README stays at root.
- Root markdown file count: 21 → 11 (added AGENTS.md to root; net cleanup is significant)
- New `docs/README.md` index explains the docs folder
- Updated 60 cross-references across 9 files to point to new paths

**Rewritten**
- README hero: concrete framing ("library of ready-to-copy files") replaces aspirational tagline. Explicitly names what the repo IS and how to use it in the first 3 lines.
- "Before You Start" safety warning moved ABOVE Quick Start (was below). Prevents the #1 newcomer mistake of running Claude Code inside the blueprint repo.

**Added**
- `AGENTS.md` at root (67 lines) — AI-assistant orientation file. Gives downstream users' AI tools (Claude, Cursor, Codex, Gemini) a fast accurate read on what this repo is and how to help the user.
- New `## How Memory Works` section in `GETTING-STARTED.md` — explains the built-in memory system, privacy guard, opt-in flow, optional sync, and Kiyoraka inspiration credit.
- `memory/.gitignore` — privacy guard preventing accidental fork-publication of personal memory content (session.md, reminders.md, diary/, projects/).

**Memory: now a built-in feature, no external repo needed (Path A)**
- Folder `memory-template/` renamed to `memory/` — this is now the WORKING memory location, ready to use.
- `setup.sh` adds hybrid prompt: "Enable persistent memory? [Y/n]" (default Y). When enabled, Claude remembers preferences, decisions, and session context across sessions on this machine.
- `{MEMORYCORE_PATH}` placeholder eliminated entirely — skills use relative `./memory/` paths now.
- Privacy: personal content `.gitignore`d by default. Optional cross-machine sync documented for advanced users.
- Operational `MemoryCore` references → `memory` across 16 files. Kiyoraka credit in all 4 README acknowledgements **preserved verbatim** — rename is operational-only, not attributional.
- File `rules/memorycore-session.md` → `rules/memory-session.md`.
- Skills (`load-session`, `save-session`, `save-diary`, `session-end`) now fail gracefully with a clear "memory persistence is disabled" message when user opts out at setup.

**Tone audit**
- Replaced "auto-memory" → "session memory" / "what Claude remembers" in user-facing docs (Anthropic uses "auto-memory" internally; "session memory" is clearer for newcomers).
- Other technical terms (hook, skill, agent) kept since they're load-bearing Claude Code concepts.

**Why this matters**: claude-code-blueprint is now a true one-stop tool. Fork the repo, run `./setup.sh`, choose Y on memory, and Claude has persistent session memory immediately — no external repository to create, no path placeholders to fill, no second tool to learn. A non-powerful AI model that a downstream user prompts about this repo can answer accurately from the first 67 lines of AGENTS.md alone. For humans, the root browser is no longer overwhelming, and memory is honestly described as a real built-in feature.

## 2026-05-25

### Maintenance & Community Updates

**Updated**
- **Version badges**: Claude Code 2.1.91 → 2.1.150 across all 4 README translations (en, ja, ko, zh)

**Added**
- **SELF-MONITORING.md**: Lean introduction to two community-applicable patterns — gitleaks pre-commit secret scanning + memory-curator agent template for setup drift detection. Linked from README Deep Dives.
- New issue (community-pickable): skill description capability-statement improvements (extracted from a vendor-attached PR; the underlying observations are sound even though the PR itself was a promo).

**Community**
- Closed issue #3 (harixth): redirected to upstream Claude Code repo (Stop hook UX labeling is an upstream concern, not a blueprint code change). Filed upstream with credit. Invited harixth to contribute a CLAUDE.md template for his stack.
- Closed PR #2 (yogesh-tessl): vendor-attached benchmark + bundled Tessl-specific GitHub Action conflicts with the cross-tool philosophy. Technical observations extracted into a community issue for organic contribution.

**Audit**
- Meta-commentary scan: no chat-residue or private-workflow leaks found in public docs.

## 2026-04-04

### Added
- **FAQ.md**: New file answering top 9 community questions -- framework agnosticism, skill levels, subscription plans, tool compatibility, colleague quickstart, "I'm overwhelmed" guidance, AI-vs-learning, cost/tokens
- **README.md**: "Who Is This For?" persona table moved above the fold (from line 173 to ~line 47) with new "Time to Value" column and Level 1/2/3 skill progression
- **README.md**: Mini-FAQ section (4 one-line answers linking to FAQ.md)
- **README.md**: Deep Dives grid expanded from 2x3 to 3x3 (added FAQ, Getting Started, Troubleshooting)
- **GETTING-STARTED.md**: "Got This Link from a Colleague?" quickstart flow in beginner section
- **GETTING-STARTED.md**: FAQ.md link at end of beginner section and in "What to Learn Next" list
- **setup.sh**: Interactive installer script with 3 presets (minimal/standard/full), cross-platform OS detection, safe file copying with conflict resolution and diff preview, settings.json merge via Python, placeholder variable replacement, post-install verification
- **SETUP.md**: Focused action-only setup guide covering automated (setup.sh), AI-assisted (prompt), and manual (checklist) setup methods with verification commands
- **README.md**: Setup automation block in Quick Start (setup.sh + condensed "let Claude do it" prompt) and Option D in Getting Started
- **FAQ.md**: setup.sh shortcut added to "A colleague sent me this link" section
- **GETTING-STARTED.md**: Cross-links to SETUP.md and setup.sh in "Let Claude Code Set Up for You" and "5-Minute Setup" sections
- **README.ja.md, README.ko.md, README.zh.md**: Setup automation block and Option D mirrored with translations
- **ROADMAP.md**: Project direction with Completed/In Progress/Planned/Not Planned sections and contribution guidance
- **examples/claude-md-python.md**: Complete copy-ready CLAUDE.md with Python/FastAPI/Django/SQLAlchemy stack rules
- **examples/claude-md-react.md**: Complete copy-ready CLAUDE.md with React/Next.js/TypeScript/Tailwind/Zod stack rules
- **examples/claude-md-go.md**: Complete copy-ready CLAUDE.md with Go/Gin/GORM/golangci-lint stack rules
- **examples/claude-md-rails.md**: Complete copy-ready CLAUDE.md with Rails/RSpec/Rubocop/Sidekiq stack rules
- **examples/README.md**: Index of all example files with copy commands and usage guide
- **.github/workflows/ci.yml**: GitHub Actions CI with hook smoke tests, markdown link checker (lychee), and markdown linting (markdownlint-cli2)
- **README.md**: Deep Dives grid expanded to 4x3 (added Setup Guide, Examples, Roadmap row)
- **README.ja.md, README.ko.md, README.zh.md**: Deep Dives grid expansion mirrored

### Changed
- **README.md**: Hero subtitle rewritten to lead with benefits ("Make Claude Code smarter, safer, and more consistent -- for any project, at any skill level")
- **README.md**: "What Makes This Different" table gains framework-agnostic row
- **README.md**: Standalone Troubleshooting section absorbed into Deep Dives grid
- **README.ja.md, README.ko.md, README.zh.md**: All structural changes mirrored with translations
- **README.zh.md**: Hero subtitle rewritten to remove "advanced users" framing (was "为 Claude Code 高级用户设计")
- GitHub repo description updated: removed "power users", added "framework-agnostic" and "beginner-friendly"
- GitHub topics: added `beginner-friendly`, `framework-agnostic`

## 2026-04-03

### Added
- **CROSS-TOOL-GUIDE.md**: Cursor coverage expansion -- hooks.json example, `permissions.json`, `.cursorignore`, CLI/IDE hook disparity, "Cursor in depth" section
- **hooks/README.md + ARCHITECTURE.md**: `PermissionDenied` and `TaskCreated` hook events (available but not used in blueprint)
- **SETTINGS-GUIDE.md**: `disableSkillShellExecution` setting, `showThinkingSummaries` setting (default off since v2.1.89), `CLAUDE_CODE_NO_FLICKER` env var, `PermissionDenied` hook note under auto mode
- **GETTING-STARTED.md**: `/powerup` interactive tutorial mention for beginners
- **agents/README.md**: Named subagent pattern (`name` parameter for `@` mention and `SendMessage` addressability)

### Changed
- Version badge updated from 2.1.85 to 2.1.91
- Cursor hooks reframed from "partial subset" to "different surfaces" (11 hook types listed by name)
- Removed unconfirmed `.cursor/agents/*.md` claims from CROSS-TOOL-GUIDE.md (feature not shipped)

### Fixed
- Added `permissions.json` alongside `cli-config.json` at all Cursor references in CROSS-TOOL-GUIDE.md

## 2026-03-28

### Fixed
- **Hook safety**: Python fallback in `block-git-push.sh`, JSON injection in `post-commit-review.sh`/`precompact-state.sh`/`cost-tracker.sh`, shell injection in `session-start.sh`/`verify-mcp-sync.sh`, error handling in `session-checkpoint.sh`
- **Factual accuracy**: Permission modes table was missing `code-reviewer` and `security-reviewer` (across 4 files), `CONTRIBUTING.md` had wrong model IDs and non-existent "Notification" event, lifecycle event count was 12 (should be 10), `git push` allow-list claim was wrong
- **Playwright MCP**: Package name corrected from `@anthropic-ai/mcp-playwright` to `@playwright/mcp`
- **Agent inconsistencies**: Removed `Bash` from `db-analyst`/`devops-engineer` tools (contradicts `permissionMode: plan`), removed `skills: [review]` from `security-reviewer` (recursion risk)
- **Cost tracker**: Added 10MB size cap to prevent unbounded JSONL growth
- **Python version**: Hooks now require Python 3.6+ (f-strings used), was incorrectly claiming 2.7+

### Added
- **Agent hardening**: "When project context is missing" graceful degradation in all 11 agents
- **agents/README.md**: maxTurns table, cost estimates, hallucination warnings, instruction compliance explanation
- **Configuration placement**: "Where Config Belongs" section in GETTING-STARTED.md with project-vs-personal table and cross-platform paths for 7 AI tools
- **Safer setup prompt**: Explicitly directs to `~/.claude/`, not project directory
- **Placeholder variables**: All 6 documented in skills/README.md with grep check command
- **Privacy notice**: Bold warning + `.gitignore` template + "What NOT to Store" in memory-template/README.md
- **Troubleshooting**: 7 new sections (MEMORYCORE_PATH, agent permissions, maxTurns, config placement, Windows hooks, shell compatibility, git history)
- **Safety callouts**: "Before You Start" in README.md + all 3 localized READMEs (ja/ko/zh), secrets warning in CLAUDE.md
- `.gitattributes` enforcing LF line endings for `.sh` files
- `hooks/test-hooks.sh` smoke test script (35 tests: syntax, Python detection, empty/malformed/missing-field input)

### Changed
- Version badge updated from 2.1.83 to 2.1.85
- All hooks now use unified Python detection with "not found" stderr warning
- All hooks construct JSON via Python `json.dumps()` (no shell string interpolation)
- Pricing URLs standardized to `docs.anthropic.com`
- Removed version-pinned feature attributions ("new in 2.1.83")

## 2026-03-26

### Added
- Token cost per component breakdown with verified file measurements in [BENCHMARKS.md](docs/BENCHMARKS.md#token-cost-per-component)
- Subscription plan recommendations, upgrade guide, and Pro user's blueprint journey in [BENCHMARKS.md](docs/BENCHMARKS.md#subscription-plans--the-blueprint)
- API billing cost analysis with per-session overhead calculations in BENCHMARKS.md
- "Will This Affect My Token Usage?" FAQ in [GETTING-STARTED.md](GETTING-STARTED.md#will-this-affect-my-token-usage) beginner section
- Token cost philosophy point (#4: "Hooks are free, context is cheap") in README.md
- Complete beginner onboarding section in [GETTING-STARTED.md](GETTING-STARTED.md#new-to-claude-code-start-here) (model recommendations, 1-minute setup, `~/.claude/` explained, self-setup prompt)
- "Complete beginner" row in README.md adoption table
- ADR template ([memory-template/templates/adr-template.md](memory-template/templates/adr-template.md)) for structured architectural decision records
- Category-based stack rule templates in [PRESETS.md](docs/PRESETS.md#stack-rule-templates) (Backend API, Full-Stack App, Database + ORM)
- Skill customization guide in [skills/README.md](skills/README.md#extending-skills-for-your-stack) with 4 extension examples
- Stack rules placeholder section in [CLAUDE.md](CLAUDE.md) template for project-specific framework rules
- ADR template and stack rule templates references in [GETTING-STARTED.md](GETTING-STARTED.md#what-to-learn-next)

### Fixed
- Python interpreter portability across 6 hook scripts (now auto-detects `python3` or `python`)
- Token substitution guidance added to [init-project](skills/init-project/SKILL.md) skill and [session-lifecycle](rules/session-lifecycle.md) rule
- Testing rule template now framework-agnostic (was Vitest/Vue-specific)

### Previously added
- Auto permission mode documentation with comparison table of all 4 modes ([SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md#defaultmode))
- `autoMode.environment` configuration guide for classifier context
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` environment variable documentation
- `managed-settings.d/` team policy drop-in directory documentation
- `sandbox.failIfUnavailable` setting documentation
- `CwdChanged` and `FileChanged` hook events to [hooks/README.md](hooks/README.md)
- Playwright CLI vs MCP token cost comparison (76% savings) to cost section
- Auto mode classifier troubleshooting to [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Deprecated colon wildcard syntax warning (`Bash(npm:*)` to `Bash(npm *)`)
- Version badge: "Last verified with Claude Code 2.1.83"
- Starter presets guide ([PRESETS.md](docs/PRESETS.md)) with 4 adoption tiers
- Benchmarks template ([BENCHMARKS.md](docs/BENCHMARKS.md)) with token, cost, and quality metrics
- Model routing decision guide in [ARCHITECTURE.md](docs/ARCHITECTURE.md#when-to-use-each-model)
- Japanese, Korean, and Chinese README translations
- Community battle story issue template

### Changed
- Permission Modes table expanded from 2 to 3 rows (added `"auto"`)
- `defaultMode` section rewritten to cover all 4 modes
- Settings template updated with `autoMode` section and `ENV_SCRUB`
- Removed deprecated `Skill(update-config:*)` colon syntax from template

## 2026-03-25

### Added
- [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md): every environment variable, setting, and permission explained with rationale
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): 16 common issues across 7 categories (hooks, agents, MCP, rules, settings, cost, Windows)
- [GETTING-STARTED.md](GETTING-STARTED.md): prerequisites, Windows notes, team onboarding, permission modes
- [README.md](README.md): "Who is this for?" scaling table with 5 adoption personas
- [rules/README.md](rules/README.md) for directory discoverability
- Social preview card (1280x640) for GitHub link sharing
- [SECURITY.md](SECURITY.md) for GitHub community standards compliance

### Changed
- README.md: added Settings + Troubleshooting section links
- ARCHITECTURE.md: cross-reference to SETTINGS-GUIDE.md

## 2026-03-24

### Added
- Initial public release
- 11 specialized agents with model tiering (Opus/Sonnet/Haiku)
- 17 natural-language-triggered skills
- 10 hook scripts covering 10 lifecycle events
- 5 path-scoped behavioral rules
- Memory system template (AI-MemoryCore compatible)
- Complete [settings-template.json](examples/settings-template.json) with categorized permissions
- [CLAUDE.md](CLAUDE.md) behavioral rules template
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) with component relationship and agent ecosystem diagrams
- [WHY.md](docs/WHY.md) with 13 battle stories explaining the reasoning behind every component
- [CROSS-TOOL-GUIDE.md](docs/CROSS-TOOL-GUIDE.md) mapping patterns to Cursor, Codex CLI, Gemini CLI, Windsurf
- [GETTING-STARTED.md](GETTING-STARTED.md) beginner walkthrough (30-minute onboarding)
- [CONTRIBUTING.md](CONTRIBUTING.md) with PR guidelines, NDA requirements, and file naming conventions
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) (Contributor Covenant)
- GitHub issue templates (battle story, bug report, feature request)
- PR template with NDA compliance checklist
