# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-03-26

### Added
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
