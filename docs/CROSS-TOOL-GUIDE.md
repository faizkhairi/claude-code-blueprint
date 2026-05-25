# Cross-Tool Guide -- Using These Concepts Beyond Claude Code

While this blueprint is built for Claude Code, the **principles are universal**. This guide maps each concept to its equivalent in other AI coding tools, based on their official documentation as of April 2026.

## Quick Reference: Config File Locations

| Tool | Behavioral Rules | Main Config | User Config Directory | Custom Agents / Skills | MCP Config |
|------|-----------------|-------------|----------------------|------------------------|------------|
| **Claude Code** | `CLAUDE.md` | `~/.claude/settings.json` | `~/.claude/` | `.claude/agents/*.md` + `~/.claude/skills/` | `.mcp.json` (project) or `~/.claude.json` (user) |
| **Copilot** | `.github/copilot-instructions.md` + `.instructions.md` | `~/.copilot/config.json` | `~/.copilot/` | `.github/agents/*.agent.md` | `.vscode/mcp.json` or `~/.copilot/mcp-config.json` |
| **Cursor** | `.cursor/rules/*.mdc` + User Rules | `cli-config.json` / `permissions.json` | `~/.cursor/` | `~/.cursor/skills/` + built-in subagents | `~/.cursor/mcp.json` or Settings UI |
| **Cline** | `.clinerules/` dir or `.clinerules` file | `~/.cline/data/globalState.json` | `~/.cline/` | `.clinerules/workflows/*.md` | `~/.cline/settings/cline_mcp_settings.json` |
| **Roo Code** | `.roo/rules/` dir or `.roorules` file | VS Code globalStorage | `~/.roo/` | `.roo/skills/` + `.roomodes` | `.roo/mcp.json` or global `mcp_settings.json` |
| **OpenCode** | `AGENTS.md` (+ reads `CLAUDE.md`) | `~/.config/opencode/opencode.json` | `~/.config/opencode/` | `.opencode/skills/` + `.opencode/agents/` | In `opencode.json` under `mcp` |
| **Codex CLI** | `AGENTS.md` | `~/.codex/config.toml` | `~/.codex/` | Via Agents SDK | In `config.toml` |
| **Gemini CLI** | `GEMINI.md` | `~/.gemini/settings.json` | `~/.gemini/` | Subagent configs | In `settings.json` |
| **Amazon Q** | `.amazonq/rules/*.md` | `q settings` | `~/.aws/amazonq/` | `.amazonq/cli-agents/*.json` | `.amazonq/mcp.json` |
| **Windsurf** | `.windsurf/rules/*.md` + `AGENTS.md` | `~/.codeium/windsurf/` | `~/.codeium/windsurf/` | Not supported | `mcp_config.json` |
| **Aider** | `CONVENTIONS.md` (via `--read`) | `~/.aider.conf.yml` | `~/.aider.conf.yml` | Not supported | Not supported |

**Copilot notes:**

