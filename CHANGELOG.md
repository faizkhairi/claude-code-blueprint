# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
- Token cost per component breakdown with verified file measurements in [BENCHMARKS.md](BENCHMARKS.md#token-cost-per-component)
- Subscription plan recommendations, upgrade guide, and Pro user's blueprint journey in [BENCHMARKS.md](BENCHMARKS.md#subscription-plans--the-blueprint)
- API billing cost analysis with per-session overhead calculations in BENCHMARKS.md
- "Will This Affect My Token Usage?" FAQ in [GETTING-STARTED.md](GETTING-STARTED.md#will-this-affect-my-token-usage) beginner section
- Token cost philosophy point (#4: "Hooks are free, context is cheap") in README.md
- Complete beginner onboarding section in [GETTING-STARTED.md](GETTING-STARTED.md#new-to-claude-code-start-here) (model recommendations, 1-minute setup, `~/.claude/` explained, self-setup prompt)
- "Complete beginner" row in README.md adoption table
- ADR template ([memory-template/templates/adr-template.md](memory-template/templates/adr-template.md)) for structured architectural decision records
- Category-based stack rule templates in [PRESETS.md](PRESETS.md#stack-rule-templates) (Backend API, Full-Stack App, Database + ORM)
- Skill customization guide in [skills/README.md](skills/README.md#extending-skills-for-your-stack) with 4 extension examples
- Stack rules placeholder section in [CLAUDE.md](CLAUDE.md) template for project-specific framework rules
- ADR template and stack rule templates references in [GETTING-STARTED.md](GETTING-STARTED.md#what-to-learn-next)

### Fixed
- Python interpreter portability across 6 hook scripts (now auto-detects `python3` or `python`)
- Token substitution guidance added to [init-project](skills/init-project/SKILL.md) skill and [session-lifecycle](rules/session-lifecycle.md) rule
- Testing rule template now framework-agnostic (was Vitest/Vue-specific)

### Previously added
- Auto permission mode documentation with comparison table of all 4 modes ([SETTINGS-GUIDE.md](SETTINGS-GUIDE.md#defaultmode))
- `autoMode.environment` configuration guide for classifier context
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` environment variable documentation
- `managed-settings.d/` team policy drop-in directory documentation
- `sandbox.failIfUnavailable` setting documentation
- `CwdChanged` and `FileChanged` hook events to [hooks/README.md](hooks/README.md)
- Playwright CLI vs MCP token cost comparison (76% savings) to cost section
- Auto mode classifier troubleshooting to [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Deprecated colon wildcard syntax warning (`Bash(npm:*)` to `Bash(npm *)`)
- Version badge: "Last verified with Claude Code 2.1.83"
- Starter presets guide ([PRESETS.md](PRESETS.md)) with 4 adoption tiers
- Benchmarks template ([BENCHMARKS.md](BENCHMARKS.md)) with token, cost, and quality metrics
- Model routing decision guide in [ARCHITECTURE.md](ARCHITECTURE.md#when-to-use-each-model)
- Japanese, Korean, and Chinese README translations
- Community battle story issue template

### Changed
- Permission Modes table expanded from 2 to 3 rows (added `"auto"`)
- `defaultMode` section rewritten to cover all 4 modes
- Settings template updated with `autoMode` section and `ENV_SCRUB`
- Removed deprecated `Skill(update-config:*)` colon syntax from template

## 2026-03-25

### Added
- [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md): every environment variable, setting, and permission explained with rationale
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
- [ARCHITECTURE.md](ARCHITECTURE.md) with component relationship and agent ecosystem diagrams
- [WHY.md](WHY.md) with 13 battle stories explaining the reasoning behind every component
- [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) mapping patterns to Cursor, Codex CLI, Gemini CLI, Windsurf
- [GETTING-STARTED.md](GETTING-STARTED.md) beginner walkthrough (30-minute onboarding)
- [CONTRIBUTING.md](CONTRIBUTING.md) with PR guidelines, NDA requirements, and file naming conventions
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) (Contributor Covenant)
- GitHub issue templates (battle story, bug report, feature request)
- PR template with NDA compliance checklist
