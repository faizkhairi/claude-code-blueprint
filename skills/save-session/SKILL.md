---
name: save-session
description: "MUST use when user says 'save', 'save session', or explicitly wants to preserve session state. {USER_NAME} does NOT use slash commands — also trigger proactively when significant work has been completed and session context should be persisted. For session endings (bye/done/goodbye), use the session-end skill instead which combines save-session + save-diary."
user-invocable: true
---

Save session state to AI MemoryCore:

1. **Update session.md** at `{MEMORYCORE_PATH}/core/session.md`:
   - Current topic and what we're working on
   - Recent progress (what was accomplished this session)
   - Next steps (what should happen next session)
   - Any blockers or open questions

2. **Update reminders** at `{MEMORYCORE_PATH}/core/reminders.md`:
   - Ask the user if there are any pending tasks, deadlines, or reminders to carry forward
   - Remove completed reminders (move to Completed section with date), keep active ones, add new ones

3. **Update per-project context**: If working on a registered project, update `{MEMORYCORE_PATH}/projects/active/{project}.md` → Session Context section:
   - Last worked on (what specifically)
   - In progress (current state)
   - Next up (what should happen next on THIS project)

4. **Check preferences.md**: If new preferences or work patterns were observed during this session, update `{MEMORYCORE_PATH}/core/preferences.md`

5. **Check MEMORY.md**: If new technical learnings or gotchas were discovered, update `{MEMORY_MD_PATH}`. After any edit, count total lines — if over 170, warn that MEMORY.md is approaching the 200-line auto-truncation limit and suggest moving content to topic files.

6. **Check decisions.md**: If a non-obvious architectural or technical decision was made this session (something future-us would ask "why?"), append to `{MEMORYCORE_PATH}/core/decisions.md` using the existing format: `## YYYY-MM-DD — Title` / `**Context**` / `**Decision**` / `**Rationale**`

7. **Diary** (if this was a significant session — e.g., feature shipped, major bug fixed, architecture decision made): Use the `save-diary` skill to create or append an entry to `{MEMORYCORE_PATH}/diary/current/YYYY-MM-DD.md`

8. **Git commit + push MemoryCore**: Stage all changed files in MemoryCore, commit with a descriptive message, and push to GitHub (`git push origin main`). This keeps the remote diary and session state up to date.

9. **Confirm**: Summarize what was saved and where
