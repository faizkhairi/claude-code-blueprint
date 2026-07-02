# Getting Started — From Zero to Productive

This guide is for anyone who wants to get more out of Claude Code — whether you're a complete beginner or an experienced developer looking to level up your setup. No prior experience required.

> **How to read this:** start with the hands-on path — **[New to Claude Code? Start Here](#new-to-claude-code-start-here)** → **[Prerequisites](#prerequisites)** → **[Your First 30 Minutes](#your-first-30-minutes)**. That gets you a working setup. The deeper topics below (MCP servers, plugins, teams, memory) are optional — read them when you need them. New to the terms (agent, skill, hook, rule)? Jump to **[The Building Blocks (Glossary)](#the-building-blocks-glossary)** any time.

---

## New to Claude Code? Start Here

If you've never configured Claude Code before, this section is for you. Skip to [Prerequisites](#prerequisites) if you already know the basics.

### What Is This Repository?

This is a collection of configuration files that make Claude Code smarter, safer, and more consistent. Think of it as a recipe book — you pick the recipes you need and add them to your own kitchen. The most important file is **CLAUDE.md**, which tells Claude Code how to behave (like a set of house rules it follows every session).

### Got This Link from a Colleague?

Welcome. Here's your fastest path:

1. **Right now (60 seconds):** Open [CLAUDE.md](CLAUDE.md) in this repo. Click "Raw" (top-right), copy everything, and paste it into a new file called `CLAUDE.md` in your project's root folder.
2. **Start using Claude Code normally.** No special prompts needed. Claude automatically reads CLAUDE.md and follows the four rules inside it (Verify-After-Complete, Diagnose-First, Plan-First, Verify-Before-Exit-Plan).
3. **When curious:** Read the rest of this section to understand what Claude Code is and how to access it.
4. **When ready for more:** Follow the [recommended adoption path](README.md#recommended-adoption-path) to add hooks, agents, and skills incrementally.

No installation required. No dependencies. No package manager. Just one markdown file to start.

### How to Access Claude Code

There are multiple ways to use Claude Code. Pick the one that fits you:

| Method | Best For | How to Get It |
|--------|----------|---------------|
| **Desktop App** (Mac/Windows) | Easiest start — no terminal needed | Download from [claude.ai/code](https://claude.ai/code) |
| **VS Code Extension** | If you already use VS Code | Search "Claude Code" in the Extensions panel |
| **Web App** | Try it without installing anything | Visit [claude.ai/code](https://claude.ai/code) in your browser |
| **CLI (Terminal)** | Power users, scripting, automation | `npm install -g @anthropic-ai/claude-code` |

All methods support CLAUDE.md, agents, skills, and hooks. The CLI gives the most control, but you don't need it to get started.

> **First time?** Try `/powerup` in any Claude Code session for interactive lessons with animated demos -- it's the fastest way to learn the features.

### Which Model Should I Use?

Claude Code can use different AI models. Here's what to pick:

| If You Are | Recommended Model | Why |
|------------|-------------------|-----|
| Just starting out | **Claude Sonnet** | Best balance of speed, quality, and cost. Handles 90% of tasks well. |
| Building complex features / architecture | **Claude Opus** | Deepest reasoning. Use for system design, hard debugging, multi-file refactors. |
| Quick edits, docs, simple tasks | **Claude Haiku** | Fastest and cheapest. Great for straightforward work. |

You don't need to pick one forever — switch anytime by typing `/model` in Claude Code. **Start with Sonnet** and move to Opus only when a task clearly needs deeper reasoning.

### The 1-Minute Setup (Easiest Possible Start)

You can improve Claude Code in under a minute by adding just one file:

**Step 1.** Open the [CLAUDE.md](CLAUDE.md) file in this repository. Click **"Raw"** (top-right of the file view), then **select all** and **copy** the entire contents.

**Step 2.** Go to your project folder (the folder where your code lives). Create a new file called `CLAUDE.md` in the root of that folder. Paste the contents you copied and save.

**Step 3.** Start Claude Code in that folder. It automatically reads CLAUDE.md and follows the rules inside it.

**That's it.** You just gave Claude Code four behavioral rules that prevent the most common AI coding mistakes:
- **Verify-After-Complete** — Claude must prove its work before saying "done"
- **Diagnose-First** — Claude investigates before jumping to fixes
- **Plan-First** — Claude designs an approach before making changes

### The 5-Minute Setup (Recommended)

For a more complete setup, **fork** this repository so you have your own copy to customize.

> **What is forking?** When you "fork" a repository on GitHub, you create your own copy of it under your account. This lets you customize everything without affecting the original. You can also pull updates later as the blueprint evolves.

1. Click the **Fork** button (top-right corner of this GitHub page)
2. GitHub creates your copy at `github.com/YOUR-USERNAME/claude-code-blueprint`
3. Open a terminal and clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/claude-code-blueprint.git
   ```
4. Copy `CLAUDE.md` into each of your project folders
5. *(Optional)* Run `./setup.sh` to install hooks, agents, and settings to `~/.claude/` automatically — or copy them manually (see below for what this means)

### Where Is `~/.claude/`?

You'll see `~/.claude/` referenced throughout this guide. This is Claude Code's configuration folder. The `~` symbol means "your home folder":

| Your Computer | The Full Path |
|--------------|---------------|
| **Mac** | `/Users/yourname/.claude/` |
| **Linux** | `/home/yourname/.claude/` |
| **Windows** | `C:\Users\yourname\.claude\` |

If this folder doesn't exist yet, that's normal — Claude Code creates it the first time you run it. You can also create it manually.

> **Windows users:** If hooks or paths aren't working as expected, jump to [Windows Notes](#windows-notes) for platform-specific guidance before continuing.

Inside `~/.claude/` you'll find (or create):
- `settings.json` — Claude Code's main configuration (hooks, permissions, environment variables)
- `hooks/` — Shell scripts that run automatically on specific events
- `agents/` — Specialized sub-assistants you can invoke
- `skills/` — Multi-step workflows triggered by natural language
- `rules/` — Path-scoped instruction files

### What Is settings.json?

`settings.json` is Claude Code's main configuration file at `~/.claude/settings.json`. It controls hooks (automatic behaviors), permissions (what Claude can and can't do), and environment variables.

If you don't have one yet, that's normal — Claude Code works fine without it. You only need it when you want to add hooks or customize permissions. See [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md) for a complete reference.

### Let Claude Code Set Up for You

Here's a shortcut — you can ask Claude Code to configure itself. Paste this prompt into a Claude Code session:

```
I want to set up the Claude Code Blueprint from this repository.
Please help me:
1. Copy the CLAUDE.md behavioral rules into my current project root (this is the only project-level file)
2. Set up hooks in my USER-LEVEL config at ~/.claude/hooks/ (NOT in the project directory)
3. Set up permissions in ~/.claude/settings.json (NOT in .claude/settings.json in the project)
Show me what you're doing at each step so I can learn.
IMPORTANT: Do NOT modify any project-level .claude/ directory. All hooks, permissions, and personal settings belong in ~/.claude/ (your home directory).
```

Claude Code will walk you through the setup interactively — creating files, explaining what each one does, and wiring everything together.

For a non-interactive automated setup, run `./setup.sh` from the blueprint repository. See [SETUP.md](SETUP.md) for usage, presets, and a verification checklist.

### Will This Affect My Token Usage?

The short answer: **barely.** Here's why:

| Component | Token Cost | When It Loads |
|-----------|-----------|---------------|
| **Hooks** (all 10) | **Zero** | External shell scripts — never touch your token budget |
| **CLAUDE.md** | ~2,300 tokens | Once at session start (stays in context) |
| **Rules** | ~700-1,500 each | Only when editing matching files (path-scoped) |
| **Skills** | ~500-1,100 each | Only when you trigger them |
| **Agents** | Varies (new context per spawn) | Only when explicitly invoked |

For perspective: a typical 30-turn coding session uses 50,000-200,000+ tokens. The blueprint adds ~2,300 tokens (~1-5% overhead). Meanwhile, one prevented wrong-approach-then-redo cycle saves 5,000-20,000 tokens. **The blueprint saves more than it costs.**

**Subscription users (Pro, Max):** Start with CLAUDE.md + hooks (the Minimal preset). Hooks are free. CLAUDE.md is a tiny fraction of your usage. When you want more, the `core` preset is a sensible next step -- a curated set of review/test/deploy skills and two path-scoped rules, without the full specialist ecosystem.

**API billing users:** The blueprint adds roughly 1-3 cents per session. Model tiering (Haiku for docs, Sonnet for code) is your biggest savings lever.

**Budget-conscious?** Hooks give the most value per token spent (literally free). CLAUDE.md is the second-best ROI. Agents are the most expensive — add them one at a time, starting with `verify-plan`.

See [BENCHMARKS.md](docs/BENCHMARKS.md#token-cost-per-component) for the complete breakdown, including subscription plan recommendations and an upgrade guide.

### Important: Placeholder Variables

Several files in this blueprint contain placeholder variables like `{PROJECTS_ROOT}` and `{CLAUDE_CONFIG_PATH}`. You must replace these with your actual paths before use (the `./setup.sh` installer does this for you). Note that `./memory/` is not a placeholder -- it is the built-in opt-in memory folder shipped with the blueprint, and needs no replacement. See [skills/README.md](skills/README.md#required-replace-placeholder-variables) for the full list and platform-specific examples.

### Ready for More?

The rest of this guide covers the full Claude Code ecosystem — prerequisites, MCP servers, agents, skills, hooks, and memory systems. Continue to [Prerequisites](#prerequisites) when you're ready to go deeper.

> **Have questions?** See the [FAQ](FAQ.md) for answers to the most common community questions -- framework support, skill levels, pricing plans, and more.

---

## Prerequisites

Before you begin, make sure you have:

| Requirement | Minimum | Check With | Install |
|------------|---------|------------|---------|
| **Node.js** | v18+ | `node --version` | [nodejs.org](https://nodejs.org) |
| **npm** | v9+ (ships with Node) | `npm --version` | Included with Node.js |
| **Git** | v2.30+ | `git --version` | [git-scm.com](https://git-scm.com) |
| **Bash shell** | Any | `bash --version` | macOS/Linux: built-in. Windows: see [Windows Notes](#windows-notes) |
| **Claude Code access** | A Claude subscription (Pro/Max/Team/Enterprise) **or** an Anthropic API key | — | See below |

### Claude Code Access

Claude Code authenticates one of two ways -- you only need one:

**Option A -- Claude subscription (recommended for most people).** If you have a Claude Pro, Max, Team, or Enterprise plan, just run `claude` and sign in with your Claude account in the browser. No API key needed.

**Option B -- Anthropic API key (usage-based billing).** If you prefer to pay per token via the API:

1. Sign up or log in at [console.anthropic.com](https://console.anthropic.com)
2. Navigate to **API Keys**, create a new key, and enable billing under the Billing section
3. Set the key in your environment:
   ```bash
   # Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
   export ANTHROPIC_API_KEY="sk-ant-..."
   ```

Then run `claude` to start. Note: if you have a subscription **and** an `ANTHROPIC_API_KEY` set, the API key takes precedence -- `unset ANTHROPIC_API_KEY` to use your subscription instead.

### Enable Agent Teams (Required for Agents)

If you plan to use any of the [11 agents](agents/) in this blueprint, you must enable the agent teams feature. Add this to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Without this, the Agent tool is unavailable and all multi-agent workflows (parallel reviews, sprint planning, specialist agents) are non-functional. See [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md#claude_code_experimental_agent_teams) for the full explanation.

---

## Your First 30 Minutes

Here's what to do right now to get the most out of Claude Code:

### Minute 0-5: Install and Create CLAUDE.md

```bash
# In your project root
claude  # start Claude Code
```

Copy the [CLAUDE.md](CLAUDE.md) from this blueprint into your project root. This alone gives you:
- Verify-After-Complete rule (prevents "done" without proof)
- Diagnose-First rule (prevents wasted investigation)
- Plan-First rule (prevents implementing the wrong approach)

### Minute 5-10: Add Your First Hook

Copy [hooks/protect-config.sh](hooks/protect-config.sh) to `~/.claude/hooks/` and add to your `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"~/.claude/hooks/protect-config.sh\""
          }
        ]
      }
    ]
  }
}
```

This prevents Claude from "fixing" lint errors by disabling lint rules.

### Minute 10-15: Add Context7 MCP

Run this in your terminal:

```bash
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest
```

Restart Claude Code. Now Claude can look up any library's latest docs in real-time.

### Minute 15-20: Add Cost Tracking

Copy [hooks/cost-tracker.sh](hooks/cost-tracker.sh) to `~/.claude/hooks/` and add to your `settings.json` Stop hook. Now you have a JSONL log of every session's cost.

### Minute 20-30: Read WHY.md

Read [WHY.md](docs/WHY.md) to understand why each component exists. This is where the real value is — not in copying files, but in understanding the thinking behind them.

---

## Common Mistakes (and How to Avoid Them)

### 1. Context Window Bloat
**Mistake:** Loading everything into every session — massive CLAUDE.md, every agent, every rule.
**Fix:** Keep CLAUDE.md under 100 lines. Use path-scoped rules. Extract details to topic files that load on-demand.

### 2. No Verification
**Mistake:** Accepting "done" at face value. Claude says it fixed the bug → you move on.
**Fix:** Always verify. Run the tests. Hit the endpoint. Re-read the file. A 200 response with empty data is not success.

### 3. Skipping Plan Mode
**Mistake:** Asking Claude to "just do it" for complex changes. It implements fast — but wrong.
**Fix:** Use plan mode for anything touching more than 1-2 files. Five minutes of review saves hours of rework.

### 4. Too Many Permissions
**Mistake:** Allowing everything in `settings.json` so Claude never asks for permission.
**Fix:** Start restrictive, add permissions as needed. Use `"defaultMode": "dontAsk"` only after you trust your hooks to catch mistakes.

### 5. Ignoring the Stop Hook
**Mistake:** Not having a security check on every response.
**Fix:** Add the Stop hook from [settings-template.json](examples/settings-template.json). It catches SQL injection, exposed secrets, and verification gaps automatically.

### 6. Not Using Agents for Review
**Mistake:** Asking Claude to review its own code in the same context window.
**Fix:** Use a separate review agent with `isolation: worktree`. Fresh context catches blind spots that self-review in the same window misses.

### 7. Fighting the AI Instead of Guiding It
**Mistake:** Correcting the same behavior over and over without writing it down.
**Fix:** If you've corrected Claude twice on the same thing, add it to CLAUDE.md. Rules are cheaper than repeated corrections.

---

## What is Claude Code?

Claude Code is Anthropic's **command-line interface (CLI)** for Claude. Unlike the web chat at claude.ai, Claude Code:

- Runs in your terminal (or as a VSCode extension)
- Can read, write, and edit files on your machine
- Can run shell commands (git, npm, docker, etc.)
- Has a permission system so you control what it can do
- Supports hooks, agents, skills, and MCP servers for automation

Think of it as having a senior developer sitting in your terminal who can read your codebase, write code, run tests, and follow your team's conventions — if you configure it well.

### Installation

```bash
# Install globally
npm install -g @anthropic-ai/claude-code

