# Architecture — System Design

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

```
                    ┌─────────────────┐
                    │ project-architect│ (opus — complex planning)
                    └────────┬────────┘
                             │ designs
                    ┌────────▼────────┐
              ┌─────┤  sprint-plan    ├─────┐
              │     │  (skill)        │     │
              │     └─────────────────┘     │
     ┌────────▼────────┐          ┌────────▼────────┐
     │backend-specialist│          │frontend-specialist│
     │ (sonnet + write) │          │ (sonnet + write)  │
     └────────┬────────┘          │ + design thinking │
              │                    └────────┬────────┘
              │         implements          │
              └──────────┬──────────────────┘
                         │
              ┌──────────▼──────────┐
              │     qa-tester       │ (sonnet + write)
              └──────────┬──────────┘
                         │ tests pass
              ┌──────────▼──────────┐
              │  review (skill)     │ spawns 1-3 agents:
              │  ├─ code-reviewer   │ (sonnet, worktree)
              │  ├─ security-reviewer│ (sonnet, worktree)
              │  └─ db-analyst      │ (sonnet, plan mode)
              └──────────┬──────────┘
                         │ GO verdict
              ┌──────────▼──────────┐
              │  deploy-check       │ (skill)
              └─────────────────────┘
```

## Model Tiering Strategy

| Model | Cost | Use For | Agents |
|-------|------|---------|--------|
| **Opus** | $$$ | Complex architecture, multi-system planning | project-architect |
| **Sonnet** | $$ | Implementation, review, analysis | 8 agents (backend, frontend, code-reviewer, etc.) |
| **Haiku** | $ | Documentation, API docs | docs-writer, api-documenter |

### When to Use Each Model

Pick the model tier based on the task's **cognitive complexity**, not its importance:

| Task Characteristic | Model | Why | Example |
|--------------------|-------|-----|---------|
| Generates text from templates | **Haiku** ($1/$5 per 1M tokens) | Fast, cheap, follows patterns well | API docs, changelog, README generation |
| Implements code from clear specs | **Sonnet** ($3/$15) | Good balance of reasoning and speed | Backend routes, frontend components, tests |
| Reviews code for subtle issues | **Sonnet** ($3/$15) | Needs reasoning but not creativity | Code review, security audit, DB analysis |
| Designs architecture or makes tradeoffs | **Opus** ($5/$25) | Complex reasoning, multi-system thinking | System design, migration planning, tech decisions |
| Quick lookups or simple transforms | **Haiku** ($1/$5) | Overkill to use a larger model | File search, grep analysis, format conversion |

**Rule of thumb:** Start with Sonnet for new agents. Promote to Opus only if the agent consistently makes poor architectural decisions. Demote to Haiku only if the agent's output is templated enough that a smaller model handles it fine.

**Cost impact:** A session using all Opus agents costs roughly 5x more than the same session with Sonnet agents. The tiering in this blueprint keeps Opus to 1 agent (project-architect) while using Haiku for 2 documentation agents -- keeping the blended cost close to Sonnet-only pricing.

## Memory Architecture

```
Auto-Memory (~/.claude/projects/<project>/memory/)
  ├─ MEMORY.md (index, <100 lines)
  ├─ Topic files (on-demand: project-conventions.md, frameworks.md, etc.)
  └─ Feedback files (learned behaviors)

External Memory (git-backed repo, see memory-template/)
  ├─ core/session.md (working memory)
  ├─ core/preferences.md (user profile)
  ├─ core/reminders.md (persistent tasks)
  ├─ core/decisions.md (architectural log)
  └─ diary/ (session narratives)
```

---

See [SETTINGS-GUIDE.md](SETTINGS-GUIDE.md) for a walkthrough of the settings that wire these components together.
