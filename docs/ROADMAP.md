# Roadmap

This project evolves based on real-world usage and community feedback. If you want to influence the direction, open a [Discussion](https://github.com/faizkhairi/claude-code-blueprint/discussions/categories/ideas) or submit a PR.

---

## Completed

- **FAQ.md** -- 9 community questions answered (framework support, skill levels, plans, tools)
- **setup.sh** -- Interactive installer with 3 presets (minimal/standard/full)
- **SETUP.md** -- Action-focused setup guide with checklist and verification commands
- **Beginner accessibility** -- Persona table above the fold, Level 1/2/3 progression, "Got This Link from a Colleague?" flow
- **Framework-agnostic signaling** -- Hero subtitle, comparison table, GitHub topics and description updated
- **Cross-tool guide** -- Cursor (in depth), Codex CLI, Gemini CLI, Windsurf concept mapping
- **Hook smoke tests** -- 35 automated tests in `hooks/test-hooks.sh`
- **4 localized READMEs** -- Japanese, Korean, Simplified Chinese (structural translations)

## In Progress

- **Framework-specific CLAUDE.md examples** -- Copy-ready templates for Python, React, Go, Rails in `examples/`
- **GitHub Actions CI** -- Hook tests + link checker on every PR

## Planned

Items we intend to build. No timeline -- contributions welcome.

- **Video walkthrough** -- Upload `assets/walkthrough.mp4` to YouTube with search-optimized title and description. Embed in README and GETTING-STARTED.md
- **CLI scaffolder** -- `create-claude-blueprint` (separate repo). Interactive TypeScript CLI that walks users through setup without requiring a fork
- **Architecture diagrams** -- SVG or Mermaid visual of hook lifecycle, agent ecosystem, and component relationships. Replace ASCII art in ARCHITECTURE.md
- **FUNDING.yml** -- GitHub Sponsors configuration
- **Discussion templates** -- Structured templates for Q&A and Show & Tell categories
- **Community case studies** -- Anonymized before/after metrics and workflow improvements from real users

## Community Wishlist

Have an idea? Post it in [Discussions > Ideas](https://github.com/faizkhairi/claude-code-blueprint/discussions/categories/ideas).

We review ideas regularly and promote popular ones to Planned.

## Not Planned

Things we've considered and decided against (for now):

- **npm package** -- This is a reference architecture, not a library. Installing it via npm would defeat the purpose of understanding and adapting each component. The `setup.sh` script handles automated installation.
- **Localized deep-dive docs** -- The 4 README translations serve as landing pages. Deep-dive docs (GETTING-STARTED, SETTINGS-GUIDE, etc.) remain English-only. Developers who need those docs can read English. If community translators volunteer, we'll reconsider.
- **Plugin marketplace** -- Plugins that inject context or modify CLAUDE.md conflict with the blueprint's design philosophy. MCP server plugins are fine and documented.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to submit changes. The most impactful contributions right now:

1. **Battle stories** -- Real incidents that led to a configuration decision (submit via the [battle story template](https://github.com/faizkhairi/claude-code-blueprint/issues/new?template=battle_story.md))
2. **Framework examples** -- CLAUDE.md stack rules for frameworks not yet covered
3. **Cross-tool mappings** -- How blueprint concepts translate to tools beyond the 5 currently documented
