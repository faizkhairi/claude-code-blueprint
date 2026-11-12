# Agents

12 specialized subagents with model tiering, permission modes, and persistent memory. Worktree isolation is documented as an option, but no shipped agent uses it.

> **Framework-agnostic by design.** These agents adapt to any stack. Each one reads your `CLAUDE.md` and detects the project from its manifest (`package.json`, `composer.json`, `pom.xml`, `Gemfile`, `*.csproj`, `go.mod`, `Cargo.toml`, `pyproject.toml`, ...), so the same roster serves a Laravel, Spring Boot, Rails, Django, Go, .NET, or Node project. Where an example names a specific tool, it is an example, not a requirement.

## When to Use an Agent vs a Skill vs the Main Thread

This is the most important page in the repo, and the easiest to skip. Copying 12 agent files is not the goal: *knowing which to reach for, and wiring only those, is.* An agent you never invoke is dead weight: it adds nothing and quietly implies your setup does more than it does.

Use this table to decide where a piece of work belongs:

| Reach for a... | When the work is... | Because |
|---|---|---|
| **Main thread** (no delegation) | Quick, one-off, needs your full session context, or is the "thinking" itself | Spawning a subagent costs context-setup and loses your session history. Most work stays here. |
| **Skill** | A repeatable *procedure* you trigger by phrase ("review this", "cut a changelog"), same steps each time | Skills are cheap, deterministic-ish recipes. They can *orchestrate* agents but don't need their own context window. |
| **Agent (subagent)** | A bounded task that benefits from an *independent context window*, a *different model tier*, or *read-only isolation* (by intent, see [Permission Modes](#permission-modes)): bulky search, a focused review, parallel fan-out | Agents get a clean context and can run in parallel. Worth it when the task is big enough that isolation pays for the setup cost. |
| **Hook** | Something that must happen *every single time*, no exceptions (block a push, scan for secrets, checkpoint state) | Hooks are deterministic shell scripts: they fire 100% of the time and cannot be skipped by the model. See [../hooks/](../hooks/). |

**The rule that keeps a roster healthy: wire it, don't just define it.** An agent only fires if something *invokes* it: a skill that spawns it, a rule that calls for it, or you asking by name. In this repo, exactly one skill wires agents automatically: `review-full` spawns `code-reviewer`, `security-reviewer`, `db-analyst`, and `architecture-reviewer` by what changed. Every other agent is invoked deliberately, by you, when the moment calls for it. That is intentional, since a build pipeline that fits a Node app does not fit a Rust one, so we ship the agents and the *pattern*, not a hard-wired flow you would have to unpick.

**How to right-size for yourself:** start from zero wired agents. Add the ones your actual work reaches for (watch which you invoke by hand over a week), and wire those into the skill where they naturally belong: copy the "spawn agents" step from [`review-full`](../skills/review-full/SKILL.md) and name the agent by `subagent_type`. Delete the agents you never touch. A lean, wired roster beats a large, inert one every time.

Anthropic's own guidance leans skill-heavy for exactly this reason, since skills are cheaper to keep and easier to trigger than agents. Treat 12 as a menu, not a checklist.

## The Standard Agent Pattern

Every agent follows this structure:
1. **Frontmatter**: name, description, model, tools, maxTurns, permissionMode, memory (see [Frontmatter fields](#frontmatter-fields))
2. **Role statement**: 1-2 sentences establishing expertise
3. **Context loading**: "Before starting work: read CLAUDE.md, check the project manifest, search patterns"
4. **Responsibilities**: Specific, numbered, actionable items
5. **Best practices**: Domain-specific guidelines
6. **Memory guidance**: "Consult before / update after"

## Model Assignment

| Agent Type | Model | Rationale |
|-----------|-------|-----------|
| Architecture/planning | opus | Needs strongest reasoning for multi-system design |
| Implementation/review | sonnet | Balanced quality for iterative code work |
| Structural review | sonnet | Analyzes architecture without the cost of opus for pattern-matching |
| Documentation | haiku | Straightforward prose, cost-efficient |

The agent files use the aliases `opus`, `sonnet`, and `haiku`, which resolve to the newest version of each family. Today that is Opus 5.5 (`claude-opus-5-5`), Sonnet 5.5 (`claude-sonnet-5-5`), and Haiku 5.5 (`claude-haiku-5-5`), so the files need no change when a new generation ships. Fable 5.2 (`claude-fable-5-2`, alias `fable`) is an optional top tier for the hardest long-running tasks. Set `model: fable` on an agent if you want it there. No shipped agent does.

## Frontmatter fields

Subagent files are Markdown with YAML frontmatter. Only `name` and `description` are required. Full reference: [Claude Code subagent docs](https://code.claude.com/docs/en/sub-agents).

| Field | What it does |
|-------|--------------|
| `name` | Unique identifier (hooks receive it as `agent_type`). |
| `description` | When Claude should delegate to this subagent. |
| `tools` | Tools the subagent can use (comma-separated string or YAML list). Inherits all if omitted. |
| `disallowedTools` | Tools to remove from the inherited or specified list. |
| `model` | `sonnet`, `opus`, `haiku`, `fable`, a full model ID such as `claude-opus-5-5`, or `inherit`. |
| `permissionMode` | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, or `manual` (alias for `default`). See [Permission Modes](#permission-modes). |
| `maxTurns` | Maximum agentic turns before the subagent stops. |
| `skills` | Skills to preload at startup. The full skill content is injected, not only the description. |
| `mcpServers` | MCP servers available to this subagent: a configured server name or an inline definition. |
| `hooks` | Lifecycle hooks scoped to this subagent. |
| `memory` | Persistent memory scope: `user`, `project`, or `local`. |
| `background` | `true` keeps the subagent in the background even when Claude asks to wait for it. |
| `effort` | `low`, `medium`, `high`, `xhigh`, or `max` (available levels depend on the model). Overrides the session effort level, but not the `CLAUDE_CODE_EFFORT_LEVEL` environment variable. |
| `isolation` | `worktree` runs the subagent in a temporary git worktree. See [Worktree Isolation](#worktree-isolation). |
| `color` | Display color in the task list and transcript. |
| `initialPrompt` | Auto-submitted as the first user turn when the agent runs as the main session agent (`--agent` or the `agent` setting). |

### Which model a subagent runs on

Claude Code resolves the model in this order:

1. The per-invocation `model` parameter (an alias, passed on the Agent tool call)
2. The `model` frontmatter (`inherit` selects the main conversation's model)
3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable
4. The main conversation's model

`CLAUDE_CODE_SUBAGENT_MODEL` is only a default. To apply one model to every subagent, also set `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` to `1`, which makes Claude Code ignore the `model` field in subagent definitions.

## Permission Modes

| Mode | Agents | Why |
|------|--------|-----|
| `default` (explicit) | backend, frontend, qa-tester, project-architect, docs-writer | Need write access to implement or generate. Frontmatter declares `permissionMode: default` explicitly for clarity. |
| `plan` | verify-plan, code-reviewer, security-reviewer, db-analyst, devops-engineer, architecture-reviewer, memory-curator | Read-only analysis by intent, should not modify files. (memory-curator uses Write only to emit its health report.) |

Note: `permissionMode: plan` is read-only only when the main session runs in `default` (Manual) or `dontAsk` mode. A subagent inherits the main conversation's permission mode: when the main session is in `bypassPermissions`, `acceptEdits`, or `auto` mode, the agent runs in that mode and its own `permissionMode` is ignored (see the [subagents docs](https://code.claude.com/docs/en/sub-agents)). The `memory` field also enables Read, Write and Edit automatically, so `tools:` cannot remove Write and Edit from the agents here that set `memory` (everything except verify-plan). A PreToolUse hook keyed on `agent_type` is the enforceable guard (a hook-based guard is planned for v1.3.0). If an agent omits `permissionMode`, it inherits the main conversation's mode. We declare `permissionMode: default` explicitly on write-access agents to make the intent visible in the frontmatter.

## Worktree Isolation

`isolation: worktree` creates a temporary git worktree so an agent that WRITES files works on an isolated copy and cannot disturb the main working tree. It requires a git repository at the workspace root; if the Claude Code root is a non-git parent directory (for example, one folder holding several project repos), worktree creation fails and the agent cannot start.

**None of the review agents use worktree.** `verify-plan`, `code-reviewer`, `security-reviewer`, and `architecture-reviewer` are read-only by intent (`Read`, `Grep`, `Glob` under `permissionMode: plan`, subject to the condition above), so worktree isolation would guard against writes they can never make while adding a git-root requirement for no benefit. The property that actually gives them unbiased "cold" review is the fresh CONTEXT WINDOW every subagent gets, not a fresh checkout: a read-only agent reads the same committed files whether or not it sits in a worktree. Removing the pin lets these agents run at any workspace root, git or not.

**When to use worktree**: reserve `isolation: worktree` for an agent that actually mutates files and could otherwise collide with the main session. For a read-only reviewer it is unnecessary.

## Named Subagents

Agents can be given a `name` parameter when spawned, making them addressable via `SendMessage({to: name})` and visible in `@` mention typeahead. This is useful for long-running background agents or multi-agent coordination where you need to send follow-up instructions to a specific agent.

## What Happens When maxTurns Is Reached

Each agent has a `maxTurns` limit in its frontmatter that caps the number of tool calls + responses. When reached, the agent stops gracefully. Any work already written to disk (file edits, test runs, commits) persists.

| Agent | Model | maxTurns |
|-------|-------|----------|
| project-architect | opus | 30 |
| backend-specialist | sonnet | 25 |
| frontend-specialist | sonnet | 25 |
| qa-tester | sonnet | 25 |
| db-analyst | sonnet | 20 |
| devops-engineer | sonnet | 20 |
| code-reviewer | sonnet | 15 |
| security-reviewer | sonnet | 15 |
| docs-writer | haiku | 15 |
| architecture-reviewer | sonnet | 20 |
| verify-plan | sonnet | 3 |
| memory-curator | sonnet | 25 |

**If an agent stops mid-task:**
1. Check what was completed: `git diff` for file changes, `git status` for uncommitted work
2. Spawn a new agent of the same type with context: "Continue the previous agent's work. Here is what was done so far: [summary]"
3. Or continue the work manually in the main session

## Relative Cost by Model Tier

Cost depends on task complexity, turns used, and the model tier. Relative ordering per token:

| Model Tier | Agents | Relative cost |
|-----------|--------|---------------|
| Opus | project-architect | Most expensive |
| Sonnet | backend, frontend, qa-tester, db-analyst, devops, code-reviewer, security-reviewer, architecture-reviewer, verify-plan, memory-curator | Mid |
| Haiku | docs-writer | Cheapest |

Prices change, so check current rates rather than trusting a figure copied into a README: [claude.com/pricing](https://claude.com/pricing) for plans and [API pricing](https://platform.claude.com/docs/en/about-claude/pricing) for per-token rates. The [cost-tracker.sh](../hooks/cost-tracker.sh) hook logs session costs to `~/.claude/metrics/costs.jsonl` for actual spending data.

## Agents Are Not Infallible

Agents are powerful but imperfect. Common failure modes:

- **Hallucination**: An agent may reference files, functions, or APIs that do not exist. Always verify with `git diff` (for write agents) or manual inspection (for analysis agents).
- **Stale context**: Agents cannot see the main session's full history. They may repeat work or miss earlier decisions.
- **Overconfidence**: An agent that says "all checks pass" may not have actually run all checks. Verify critical claims.
- **Read-only safety**: Agents with `permissionMode: plan` (verify-plan, code-reviewer, security-reviewer, db-analyst, devops-engineer, architecture-reviewer, memory-curator) are intended to analyze and report rather than modify source files. This is a safety feature, not a limitation, but it holds only when the main session runs in `default` or `dontAsk` mode, and agents that set `memory` can still write (see Permission Modes). (memory-curator is the one exception that uses Write, and only to emit its own health-report file.)

**Rule of thumb:** Trust agents for research and drafting. Verify before committing their output.

## Why Agents Might Ignore Instructions

CLAUDE.md rules and agent instructions are guidance, not guarantees. They are followed most of the time, at a high rate, but not absolute. Reasons agents may deviate:

- **Context window limits**: Long or complex instructions may get compressed during context management, reducing attention to specific rules.
- **Competing instructions**: If multiple sources (CLAUDE.md, agent frontmatter, user prompt) give conflicting guidance, the agent resolves the conflict unpredictably.
- **Probabilistic behavior**: Language models are inherently probabilistic. The same instruction may be followed 9 out of 10 times but missed on the 10th.
- **Task complexity**: On complex multi-step tasks, agents may optimize for completing the task over following every peripheral instruction.

**For behaviors that MUST happen every time**, use [hooks](../hooks/) instead. Hooks are deterministic shell scripts that fire 100% of the time; they cannot be ignored or overridden by the AI.
