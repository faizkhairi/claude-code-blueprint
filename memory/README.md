# Memory System — Built-in Opt-in Persistent Memory

Gives your AI assistant persistent context across sessions, IDE reinstalls, and (with optional cross-machine sync) machine changes. Enabled via `./setup.sh` — no separate repo required.

> **Privacy by default:** The `.gitignore` shipped in this folder keeps personal content (session, preferences, diary, projects) **out of git** — your blueprint fork can stay public without leaking your work history. Templates and this README stay tracked.

## Quick Reference

| File | What it holds | Updated when |
|------|---------------|--------------|
| `core/session.md` | What happened this session, current state, next steps | Session end + significant milestones |
| `core/preferences.md` | Your work style and communication preferences | Additively, when new patterns observed |
| `core/identity.md` | AI personality config (how Claude should behave) | Once during setup; rarely after |
| `core/reminders.md` | Persistent reminders that survive session changes | When user mentions deadlines or follow-ups |
| `core/decisions.md` | **Append-only** architectural decision log | When non-obvious technical decisions are made |
| `diary/current/YYYY-MM-DD.md` | What happened on this date, lessons learned | End of significant sessions |
| `projects/active/{name}.md` | Per-project context (max ~10 active) | When user registers a project, session-end |
| `templates/adr-template.md` | Reusable ADR scaffold | Never (read-only template) |
| `templates/coding-template.md` | Per-project context scaffold | Never (read-only template) |

Files in `core/` and `diary/` and `projects/active/` are **git-ignored** — they hold your personal data. Templates and this README are tracked so they survive `git clean` and travel with the blueprint.

## Why This Exists

Claude Code's built-in auto-memory (`~/.claude/projects/*/memory/`) is powerful but session-scoped — it can be lost on IDE reinstalls or machine changes. The blueprint's memory system:

- **Survives reinstalls** — lives in this folder, not in `~/.claude/projects/`
- **Separates concerns** — auto-memory stores technical facts, this stores relational context
- **Enables session continuity** — pick up exactly where you left off, even weeks later
- **Tracks decisions** — append-only decision log prevents "why did we do it this way?" moments
- **Private by default** — personal content is git-ignored; you control what (if anything) gets committed

## Setup

### The easy way: `./setup.sh`

From your fork of the blueprint, run:

```bash
./setup.sh
```

When it asks **"Enable persistent memory? [Y/n]"**, answer **Y** (the default). That single answer wires everything: this folder becomes Claude's memory location, the `memory-session` rule activates so Claude knows the conventions for reading/writing here, and the session-lifecycle skills (`load-session`, `save-session`, `session-end`, `save-diary`) become available.

If you've already run `setup.sh` without enabling memory, re-run it — it's idempotent and will prompt again.

### Optional: cross-machine sync

By default, memory lives in this folder on one machine, git-ignored for privacy. If you want your context to follow you across machines:

1. Create a **separate private** git repo for your memory data.
2. Replace this `memory/` folder with a clone of that private repo, OR symlink it.
3. Commit only the parts you want synced (e.g., `core/decisions.md`, `core/preferences.md`) — keep diary/projects local if they contain sensitive context.

This is advanced and most users don't need it. Single-machine setup is the default and works for the majority of adopters.

### Advanced: manual setup (skip if you used `setup.sh`)

If you prefer to set things up by hand (or you forked just `memory/` without the blueprint's setup.sh), wire it like this:

1. **Path-scoped rule** — add `~/.claude/rules/memory-session.md` (the blueprint ships one at `rules/memory-session.md` you can copy):

   ```markdown
   ---
   paths:
     - "**/memory/**"
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

2. **Session lifecycle skills** — copy `skills/load-session/`, `skills/save-session/`, `skills/session-end/`, `skills/save-diary/` from the blueprint into `~/.claude/skills/`. They reference `./memory/` directly — no path substitution needed.

## What's git-ignored here

The `.gitignore` in this folder is managed by `setup.sh` and covers only personal-content files (`core/session.md`, `core/preferences.md`, `core/reminders.md`, `core/identity.md`, the entire `diary/` and `projects/active/` folders). Templates and this README stay tracked.

Machine-level patterns (`.DS_Store`, `.vscode/`, etc.) belong in your project root's `.gitignore` or your global `~/.gitignore`, not here. Memory holds structured data only.

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
