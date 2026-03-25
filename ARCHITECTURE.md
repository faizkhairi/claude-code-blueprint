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
