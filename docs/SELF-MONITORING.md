# Self-Monitoring Patterns

Two lightweight patterns for catching drift in a Claude Code setup before it bites: **pre-commit secret scanning** and a **memory-curator agent**. Both are optional. Both can be adopted independently. Both adapt to any project.

> **Why bother:** A Claude Code setup grows. Hooks accumulate. Memory files drift from reality. Skills duplicate each other. These two patterns catch the most common failure modes (secrets in commits + stale references in memory) without adding ceremony.

---

## Pattern 1: gitleaks pre-commit hook

**Problem it solves:** Prompt-based secret detection (e.g., a Stop hook asking the model "did you see any secrets?") is unreliable. A binary scanner is deterministic and runs in milliseconds.

**What it is:** A `PreToolUse` hook that intercepts `git commit` commands and runs [gitleaks](https://github.com/gitleaks/gitleaks) against staged content. If a secret matches a known pattern (AWS keys, GitHub PATs, generic high-entropy strings, etc.), the commit is blocked.

**Install gitleaks once:**
```bash
# macOS
brew install gitleaks
# Windows (winget)
winget install gitleaks
# Linux / manual
# https://github.com/gitleaks/gitleaks/releases
```

**Hook script (`~/.claude/hooks/pre-commit-secret-scan.sh`):**
```bash
#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

# Only intercept git commit (skip non-commit commands)
if ! echo "$COMMAND" | grep -qE 'git commit( |$)'; then exit 0; fi
# Honor user's explicit --no-verify
if echo "$COMMAND" | grep -qE 'git commit.*--no-verify'; then exit 0; fi
# Skip if gitleaks not installed (no false-positive blocks)
command -v gitleaks >/dev/null 2>&1 || exit 0

OUTPUT=$(gitleaks protect --staged --no-banner --redact --exit-code 1 2>&1)
if [ $? -ne 0 ]; then
  echo "Blocked: gitleaks detected secrets in staged content." >&2
  echo "$OUTPUT" | head -20 >&2
  echo "To bypass (use sparingly): git commit --no-verify" >&2
  exit 2
fi
exit 0
```

**Wire in `settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash|PowerShell",
      "hooks": [{ "type": "command", "command": "bash \"~/.claude/hooks/pre-commit-secret-scan.sh\"" }]
    }]
  }
}
```

Per-repo allowlists go in `.gitleaks.toml` at the project root (see gitleaks docs).

---

## Pattern 2: memory-curator agent

**Problem it solves:** Your `~/.claude/projects/*/memory/MEMORY.md` index drifts from reality over time. Files get added without indexing. Filenames in the index point to files that no longer exist. Section counts say "(15)" when there are actually 18 bullets. None of this breaks immediately, but it slowly degrades how reliably Claude can find what you've written down.

**What it is:** A small agent you invoke manually (weekly is fine), or wire into `/schedule` if you have it, that audits your memory folder for orphans, phantoms, broken wiki-links, and section-count drift. It writes a dated report and never edits anything itself.

**Agent file (`~/.claude/agents/memory-curator.md`):**
```markdown
---
name: memory-curator
description: Audits the local memory folder for orphans, phantoms, broken wiki-links, section-count drift, and near-duplicates. Writes a dated health report. Manual or scheduled.
model: sonnet
tools: Read, Grep, Glob, Bash, Write
---

You are a memory-system librarian. Your job is read-only audit.

1. **Inventory**: `Glob` all `.md` files in the memory folder. Group by prefix (feedback_, project_, reference_, topic).
2. **Index vs reality**: Read `MEMORY.md`. Compare every referenced filename to the inventory.
   - Orphans = on disk but not in MEMORY.md
   - Phantoms = in MEMORY.md but not on disk
3. **Section count drift**: For each `### Section (N)` header, count actual bullets. Flag any mismatch.
4. **Wiki-link integrity**: Grep `[[name]]` patterns. Verify each target exists.
5. **Stale flags**: List files >60 days old that reference specific dates/PRs/incidents (truly stale ≠ evergreen rules).
6. **Write report** to `~/.claude/memory-health-YYYY-MM-DD.md`. Sections: Orphans / Phantoms / Section Drift / Broken Links / Stale / All-Clear.
7. **End with one-line verdict**: HEALTHY or "N issues found — see report".

Operating rules: read-only. Do not edit memory files. Be conservative on stale flagging, since most memory is evergreen.
```

**Invoke manually:**
```
Agent({ subagent_type: "memory-curator", description: "Memory health check", prompt: "Run the standard audit." })
```

---

## Deliberately not in this file

Two patterns from heavier setups were considered and excluded:

- **Skill test harness** (bash assertions per SKILL.md): useful for maintainers tracking 10+ custom skills with strict structural invariants. Too specific to recommend as a default.
- **Transcript cleanup script** (delete `.jsonl` >90 days): Anthropic ships better lifecycle tooling over time, so rolling your own may be redundant soon. Check your CLI version first.

Both can be added later as the setup demands. Start with the two above.
