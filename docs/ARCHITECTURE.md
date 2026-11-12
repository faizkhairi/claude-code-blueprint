# Architecture: System Design

## Component Relationships

```
Session Start
  │
  ├─ SessionStart hook ──→ session-start.sh (inject workspace context)
  ├─ session-lifecycle rule ──→ reads memory system files
  └─ load-session skill ──→ full 8-item context restore
  │
  ▼
Active Session
  │
  ├─ PreToolUse hooks
  │   ├─ Bash ──→ block-git-push.sh (protect remote)
  │   └─ Write|Edit ──→ protect-config.sh (guard linter configs)
  │
  ├─ PostToolUse hooks
  │   ├─ Write|Edit ──→ notify-file-changed.sh (verify reminder)
  │   └─ Bash ──→ post-commit-review.sh (review + risk flags)
  │
  ├─ PostToolUseFailure hooks
  │   └─ mcp__* ──→ mcp-failure-hint.sh (fallback guidance)
  │
  ├─ PermissionDenied hooks (auto mode)
  │   └─ (available) ──→ log or retry after classifier blocks
  │
  ├─ PreCompact ──→ precompact-state.sh (snapshot to disk + summary instructions)
  ├─ SessionStart (compact) ──→ inline recovery steps (read state file)
  │
  └─ Stop hooks
      ├─ Security verification (sonnet model)
      ├─ session-checkpoint.sh (timestamp breadcrumb)
      └─ cost-tracker.sh (JSONL metrics)
  │
  ▼
Session End
  └─ SessionEnd hook ──→ session-checkpoint.sh (guaranteed final save)
```

## Agent Ecosystem

Two things live in this picture, and it matters which is which:

