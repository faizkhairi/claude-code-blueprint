# Agents

12 specialized subagents with model tiering, permission modes, and worktree isolation.

## The Standard Agent Pattern

Every agent follows this structure:
1. **Frontmatter**: name, description, model, tools, maxTurns, permissionMode, memory
2. **Role statement**: 1-2 sentences establishing expertise
3. **Context loading**: "Before starting work: read CLAUDE.md, check package.json, search patterns"
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

## Permission Modes

| Mode | Agents | Why |
|------|--------|-----|
| `default` (explicit) | backend, frontend, qa-tester, project-architect, docs-writer | Need write access to implement or generate. Frontmatter declares `permissionMode: default` explicitly for clarity. |
| `plan` | verify-plan, code-reviewer, security-reviewer, db-analyst, devops-engineer, api-documenter, architecture-reviewer | Read-only analysis — should never modify files. Cannot use Write/Edit tools. |

Note: if an agent omits the `permissionMode` field, Claude Code falls back to write-access default. We declare `permissionMode: default` explicitly on write-access agents to make the intent visible in the frontmatter.

## Worktree Isolation

`isolation: worktree` creates a temporary git worktree so the agent sees a clean copy of the repo. If the project is not a git repository, worktree isolation is skipped and the agent runs in the main context.

**Agents using worktree**: verify-plan, code-reviewer, security-reviewer, architecture-reviewer. Reason — these are review agents that benefit from a fresh checkout: their analysis isn't biased by the main session's in-progress edits.

**Analysis-only agents NOT using worktree**: db-analyst, devops-engineer, api-documenter. Reason — these read live config/schema state (e.g., the current Prisma schema, the current Dockerfile, the current OpenAPI spec). A worktree could give them stale state if the main session has uncommitted changes that matter for analysis.

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
| api-documenter | haiku | 10 |
| architecture-reviewer | sonnet | 20 |
| verify-plan | sonnet | 3 |

**If an agent stops mid-task:**
1. Check what was completed: `git diff` for file changes, `git status` for uncommitted work
2. Spawn a new agent of the same type with context: "Continue the previous agent's work. Here is what was done so far: [summary]"
3. Or continue the work manually in the main session

## Estimated Cost Per Agent Invocation

Costs vary with task complexity and turns used. These are rough estimates for typical usage.

| Model Tier | Agents | Approximate Cost Range |
|-----------|--------|----------------------|
| Opus | project-architect | ~$0.50 - $2.00 per invocation |
| Sonnet | backend, frontend, qa-tester, db-analyst, devops, code-reviewer, security-reviewer | ~$0.10 - $0.60 per invocation |
| Haiku | docs-writer, api-documenter | ~$0.01 - $0.08 per invocation |

Verify current pricing at [Anthropic's pricing page](https://docs.anthropic.com/en/docs/about-claude/pricing). The [cost-tracker.sh](../hooks/cost-tracker.sh) hook logs session costs to `~/.claude/metrics/costs.jsonl` for actual spending data.

## Agents Are Not Infallible

Agents are powerful but imperfect. Common failure modes:

- **Hallucination**: An agent may reference files, functions, or APIs that do not exist. Always verify with `git diff` (for write agents) or manual inspection (for analysis agents).
- **Stale context**: Agents cannot see the main session's full history. They may repeat work or miss earlier decisions.
- **Overconfidence**: An agent that says "all checks pass" may not have actually run all checks. Verify critical claims.
- **Read-only safety**: Agents with `permissionMode: plan` (verify-plan, code-reviewer, security-reviewer, db-analyst, devops-engineer, api-documenter, architecture-reviewer) cannot modify files -- they can only analyze and report. This is a safety feature, not a limitation.

**Rule of thumb:** Trust agents for research and drafting. Verify before committing their output.

## Why Agents Might Ignore Instructions

CLAUDE.md rules and agent instructions are guidance, not guarantees. They are followed most of the time -- high, but not absolute. Reasons agents may deviate:

- **Context window limits**: Long or complex instructions may get compressed during context management, reducing attention to specific rules.
- **Competing instructions**: If multiple sources (CLAUDE.md, agent frontmatter, user prompt) give conflicting guidance, the agent resolves the conflict unpredictably.
- **Probabilistic behavior**: Language models are inherently probabilistic. The same instruction may be followed 9 out of 10 times but missed on the 10th.
- **Task complexity**: On complex multi-step tasks, agents may optimize for completing the task over following every peripheral instruction.

**For behaviors that MUST happen every time**, use [hooks](../hooks/) instead. Hooks are deterministic shell scripts that fire 100% of the time -- they cannot be ignored or overridden by the AI.
