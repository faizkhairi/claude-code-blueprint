---
name: save-diary
description: MUST use when user says 'save diary', 'write diary', 'diary entry', 'update diary', or 'document session'. Also auto-trigger at the end of any significant session (feature shipped, major bug fixed, architecture decision, new project started).
user-invocable: true
---

# Dev Diary — Session Documentation Skill

*Today's story takes shape.*

## Activation

When this skill activates, output: "Dev Diary — documenting today's session."

## Context Guard

| Context | Status |
|---------|--------|
| User says "save diary" / "write diary" / "diary entry" | ACTIVE — full diary write |
| End of significant session | ACTIVE — auto-document |
| User says "review diary" | ACTIVE — read recent entries |
| Mid-conversation (no save request) | DORMANT — no diary action |

## Protocol

### Step 1: Monthly Archive Check

- Scan `{MEMORYCORE_PATH}/diary/current/` for files from previous months
- For each file where month != current month:
  - Create `{MEMORYCORE_PATH}/diary/archived/YYYY-MM/` folder if not exists
  - Move the file from `current/` to `archived/YYYY-MM/`
- Continue with diary write

### Step 2: Find or Create Today's File

- Check if `{MEMORYCORE_PATH}/diary/current/YYYY-MM-DD.md` exists
- If exists: use it (will append new entry)
- If not: create new file with header:
```
# YYYY-MM-DD — Session N: Brief Description
```

### Step 3: Compose and Append Diary Entry

- Get current date via bash: `date +"%B %d, %Y"` or PowerShell `Get-Date -Format "MMMM dd, yyyy"`
- Analyze current session for key content
- Write structured entry using our actual diary format:
  - **Title**: `# YYYY-MM-DD — Session N: Brief Description`
  - **What Happened**: Concise summary of the session context and goals
  - **Fixes Applied / Key Changes**: Specific technical work done (commits, code changes)
  - **Key Insight**: Lessons learned or important observations
  - **Pending / Next Steps**: What's left to do
- **Session numbering**: Read the existing file first. Find the highest `Session N` number in today's entries and increment by 1. If this is the first entry of the day, check the previous day's file for the last session number and continue from there. If no previous entries exist, start at Session 1.
- **APPEND** to today's file (never overwrite existing content)
- Multiple entries per day are separated by `---`

### Step 4: Update Session Memory

- Update `{MEMORYCORE_PATH}/core/session.md` with:
  - Session recap and key achievements
  - Current working state for continuity
  - Next steps identified
- Confirm diary entry saved

## Mandatory Rules

1. **Always APPEND** — never overwrite existing diary entries
2. **One file per day** — multiple entries separated by `---`
3. **Use real timestamps** — get current date via system command
4. **Archive first** — run monthly archive check before every write
5. **Evidence-based** — document actual session content, not generic summaries
6. **Use our format** — concise technical summaries (What Happened, Key Changes, Key Insight, Pending)

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| First entry of the day | Create new file with header + first entry |
| Second+ entry same day | Append with `---` separator |
| No significant content | Create brief entry noting session type |
| "review diary" command | Read and present recent entries from current/ |
