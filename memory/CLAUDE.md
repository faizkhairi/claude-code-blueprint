# Memory System

Markdown-based persistent memory system for AI assistants. Used by Claude Code to maintain context across sessions.

## Purpose
This is NOT a code project — it is a structured knowledge base. Files here are read/written by Claude Code to maintain development context, user preferences, and project state.

## Key Files
- `core/identity.md` — AI personality and communication style config
- `core/preferences.md` — User preferences, work patterns, tech stack knowledge
- `core/session.md` — Working memory. Update at session end.
- `core/reminders.md` — Persistent reminders that survive session changes
- `core/decisions.md` — Append-only architectural decision log

## Session Protocol
1. **Session Start**: Read `core/session.md` to recall where we left off
2. **During Session**: No need to constantly update files; focus on the work
3. **Session End**: When the user says "save" or the session is wrapping up, update:
   - `core/session.md` with current topic, progress, next steps
   - `core/preferences.md` if new preferences or patterns were discovered
   - `core/reminders.md` — move completed items, add new ones
   - `diary/` if this was a significant session (new feature shipped, major bug fixed, etc.)

## Project System
- Active projects tracked in `projects/active/`
- Use `templates/coding-template.md` for new project entries
- Max 10 active projects; oldest auto-archived

## Integration with Claude Code
This repo complements (does not replace) Claude Code's native memory:
- Claude Code's `MEMORY.md` stores technical facts (gotchas, patterns, configs)
- This system stores relational context (preferences, session history, communication style)
- Both are read at session start for full context restoration

## Don't
- Don't commit sensitive data (API keys, passwords, PII, tokens)
- Don't store code here — this is for context only
- Don't delete diary entries (they form the session history)