# Or use npx (no install)
npx @anthropic-ai/claude-code

# Start Claude Code in your project
cd your-project
claude
```

---

## The Building Blocks (Glossary)

Before diving in, here's what each piece does:

| Component | What It Is | Analogy |
|-----------|-----------|---------|
| **CLAUDE.md** | A markdown file in your project root with behavioral rules | Like a `.editorconfig` but for AI behavior |
| **settings.json** | Configuration at `~/.claude/settings.json` — hooks, permissions, env vars | Like VS Code's `settings.json` |
| **Agents** | Specialized sub-assistants with their own model, tools, and instructions | Like microservices — each does one thing well |
| **Skills** | Step-by-step workflows triggered by natural language | Like shell aliases — "deploy" triggers a 10-step checklist |
| **Hooks** | Shell scripts that run automatically on lifecycle events | Like git hooks — deterministic, can't be skipped |
| **Rules** | Path-scoped instruction files that load only for specific file types | Like ESLint configs that only apply to certain folders |
| **MCP Servers** | External tools that give Claude new capabilities | Like VS Code extensions — add features without modifying core |
| **Memory** | Persistent context files that survive across sessions | Like a dev journal that Claude reads at the start of each session |

Knowing *what* each piece is only gets you halfway — the harder question is *when* to reach for an agent versus a skill versus just letting Claude work on the main thread. For that, see **[When to Use an Agent vs a Skill vs the Main Thread](agents/README.md#when-to-use-an-agent-vs-a-skill-vs-the-main-thread)**. The short version: most work stays on the main thread, skills are cheap repeatable recipes, agents earn their cost only when a task needs its own context window, and hooks are for what must happen every time.

### How They Work Together

```
You type a message
  │
  ├─ CLAUDE.md rules loaded (behavioral guidelines)
  ├─ Rules loaded (path-scoped, based on files being edited)
  ├─ Memory loaded (session memory + memory/ folder if enabled)
  │
  ├─ Claude processes your request
  │   ├─ May spawn Agents (specialized subagents)
  │   ├─ May use MCP tools (browser, docs, docker)
  │   └─ May trigger Skills (multi-step workflows)
  │
  ├─ Before tool use → PreToolUse hooks fire (can block dangerous actions)
  ├─ After tool use → PostToolUse hooks fire (can remind you to verify)
  │
  └─ After response → Stop hooks fire (security check, cost tracking)
