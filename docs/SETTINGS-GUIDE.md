# Settings Guide

Companion to [settings-template.json](../examples/settings-template.json). Every setting explained with context, defaults, and rationale.

---

## Environment Variables

These live under the `"env"` key in `settings.json` and control Claude Code's runtime behavior.

### CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

```json
"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

(Optional opt-in example. The template does not set it.)

**What it does:** Enables the separate, experimental [agent teams](https://code.claude.com/docs/en/agent-teams) feature: one lead session coordinates several teammate sessions through a shared task list. It is not needed for subagents.

**Subagents do not need it:** The Agent tool, `subagent_type`, and everything in the [agents/](../agents/) directory of this blueprint work without any env flag, including skills that fan out to several agents in parallel (like the review-full skill).

**Side effect:** While agent teams are on, a subagent that Claude names launches as a teammate instead of a subagent. If your agents behave differently than documented, check that this flag is not set.

**Cost:** Teams use significantly more tokens than a single session.

**Default:** Not set (disabled), and not set by the template.

**Who needs it:** Only people who want to try agent teams. Everyone else can leave it unset.

### CLAUDE_AUTOCOMPACT_PCT_OVERRIDE

```json
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
```

**What it does:** Triggers context compaction when the context window is 80% full, instead of Claude's default threshold (higher).

**Why 80%:** Compaction is aggressive: it summarizes and discards earlier context. By triggering it earlier, you give the PreCompact hook more room to serialize working state (active plan, modified files, current branch) to disk before context is lost. See [WHY.md](WHY.md#compaction-recovery-why-state-serialization) for the battle story.

**Default:** Claude's built-in threshold (not publicly documented, but higher than 80%).

**Trade-off:** Lower = more frequent compaction (loses context sooner) but safer state preservation. Higher = more context retained but hooks may not fire in time.

### CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS

```json
"CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS": "5000"
```

**What it does:** Gives SessionEnd hooks 5 seconds to complete before the Claude Code process exits.

**Why 5 seconds:** The default timeout is lower. Hooks like `session-checkpoint.sh` write state to disk and may need a moment to complete. Without enough time, the hook gets killed mid-write, leaving incomplete or corrupt checkpoint files.

**Default:** Lower than 5000ms (varies by version).

### CLAUDE_CODE_SUBPROCESS_ENV_SCRUB

```json
"CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1"
```

**What it does:** Strips sensitive environment variables (ANTHROPIC_API_KEY, AWS credentials, cloud tokens) from subprocess environments: hooks, MCP servers, and Bash commands.

**Why it matters:** Without this, any subprocess Claude spawns inherits your full environment, including API keys. A malicious or buggy MCP server could read your Anthropic API key from its own environment.

**Default:** Not set (subprocesses inherit all env vars).

**Who needs it:** Everyone running MCP servers or custom hooks. Minimal risk to enable, since your hooks and MCP servers almost never need your Anthropic API key.

### CLAUDE_CODE_NO_FLICKER

```json
"CLAUDE_CODE_NO_FLICKER": "1"
```

**What it does:** Enables flicker-free alt-screen rendering with virtualized scrollback. Eliminates visual flicker during streaming responses.

**When to use:** If you experience screen flashing or flickering during Claude's responses, especially in certain terminal emulators (iTerm2, tmux, WezTerm). Has no downside; safe to enable always.

**Default:** Not set (standard rendering).

---

## Top-Level Settings

### cleanupPeriodDays

```json
"cleanupPeriodDays": 60
```

Auto-deletes Claude Code session data older than 60 days. This includes conversation logs and temporary files, not your project code, hooks, or agents.

**Default:** Check Claude Code docs for the current default. 60 days is a reasonable balance between disk usage and being able to reference old sessions.

### includeGitInstructions

```json
"includeGitInstructions": false
```

**What it does:** When `true`, Claude Code injects default git usage instructions into every session's context. When `false`, those instructions are suppressed.

**Why false:** This blueprint provides its own git rules via [CLAUDE.md](../CLAUDE.md) (Diagnose-First Rule checks `git status` first) and hooks (`block-git-push.sh` prevents accidental pushes). The default instructions conflict with these custom rules and waste context tokens.

**When to set true:** If you're not using custom git rules and want Claude's default git behavior.

### alwaysThinkingEnabled

```json
"alwaysThinkingEnabled": true
```

**What it does:** Claude uses extended thinking (chain-of-thought reasoning) on every response, not just when the task seems complex.

**Trade-off:** Better reasoning quality, especially for subtle bugs and architectural decisions. Costs more tokens per response (thinking tokens are billed). For simple tasks like "rename this variable," extended thinking is overkill, but the quality improvement on complex tasks outweighs the cost.

### showThinkingSummaries

```json
"showThinkingSummaries": true
```

**What it does:** Shows summarized thinking output in the UI. Since v2.1.89, thinking summaries are **off by default**: you must opt in to see them.

**Why it changed:** Most users found summaries noisy during normal coding. Disabling them by default keeps the output clean while `alwaysThinkingEnabled` still gives Claude full reasoning depth behind the scenes.

**When to set true:** If you like seeing Claude's reasoning process, or if you're debugging why Claude made a particular decision. Pairs well with `alwaysThinkingEnabled: true`.

**Default:** `false` (since v2.1.89).

### effortLevel

The template does not set `effortLevel`. A top-level `effortLevel` in user settings is ignored for Opus 5.5 and later (Opus 5.5 starts at `medium`) and still applies to older models. See [model configuration](https://code.claude.com/docs/en/model-config).

**How to set effort now:** Run `/effort`, which saves the level per model under the `modelSettings` key. Subagents and skills can also set `effort` in their frontmatter.

**Options:** `low`, `medium`, `high`, `xhigh` (`max` is not accepted in settings). Lower effort = faster, cheaper responses. Higher effort = more thorough reasoning.

**Recommendation:** Raise effort for hard development work. Lower it for repetitive tasks like bulk file edits or documentation generation.

### disableSkillShellExecution

```json
"disableSkillShellExecution": true
```

**What it does:** Prevents skills and custom slash commands from executing shell commands inline. Skills can still instruct Claude to use the Bash tool (which goes through normal permission checks), but they cannot embed shell execution directly.

**When to use:** Security-conscious teams that want skills to suggest commands but not execute them autonomously. Also useful when onboarding new skills from the community that you haven't fully reviewed.

**Default:** `false` (skills can execute shell commands).

---

## Permissions

### defaultMode

Claude Code has six permission modes, each balancing safety against productivity (see [permission modes](https://code.claude.com/docs/en/permission-modes)):

| Mode | Behavior | Best For |
|------|----------|----------|
| `"default"` (Manual; `manual` is an alias; also what you get when unset) | Asks permission for every tool use | New users building trust |
| `"acceptEdits"` | File edits run without asking; other tools still prompt | Iterating on code you will review in the diff |
| `"plan"` | Claude researches and proposes a plan; no edits until you approve | Exploring a change before committing to it |
| `"dontAsk"` | Allow-listed tools run silently; unlisted tools are silently **denied** | CI pipelines, locked-down environments |
| `"auto"` | Allow-listed tools run silently; unlisted tools go through an **AI classifier** that evaluates safety contextually | Power users who want fewer prompts without losing safety |
| `"bypassPermissions"` | Everything runs without checks | Isolated containers/VMs only, never on a real machine |

`auto` and `bypassPermissions` do not take effect from project or local settings files (`.claude/settings.json`, `.claude/settings.local.json`); set them in user settings. The VS Code extension never reads the starting mode from project settings at all. A subagent with no `permissionMode` inherits the main conversation's mode, and a parent in `bypassPermissions`, `acceptEdits` or `auto` overrides the subagent's own value ([sub-agents](https://code.claude.com/docs/en/sub-agents)).

**Hardening keys that work in any mode** (from the [settings reference](https://code.claude.com/docs/en/settings-reference)):

| Key | Effect | Where it can be set |
|-----|--------|---------------------|
| `permissions.blockWritesOutsideWorkingDirectories` | `Write`, `Edit` and `NotebookEdit` refuse paths outside the working directories, in every mode including `bypassPermissions` (v2.1.314+). Add a directory with `/add-dir` or `additionalDirectories` to open it | Any settings file |
| `permissions.denyInsteadOfPrompting` | A tool call that would wait on a permission prompt is denied instead, so an unattended session keeps moving (v2.1.319+) | User or managed settings |
| `sandbox.enabled` | Runs Bash inside an OS sandbox (macOS, Linux, WSL2): writes limited to the working directory and temp, network only to allowed domains. Off by default; `/sandbox` turns it on. See [sandboxing](https://code.claude.com/docs/en/sandboxing) and [`sandbox.failIfUnavailable`](#sandboxfailifunavailable) below | Any settings file |

The blueprint's template sets none of these, because each changes how a session behaves in ways you should choose deliberately. `blockWritesOutsideWorkingDirectories` pairs well with `auto` or `bypassPermissions`; `denyInsteadOfPrompting` suits headless runs.

**`"auto"` mode:**

```json
"defaultMode": "auto"
```

The auto mode classifier (Sonnet 5 by default, configurable with `CLAUDE_CODE_AUTO_MODE_MODEL`) reviews each non-allow-listed action against built-in block rules (force push, data exfiltration, production deploys, `curl | bash`, etc.). It approves safe actions and blocks risky ones, no manual prompting needed.

**Key facts about auto mode:**
- Allow-listed commands bypass the classifier entirely (saves tokens and latency)
- Hooks still run regardless of mode: your `block-git-push.sh` and `protect-config.sh` remain active
- Classifier calls add token cost (small per call, but adds up in long sessions)
- If the classifier blocks actions 3 times in a row or 20 times in a session, auto mode pauses and Claude Code prompts you again
- The `PermissionDenied` hook (v2.1.89+) fires after each classifier denial: return `{retry: true}` to retry, or use it for logging/alerting

**Recommendation:**
- **New users:** Don't set this. Use the default mode until you trust your setup.
- **Power users with hooks:** `"auto"` is the sweet spot: intelligent safety without prompt fatigue. The allow list becomes a performance optimization, not a security boundary.
- **CI/CD pipelines:** `"dontAsk"` is still better here: predictable behavior, no classifier overhead.
- **Teams:** See [GETTING-STARTED.md](../GETTING-STARTED.md#setting-up-for-teams).

### autoMode.environment

When using `"auto"` mode, you can tell the classifier about your trusted infrastructure:

```json
"autoMode": {
    "environment": [
        "Organization: Your Company. Primary use: web development",
        "Source control: github.com/your-org",
        "Cloud provider(s): AWS (EC2, S3)",
        "Trusted internal domains: *.internal.example.com",
        "Key internal services: PostgreSQL, Redis, CI/CD runners",
        "Platform: macOS / Linux / Windows with Git Bash"
    ]
}
```

**What it does:** Provides context so the classifier can distinguish between "pushing to our GitHub org" (safe) and "pushing to an unknown remote" (blocked).

**Important:** Only set `environment`. Do NOT set `autoMode.allow` or `autoMode.soft_deny` unless you copy ALL defaults first: setting them **replaces the entire default list**.

**Verification:** Check your effective auto mode configuration by reviewing `~/.claude/settings.json` and any project-level overrides. Consult Claude Code's CLI reference (`claude --help`) for available auto-mode subcommands in your version.

### Team Settings (managed-settings.d/)

For teams deploying organization-wide policies, Claude Code supports drop-in settings fragments:

```
~/.claude/managed-settings.d/
  01-security-baseline.json
  02-team-conventions.json