- **Three rule layers**: Personal (`~/.copilot/instructions/`), repository (`.github/`), and organization (org's `.github` repo). Priority: personal > repo > org.
- **Custom agents** use `.agent.md` files with YAML frontmatter (`name`, `description`, `tools`, `model`, `mcp-servers`). Three scopes: `.github/agents/` (repo), org's `.github/agents/` (org), `~/.copilot/agents/` (personal).
- **`copilot-setup-steps.yml`** is a GitHub Actions workflow (`.github/workflows/`) that runs before the cloud coding agent starts -- for installing dependencies and configuring the environment.
- **Three agent surfaces**: VS Code interactive, Copilot CLI (local), and cloud coding agent (remote, creates PRs).

**Cursor notes (read this if you use Cursor seriously):**

- **Rules** load from **two places**: repo `.cursor/rules/*.mdc` (often with `globs` / `alwaysApply`) and **global User Rules** in Cursor Settings. You do not have to duplicate everything in both -- use project rules for repo-specific conventions and User Rules for habits you want in every workspace.
- **Skills** (`~/.cursor/skills/<name>/SKILL.md`) are the closest analog to this blueprint's **skills** folder for **Cursor's native Agent** (natural-language triggers via the skill description). They are separate from `.mdc` rules.
- **Permissions**: `cli-config.json` controls **tool allowlists** for the Agent CLI; `permissions.json` provides **unified editor + CLI permissions** with sandbox modes. Neither is the same as VS Code's `settings.json`. See [permissions docs](https://cursor.com/docs/reference/permissions).
- **Hooks** are configured in `hooks.json` (not `settings.json`). Cursor has ~11 hook types -- see the [Lifecycle Hooks](#3-lifecycle-hooks) section for the full list and CLI limitations.
- **`.cursorignore`** controls which files are excluded from Cursor's codebase indexing -- like `.gitignore` for AI context. Add your memory/session files here if they shouldn't be indexed.

---

## Feature Comparison Matrix

### Table A -- Configuration & Rules

| Tool | Rules File | Hierarchy | Path-Scoped | Skills / Workflows |
|------|:----------:|:---------:|:-----------:|:------------------:|
| **Claude Code** | Yes | Yes | Yes (`paths:` frontmatter) | Yes (`~/.claude/skills/`) |
| **Copilot** | Yes | Yes (3 levels) | Yes (`applyTo` globs) | Yes (`.agent.md` profiles) |
| **Cursor** | Yes | Yes | Yes (globs in `.mdc`) | Yes (`~/.cursor/skills/`) |
| **Cline** | Yes | Yes | Yes (YAML frontmatter globs) | Yes (custom workflows) |
| **Roo Code** | Yes | Yes | No (mode-based file regex) | Yes (Skills system) |
| **OpenCode** | Yes | Yes | Partial (community plugin) | Yes (skills + commands) |
| **Codex CLI** | Yes | Yes | Yes (directory walk) | Varies |
| **Gemini CLI** | Yes | Yes | Yes (directory walk) | Varies |
| **Amazon Q** | Yes | Partial (project only) | No | Yes (custom agents) |
| **Windsurf** | Yes | Yes | Yes (glob triggers) | Varies |
| **Aider** | Yes | Yes | No | No |

### Table B -- Architecture & Capabilities

| Tool | Subagents | Hooks | MCP | Memory | Model Tiering | Permissions | Worktree |
|------|:---------:|:-----:|:---:|:------:|:-------------:|:-----------:|:--------:|
| **Claude Code** | Yes | Yes (broad) | Yes | Yes (dual) | Yes (per-agent) | Yes (`settings.json`) | Yes |
| **Copilot** | Yes | Yes (8 events, Preview) | Yes | Yes (repo-scoped, 28-day) | Yes (per-agent + BYOK) | Yes (agent-level + firewall) | Yes |
| **Cursor** | Yes | Yes (~11 types) | Yes | Removed | Mostly global | Yes (unified sandbox) | No |
| **Cline** | Partial (`new_task` + Kanban) | Yes (8 events) | Yes | Partial (Memory Bank pattern) | Yes (Plan/Act separate) | Yes (8 categories + YOLO) | Partial (CLI-based) |
| **Roo Code** | Yes (Orchestrator + Boomerang) | No | Yes | No (community MCP) | Yes (Sticky Models per mode) | Yes (per-mode tool groups) | Yes (built-in UI) |
| **OpenCode** | Yes (built-in + custom) | Yes (20+ plugin events) | Yes | Partial (SQLite sessions) | Yes (per-agent, per-command) | Yes (allow/ask/deny) | Partial (community plugin) |
| **Codex CLI** | Yes | Limited (prompt-level) | Yes | Transcript resume | Yes (per-config) | Yes (sandbox modes) | No |
| **Gemini CLI** | Yes (experimental) | Yes (experimental) | Yes | Yes (`save_memory`) | No | No | No |
| **Amazon Q** | Yes (custom agents) | Yes (5 triggers) | Yes | Partial (resume + save/load) | No | Yes (per-tool trust) | No |
| **Windsurf** | No (parallel Cascade only) | Limited (enterprise) | Yes | Yes (auto-generated) | No | No | Yes (parallel agents) |
| **Aider** | No | No | No | Partial (chat history replay) | Yes (3-tier: main/weak/editor) | Partial (binary `--yes`) | No |

**Hooks -- a growing ecosystem with different surfaces:** Claude Code (SessionStart, PreToolUse matchers, Pre/PostCompact, Stop), Copilot (8 events including SubagentStart/Stop, Preview), Cursor (~11 types including `beforeSubmitPrompt`, `afterAgentResponse`), Cline (8 events including TaskStart, PreToolUse), Amazon Q (5 triggers in custom agents), and OpenCode (20+ plugin events covering tools, sessions, files, LSP, and TUI) all have hooks -- but they cover **different events** with different APIs. For **policy that must hold regardless of product**, prefer **git hooks** or **CI**; use each product's hooks where they fit.

---

## Copilot in depth (for Claude Code users)

This section covers GitHub Copilot's agentic features (Agent Mode, CLI, and cloud coding agent). It is **generic** and does not assume any particular employer, stack, or private workflow.

### Three agent surfaces, one config tree

| Surface | Runs where | Creates PRs? | Hooks? |
|---------|-----------|:------------:|:------:|
| **VS Code Agent** | Local, inside editor | No | Yes (all 8 events) |
| **Copilot CLI** | Local, in terminal | No | Yes (all 8 events) |
| **Cloud coding agent** | Remote (GitHub-hosted) | Yes | Yes (repo-level `.github/hooks/`) |

All three share the same instruction hierarchy (personal > repo > org) and custom agent definitions.

### Custom agents (`.agent.md`)

Agent profiles are Markdown files with YAML frontmatter:

```yaml
---
name: security-reviewer
description: Reviews code for security vulnerabilities
tools: ["read", "search", "edit"]
model: claude-opus-4-6
---
Review the code for OWASP Top 10 vulnerabilities...
```

**Scopes:** `.github/agents/` (repo), org `.github/agents/` (org), `~/.copilot/agents/` (personal). Standard tool aliases: `execute`, `read`, `edit`, `search`, `agent`, `web`, `todo`.

### Hooks (Preview, 8 event types)

Configured in `.github/hooks/*.json` (workspace) or `~/.copilot/hooks/` (user-level):

| Event | Can Block? | Notes |
|-------|:----------:|-------|
| `SessionStart` | No | Session initialization |
| `UserPromptSubmit` | Yes (exit 2) | Before prompt reaches model |
| `PreToolUse` | Yes (deny/ask/allow) | Most powerful -- can modify inputs |
| `PostToolUse` | No | Post-processing |
| `PreCompact` | No | Before context compaction |
| `SubagentStart` | Yes | When subagent spawns |
| `SubagentStop` | No | When subagent completes |
| `Stop` | No | Session ends |

### Copilot Memory

- **Repo-scoped**: memories are tied to a repository, shared across all users with access
- **Auto-validated**: before reuse, Copilot checks each memory against the current branch
- **28-day expiry**: auto-deleted if not reused; reuse extends the window
- **Surfaces**: cloud agent, code review, CLI. Not yet in regular IDE chat.
- **Separate from VS Code local memory** (`~/.copilot/`), which persists per-user across workspaces

### Permissions and firewall

- **Agent profiles**: `tools: [...]` whitelist per agent
- **Cloud firewall** (GA April 2026): recommended allowlist for network access, org-admin configurable
- **PreToolUse hooks**: programmatic deny/ask/allow per tool invocation
- **CLI sandbox**: not yet shipped (feature request open)

### Cross-session context

Copilot reads `CLAUDE.md` and `AGENTS.md` files at workspace root for cross-tool compatibility. The [memory-template/](memory-template/) pattern works if you teach your agent profiles to read/update the files.

---

## Cursor in depth (for Claude Code users)

This section is **generic**: adapt paths, repo names, and policies to your own team. It does not assume any particular employer, stack, or private workflow.

### Same app, two configs (common confusion)

You can run **Claude Code inside Cursor** *and* use **Cursor's own Agent / Chat**. They are different runtimes:

| Runtime | Typical config home | This blueprint maps to... |
|--------|---------------------|-------------------------|
| **Claude Code** (extension or CLI) | `~/.claude/` | Agents, skills, hooks, `settings.json` as documented in this repo |
| **Cursor native Agent** | `~/.cursor/` (+ Settings UI) | User Rules, `~/.cursor/skills/`, `cli-config.json`, `permissions.json`, `mcp.json` |

**Nothing auto-syncs** between those trees. If you want the same MCP servers in both, define them in **each** place (or script a small sync check). Same idea for "habit" rules: duplicate or split intentionally (global User Rules vs project `.mdc`).

### Skills on Cursor Agent

To reuse the **idea** of this blueprint's skills (load-session, review, deploy-check, etc.) under Cursor's Agent:

- Add folders under **`~/.cursor/skills/<skill-name>/SKILL.md`** with YAML frontmatter (`name`, `description`, ...) as Cursor documents.
- **Optional:** On one machine, **directory junctions** (Windows) or **symlinks** (macOS/Linux) from `~/.cursor/skills/foo` -> `~/.claude/skills/foo` avoid maintaining two copies -- but **edits apply to both**; do not "fix for Cursor only" inside a shared file without affecting Claude Code.

### Permissions (`cli-config.json`)

Cursor's permission system has two layers: **`cli-config.json`** (tool allowlists for the Agent CLI) and **`permissions.json`** (unified editor + CLI permissions with sandbox modes). If the Agent refuses or always asks approval for basic work, your allowlist may be very narrow. Expanding `permissions.allow` (e.g. broader `Shell(*)` / read/write patterns) is a **conscious security and ergonomics tradeoff** -- pair with **git hooks** or team policy for anything that must never happen (e.g. pushes to protected branches). See [Cursor permissions docs](https://cursor.com/docs/reference/permissions) for sandbox modes and granular domain allowlisting.

### Hooks (`hooks.json`)

Cursor hooks are configured in a project-level or global `hooks.json` (not `settings.json`):

```json
{
  "version": 1,
  "hooks": {
    "beforeShellExecution": { "command": ["bash", "hooks/block-git-push.sh"] },
    "afterFileEdit": { "command": ["bash", "hooks/notify-file-changed.sh"] },
    "stop": { "command": ["bash", "hooks/security-check.sh"] }
  }
}
```

### When Claude hooks have no 1:1 equivalent

Some blueprint hooks (session injection, post-edit nudges, stop-time review) are **Claude Code-specific**. On Cursor you typically **combine**:

- **User Rules** -- e.g. "before finishing a change, self-check security and verification" (behavioral, not as strict as an external hook).
- **Git hooks** -- e.g. `pre-push` for branch policy (works for human and any AI).
- **Cursor hooks** (where available) -- wire only what your Cursor version supports; verify in official docs.
- **CLI limitation** -- if you use Cursor's CLI, only shell-related hooks fire. Other hooks (`afterFileEdit`, `stop`, `beforeSubmitPrompt`, etc.) require the IDE.

### Cross-session context without vendor "memory"

The [memory-template/](memory-template/) pattern (a **small private git repo** with markdown like `session.md`, decisions, reminders) works for **any** tool: any agent that can read files can load it when you ask. Automation differs: only your **skills / rules** define when that happens -- there is no single universal auto-load unless you configure it per tool.

---

## Translating the Blueprint

### 1. Behavioral Rules (Every Tool Has This)

This is the most portable concept. Every AI coding tool reads a project-level instruction file.

**Claude Code** -> `CLAUDE.md` in project root

**Copilot** -> Combine as needed:

1. **Repository:** `.github/copilot-instructions.md` (always-on) and `.github/instructions/*.instructions.md` (with optional `applyTo` globs).
2. **Personal:** `~/.copilot/instructions/*.md` (highest priority, user-only).
3. **Organization:** Org's `.github` repo (GA April 2026, admin-managed).
4. **Cross-tool:** Also reads `AGENTS.md` and `CLAUDE.md` at workspace root.

**Cursor** -> Combine as needed:

1. **Project:** `.cursor/rules/*.mdc` with frontmatter (`globs`, `alwaysApply`, `description`).
2. **Global:** Cursor **Settings -> Rules** (User Rules) for habits you want in every repo.

```markdown
---
description: Verify after completing any implementation
globs: ["**/*.ts", "**/*.tsx"]
alwaysApply: true
---
After finishing any implementation, always run a verification step...
```

Note: `.cursorrules` (root file) is deprecated but still works. The `.mdc` format supports glob-scoped activation.

**Cline** -> `.clinerules/` directory at project root with `.md` and `.txt` files. Also reads `.cursorrules`, `.windsurfrules`, and `AGENTS.md` for cross-tool compatibility. Global rules in `~/Documents/Cline/Rules/`. A toggleable Rules panel lets you enable/disable individual rule files per session.

**Roo Code** -> `.roo/rules/` directory with optional mode-specific subdirectories (`.roo/rules-code/`, `.roo/rules-architect/`). Global rules in `~/.roo/rules/`. Also reads `.clinerules` (legacy) and `AGENTS.md`. Supports import/export of modes + rules as portable YAML files.

**OpenCode** -> `AGENTS.md` at project root (primary). Also reads `CLAUDE.md` at both project and global levels (disable via `OPENCODE_DISABLE_CLAUDE_CODE` env var). Global rules at `~/.config/opencode/AGENTS.md`. Additional instruction files via `instructions` field in `opencode.json` (supports globs and remote URLs).

**Codex CLI** -> `AGENTS.md` (hierarchical discovery)
Codex walks from `~/.codex/AGENTS.md` (global) down through project root to CWD, loading every `AGENTS.md` it finds. `AGENTS.override.md` takes precedence at each level.

**Gemini CLI** -> `GEMINI.md` (hierarchical + imports)
Similar directory walk from `~/.gemini/GEMINI.md` (global) to project root (`.git` boundary). Supports `@file.md` imports for splitting large files into modules.

**Amazon Q** -> `.amazonq/rules/*.md` (project only)
Markdown files in `.amazonq/rules/` with subdirectory support. Priority levels (Critical/High/Medium/Low) expressed in markdown body. **No global rules yet** (feature request open).

**Windsurf** -> `.windsurf/rules/*.md` + `AGENTS.md`
Rules use frontmatter with `trigger` field (`glob`, `always_on`, `manual`). Root `AGENTS.md` files are always-on. Subdirectory `AGENTS.md` files auto-scope to that directory. Note: Windsurf was acquired by OpenAI in 2025.

**Aider** -> `CONVENTIONS.md` loaded via `--read CONVENTIONS.md` or `/read` in-chat. Marked as read-only and cached with prompt caching. Config hierarchy: `~/.aider.conf.yml` (global) -> repo root -> CWD, with later files taking priority. No native auto-discovery of rules files.

**What to copy:** Take the [CLAUDE.md](CLAUDE.md) template. Paste the rules into your tool's equivalent file(s). The content is tool-agnostic -- only the file name, split, and format change.

---

### 2. Subagents / Custom Agents (Most Tools)

Claude Code lets you create specialized subagents with their own instructions, model, and tool access.

**Copilot** -- custom agents via `.agent.md` files with YAML frontmatter (name, description, tools, model, MCP servers). Three scopes: repo, org, personal. Agents can spawn subagents via the `agent` tool alias. Cloud coding agent runs remotely and creates PRs autonomously.

**Cursor** -- two mechanisms:

1. **Built-in subagents** (e.g. review-focused tasks) invoked from the product UI / agent APIs -- check current Cursor docs for names and limits.
2. **`~/.cursor/skills/`** -- reusable workflows triggered by natural language; often easier for community members than maintaining many separate agent files.

**Cline** -- `new_task` tool (`/newtask` command) packages distilled context into a fresh task with a clean context window. Sequential handoff, not true parallel subagents. The **Cline CLI + Kanban board** (2026) runs CLI tasks in isolated worktrees for parallel execution.

**Roo Code** -- five built-in modes (Code, Architect, Ask, Debug, Orchestrator) plus unlimited custom modes with per-mode tool permissions. **Boomerang Tasks** enable the Orchestrator to delegate subtasks to specialized modes and receive results back. Modes can be packaged as portable YAML for sharing.

**OpenCode** -- built-in subagents (General, Explore) plus custom agents defined in `opencode.json` or `.opencode/agents/`. Each can have its own model, prompt, tool permissions, and temperature. Primary agents invoke subagents via the `Task` tool. Interactive wizard: `opencode agent create`.

**Codex CLI** supports subagents that spawn in parallel with independent context. Custom agents are configured via the OpenAI Agents SDK with model/instruction overrides.

**Gemini CLI** has experimental local and remote subagents with isolated context, independent history, and recursion protection.

**Amazon Q** -- custom agents defined as JSON in `.amazonq/cli-agents/` (project) or `~/.aws/amazonq/cli-agents/` (global). Each agent has its own prompt, model, tools, permissions, and hooks. `/agent generate` creates agent configs from natural language descriptions.

**Windsurf** runs up to 5 parallel Cascade agents using Git worktrees (each gets its own branch), but does not support custom subagent definitions -- they're full Cascade instances, not lightweight task-specific agents.

**Aider** -- single-agent tool with no subagent support. Third-party MCP servers (e.g. `aider-mcp-server`) allow other tools to delegate to Aider, but Aider itself does not spawn sub-agents.

**What to copy:** The agent `.md` files from this blueprint can be adapted as **skill bodies** under `~/.cursor/skills/`, `.agent.md` profiles for Copilot, agent configs for Amazon Q / OpenCode, or as instruction sets for Codex/Gemini subagents. The pattern -- separate concerns for architecture, implementation, review, and testing -- is tool-agnostic.

---

### 3. Lifecycle Hooks

Hooks are deterministic automation that fires on specific events (before/after file edits, shell commands, session start/end, etc.).

**Claude Code** has a broad hook system: SessionStart, PreToolUse, PostToolUse, PostToolUseFailure, PreCompact, PostCompact, Stop, SessionEnd -- with matchers for specific tools.

**Copilot** has 8 hook events (Preview): SessionStart, UserPromptSubmit (blocking), PreToolUse (deny/ask/allow with input modification), PostToolUse, PreCompact, SubagentStart (blocking), SubagentStop, Stop. Configured in `.github/hooks/*.json` (workspace) or `~/.copilot/hooks/` (user-level).

**Cursor** has ~11 hook types configured via `hooks.json` (executables run outside the model): `beforeShellExecution`, `afterShellExecution`, `beforeMCPExecution`, `afterMCPExecution`, `beforeReadFile`, `afterFileEdit`, `beforeTabFileRead`, `afterTabFileEdit`, `beforeSubmitPrompt`, `afterAgentResponse`, `afterAgentThought`, and `stop`. Cursor also has hooks Claude Code lacks (e.g. `beforeSubmitPrompt`, `afterAgentResponse`). **CLI caveat:** the Cursor CLI currently only fires `beforeShellExecution` and `afterShellExecution`; other hooks require the IDE. Verify available hooks against [Cursor docs](https://cursor.com/docs/hooks) for your version.

**Cline** has 8 hook types: TaskStart, TaskResume, TaskCancel, TaskComplete, PreToolUse (blocking), PostToolUse, UserPromptSubmit, PreCompact. Global hooks in `~/.cline/hooks/`, workspace hooks in `.clinerules/hooks/`. Communicate via JSON stdin/stdout with 30-second timeout. Can inject context modifications into the prompt.

**OpenCode** has 20+ hook events via a plugin system (JS/TS modules in `.opencode/plugins/`): tool execute before/after, session created/compacted/deleted/idle/error, file edited, message updated, permission asked/replied, command executed, LSP diagnostics, TUI events. Plugins can also register custom tools.

**Amazon Q** supports 5 hook triggers in custom agents: `agentSpawn` (initialization), `userPromptSubmit` (per message), `preToolUse` (with matcher), `postToolUse` (with matcher), and `stop`. Output persists in session context for spawn hooks; current prompt only for submit hooks.

**Codex CLI** has a `userpromptsubmit` hook that can block/augment prompts before execution. No file-edit or shell-execution lifecycle hooks.

**Gemini CLI** has experimental hooks for session context injection and active-agent tracking. Behind a toggle.

**Windsurf** has Cascade Hooks for logging and policy enforcement -- enterprise/teams only, not general-purpose.

**Roo Code** does not have a built-in lifecycle hook framework. Tool restrictions are handled via mode-based tool groups and file regex patterns.

**Aider** does not support lifecycle hooks. An open feature request exists but has no implementation.

**What to copy:** The hook *scripts* in this blueprint (`protect-config.sh`, `block-git-push.sh`, etc.) can be repurposed as:

- **Git hooks** (`pre-push`, `post-commit`) that work with **any** editor or AI
- **Copilot hooks** (`.github/hooks/`) or **Cursor hooks** (`hooks.json`) or **Cline hooks** (`.clinerules/hooks/`) where your version supports a matching event
- **OpenCode plugins** (`.opencode/plugins/`) for the broadest event coverage
- **Amazon Q agent hooks** for custom agent lifecycle control
- **CI checks** for environments without editor hooks

---

### 4. Memory Persistence (Varies Significantly)

**Claude Code** has dual memory: auto-memory (`~/.claude/projects/*/memory/MEMORY.md`) + the git-backed pattern in this blueprint's [memory-template/](memory-template/).

**Copilot** has two memory systems. **Copilot Memory** (public preview) is repo-scoped, shared across users, auto-validated against the current branch, and auto-deleted after 28 days if not reused. Available in cloud agent, code review, and CLI -- not yet in regular IDE chat. **VS Code local memory** (`~/.copilot/`) persists per-user across workspaces with the first 200 lines auto-loaded at session start.

**Cursor** briefly had a "Memories" feature but **removed it** starting v2.1.x. Users were told to export memories into Rules files. No built-in cross-session persistence. Community workarounds exist via MCP servers (Memory Banks, ContextForge) or a **private markdown/git "session log"** repo that agents read when instructed.

**Cline** uses a **Memory Bank** pattern -- structured markdown files (`projectbrief.md`, `productContext.md`, `activeContext.md`, `systemPatterns.md`, `techContext.md`, `progress.md`) stored in a `memory-bank/` directory. This is a **methodology, not a built-in feature** -- configured via custom instructions in `.clinerules`. Community MCP servers formalize this as a tool-based approach. **Checkpoints** (shadow Git snapshots) preserve code state but not knowledge.

**Roo Code** has no built-in memory. Community MCP servers (Roo Code Memory Bank) and the Memory Bank methodology work the same way as Cline's approach. **Checkpoints** restore both file state and conversation state.

**OpenCode** persists sessions via SQLite (close and resume). Cross-session memory requires community plugins: `open-mem`, `opencode-supermemory`, or `opencode-agent-memory` (global + project scoped). Context compaction (automatic summarization) is built-in.

**Codex CLI** saves session transcripts to `~/.codex/history.jsonl`. `codex resume` reopens earlier threads with same state. This is transcript replay, not semantic memory.

**Gemini CLI** has a `save_memory` tool that appends facts to `~/.gemini/GEMINI.md` under a `## Gemini Added Memories` section. Loaded automatically in subsequent sessions. Note: this writes directly into the same file used for instructions -- a known limitation.

**Amazon Q** supports `q chat --resume` (auto-loads previous conversation by working directory), `/save [path]` and `/load [path]` (explicit JSON save/load), and `/compact` (context summarization). No cross-session semantic memory -- persistence is conversation replay. Feature request for persistent memory is open.

**Windsurf** auto-generates memories during conversations, stored in `~/.codeium/windsurf/memories/`. Workspace-scoped, persists across sessions. Users can also write durable facts to `.windsurf/rules/` files.

**Aider** stores full chat transcripts in `.aider.chat.history.md`. `--restore-chat-history` replays previous messages when starting a new session (disabled by default). Chat history has a soft token limit after which summarization kicks in via the weak model. No semantic memory or knowledge graph.

**What to copy:** The [memory-template/](memory-template/) pattern works with **any** tool:

1. Create a **separate private** git repo for your memory data (not in your public blueprint fork if it contains secrets).
2. Teach your **rules or skills** to read/update agreed files (e.g. session summary, decisions) when you start or end work.
3. Only Claude Code can wire some of this to **hooks** automatically; elsewhere, a short **User Rule**, **skill**, or **agent instruction** replaces "on session start, load X."

---

### 5. Model Tiering (Partially Portable)

Claude Code lets you assign different models to different agents via frontmatter (`model: opus`, `model: sonnet`, `model: haiku`).

**Copilot** supports per-agent model selection via the `model` field in `.agent.md` frontmatter. Multi-model picker includes OpenAI, Anthropic, and Google models. BYOK (Bring Your Own Key) allows adding custom providers. **Auto mode** selects the best available model automatically.

**Aider** has the most granular tiering: **main model** (primary reasoning), **weak model** (commit messages, summarization), and **editor model** (translates proposals into file edits in architect mode). You can pair an expensive model for architecture with a cheap model for editing -- e.g. o1-preview as architect with Deepseek as editor. Switch models mid-session with `/model`.

**OpenCode** supports per-agent and per-command model overrides. 75+ models across OpenAI, Anthropic, Google, AWS Bedrock, Groq, Azure, OpenRouter, and local models. Built-in model variants for thinking levels (reasoning effort settings).

**Roo Code** has **Sticky Models** -- each mode automatically remembers the last model used with it. Different modes can use different models without reconfiguration (e.g. cheap model for Ask mode, premium for Code mode). Supports 30+ providers.

**Cline** supports **Plan/Act separate model selection** -- maintains independent model selections for planning vs implementation. Allows using a budget model for planning and a premium model for code changes.

**Codex CLI** supports per-config model overrides, making it a flexible option for tiering.

**Other tools:** Cursor lets you select a model globally or per chat. Amazon Q currently offers single model per session (Claude Sonnet variants only). Gemini CLI and Windsurf do not support per-task model selection.

The *principle* still applies regardless of tool:

- Use the strongest model for architecture and planning
- Use a balanced model for implementation and review
- Use the cheapest model for documentation

---

### 6. Path-Scoped Rules (Most Tools Support This)

Loading different instructions for different parts of the codebase.

| Tool | Mechanism |
|------|-----------|
| **Claude Code** | `paths:` frontmatter in `.claude/rules/*.md` |
| **Copilot** | `applyTo:` globs in `.github/instructions/*.instructions.md` |
| **Cursor** | `globs:` in `.cursor/rules/*.mdc` |
| **Cline** | `paths:` YAML frontmatter with glob patterns in `.clinerules/*.md` |
| **Codex CLI** | Directory walk -- `AGENTS.md` in any subdirectory scopes to that tree |
| **Gemini CLI** | Directory walk -- `GEMINI.md` in subdirectories scopes automatically |
| **Windsurf** | `trigger: glob` in `.windsurf/rules/*.md` frontmatter |
| **OpenCode** | Community plugin (`opencode-rules`); `instructions` field supports globs |
| **Roo Code** | Mode-based file regex (`.roomodes` groups config), not path-scoped rules |
| **Amazon Q** | Not natively supported; agent `resources` support `file://` globs |
| **Aider** | Not supported -- rules load globally into context |

---

## The Universal Takeaways

Regardless of which tool you use, these principles from the blueprint apply everywhere:

1. **Write your rules down.** Every tool has a rules file (and often global + project layers). Use them.
2. **Enforce, don't suggest.** Use hooks where they exist, **git hooks** or **CI** for rules that must hold no matter which AI or human runs the command.
3. **Scope your context.** Don't load everything into every session. Organize by domain (path-scoped rules, separate skill descriptions).
4. **Verify outputs.** Never trust "done" without checking the actual result. Tool-agnostic.
5. **Track decisions.** An append-only decision log prevents "why did we do this?" across sessions.
6. **Match model to task.** Use capable models for hard problems, cheaper models for routine work.
7. **Separate enforcement from guidance.** Things that MUST happen need hooks/CI. Things that SHOULD happen go in rules and skills.

---

*This guide reflects the state of these tools as of April 2026. AI coding tools evolve rapidly -- features marked "experimental" or "Preview" may stabilize or change. Always confirm hook names, skill folders, and Settings paths against the vendor docs for your installed version.*
