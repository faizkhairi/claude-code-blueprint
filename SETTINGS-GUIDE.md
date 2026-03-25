# Settings Guide

Companion to [settings-template.json](examples/settings-template.json). Every setting explained with context, defaults, and rationale.

---

## Environment Variables

These live under the `"env"` key in `settings.json` and control Claude Code's runtime behavior.

### CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

```json
"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

**What it does:** Enables multi-agent spawning -- the ability for Claude to launch specialized subagents that run in parallel with independent context windows.

**Why it matters:** Without this, the entire [agents/](agents/) directory in this blueprint is non-functional. The Agent tool won't appear, `subagent_type` has no effect, and skills that orchestrate multiple agents (like the review skill spawning code-reviewer + security-reviewer + db-analyst in parallel) silently degrade to single-agent mode.

**Default:** Not set (disabled). You must explicitly enable it.

**Who needs it:** Anyone using agents from this blueprint. If you're only using CLAUDE.md + hooks, you can skip this.

### CLAUDE_AUTOCOMPACT_PCT_OVERRIDE

```json
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "80"
```

**What it does:** Triggers context compaction when the context window is 80% full, instead of Claude's default threshold (higher).

**Why 80%:** Compaction is aggressive -- it summarizes and discards earlier context. By triggering it earlier, you give the PreCompact hook more room to serialize working state (active plan, modified files, current branch) to disk before context is lost. See [WHY.md](WHY.md#postcompact-hook-why-state-serialization) for the battle story.

**Default:** Claude's built-in threshold (not publicly documented, but higher than 80%).

**Trade-off:** Lower = more frequent compaction (loses context sooner) but safer state preservation. Higher = more context retained but hooks may not fire in time.

### CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS

```json
"CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS": "5000"
```

**What it does:** Gives SessionEnd hooks 5 seconds to complete before the Claude Code process exits.

**Why 5 seconds:** The default timeout is lower. Hooks like `session-checkpoint.sh` write state to disk and may need a moment to complete. Without enough time, the hook gets killed mid-write, leaving incomplete or corrupt checkpoint files.

**Default:** Lower than 5000ms (varies by version).

---

## Top-Level Settings

### cleanupPeriodDays

```json
"cleanupPeriodDays": 60
```

Auto-deletes Claude Code session data older than 60 days. This includes conversation logs and temporary files -- not your project code, hooks, or agents.

**Default:** Check Claude Code docs for the current default. 60 days is a reasonable balance between disk usage and being able to reference old sessions.

### includeGitInstructions

```json
"includeGitInstructions": false
```

**What it does:** When `true`, Claude Code injects default git usage instructions into every session's context. When `false`, those instructions are suppressed.

**Why false:** This blueprint provides its own git rules via [CLAUDE.md](CLAUDE.md) (Diagnose-First Rule checks `git status` first) and hooks (`block-git-push.sh` prevents accidental pushes). The default instructions conflict with these custom rules and waste context tokens.

**When to set true:** If you're not using custom git rules and want Claude's default git behavior.

### alwaysThinkingEnabled

```json
"alwaysThinkingEnabled": true
```

**What it does:** Claude uses extended thinking (chain-of-thought reasoning) on every response, not just when the task seems complex.

**Trade-off:** Better reasoning quality, especially for subtle bugs and architectural decisions. Costs more tokens per response (thinking tokens are billed). For simple tasks like "rename this variable," extended thinking is overkill -- but the quality improvement on complex tasks outweighs the cost.

### effortLevel

```json
"effortLevel": "high"
```

**What it does:** Sets Claude's reasoning effort to maximum. Pairs with `alwaysThinkingEnabled` for deepest analysis.

**Options:** `"low"`, `"medium"`, `"high"`. Lower effort = faster, cheaper responses. Higher effort = more thorough reasoning.

**Recommendation:** Start with `"high"` for development work. Switch to `"medium"` or `"low"` for repetitive tasks like bulk file edits or documentation generation.

---

## Permissions

### defaultMode

```json
"defaultMode": "dontAsk"
```

**What it does:** Claude executes any tool in the `allow` list without asking for permission. Tools not in the list are still blocked.

**Warning for beginners:** This is the most permissive mode. It's safe *only if* you have well-configured hooks as guardrails (like `protect-config.sh` blocking config edits and `block-git-push.sh` preventing pushes). Without hooks, Claude can freely write files, run shell commands, and make git commits without confirmation.

**Recommendation:**
- **New users:** Don't set this. Use the default mode (asks for permission on each tool use) until you trust your setup.
- **Power users with hooks:** `dontAsk` is efficient -- hooks catch the dangerous actions, and you don't get prompted for routine operations.
- **Teams:** Start new developers on default mode. Graduate to `dontAsk` after they've set up hooks. See [GETTING-STARTED.md](GETTING-STARTED.md#setting-up-for-teams).

### Permission Categories

The `allow` list in the template is organized by category. Here's what each allows:

| Category | What It Allows | Why |
|----------|---------------|-----|
| **Git Operations** | `git status`, `git diff`, `git log`, `git add`, `git commit`, etc. | Core development workflow. Note: `git push` is intentionally allowed here but blocked by the `block-git-push.sh` hook -- defense in depth. |
| **Package Managers** | `npm`, `npx`, `yarn`, `pnpm`, `pip`, `pip3`, `uv`, `composer` | Installing dependencies, running scripts, executing tools. |
| **Runtimes** | `node`, `python`, `python3`, `java` | Running scripts and REPL commands for debugging. |
| **Testing + Linting** | `pytest`, `mypy`, `ruff`, `./node_modules/.bin/*` | Running test suites and linters without permission prompts. |
| **Build + Deploy** | `docker`, `vercel`, `./gradlew` | Building containers, deploying, running Gradle tasks. |
| **CLI Utilities** | `curl`, `ls`, `jq`, `chmod`, `unzip`, `echo`, `sort`, `cut`, `tr`, `tee`, `code` | Common shell utilities for investigation and scripting. |
| **Web Access** | `raw.githubusercontent.com`, `api.github.com`, `registry.npmjs.org`, `WebSearch` | Fetching files from GitHub, checking npm registry, web searches. |
| **MCP Tools** | Playwright browser tools, Context7 docs | Browser automation and documentation lookup. See [GETTING-STARTED.md](GETTING-STARTED.md#mcp-servers--giving-claude-superpowers) for setup. |
| **Skills** | `update-config` | Allows Claude to modify settings via the update-config skill. |

### additionalDirectories

```json
"additionalDirectories": [
  "C:\\Users\\YourUser\\.claude",
  "C:\\Users\\YourUser\\.claude\\skills",
  "C:\\Users\\YourUser\\.claude\\plans",
  "C:\\Users\\YourUser\\.claude\\agents"
]
```

Claude Code can only read/write files in the current working directory by default. This setting grants access to additional paths -- typically your `~/.claude/` directory so Claude can read/edit hooks, agents, skills, and plan files.

**Replace `YourUser`** with your actual username. On macOS/Linux, use `/home/youruser/.claude` or `/Users/youruser/.claude`.

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
| **PostToolUseFailure** (MCP) | Prompt hook | Guides fallback when MCP tools fail |
| **PreCompact** | `precompact-state.sh` | Serializes working state before context compaction |
| **PostCompact** | Prompt hook | Instructs Claude to restore state from disk |
| **Stop** | Security prompt (Sonnet) + `session-checkpoint.sh` + `cost-tracker.sh` | Security review, state checkpoint, cost logging |
| **SessionEnd** | `session-checkpoint.sh` | Final state save before process exit |

### The Stop Hook's Sonnet Model

The Stop hook uses `"model": "sonnet"` for its security verification prompt. This means every Claude response triggers a Sonnet evaluation for SQL injection, XSS, exposed secrets, and verification gaps. This is the single biggest recurring cost in the blueprint -- but it caught a SQL injection that Haiku missed (see [WHY.md](WHY.md#stop-hook-why-sonnet-not-haiku)).

---

## Cost Implications

**Prices as of March 2026 -- verify at [Anthropic's pricing page](https://docs.anthropic.com/en/docs/about-claude/pricing) for current rates.**

### Model Pricing Reference

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Used By |
|-------|----------------------|------------------------|---------|
| Opus 4.6 | $5 | $25 | project-architect agent |
| Sonnet 4.6 | $3 | $15 | 8 implementation/review agents + Stop hook |
| Haiku 4.5 | $1 | $5 | docs-writer, api-documenter agents |

### What Drives Cost Up

1. **Stop hook (Sonnet on every response):** Each response triggers a Sonnet security review. In a 50-response session, that's 50 additional Sonnet invocations.
2. **Parallel agent spawns:** The review skill spawns up to 3 agents simultaneously. Each agent has its own context window and token budget.
3. **Always-thinking + high effort:** Extended thinking generates additional tokens that are billed. `effortLevel: "high"` increases this further.
4. **Agent teams:** Sessions with active agent teams use roughly 7x more tokens than standard sessions (per Anthropic's official docs).

### Rough Daily Estimates

From [Anthropic's official Claude Code cost documentation](https://code.claude.com/docs/en/costs):

| Usage Pattern | Daily Cost (approx) |
|--------------|-------------------|
| Light (5-10 responses) | ~$1-3 |
| Average developer | ~$6/day |
| Heavy (100+ responses, agents) | ~$12+ |
| 90th percentile | below $12/day |

### How to Track Your Actual Costs

The blueprint includes [cost-tracker.sh](hooks/cost-tracker.sh) as a Stop hook that logs session costs to a JSONL file. Check your metrics at `~/.claude/metrics/costs.jsonl` for actual spending data.

### How to Reduce Costs

- **Disable always-thinking** for simple tasks: set `"alwaysThinkingEnabled": false` or use `/fast` mode
- **Lower effort level** to `"medium"` for routine work
- **Use Haiku for documentation agents** (already configured in this blueprint)
- **Remove the Stop hook** if you trust your code review process (not recommended, but it's the biggest cost lever)
- **Limit parallel agents** by modifying skills to spawn fewer reviewers