```

Files merge alphabetically alongside `managed-settings.json`. Each fragment can enforce policies (deny rules, environment descriptions) independently. Useful when different teams need different rules.

### sandbox.failIfUnavailable

```json
"sandbox": {
    "failIfUnavailable": true
}
```

**What it does:** Exits with an error if sandboxing is enabled but the sandbox runtime can't start, instead of silently falling back to running unsandboxed. Useful in CI/CD where you want to guarantee sandboxed execution.

**Default:** false (falls back to unsandboxed if sandbox unavailable).

### Permission Categories

The `allow` list in the template is organized by category. Here's what each allows:

| Category | What It Allows | Why |
|----------|---------------|-----|
| **Git Operations** | `git status`, `git diff`, `git log`, `git add`, `git commit`, etc. | Core development workflow. Note: `git push` is intentionally absent from the allow list. The `block-git-push.sh` hook provides additional domain-level protection. |
| **Package Managers** | `npm`, `npx`, `yarn`, `pnpm`, `pip`, `pip3`, `uv`, `composer` | Installing dependencies, running scripts, executing tools. |
| **Runtimes** | `node`, `python`, `python3`, `java` | Running scripts and REPL commands for debugging. |
| **Testing + Linting** | `pytest`, `mypy`, `ruff`, `./node_modules/.bin/*` | Running test suites and linters without permission prompts. |
| **Build + Deploy** | `docker`, `vercel`, `./gradlew` | Building containers, deploying, running Gradle tasks. |
| **CLI Utilities** | `curl`, `ls`, `jq`, `chmod`, `unzip`, `echo`, `sort`, `cut`, `tr`, `tee`, `code` | Common shell utilities for investigation and scripting. |
| **Web Access** | `raw.githubusercontent.com`, `api.github.com`, `registry.npmjs.org`, `WebSearch` | Fetching files from GitHub, checking npm registry, web searches. |
| **MCP Tools** | Playwright browser tools, Context7 docs | Browser automation and documentation lookup. See [GETTING-STARTED.md](../GETTING-STARTED.md#mcp-servers-giving-claude-superpowers) for setup. |
| **Skills** | `update-config` | Allows Claude to modify settings via the update-config skill. |

### additionalDirectories

Claude Code can only read/write files in the current working directory by default. This setting grants access to additional paths, typically your `~/.claude/` directory so Claude can read/edit hooks, agents, skills, and plan files.

**Windows:**
```json
"additionalDirectories": [
  "C:\\Users\\YourUser\\.claude",
  "C:\\Users\\YourUser\\.claude\\skills",
  "C:\\Users\\YourUser\\.claude\\plans",
  "C:\\Users\\YourUser\\.claude\\agents"
]
```

**macOS:**
```json
"additionalDirectories": [
  "/Users/youruser/.claude",
  "/Users/youruser/.claude/skills",
  "/Users/youruser/.claude/plans",
  "/Users/youruser/.claude/agents"
]
```

**Linux:**
```json
"additionalDirectories": [
  "/home/youruser/.claude",
  "/home/youruser/.claude/skills",
  "/home/youruser/.claude/plans",
  "/home/youruser/.claude/agents"
]
```

Replace `YourUser` (Windows) or `youruser` (macOS/Linux) with your actual username.

> **macOS/Linux note:** Tilde expansion (`~/.claude`) is NOT supported in `additionalDirectories`; use full absolute paths.

---

## Hooks

The template configures hooks across 8 lifecycle events. For the full lifecycle diagram, see [ARCHITECTURE.md](ARCHITECTURE.md). For battle stories explaining why each hook exists, see [WHY.md](WHY.md).

| Event | Hook | Purpose |
|-------|------|---------|
| **SessionStart** | `session-start.sh` | Injects workspace context at the beginning of each session |
| **PreToolUse** (Bash) | `block-git-push.sh` | Blocks `git push` to protected remotes |
| **PreToolUse** (Write/Edit) | `protect-config.sh` | Prevents modifying linter/build configs |
| **PostToolUse** (Write/Edit) | `notify-file-changed.sh` | Reminds Claude to verify after file changes |
| **PostToolUse** (Bash) | `post-commit-review.sh` | Auto-reviews commits for risk flags |
| **PostToolUseFailure** (MCP) | `mcp-failure-hint.sh` | Guides fallback when MCP tools fail |
| **PreCompact** | `precompact-state.sh` | Saves a working-state snapshot and prints instructions for the compaction summary |
| **SessionStart** (`compact` matcher) | Inline command | Recovery steps after compaction |
| **Stop** | Security and claim-evidence prompt (Sonnet) + `session-checkpoint.sh` + `cost-tracker.sh` | Security and evidence review, state checkpoint, cost logging |
| **SessionEnd** | `session-checkpoint.sh` | Final state save before process exit |

### The Stop Hook's Sonnet Model

The Stop hook uses `"model": "sonnet"` for its security verification prompt. This means every Claude response triggers a Sonnet evaluation of the final message: SQL, XSS or command injection in code it contains, a credential written out literally, a reported push that breaks a stated push policy, and a claim of done, fixed or passing that the message does not back with its own evidence (a command and its result, a test count, a file and line). It judges only that final message, so earlier evidence in the turn does not count. Replay `tests/judge-fixtures/` with `tests/judge-eval.sh` (manual, needs an API key) after editing the prompt. This is the single biggest recurring cost in the blueprint, but it caught a SQL injection that Haiku missed (see [WHY.md](WHY.md#stop-hook-why-sonnet-not-haiku)).

---

## Cost Implications

This guide does not reproduce prices, because they change with each model generation. Per-token API rates are on the [API pricing page](https://platform.claude.com/docs/en/about-claude/pricing); subscription plans are on [claude.com/pricing](https://claude.com/pricing).

### Model Tiers

| Tier | Alias (current model) | Relative cost per token | Used By |
|------|----------------------|-------------------------|---------|
| Opus | `opus` (Opus 5.5) | Highest of the three | project-architect agent |
| Sonnet | `sonnet` (Sonnet 5.5) | Middle | 10 implementation/review agents + Stop hook |
| Haiku | `haiku` (Haiku 5.5) | Lowest | docs-writer agent |

On the 5.5 generation's published API rates (checked 2026-11-12), Opus costs about twice Sonnet per token and Haiku about a twentieth of Sonnet for prompts under 100,000 tokens. `fable` (Fable 5.2) sits above Opus at about twice its rate; no agent here uses it. Aliases resolve to the newest model in each family on the Anthropic API and may resolve to older versions on cloud providers ([model configuration](https://code.claude.com/docs/en/model-config)).

### What Drives Cost Up

1. **Stop hook (Sonnet on every response):** Each response triggers a Sonnet security review. In a 50-response session, that's 50 additional Sonnet invocations.
2. **Parallel agent spawns:** The review-full skill spawns up to 4 agents simultaneously. Each agent has its own context window and token budget.
3. **Always-thinking + high effort:** Extended thinking generates additional tokens that are billed. A higher effort level (set with `/effort`) increases this further.
4. **Agent teams:** Agent teams use approximately 7x more tokens than standard sessions when teammates run in plan mode (per the [costs page](https://code.claude.com/docs/en/costs)), because each teammate keeps its own context window.
5. **Playwright MCP vs CLI:** The Playwright MCP server streams full DOM accessibility trees into context (~114K tokens per task). Running `npx playwright test` via Bash uses ~27K tokens for the same work, a 76% reduction. Use MCP for interactive browser exploration; use CLI for test execution.

### Typical Spend

The official [costs page](https://code.claude.com/docs/en/costs) publishes current averages per developer per day and explains how to read your own numbers. Inside a session, `/usage` shows the session's token usage and, on a subscription plan, how much of your plan limit you have used.

### How to Track Your Actual Costs

The blueprint includes [cost-tracker.sh](../hooks/cost-tracker.sh) as a Stop hook that logs session costs to a JSONL file. Check your metrics at `~/.claude/metrics/costs.jsonl` for actual spending data.

### How to Reduce Costs

- **Disable always-thinking** for simple tasks: set `"alwaysThinkingEnabled": false` or use `/fast` mode
- **Lower effort level** to `"medium"` for routine work
- **Use Haiku for the documentation agent** (already configured in this blueprint)
- **Remove the Stop hook** if you trust your code review process (not recommended, but it's the biggest cost lever)
- **Limit parallel agents** by modifying skills to spawn fewer reviewers
