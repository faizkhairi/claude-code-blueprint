# Memory System — Git-Backed Persistent Memory

**Privacy Notice:** This memory system will contain your work history, preferences, and project context. **Keep your memory repository private** (this is a separate repo from the blueprint -- your fork of claude-code-blueprint should stay public). If you accidentally push memory files to a public repo, treat it as a data exposure -- review what was published and rotate any credentials that may have been captured in diary entries or session notes.

A structured, git-backed memory system that gives your AI assistant persistent context across sessions, IDE reinstalls, and machine changes.

## Why This Exists

Claude Code's built-in auto-memory (`~/.claude/projects/*/memory/`) is powerful but session-scoped — it can be lost on IDE reinstalls or machine changes. This external memory system:

- **Survives anything** — it's a git repo, so it's backed up and versioned
- **Separates concerns** — auto-memory stores technical facts, this stores relational context
- **Enables session continuity** — pick up exactly where you left off, even weeks later
- **Tracks decisions** — append-only decision log prevents "why did we do it this way?" moments

## Setup

### 1. Create your memory repo

```bash
# Fork this template, or create a new private repo
git init my-memory
cd my-memory
# Copy these template files into it
```

### 2. Wire into Claude Code

Add a path-scoped rule at `~/.claude/rules/memory-session.md`:

```markdown
---
paths:
  - "**/my-memory/**"
---

# Memory Session Rules

When working with memory files:
1. Never delete diary entries — they form the session history
2. Never store sensitive data (API keys, passwords, PII, tokens)
3. Update core/session.md at the end of significant work sessions
4. Changes to core/preferences.md should be additive, not destructive
5. Project entries should use the template from templates/
6. Diary entries go in diary/current/YYYY-MM-DD.md
7. Don't store code — this is for context and memory only
```

### 3. Add session lifecycle (optional)

Create a rule at `~/.claude/rules/session-lifecycle.md` that reads your memory files at session start and updates them at session end. See the `skills/` directory in the blueprint for `load-session`, `save-session`, and `session-end` skills that automate this.

### 4. Keep your memory repo private

Your memory repo contains personal context -- keep it as a **private** repository. This is separate from your fork of the blueprint itself, which should remain **public** (to contribute back, receive updates, and support the community). The blueprint teaches the *pattern*; your personal data stays in your private memory repo.

## Recommended .gitignore

Add this to your memory repository's `.gitignore`:

```
# Never commit secrets or credentials
.env
.env.*
*.key
*.pem

# IDE and OS artifacts
.DS_Store
Thumbs.db
.vscode/
.idea/

# Temporary files
*.tmp
*.bak
*.swp
```

## File Structure

```
core/
  ├── session.md        — Working memory (what happened, what's next)
  ├── preferences.md    — Your work style and communication preferences
  ├── identity.md       — AI personality config (how Claude should behave)
  ├── reminders.md      — Persistent reminders that survive session changes
  └── decisions.md      — Append-only architectural decision log
diary/
  ├── current/          — This month's session diary entries (YYYY-MM-DD.md)
  └── archived/         — Previous months (YYYY-MM/ folders)
projects/
  └── active/           — Per-project context files (max ~10)
templates/
  ├── adr-template.md     — Reusable ADR template for architectural decisions
  └── coding-template.md  — Template for new project entries
```

## What NOT to Store

Even in a private repo, avoid storing:
- API keys, tokens, or passwords (use environment variables or a secrets manager)
- Database connection strings with credentials
- Personally identifiable information (PII) of others -- names, emails, IDs
- Proprietary code snippets from employer/client projects
- Access credentials for production systems

Memory files should contain **context** (what you were working on, decisions made, conventions learned) -- not **secrets** (anything that grants access to a system).

## How It Works

| Event | What Happens |
|-------|-------------|
| **Session start** | Claude reads `core/session.md` + `core/preferences.md` to restore context |
| **During session** | No constant updates needed — focus on the work |
| **Session end** | Claude updates session.md, reminders.md, and optionally writes a diary entry |
| **Significant session** | A diary entry captures what happened, decisions made, and lessons learned |
| **Monthly** | Diary entries in `current/` get archived to `archived/YYYY-MM/` |

## Integration with Claude Code's Auto-Memory

This system **complements** (does not replace) Claude Code's built-in memory:

| System | Stores | Lifespan |
|--------|--------|----------|
| Auto-memory (`MEMORY.md`) | Technical facts, gotchas, code patterns | Per-project, tied to Claude install |
| This memory repo | Session history, preferences, decisions, diary | Permanent, git-backed |

Both are read at session start for full context restoration.