```

---

## MCP Servers -- Giving Claude Superpowers

### What Are MCP Servers?

MCP (Model Context Protocol) servers are external processes that give Claude new **tools**. Without MCP, Claude can read files and run shell commands. With MCP, Claude can:

- **Browse the web** (Playwright MCP)
- **Look up library documentation** (Context7 MCP)
- **Run Docker containers** (Docker MCP)
- **Query databases** (various DB MCPs)
- **Interact with APIs** (custom MCPs)

MCP servers are safe to use alongside this blueprint -- they add tools, not rules, so there's no conflict with your configuration.

### Adding MCP Servers

#### Option A: CLI (Recommended)

The `claude mcp add` command is the easiest way to add MCP servers. Run it in your terminal (or VS Code's integrated terminal):

```bash
# Context7 -- live library documentation (works for any project)
claude mcp add context7 -- npx -y @upstash/context7-mcp@latest

# Playwright -- browser automation (works for any web project)
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

By default, servers are added to the **local** scope (this session only). Use `--scope` to control where the config is saved:

```bash
# Available in every project (saved to ~/.claude.json)
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest

# Shared with your team via git (saved to .mcp.json in project root)
claude mcp add --scope project playwright -- npx -y @playwright/mcp@latest
```

After adding, use it naturally:

