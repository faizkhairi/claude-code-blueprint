<div align="center">

# Claude Code Blueprint

**A battle-tested reference architecture for Claude Code. Not a plugin to install -- a blueprint to learn from and adapt.**

[![Stars](https://img.shields.io/github/stars/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/stargazers)
[![Forks](https://img.shields.io/github/forks/faizkhairi/claude-code-blueprint?style=flat)](https://github.com/faizkhairi/claude-code-blueprint/network/members)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.85-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**11 agents** · **17 skills** · **10 hooks** · **5 rules** -- every one battle-tested

[English](README.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [简体中文](README.zh.md)

<img src="assets/walkthrough.gif" alt="Claude Code Blueprint Walkthrough" width="680">

</div>

---

## Quick Start

Copy one file. Get three behavioral rules. Done in 60 seconds.

```bash
# In your project root
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

This gives Claude Code three rules that prevent the most common AI coding mistakes:

**Verify-After-Complete** · **Diagnose-First** · **Plan-Before-Execute**

Ready for more? See the [full adoption path](#recommended-adoption-path) or the [30-minute beginner guide](GETTING-STARTED.md).

---

### Before You Start

> **Important:** This is a reference architecture, not a project template. Do **not** run Claude Code inside this repository -- it will read the blueprint's own CLAUDE.md instead of your project's rules. Fork or cherry-pick files into your own project.
>
> Several files contain placeholder variables (`{MEMORYCORE_PATH}`, `{PROJECTS_ROOT}`) that you must replace with your actual paths. Hooks and settings belong in your **user-level** config (`~/.claude/`), not in your project directory. See [GETTING-STARTED.md](GETTING-STARTED.md) for the full setup guide.

---

## What Makes This Different

Other repos give you **135 agents**. We give you **11** -- and explain why each one exists.

| This Blueprint | Generic Config Repos |
|---------------|---------------------|
| Every component has a [battle story](WHY.md) explaining why it exists | Configs without context |
| [3 behavioral rules](CLAUDE.md) that prevent AI coding mistakes | Lists of settings to copy |
| [Cross-tool guide](CROSS-TOOL-GUIDE.md) for Cursor, Codex, Gemini, Windsurf | Single-tool only |
| [Beginner-friendly](GETTING-STARTED.md) with 6 adoption personas | Assumed expertise |
| [Smoke-tested hooks](hooks/test-hooks.sh) with 35 automated tests | Untested scripts |
| Safety-first: [config placement guide](GETTING-STARTED.md#where-config-belongs-project-vs-personal), privacy warnings, [graceful degradation](agents/README.md#agents-are-not-infallible) | No safety guidance |

---

## What's Inside

<details>
<summary><strong>11 Agents</strong> -- Specialized subagents with model tiering (opus/sonnet/haiku)</summary>

&nbsp;

| Agent | Model | Role |
|-------|-------|------|
| project-architect | opus | System design, architecture decisions, technology choices |
| backend-specialist | sonnet | API endpoints, services, database operations, middleware |
| frontend-specialist | sonnet | UI components, state management, forms, styling |
| code-reviewer | sonnet | Code quality, patterns, best practices (read-only) |
| security-reviewer | sonnet | OWASP Top 10, auth flaws, injection attacks (read-only) |
| db-analyst | sonnet | Schema analysis, query optimization, migration planning (read-only) |
| devops-engineer | sonnet | Deployment configs, CI/CD, Docker, infrastructure (read-only) |
| qa-tester | sonnet | Unit tests, integration tests, E2E tests |
| verify-plan | sonnet | 7-point mechanical plan verification (read-only) |
| docs-writer | haiku | README, API docs, changelogs, architecture docs |
| api-documenter | haiku | OpenAPI specs, integration guides (read-only) |

See [agents/README.md](agents/README.md) for permission modes, cost estimates, and maxTurns.

</details>

<details>
<summary><strong>17 Skills</strong> -- Natural-language-triggered workflows (no slash commands needed)</summary>

&nbsp;

| Category | Skills | Triggers |
|----------|--------|----------|
| Code Quality | review, review-diff | "is this secure?", "scan diff", "check for vulnerabilities" |
| Testing | test-check, e2e-check | "run the tests", "browser test", "are tests passing?" |
| Deployment | deploy-check | "deploy", "push to prod", "ready to ship" |
| Planning | sprint-plan, elicit-requirements | "let's build", "new feature", multi-step tasks |
| Session | load-session, save-session, session-end, save-diary | Session start/end, "save", "bye", "done" |
| Project | init-project, register-project, status, changelog | "new project", "status", "changelog" |
| Database | db-check | "check the schema", "validate models" |
| Utilities | tech-radar | "what's new?", "should we upgrade?" |

See [skills/README.md](skills/README.md) for customization and placeholder variable setup.

</details>

<details>
<summary><strong>10 Hooks</strong> -- Deterministic lifecycle automation (100% compliance, unlike ~80% for CLAUDE.md rules)</summary>

&nbsp;

| Event | Hook | Purpose |
|-------|------|---------|
| SessionStart | session-start.sh | Inject workspace context |
| PreToolUse (Bash) | block-git-push.sh | Protect remote repos |
| PreToolUse (Write/Edit) | protect-config.sh | Guard linter/build configs |
| PostToolUse (Write/Edit) | notify-file-changed.sh | Verify reminder |
| PostToolUse (Bash) | post-commit-review.sh | Post-commit review |
| PreCompact | precompact-state.sh | Serialize state to disk |
| Stop | security check + cost-tracker.sh | Last defense + metrics |
| SessionEnd | session-checkpoint.sh | Guaranteed final save |

Plus 2 utility scripts: `verify-mcp-sync.sh` (MCP config checker) and `status-line.sh` (branch/project status).

Run `bash hooks/test-hooks.sh` to verify all hooks pass (35 automated tests).

See [hooks/README.md](hooks/README.md) for the full lifecycle, testing guide, and design principles.

</details>

<details>
<summary><strong>5 Rules</strong> -- Path-scoped behavioral constraints (load only when editing matching files)</summary>

&nbsp;

| Rule | Activates On | Purpose |
|------|-------------|---------|
| api-endpoints | `**/server/api/**/*.{js,ts}` | API route conventions |
| database-schema | `**/prisma/**`, `**/drizzle/**`, `**/migrations/**` | Schema design patterns |
| testing | `**/*.test.*`, `**/*.spec.*` | Test writing conventions |
| session-lifecycle | Always | Session start/end behaviors |
| memorycore-session | `**/memory-core/**` | External memory integration |

See [rules/README.md](rules/README.md) for creating custom rules.

</details>

**Also included:**

| Component | Purpose |
|-----------|---------|
| [**CLAUDE.md**](CLAUDE.md) | Battle-tested behavioral rules template |
| [**Settings Template**](examples/settings-template.json) | Full hook + permission configuration |
| [**Memory System**](memory-template/) | Dual: auto-memory + external git-backed persistence |

---

## Philosophy

1. **Hooks for enforcement, CLAUDE.md for guidance** -- Hooks fire 100% of the time. CLAUDE.md instructions are followed ~80%. If something MUST happen, make it a hook.

2. **Agent-scoped knowledge, not global bloat** -- Design principles live in the frontend agent, not in every session's context. Security patterns live in the security-reviewer, not in CLAUDE.md.

3. **Context is currency** -- Every token loaded into context is a token not available for your code. Keep MEMORY.md under 100 lines. Extract to topic files. Use path-scoped rules so irrelevant rules don't load.

4. **Hooks are free, context is cheap** -- The 10 hook scripts cost zero tokens (they run outside Claude's context). CLAUDE.md adds ~2,300 tokens per session -- roughly 1-5% of a typical session. The blueprint saves more tokens than it costs by preventing redo cycles. See [BENCHMARKS.md](BENCHMARKS.md#token-cost-per-component).

5. **Battle-tested over theoretical** -- Every rule in this repo exists because something went wrong without it. The "WHY" matters more than the "WHAT".

---

## Getting Started

### Who is this for?

| You Are | Start Here | Adopt |
|---------|-----------|-------|
| **Complete beginner** | [Start Here](GETTING-STARTED.md#new-to-claude-code-start-here) | 1-minute setup: just copy CLAUDE.md |
| **Solo dev, small project** | [CLAUDE.md](CLAUDE.md) + 2 hooks | Enough. Don't over-engineer. |
| **Small startup (2-5 devs)** | Above + shared rules + 2-3 agents | See [Team Setup](GETTING-STARTED.md#setting-up-for-teams) |
| **Established team (5+ devs)** | Full blueprint, adapted | Fork, customize, commit shared config |
| **Learning to code** | [GETTING-STARTED.md](GETTING-STARTED.md) only | Ignore agents/skills/memory until comfortable |
| **Coming from another tool** | [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) | Concepts transfer; adapt what you need |

### Option A: Fork (recommended)
Fork this repo to customize it as your own living reference. You can pull upstream updates later as the blueprint evolves.

### Option B: Clone + Copy
Clone the repo, then selectively copy components into your `~/.claude/` directory.

### Option C: Cherry-pick
Browse the repo on GitHub and copy only the specific files you need. No installation required.

### Recommended adoption path

1. **Start with [CLAUDE.md](CLAUDE.md)** -- the behavioral rules template. Biggest impact with zero setup.
2. **Add 2-3 hooks** -- [`protect-config.sh`](hooks/protect-config.sh) + [`notify-file-changed.sh`](hooks/notify-file-changed.sh) + [`cost-tracker.sh`](hooks/cost-tracker.sh). Copy to `~/.claude/hooks/` and wire into [`settings.json`](examples/settings-template.json).
3. **Read [WHY.md](WHY.md)** to understand the reasoning -- adapt, don't blindly copy.
4. **Add agents** as your workflow matures -- start with `verify-plan` and `code-reviewer`.
5. **Set up the [memory system](memory-template/)** when you need cross-session persistence.

---

## Deep Dives

| | | |
|:--|:--|:--|
| **[Architecture](ARCHITECTURE.md)** | **[Settings Guide](SETTINGS-GUIDE.md)** | **[Battle Stories](WHY.md)** |
| System design, hook lifecycle, component relationships | Every env var, permission, and hook explained with rationale | The incidents and lessons behind every component |
| **[Benchmarks](BENCHMARKS.md)** | **[Presets](PRESETS.md)** | **[Cross-Tool Guide](CROSS-TOOL-GUIDE.md)** |
| Token savings, cost impact, quality metrics | Ready-to-copy configs for solo, team, and CI/CD | Cursor, Codex CLI, Gemini CLI, Windsurf |

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions to common issues -- hooks not firing, agents failing, MCP crashes, cost surprises, Windows-specific problems, and more.

---

<details>
<summary><strong>Plugin Compatibility</strong></summary>

&nbsp;

This blueprint is designed as a **standalone configuration** -- no plugins required. In fact, plugins can interfere with a custom setup:

**Known issues:**
- **Plugins that modify CLAUDE.md** may overwrite your custom behavioral rules
- **Plugins that add hooks** on the same events (e.g., Stop, PreToolUse) will stack with your hooks -- this can cause slowdowns or conflicting instructions
- **Plugins that inject context** consume tokens from your context window, leaving less room for your agents and memory system
- **MCP server plugins** work well alongside this setup -- they add tools, not rules, so there's no conflict

**Recommendation:** If you adopt this blueprint, audit your installed plugins and disable any that:
1. Override CLAUDE.md or settings.json hooks
2. Inject prompts on SessionStart (conflicts with your session-lifecycle rule)
3. Add broad permissions that bypass your permission restrictions

Custom setup > generic plugins, because your setup encodes YOUR project's domain knowledge. A plugin can't know your architecture, your team's conventions, or your production constraints.

</details>

---

## Acknowledgments

The memory system pattern in this blueprint was inspired by [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) by Kiyoraka -- a comprehensive AI memory architecture with 11 feature extensions (LRU project management, memory consolidation, echo recall, and more). If you want a deeper, more feature-rich memory system than the minimal scaffold included here, check out that project.

**How they differ:** This blueprint covers the *full Claude Code configuration* (agents, skills, hooks, rules, settings). The `memory-template/` here is a lightweight scaffold. Project-AI-MemoryCore goes deep on the memory layer specifically -- they're complementary, not competing.

## License

MIT
