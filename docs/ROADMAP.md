# Roadmap

This project evolves based on real-world usage and community feedback. If you want to influence the direction, open a [Discussion](https://github.com/faizkhairi/claude-code-blueprint/discussions/categories/ideas) or submit a PR.

The Claude Code Blueprint is a reference architecture for configuring Claude Code itself. It is intentionally framework-agnostic and tool-agnostic. Roadmap items must serve adoption, understanding, or community engagement around that mission. Items that contradict it (framework recipes, scaffolders, build tooling) are explicitly out of scope — see "Not Planned" below.

---

## Completed

- **FAQ.md** -- 9 community questions answered (framework support, skill levels, plans, tools)
- **setup.sh** -- Interactive installer with 4 presets (minimal/standard/core/full)
- **SETUP.md** -- Action-focused setup guide with checklist and verification commands
- **Beginner accessibility** -- Persona table above the fold, Level 1/2/3 progression, "Got This Link from a Colleague?" flow
- **Framework-agnostic signaling** -- Hero subtitle, comparison table, GitHub topics and description updated
- **Cross-tool guide** -- 10 other tools mapped (Copilot, Cursor, Cline, Roo Code, OpenCode, Codex CLI, Gemini CLI, Amazon Q, Windsurf, Aider)
- **Hook smoke tests** -- 43 automated tests in `hooks/test-hooks.sh` (run locally)
- **3 localized READMEs** -- Japanese, Korean, Simplified Chinese landing pages (English root + 3 translations = 4 README files total)
- **Built-in opt-in memory** -- Setup.sh prompts to enable persistent session memory; no external repo required
- **AGENTS.md** -- AI-assistant orientation file at repo root
- **Advisory CI** -- a link check (lychee) on Markdown and an installer matrix (`tests/install-matrix.sh`) run on push/PR. These are advisory checks that catch broken links and install regressions early; they do not gate merges or imply a "broken build," in keeping with this being a reference-config repo rather than a build target.

## In Progress

_Nothing currently in progress. Open a Discussion if you want to drive a specific direction._

## Planned

Items we intend to build. No timeline -- contributions welcome.

- **Discussion templates** -- Q&A and Show & Tell category templates (in flight as part of this cleanup)
- **Community case studies** -- Anonymized before/after metrics and workflow improvements from real adopters. Submission template lives at [CASE-STUDIES.md](CASE-STUDIES.md); no case studies yet — be the first
- **FUNDING.yml** -- GitHub Sponsors button config (file shipped; actual Sponsors enrollment is a manual GitHub UI process)
- **Additional Claude Code product-feature integration** -- As new Claude Code features ship (new hooks, agent capabilities, settings), document and integrate them through the same understand-then-adapt lens

## Community Wishlist

Have an idea? Post it in [Discussions > Ideas](https://github.com/faizkhairi/claude-code-blueprint/discussions/categories/ideas).

We review ideas regularly and promote popular ones to Planned.

## Not Planned

Things we've considered and explicitly decided against:

- **Framework-specific CLAUDE.md recipes** -- Blueprint is Claude Code's *harness*, not a project starter. Framework-specific rules belong in your own fork's CLAUDE.md. Even ones we previously shipped (Python/React/Go/Rails) were removed because they contradicted the mission. If you want a stack-specific template, fork and add your own.
- **CLI scaffolder (`create-claude-blueprint` etc.)** -- Defeats the "understand and adapt each component" principle. An installer that hides the choices removes the educational value.
- **Video walkthrough on YouTube** -- The existing `assets/walkthrough.gif` is sufficient for a docs-first GitHub repo. Production-quality video adds maintenance burden without proportional value.
- **SVG / Mermaid architecture diagrams** -- ASCII art in [ARCHITECTURE.md](ARCHITECTURE.md) is intentional. Renders everywhere, needs no tooling, copy-pastes into any editor, survives GitHub re-renders.
- **npm package** -- This is a reference architecture, not a library. Installing it via npm would defeat the purpose of understanding and adapting each component. The `setup.sh` script handles automated installation.
- **Localized deep-dive docs** -- The 3 README translations serve as landing pages. Deep-dive docs (GETTING-STARTED, SETTINGS-GUIDE, AGENTS.md, etc.) remain English-only. Developers who need those docs can read English. If community translators volunteer per the [i18n issues](https://github.com/faizkhairi/claude-code-blueprint/issues?q=label%3Ai18n), we'll reconsider.
- **Plugin marketplace** -- Plugins that inject context or modify CLAUDE.md conflict with the blueprint's design philosophy. MCP server plugins are fine and documented.

---

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to submit changes. The most impactful contributions right now:

1. **Battle stories** -- Real incidents that led to a configuration decision (submit via the [battle story template](https://github.com/faizkhairi/claude-code-blueprint/issues/new?template=battle_story.md))
2. **Cross-tool mappings** -- How blueprint concepts translate to AI coding tools beyond the 10 currently documented in [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md)
3. **Skill description improvements** -- See [issue #4](https://github.com/faizkhairi/claude-code-blueprint/issues/4) — add capability statements and dynamic detection to existing skills
4. **i18n polish** -- Native-speaker review of [Japanese](https://github.com/faizkhairi/claude-code-blueprint/issues/6), [Korean](https://github.com/faizkhairi/claude-code-blueprint/issues/7), or [Chinese](https://github.com/faizkhairi/claude-code-blueprint/issues/8) translations
5. **Case studies** -- Submit your before/after experience via [CASE-STUDIES.md](CASE-STUDIES.md)
