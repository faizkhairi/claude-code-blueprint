---
paths:
  - "**/memory-core/**"
---

# MemoryCore Session Management Rules

When working with memory system files:
1. Never delete diary entries — they form the session history
2. Never store sensitive data (API keys, passwords, PII, tokens, connection strings)
3. `core/session.md` should be updated at the end of significant work sessions
4. Changes to `core/preferences.md` should be additive, not destructive — add new observations, don't remove existing ones
5. Project entries in `projects/active/` should use the coding-template.md format from `templates/`
6. Diary entries go in `diary/current/YYYY-MM-DD.md` (monthly archival to `diary/archived/YYYY-MM/`)
7. Don't store code in MemoryCore — it's for context and memory only
