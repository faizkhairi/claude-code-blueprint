---
name: session-end
description: "MUST use when user says 'bye', 'goodbye', 'good night', 'gnight', 'done for today', 'that's all', 'that's it', 'see you', 'see ya', 'let's stop', 'stopping here', 'wrapping up', 'signing off', 'closing down', 'done', 'finished for now', 'talk later', 'cya'. The user does NOT use slash commands; detect these natural session-ending phrases and run the full wrap-up automatically."
user-invocable: true
---

**Prerequisite check (run first)**: if `./memory/` does not exist OR `~/.claude/.memory-disabled` marker file is present, skip the save-session/save-diary steps but still acknowledge the user's farewell. Output: "Memory persistence is disabled, see you next time." Otherwise proceed with the full wrap-up below.

# Session End: Graceful Wrap-Up

*Runs both save-session and save-diary together as one clean session close.*

## Activation

When this skill activates, output: "Wrapping up, saving session and diary."

## Step 1: Save Session Context

Update `./memory/core/session.md`:

- **Last session summary**: What was accomplished today (specific, not generic)
- **Current working state**: Where things stand, what's in-progress, what's done
- **Next steps**: What should be picked up next session
- **Blockers or open questions**: Anything left unresolved

## Step 2: Update Reminders

Update `./memory/core/reminders.md`:

- Ask the user: any pending tasks, deadlines, or reminders to carry forward?
- Move completed reminders to the Completed section with date
- Keep active ones, add new ones

## Step 3: Update Per-Project Context

If working on a registered project, update `./memory/projects/active/{project}.md` → Session Context section with what was last worked on, current state, and next steps for that project.

## Step 4: Check for Memory Updates

- **preferences.md**: Were any new preferences, tools, or working patterns observed? Update `./memory/core/preferences.md` if so.
- **MEMORY.md**: Were any new technical learnings, gotchas, or architectural decisions made? Update `{MEMORY_MD_PATH}` if so. **Size guard**: after editing, count lines; warn if over 170 (200-line truncation limit).
- **decisions.md**: Was a non-obvious architectural or technical decision made? Append to `./memory/core/decisions.md` using format: `## YYYY-MM-DD — Title` / `**Context**` / `**Decision**` / `**Rationale**`

## Step 5: Save Diary Entry (if session was significant)

A session is "significant" if any of these are true:
- Feature shipped or major bug fixed
- Architecture or tech decision made
- New project started or milestone reached
- Meaningful learning or discovery happened
- Career or profile work done

If significant: append entry to `./memory/diary/current/YYYY-MM-DD.md`

Run monthly archive check first (move any previous-month files from `current/` to `archived/YYYY-MM/`).

Entry structure (our actual format):
- **Title**: `# YYYY-MM-DD — Session N: Brief Description`
- **What Happened**: Concise summary of the session context and goals
- **Fixes Applied / Key Changes**: Specific technical work done (commits, code changes)
- **Key Insight**: Lessons learned or important observations
- **Pending / Next Steps**: What's left to do

## Step 6: Git Commit + Push memory

Stage all changed files in memory, commit with a descriptive message, and push to GitHub (`git push origin main`). This keeps the remote diary and session state up to date.

## Step 7: Confirm and Close

Output a brief summary:
```
Session saved:
- session.md — updated
- reminders.md — [updated / no changes]
- {project}.md — [updated / N/A]
- MEMORY.md — [updated with X / no changes]
- Dev Diary — [entry added / no significant session]
- memory — committed + pushed
See you next time.
```

## Mandatory Rules

- ALWAYS save session.md (even for short sessions)
- ONLY save diary if session was genuinely significant
- Keep the goodbye warm but brief; user prefers concise responses
