# Claude Code Blueprint

A battle-tested reference architecture for Claude Code power users. Not a plugin to install — a blueprint to learn from and adapt.

## What This Is

This repository documents a production Claude Code setup built over numerous sessions of real development work. Every agent, skill, hook, and rule exists because a real incident taught us it was needed.

**This is NOT a generic starter kit.** It's a reference architecture showing how a power user configures Claude Code for maximum productivity, with the reasoning behind every decision.

## What's Inside

| Component | Count | Purpose |
|-----------|-------|---------|
| [**Agents**](agents/) | 11 | Specialized subagents with model tiering (opus/sonnet/haiku) |
| [**Skills**](skills/) | 17 | Natural-language-triggered workflows (no slash commands needed) |
| [**Hooks**](hooks/) | 10 | Deterministic lifecycle automation (10 hook events) |
| [**Rules**](rules/) | 4 | Path-scoped behavioral constraints |
| [**Memory System**](memory-template/) | Dual | Auto-memory + external git-backed persistence |
| [**CLAUDE.md**](CLAUDE.md) | Template | Battle-tested behavioral rules |
| [**Settings**](examples/settings-template.json) | Template | Full hook + permission configuration |

## Philosophy

1. **Hooks for enforcement, CLAUDE.md for guidance** — Hooks fire 100% of the time. CLAUDE.md instructions are followed ~80%. If something MUST happen, make it a hook.

2. **Agent-scoped knowledge, not global bloat** — Design principles live in the frontend agent, not in every session's context. Security patterns live in the security-reviewer, not in CLAUDE.md.

3. **Context is currency** — Every token loaded into context is a token not available for your code. Keep MEMORY.md under 100 lines. Extract to topic files. Use path-scoped rules so irrelevant rules don't load.

4. **Battle-tested over theoretical** — Every rule in this repo exists because something went wrong without it. The "WHY" matters more than the "WHAT".

## Getting Started

### Option A: Fork (recommended)
Fork this repo to customize it as your own living reference. You can pull upstream updates later as the blueprint evolves.

### Option B: Clone + Copy
Clone the repo, then selectively copy components into your `~/.claude/` directory.

### Option C: Cherry-pick
Browse the repo on GitHub and copy only the specific files you need. No installation required.

### Recommended adoption path

1. **Start with [CLAUDE.md](CLAUDE.md)** — the behavioral rules template. Biggest impact with zero setup.
2. **Add 2-3 hooks** — [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh). Copy to `~/.claude/hooks/` and wire into [`settings.json`](examples/settings-template.json).
3. **Read [WHY.md](WHY.md)** to understand the reasoning — adapt, don't blindly copy.
4. **Add agents** as your workflow matures — start with `verify-plan` and `code-reviewer`.
5. **Set up the [memory system](memory-template/)** when you need cross-session persistence.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system design, component relationships, and hook lifecycle diagram.

## Battle Stories

See [WHY.md](WHY.md) for the incidents and lessons behind every component. This is the most valuable file in the repo — it explains *why* each piece exists.

## Using with Other AI Coding Tools

While this blueprint is built for Claude Code, the **concepts are universal**. See [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) for a mapping of how each concept translates to Cursor, Codex CLI, Gemini CLI, and Windsurf.

## Plugin Compatibility

This blueprint is designed as a **standalone configuration** — no plugins required. In fact, plugins can interfere with a custom setup:

### Known issues
- **Plugins that modify CLAUDE.md** may overwrite your custom behavioral rules
- **Plugins that add hooks** on the same events (e.g., Stop, PreToolUse) will stack with your hooks — this can cause slowdowns or conflicting instructions
- **Plugins that inject context** consume tokens from your context window, leaving less room for your agents and memory system
- **MCP server plugins** work well alongside this setup — they add tools, not rules, so there's no conflict

### Recommendation
If you adopt this blueprint, audit your installed plugins and disable any that:
1. Override CLAUDE.md or settings.json hooks
2. Inject prompts on SessionStart (conflicts with your session-lifecycle rule)
3. Add broad permissions that bypass your permission restrictions

Custom setup > generic plugins, because your setup encodes YOUR project's domain knowledge. A plugin can't know your architecture, your team's conventions, or your production constraints.

## License

MIT