```
You: "Look up the latest Prisma client API docs using Context7 and show me how to use findMany with pagination"
```

Claude will use the `mcp__context7__resolve-library-id` and `mcp__context7__query-docs` tools automatically.

#### Option B: Manual JSON Config

If you prefer editing config files directly (or need to set up MCP in CI/CD), create `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

After manual edits, restart Claude Code to load the new servers.

### Recommended MCP Servers for Beginners

| MCP Server | What It Does | When You Need It |
|------------|-------------|-----------------|
| **Context7** | Fetches up-to-date library documentation | When working with any framework or library |
| **Playwright** | Controls a real browser -- navigate, click, fill forms, screenshot | When you need to verify UI, test in browser, or scrape |
| **Docker** (optional) | Runs Docker commands through Claude | When managing containers (requires Docker Desktop) |

### Where MCP Config Lives

| Scope | File | Created By | When to Use |
|-------|------|-----------|------------|
| **Project** | `.mcp.json` in project root | `claude mcp add --scope project` | Shared with team (commit to git) |
| **User** | `~/.claude.json` | `claude mcp add --scope user` | Available in every project |
| **Local** | (session state) | `claude mcp add` (default) | Temporary, this session only |

> **Note:** The VS Code extension also reads from `~/.claude/mcp.json`. If you use both CLI and the extension, run [verify-mcp-sync.sh](hooks/verify-mcp-sync.sh) to check they're in sync.

Manage your servers anytime:

```bash
claude mcp list              # Show all configured servers
claude mcp remove <name>     # Remove a server
```

### Managing MCP Servers in VS Code

The VS Code extension uses the same config files as the CLI -- no separate setup needed. To add a new MCP server, run `claude mcp add` in VS Code's integrated terminal (`` Ctrl+` `` or `` Cmd+` ``).

Once servers are added, type `/mcp` in the Claude Code chat panel to manage them: enable/disable servers, reconnect after a crash, or complete OAuth flows. The `/mcp` dialog manages existing servers -- adding new ones requires the CLI command.

### Allowing MCP Tools in Permissions

After adding an MCP server, you need to allow its tools in `settings.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__context7__resolve-library-id",
      "mcp__context7__query-docs",
      "mcp__playwright__browser_navigate",
      "mcp__playwright__browser_snapshot",
      "mcp__playwright__browser_click"
    ]
  }
}
```

Or let Claude ask for permission each time (safer for beginners -- just don't add them to the allow list).

### Troubleshooting MCP Servers

**"MCP tool call failed"** -- If you installed the blueprint's hooks, the `PostToolUseFailure` hook automatically instructs Claude to retry once and then fall back to non-MCP alternatives (e.g., `curl` instead of Playwright, `docker` CLI instead of Docker MCP).

**"MCP tools not appearing"** -- Three quick checks:

1. **Restart Claude Code** after any config changes (MCP servers load at startup)
2. **Verify the config file** is in the right location (`.mcp.json` for project, `~/.claude.json` for user)
3. **Run `claude mcp list`** to confirm the server is registered and connected

For more causes and fixes, see [TROUBLESHOOTING.md -- MCP Servers](TROUBLESHOOTING.md#mcp-servers). If you use Claude Code across CLI, VS Code, and Cursor, the [verify-mcp-sync.sh](hooks/verify-mcp-sync.sh) utility checks that MCP configs are consistent across all three.

---

## Plugins vs. Custom Setup

### What Are Plugins?

Claude Code supports a plugin marketplace where community-built plugins can add agents, skills, hooks, and rules to your setup. Plugins are convenient but generic.

### When to Use Plugins

- **Starting out** — plugins give you a quick boost before you build your own setup
- **Generic capabilities** — a plugin that adds Playwright MCP is useful for everyone
- **Exploring ideas** — try a plugin to see if a concept works for you, then build your own version

### When to Use Custom Setup (This Blueprint)

- **Project-specific conventions** — a plugin can't know your team's naming conventions
- **Domain knowledge** — your database constraints, API patterns, deployment pipeline
- **Full control** — no unexpected updates, no context injection you didn't ask for
- **Maximum efficiency** — load only what's relevant to the current task

### The Migration Path

```
Beginner:    Plugins for quick wins
     ↓
