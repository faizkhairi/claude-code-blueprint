# Getting Started — From Zero to Productive

This guide is for developers who are new to Claude Code or want to understand how all the pieces fit together. No prior experience required.

---

## Prerequisites

Before you begin, make sure you have:

| Requirement | Minimum | Check With | Install |
|------------|---------|------------|---------|
| **Node.js** | v18+ | `node --version` | [nodejs.org](https://nodejs.org) |
| **npm** | v9+ (ships with Node) | `npm --version` | Included with Node.js |
| **Git** | v2.30+ | `git --version` | [git-scm.com](https://git-scm.com) |
| **Bash shell** | Any | `bash --version` | macOS/Linux: built-in. Windows: see [Windows Notes](#windows-notes) |
| **Anthropic API key** | With active billing | — | See below |

### API Key Setup

1. Sign up or log in at [console.anthropic.com](https://console.anthropic.com)
2. Navigate to **API Keys** and create a new key
3. **Enable billing** under the Billing section -- Claude Code requires an active billing plan
4. Set the key in your environment:
   ```bash
   # Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
   export ANTHROPIC_API_KEY="sk-ant-..."
   ```
5. Verify by running `claude` -- it should start without asking for a key

### Enable Agent Teams (Required for Agents)

If you plan to use any of the [11 agents](agents/) in this blueprint, you must enable the agent teams feature. Add this to your `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Without this, the Agent tool is unavailable and all multi-agent workflows (parallel reviews, sprint planning, specialist agents) are non-functional. See [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md#claude_code_experimental_agent_teams) for the full explanation.

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

### How They Work Together

```
You type a message
  │
  ├─ CLAUDE.md rules loaded (behavioral guidelines)
  ├─ Rules loaded (path-scoped, based on files being edited)
  ├─ Memory loaded (auto-memory + external if configured)
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

## MCP Servers — Giving Claude Superpowers

### What Are MCP Servers?

MCP (Model Context Protocol) servers are external processes that give Claude new **tools**. Without MCP, Claude can read files and run shell commands. With MCP, Claude can:

- **Browse the web** (Playwright MCP)
- **Look up library documentation** (Context7 MCP)
- **Run Docker containers** (Docker MCP)
- **Query databases** (various DB MCPs)
- **Interact with APIs** (custom MCPs)

MCP servers are safe to use alongside this blueprint — they add tools, not rules, so there's no conflict with your configuration.

### Setting Up Your First MCP Server: Context7

Context7 fetches up-to-date documentation for any library. Instead of Claude relying on its training data (which may be outdated), it can look up the latest docs in real-time.

**Step 1:** Add to your project's `.claude.json` (create it in project root if it doesn't exist):

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

**Step 2:** Restart Claude Code. Context7 is now available.

**Step 3:** Use it naturally:

```
You: "Look up the latest Prisma client API docs using Context7 and show me how to use findMany with pagination"
```

Claude will use the `mcp__context7__resolve-library-id` and `mcp__context7__query-docs` tools automatically.

### Recommended MCP Servers for Beginners

| MCP Server | What It Does | When You Need It |
|------------|-------------|-----------------|
| **Context7** | Fetches up-to-date library documentation | When working with any framework or library |
| **Playwright** | Controls a real browser — navigate, click, fill forms, screenshot | When you need to verify UI, test in browser, or scrape |
| **Docker** | Runs Docker commands through Claude | When managing containers, builds, or compose stacks |

**Adding Playwright MCP:**

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-playwright@latest"]
    }
  }
}
```

**Adding Docker MCP:**

```json
{
  "mcpServers": {
    "docker": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "mcp/docker"]
    }
  }
}
```

### Where MCP Config Lives

| Scope | File | When to Use |
|-------|------|------------|
| **Project** | `.claude.json` in project root | MCP servers specific to this project |
| **User** | `~/.claude.json` | MCP servers you want in every project |

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

Or let Claude ask for permission each time (safer for beginners — just don't add them to the allow list).

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

Follow the Context7 setup above. Now Claude can look up any library's latest docs in real-time.

### Minute 15-20: Add Cost Tracking

Copy [hooks/cost-tracker.sh](hooks/cost-tracker.sh) to `~/.claude/hooks/` and add to your `settings.json` Stop hook. Now you have a JSONL log of every session's cost.

### Minute 20-30: Read WHY.md

Read [WHY.md](WHY.md) to understand why each component exists. This is where the real value is — not in copying files, but in understanding the thinking behind them.

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
| `jq` | `cost-tracker.sh`, `precompact-state.sh` | `winget install jqlang.jq` or `choco install jq` |
| `python` | Most hook scripts | `winget install Python.Python.3` or [python.org](https://python.org) |

**Note on `python3` vs `python`:** Three hooks in this blueprint use `python3` (`protect-config.sh`, `cost-tracker.sh`, `verify-mcp-sync.sh`), while others use `python`. On Windows, the command is typically `python`, not `python3`. Fix by editing the scripts to use `python`, or add `alias python3=python` to your `~/.bashrc` in Git Bash.

For more Windows-specific issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md#windows-specific).

---

## Setting Up for Teams

If you're adopting this blueprint across a team (startup, company, open source project), here's how the pieces split.

### What's Shared vs Personal

| Scope | Location | Commit to Repo? | Contains |
|-------|----------|-----------------|----------|
| **Project** | `.claude/` in project root | Yes | Agents, skills, rules specific to this project |
| **Project** | `CLAUDE.md` in project root | Yes | Behavioral rules the whole team follows |
| **Personal** | `~/.claude/settings.json` | No (per-user) | Hooks, permissions, API key, env vars |
| **Personal** | `~/.claude/projects/*/memory/` | No (per-user) | Auto-memory (learned preferences, gotchas) |

### Onboarding a New Developer

1. **Fork this blueprint** (or your team's adapted version) as a reference
2. **Copy hooks** from the blueprint to `~/.claude/hooks/` on the developer's machine
3. **Copy settings-template.json** to `~/.claude/settings.json` and customize paths (especially `additionalDirectories`)
4. **Set the API key** -- each developer needs their own Anthropic API key with billing enabled

### Permission Modes for Teams

| Developer Level | Recommended defaultMode | Why |
|----------------|------------------------|-----|
| New to Claude Code | (default -- not set) | Asks permission for every tool, helps build understanding |
| Comfortable with hooks | `"dontAsk"` | Efficient workflow, hooks catch dangerous actions |

Start new developers on the default (ask) mode. Graduate to `dontAsk` only after they've set up and tested the hook guardrails (especially `protect-config.sh` and `block-git-push.sh`).

### Memory for Teams

- **Auto-memory** (`~/.claude/projects/*/memory/`) is per-user and cannot be shared. Each developer builds their own memory over time.
- **External memory** ([memory-template/](memory-template/)) can be team-shared (one repo everyone reads) or per-user (each developer has their own memory repo). Team-shared works well for architectural decisions and conventions. Per-user works better for personal preferences and session history.
- **CLAUDE.md** is the primary mechanism for sharing team conventions. If everyone on the team should follow a rule, it belongs in CLAUDE.md, not in personal memory.

---

## What to Learn Next

Once you're comfortable with the basics:

1. **Agents** — Read [agents/README.md](agents/README.md) to understand model tiering and permission modes
2. **Skills** — Read [skills/README.md](skills/README.md) to see how multi-step workflows are built
3. **Hooks deep dive** — Read [hooks/README.md](hooks/README.md) for the full lifecycle and design principles
4. **Settings deep dive** — Read [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md) for every env var, permission, and cost implication explained
5. **Memory system** — Read [memory-template/README.md](memory-template/README.md) when you need cross-session persistence
6. **Architecture** — Read [ARCHITECTURE.md](ARCHITECTURE.md) for how everything connects
7. **Cross-tool** — Read [CROSS-TOOL-GUIDE.md](CROSS-TOOL-GUIDE.md) if you also use Cursor, Codex, or Gemini
8. **Troubleshooting** — Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md) if something isn't working as expected

---

*This guide assumes Claude Code CLI. If you're using the VS Code extension, the concepts are identical — only the installation step differs.*