- **WIRED**: a skill in this repo actually spawns these agents. You get this behavior out of the box.
- **ILLUSTRATIVE**: a pattern you can build for *your* stack. The blueprint ships the agents, but does not force a one-size pipeline, because a Laravel build, a Go service, and a Django app want different flows. Wire the stages that fit your work (see the decision framework in [agents/README.md](../agents/README.md#when-to-use-an-agent-vs-a-skill-vs-the-main-thread)).

```
WIRED (ships working): the review-full skill spawns up to 4 agents in parallel:

              ┌──────────────────────┐
              │  review-full (skill) │  picks 1-4 agents by what changed:
              │  ├─ code-reviewer    │  (sonnet, read-only by intent)
              │  ├─ security-reviewer │  (sonnet, read-only by intent)
              │  ├─ db-analyst       │  (sonnet, plan mode)
              │  └─ architecture-reviewer │ (sonnet, read-only by intent, structural changes)
              └──────────────────────┘

   "Read-only by intent": permissionMode: plan holds only when the main session
   runs in default or dontAsk mode, and agents that set memory can still write.
   See agents/README.md (Permission Modes).


ILLUSTRATIVE (a shape you can wire yourself): a build-to-ship flow:

   project-architect ──designs──▶ sprint-plan (skill, planning only today)
                                        │
                    ┌───────────────────┴───────────────────┐
              backend-specialist                    frontend-specialist
                    └───────────────────┬───────────────────┘
                                   implements
                                        ▼
                                   qa-tester ──tests pass──▶ review-full ──GO──▶ deploy-check
```

> The ILLUSTRATIVE flow is NOT wired: `sprint-plan`, `test-check`, and `deploy-check` are skills that run on the main thread and do not spawn `backend-specialist` / `frontend-specialist` / `qa-tester` / `devops-engineer` automatically. That is deliberate: you decide when to delegate to a specialist for your stack, rather than inheriting a pipeline that assumes one. To wire it, follow the same pattern `review-full` uses (a "spawn agents" step that names the agent by `subagent_type`).

## Model Tiering Strategy

| Model | Cost | Use For | Agents |
|-------|------|---------|--------|
| **Opus** | $$$ | Complex architecture, multi-system planning | project-architect |
| **Sonnet** | $$ | Implementation, review, analysis | 10 agents (backend, frontend, code-reviewer, memory-curator, etc.) |
| **Haiku** | $ | Documentation, API docs | docs-writer |

### When to Use Each Model

Pick the model tier based on the task's **cognitive complexity**, not its importance:

| Task Characteristic | Model | Why | Example |
|--------------------|-------|-----|---------|
| Generates text from templates | **Haiku** (cheapest tier) | Fast, cheap, follows patterns well | API docs, changelog, README generation |
| Implements code from clear specs | **Sonnet** (middle tier) | Good balance of reasoning and speed | Backend routes, frontend components, tests |
| Reviews code for subtle issues | **Sonnet** (middle tier) | Needs reasoning but not creativity | Code review, security audit, DB analysis |
| Designs architecture or makes tradeoffs | **Opus** (most expensive tier) | Complex reasoning, multi-system thinking | System design, migration planning, tech decisions |
| Quick lookups or simple transforms | **Haiku** (cheapest tier) | Overkill to use a larger model | File search, grep analysis, format conversion |

> The aliases `opus`, `sonnet` and `haiku` resolve to the newest model in each family on the Anthropic API (currently Opus 5.5, Sonnet 5.5 and Haiku 5.5), so agent files never need a version bump; some cloud providers resolve them to older versions. `fable` (currently Fable 5.2) sits above Opus for the hardest, longest-running tasks; this blueprint assigns it to no agent. Per-token prices change: see the [API pricing page](https://platform.claude.com/docs/en/about-claude/pricing) for token rates and [claude.com/pricing](https://claude.com/pricing) for plans. Source for aliases: [model configuration](https://code.claude.com/docs/en/model-config).

**Rule of thumb:** Start with Sonnet for new agents. Promote to Opus only if the agent consistently makes poor architectural decisions. Demote to Haiku only if the agent's output is templated enough that a smaller model handles it fine.

**Cost impact:** On the API rates published for the 5.5 generation (checked 2026-11-12), Opus costs about twice as much per token as Sonnet, Haiku about a twentieth of Sonnet for prompts under 100,000 tokens, and Fable about twice Opus. Ratios move between generations, so check the API pricing page before you rely on them. The tiering in this blueprint keeps Opus to 1 agent (project-architect) while using Haiku for 1 documentation agent, keeping the blended cost close to Sonnet-only pricing.

## Memory Architecture

```
Auto-Memory (~/.claude/projects/<project>/memory/)
  ├─ MEMORY.md (index; only the first 200 lines or 25KB load, so keep it lean)
  ├─ Topic files (on-demand: project-conventions.md, frameworks.md, etc.)
  └─ Feedback files (learned behaviors)

Built-in Memory (opt-in via setup.sh, see memory/)
  ├─ core/session.md (working memory)
  ├─ core/preferences.md (user profile)
  ├─ core/reminders.md (persistent tasks)
  ├─ core/decisions.md (architectural log)
  └─ diary/ (session narratives)
```

**What Claude Code loads on its own** (per the [memory docs](https://code.claude.com/docs/en/memory)):

- **CLAUDE.md files** load in full at every session start; the docs suggest keeping each under 200 lines and moving detail into path-scoped rules or imports.
- **`@path/to/file` imports** inside a CLAUDE.md expand that file into context alongside it. In a project CLAUDE.md, an import from outside the project asks for a one-time approval.
- **`AGENTS.md`** is read as the project instructions when the directory has no `CLAUDE.md` or `CLAUDE.local.md` (Claude Code v2.1.277 or later). When both exist, only CLAUDE.md loads unless it imports `@AGENTS.md`, which is the way to share one file with other coding tools.
- **Auto memory** loads only the first 200 lines or 25KB of `MEMORY.md`, whichever comes first; topic files load on demand. That limit is why this blueprint keeps MEMORY.md as a short index.

---

See [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md) for a walkthrough of the settings that wire these components together.