Intermediate: CLAUDE.md + a few hooks (from this blueprint)
     ↓
Advanced:    Full custom setup (agents, skills, hooks, memory)
     ↓
Power user:  This blueprint, adapted to your workflow
```

---

## Windows Notes

Claude Code works well on Windows. These notes cover the platform differences you'll encounter.

### Shell: Use Git Bash

All hook scripts in this blueprint are bash (`.sh`) files. On Windows, you need a bash-compatible shell:

- **Git Bash** (recommended): Installs automatically with [Git for Windows](https://git-scm.com/download/win). Available in VS Code's integrated terminal (select "Git Bash" as the default shell).
- **WSL**: Works but adds latency for hooks due to the Windows/Linux file system bridge.
- **PowerShell**: Won't run `.sh` files directly. Not compatible with this blueprint's hooks.

### Path Formats

| Context | Format | Example |
|---------|--------|---------|
| Windows Explorer / CMD | Backslash | `C:\Users\YourUser\.claude\hooks\` |
| Git Bash / hook scripts | Forward slash | `/c/Users/YourUser/.claude/hooks/` |
| settings.json `command` | Tilde or forward slash | `bash "~/.claude/hooks/protect-config.sh"` |

In `settings.json`, tilde (`~`) expansion depends on the shell. If hooks aren't found, try absolute paths: `bash "/c/Users/YourUser/.claude/hooks/script.sh"`.

### Line Endings: LF, Not CRLF

Hook scripts must use LF (Unix) line endings. Git for Windows may auto-convert to CRLF, which causes `\r` errors in bash. Configure git to keep LF for shell scripts:

```bash
git config --global core.autocrlf input
```

Or add a `.gitattributes` file to force LF for hooks:
```
*.sh text eol=lf
```

### File Permissions

`chmod +x` is a no-op on NTFS. This is fine -- the blueprint invokes hooks via `bash "path/to/script.sh"` in settings.json, which doesn't require execute permission.

### CLI Tools You May Need to Install

| Tool | Used By | Install on Windows |
|------|---------|-------------------|
| `python` | All hook scripts (JSON parsing) | `winget install Python.Python.3` or [python.org](https://python.org) |

All hooks auto-detect Python using `command -v python3 || command -v python`. You need either `python3` or `python` on your PATH -- not both. If neither is found, hooks print a warning and exit cleanly (no blocking).

On Windows, `python` is the typical command name. On macOS/Linux, `python3` is standard. The hooks handle both automatically -- no aliasing or script editing needed.

### Common Edge Cases

- **Spaces in username:** If your Windows username contains spaces (e.g., `C:\Users\John Doe\.claude\`), ensure all paths in `settings.json` are wrapped in double quotes. Hook scripts already quote `$HOME` expansions, so they handle this automatically.
- **Do not use this repo as your project:** Running `cd claude-code-blueprint && claude` will cause Claude to read this blueprint's own CLAUDE.md (which has meta-instructions about the blueprint itself). Always fork or copy files into your own project.

For more Windows-specific issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#windows-specific).

---

## Where Config Belongs (Project vs Personal)

Before setting up, understand what goes where. This prevents mistakes like committing personal API keys or modifying shared team configs.

### Config Placement Table

| Config Type | Project-Level (`.claude/`) | User-Level (`~/.claude/`) | Rule of Thumb |
|-------------|---------------------------|--------------------------|---------------|
| **CLAUDE.md** | Team behavioral rules | Personal style preferences | Commit project-level to repo; keep personal in `~/.claude/CLAUDE.md` |
| **settings.json** | Shared hooks, env vars | Personal permissions, hooks | User settings override project settings |
| **Hooks** (.sh scripts) | Not recommended | Always here | Hooks are machine-specific; do not commit to team repos |
| **Agents** (.md files) | Team-shared agents | Personal agents | Both locations are loaded; user supplements project |
| **Skills** | Team workflows | Personal workflows | Both loaded; user supplements project |
| **Rules** | Team constraints | Personal constraints | Both loaded; path-scoped by glob pattern |
| **Memory** | Never | Always here | Memory is personal and should never be in a shared repo |

### Cross-Platform User Config Paths

| AI Coding Tool | Windows | macOS / Linux |
|---------------|---------|---------------|
| Claude Code | `C:\Users\{user}\.claude\` | `~/.claude/` |
| Cursor | `C:\Users\{user}\.cursor\` | `~/.cursor/` |
| Codex CLI | `C:\Users\{user}\.codex\` | `~/.codex/` |
| Gemini CLI | `C:\Users\{user}\.gemini\` | `~/.gemini/` |
| Windsurf | `C:\Users\{user}\.codeium\windsurf\` | `~/.codeium/windsurf/` |
| VS Code | `.vscode/` in project (project-level only) | Same (project-level only) |
| GitHub Copilot | Configured through IDE settings | Same |

### Team Collaboration Safety

When you fork this blueprint for a team, follow these rules to protect shared config:

- **Never let an AI agent modify shared project configs** — `.claude/settings.json`, `CLAUDE.md`, or team rules without human review first
- **Personal hooks, permissions, and environment variables** belong in `~/.claude/settings.json`, not in the project
- **When asking Claude to "set up the blueprint"**, always specify: "install to my user-level config at `~/.claude/`" to avoid confusion
- **Memory is personal** — no developer should ever commit their `~/.claude/projects/*/memory/` to the team repo

---

## How Memory Works

The blueprint includes an opt-in memory system that gives Claude persistent context across sessions on this machine.

**What gets remembered**:
- Your coding preferences (style, tools, conventions)
- Architectural decisions (why you chose pattern X over Y)
- Active project context (what you're working on, what's blocked)
- Session continuity (pick up where you left off after a break)

**Where it lives**: `./memory/` folder inside your fork of this blueprint.

**Privacy**: personal content is `.gitignore`d by default — if you push your fork publicly, your memory stays local. The `memory/.gitignore` excludes `core/session.md`, `core/reminders.md`, `diary/`, and `projects/active/`. Append-only structural files (`core/decisions.md`, `core/identity.md`, `core/preferences.md`) are tracked by default since they're less sensitive — review them before pushing if you want stricter privacy.

**How to enable**: just run `./setup.sh` and answer **Y** when prompted "Enable persistent memory? [Y/n]". The setup wizard handles the rest.

**How to disable**: re-run `./setup.sh` and answer **n** to the memory prompt. The memory skills (`load-session`, `save-session`, `save-diary`, `session-end`) become no-ops with a clear "memory disabled" message. Your data is not deleted — `memory/` stays on disk unchanged in case you re-enable later.

**Optional cross-machine sync**: the default setup gives you memory on this machine only. For cross-machine sync, see `memory/README.md` — short version: fork the blueprint to a **private** repo, comment out the `.gitignore` entries, and push. Treat the fork as private since it now contains your personal memory content.

> **Credit**: the memory pattern in this blueprint was inspired by [Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore) by Kiyoraka. The blueprint ships a lean built-in version; for a deeper memory architecture with LRU project management, echo recall, and 11 feature extensions, check out the original project — it's the more comprehensive option for users who want full memory architecture.

---

## Setting Up for Teams

If you're adopting this blueprint across a team (startup, company, open source project), here's how the pieces split.

### What's Shared vs Personal

| Scope | Location | Commit to Repo? | Contains |
|-------|----------|-----------------|----------|
| **Project** | `.claude/` in project root | Yes | Agents, skills, rules specific to this project |
| **Project** | `CLAUDE.md` in project root | Yes | Behavioral rules the whole team follows |
| **Personal** | `~/.claude/settings.json` | No (per-user) | Hooks, permissions, API key, env vars |
| **Personal** | `~/.claude/projects/*/memory/` | No (per-user) | Session memory (what Claude learns per-user over time) |

### Onboarding a New Developer

1. **Fork this blueprint** (or your team's adapted version) as a reference
2. **Copy hooks** from the blueprint to `~/.claude/hooks/` on the developer's machine
3. **Copy settings-template.json** to `~/.claude/settings.json` and customize paths (especially `additionalDirectories`)
4. **Set up Claude Code access** -- each developer signs in with their own Claude subscription, or sets their own Anthropic API key

### Permission Modes for Teams

| Developer Level | Recommended defaultMode | Why |
|----------------|------------------------|-----|
| New to Claude Code | *(not set)* | Asks permission for every tool, helps build understanding |
| Comfortable with hooks | `"auto"` | AI classifier evaluates safety contextually; hooks catch the rest |
| CI/CD pipelines | `"dontAsk"` | Predictable allow-list behavior, no classifier overhead |

Start new developers on the default (ask) mode. Graduate to `"auto"` once they've set up and tested the hook guardrails (especially `protect-config.sh` and `block-git-push.sh`). Use `"dontAsk"` only for CI/CD where you want rigid, predictable behavior. See [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md#defaultmode) for full details on all four modes.

### Memory for Teams

- **Session memory** (`~/.claude/projects/*/memory/`) is per-user and cannot be shared. Each developer builds their own memory over time.
- **Built-in memory** ([memory/](memory/)) is opt-in via `./setup.sh`. By default it lives in the user's working copy and is git-ignored for privacy. Advanced users can configure it as a separate git repo for cross-machine sync; team-shared memory works well for architectural decisions and conventions, per-user for personal preferences and session history.
- **CLAUDE.md** is the primary mechanism for sharing team conventions. If everyone on the team should follow a rule, it belongs in CLAUDE.md, not in personal memory.

---

## What to Learn Next

Once you're comfortable with the basics:

1. **Agents** — Read [agents/README.md](agents/README.md) to understand model tiering and permission modes
2. **Skills** — Read [skills/README.md](skills/README.md) to see how multi-step workflows are built
3. **Hooks deep dive** — Read [hooks/README.md](hooks/README.md) for the full lifecycle and design principles
4. **Settings deep dive** — Read [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md) for every env var, permission, and cost implication explained
5. **Memory system** — Read [memory/README.md](memory/README.md) when you need cross-session persistence
6. **ADR template** — Use [memory/templates/adr-template.md](memory/templates/adr-template.md) when documenting architectural decisions
7. **Architecture** — Read [ARCHITECTURE.md](docs/ARCHITECTURE.md) for how everything connects
8. **Cross-tool** — Read [CROSS-TOOL-GUIDE.md](docs/CROSS-TOOL-GUIDE.md) if you also use Copilot, Cursor, Cline, Roo Code, OpenCode, or other AI tools
9. **FAQ** — See [FAQ.md](FAQ.md) for answers to the most common community questions
10. **Troubleshooting** — Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if something isn't working as expected

---

*This guide assumes Claude Code CLI. If you're using the VS Code extension, the concepts are identical — only the installation step differs.*
