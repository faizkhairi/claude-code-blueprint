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
  │   └─ mcp__* ──→ fallback guidance prompt
  │
  ├─ PermissionDenied hooks (auto mode)
  │   └─ (available) ──→ log or retry after classifier blocks
  │
  ├─ PreCompact ──→ precompact-state.sh (serialize state to disk)
  ├─ PostCompact ──→ context recovery prompt (read state file)
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
              │  ├─ code-reviewer    │  (sonnet, read-only)
              │  ├─ security-reviewer │  (sonnet, read-only)
              │  ├─ db-analyst       │  (sonnet, plan mode)
              │  └─ architecture-reviewer │ (sonnet, read-only, structural changes)
              └──────────────────────┘


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
| Generates text from templates | **Haiku** ($0.80/$4 per 1M tokens) | Fast, cheap, follows patterns well | API docs, changelog, README generation |
| Implements code from clear specs | **Sonnet** ($3/$15) | Good balance of reasoning and speed | Backend routes, frontend components, tests |
| Reviews code for subtle issues | **Sonnet** ($3/$15) | Needs reasoning but not creativity | Code review, security audit, DB analysis |
| Designs architecture or makes tradeoffs | **Opus** ($15/$75)* | Complex reasoning, multi-system thinking | System design, migration planning, tech decisions |
| Quick lookups or simple transforms | **Haiku** ($0.80/$4) | Overkill to use a larger model | File search, grep analysis, format conversion |

> \* Prices per million tokens, indicative. Verify current pricing at [claude.com/pricing](https://claude.com/pricing).

**Rule of thumb:** Start with Sonnet for new agents. Promote to Opus only if the agent consistently makes poor architectural decisions. Demote to Haiku only if the agent's output is templated enough that a smaller model handles it fine.

**Cost impact:** A session using all Opus agents costs roughly 5x more than the same session with Sonnet agents. The tiering in this blueprint keeps Opus to 1 agent (project-architect) while using Haiku for 1 documentation agent, keeping the blended cost close to Sonnet-only pricing.

## Memory Architecture

```
Auto-Memory (~/.claude/projects/<project>/memory/)
  ├─ MEMORY.md (index, <100 lines)
  ├─ Topic files (on-demand: project-conventions.md, frameworks.md, etc.)
  └─ Feedback files (learned behaviors)

Built-in Memory (opt-in via setup.sh, see memory/)
  ├─ core/session.md (working memory)
  ├─ core/preferences.md (user profile)
  ├─ core/reminders.md (persistent tasks)
  ├─ core/decisions.md (architectural log)
  └─ diary/ (session narratives)
```

---

See [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md) for a walkthrough of the settings that wire these components together.
