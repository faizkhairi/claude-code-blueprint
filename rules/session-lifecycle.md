<!--
  Three session-start mechanisms exist by design (defense-in-depth):
  1. session-start hook — injects pre-computed workspace facts before Claude responds
  2. This rule — reads 3-4 core files during Claude's first response
  3. load-session skill — comprehensive 8-item restore with formatted summary
  The hook and rule are safety nets; the skill is the full restoration.
-->

> **Setup note:** `./memory/` is the built-in opt-in memory folder shipped with the blueprint (enabled via `./setup.sh`) — no path substitution needed. The `{CLAUDE_CONFIG_PATH}` placeholder on line 39 below DOES need replacement (typically `~/.claude` on macOS/Linux, `C:/Users/you/.claude` on Windows). See [skills/README.md](../skills/README.md#required-replace-placeholder-variables) for the full placeholder list.

# Session Lifecycle — Automatic Behaviors

These rules apply to EVERY session, regardless of project.

## Session Start (Before First Response)

When a new conversation begins (no prior messages in this session):

1. **Read session context** from `./memory/core/session.md`
2. **Read user preferences** from `./memory/core/preferences.md`
3. **Read active reminders** from `./memory/core/reminders.md` — these may have deadlines
4. **Read architectural decisions** from `./memory/core/decisions.md`
5. Use the loaded context to understand where the last session left off
6. If the user's first message implies continuation ("continue", "what were we doing", or jumping straight into a task from last session), reference the session recap naturally

Do NOT announce that you loaded memory. Just use it seamlessly.

## Session End (Natural Conversation Cues)

When the user signals they're done — phrases like "bye", "goodbye", "done", "that's all", "see you", "wrapping up", "signing off", "good night", "cya", "talk later", "finished for now":

1. **Update** `./memory/core/session.md` with:
   - What was accomplished this session
   - Current working state
   - Next steps for the next session
2. **Update reminders** at `./memory/core/reminders.md` — move completed to Completed section, add new ones
3. **Update per-project context**: If working on a registered project, update `./memory/projects/active/{project}.md` → Session Context section
4. **If the session was significant** (feature shipped, bug fixed, architecture decision, new project started): append a diary entry to `./memory/diary/current/YYYY-MM-DD.md`
5. **If new technical learnings or gotchas** were discovered: update `{CLAUDE_CONFIG_PATH}/projects/{project}/memory/MEMORY.md`
6. **Git commit + push** all memory changes (adjust remote and branch name to match your memory repo's configuration)
7. Move any next-steps that have persisted across 3+ sessions to `reminders.md` — session.md is for ephemeral context, not persistent deferrals

## Key Behavioral Notes

- The user does NOT use slash commands — detect intent from natural language
- Keep responses concise — no filler phrases, no emojis unless requested
- Prefer action over discussion — explain briefly, then do the thing
