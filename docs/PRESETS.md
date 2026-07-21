# Starter Presets

Not sure where to start? Pick the preset that matches your situation. Each lists exactly which files to copy and the minimal settings.json to wire them up.

See [README.md](../README.md#who-is-this-for) for which preset matches your profile.

---

## Minimal

**For:** Solo dev, small project, just want basic protection.
**Setup time:** 5 minutes.
**Impact:** Config protection + edit verification reminders.

### Files to copy

| Source | Destination | Purpose |
|--------|-------------|---------|
| [`CLAUDE.md`](../CLAUDE.md) | `~/.claude/CLAUDE.md` | Behavioral rules (biggest single impact) |
| [`hooks/protect-config.sh`](../hooks/protect-config.sh) | `~/.claude/hooks/` | Block accidental config weakening |
| [`hooks/notify-file-changed.sh`](../hooks/notify-file-changed.sh) | `~/.claude/hooks/` | Remind to verify after source edits |

### Settings

Add to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"C:/Users/YourUser/.claude/hooks/protect-config.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"C:/Users/YourUser/.claude/hooks/notify-file-changed.sh\"",
            "async": true
          }
        ]
      }
    ]
  }
}
```

**macOS/Linux:** Replace `C:/Users/YourUser/` with `/Users/youruser/` (macOS) or `/home/youruser/` (Linux).

### What you get

- Claude asks before editing ESLint, Prettier, TypeScript, or build configs
- Automatic "did you verify?" reminder after every source file edit
- CLAUDE.md rules guide Claude's behavior (followed most of the time, but not guaranteed)

### What you don't get (and don't need yet)

- Git push protection (add when working with remotes)
- Agents and skills (add when your workflow demands more structure)
- Cost tracking (add when you want spending visibility)

---

## Standard

**For:** Developer comfortable with Claude Code, wants full lifecycle hooks + basic agents.
**Setup time:** 15 minutes.
**Impact:** Complete hook coverage + plan verification + code review.

### Files to copy (everything in Minimal, plus)

| Source | Destination | Purpose |
|--------|-------------|---------|
| [`hooks/block-git-push.sh`](../hooks/block-git-push.sh) | `~/.claude/hooks/` | Protect specific remotes from accidental pushes |
| [`hooks/cost-tracker.sh`](../hooks/cost-tracker.sh) | `~/.claude/hooks/` | Track token spending to JSONL |
| [`hooks/session-checkpoint.sh`](../hooks/session-checkpoint.sh) | `~/.claude/hooks/` | Crash recovery timestamps |
| [`hooks/post-commit-review.sh`](../hooks/post-commit-review.sh) | `~/.claude/hooks/` | Post-commit review reminders |
| [`agents/verify-plan.md`](../agents/verify-plan.md) | `~/.claude/agents/` | 7-point mechanical plan verification |
| [`agents/code-reviewer.md`](../agents/code-reviewer.md) | `~/.claude/agents/` | Independent code review agent |
| [`examples/settings-template.json`](../examples/settings-template.json) | `~/.claude/settings.json` | Full settings (customize paths + permissions) |

### Settings

Use the full [`settings-template.json`](../examples/settings-template.json) as your base. Customize:

1. Replace all `YourUser` paths with your actual username (Windows: `C:/Users/YourUser/`, macOS: `/Users/youruser/`, Linux: `/home/youruser/`)
2. Adjust the `allow` list for your stack (remove tools you don't use)
3. Edit `block-git-push.sh` to match your protected remote URLs
4. Review hook paths: ensure they match your OS (forward slashes on all platforms)

### What you get (beyond Minimal)

- Git push protection for specific remotes
- Token spending tracked to `~/.claude/metrics/costs.jsonl`
- Session checkpoints for crash recovery
- Post-commit review reminders with high-risk file detection
- Plan verification before implementation (catches count errors, missing wiring, stale paths)
- Independent code review from a fresh context window

---

## Core

**For:** Developer who wants a curated, broadly-useful set without the full specialist ecosystem.
**Setup time:** 20 minutes.
**Impact:** Everything in Standard, plus review/test/deploy skills and the two most broadly-useful path-scoped rules. No stack assumptions, no memory system required.

### Files to copy (everything in Standard, plus)

| Source | Destination | Purpose |
|--------|-------------|---------|
| [`agents/security-reviewer.md`](../agents/security-reviewer.md) | `~/.claude/agents/` | OWASP / auth / injection review |
| [`agents/qa-tester.md`](../agents/qa-tester.md) | `~/.claude/agents/` | Unit / integration / E2E test generation |
| [`skills/review-full/`](../skills/review-full/) | `~/.claude/skills/` | Multi-perspective code review |
| [`skills/review-diff/`](../skills/review-diff/) | `~/.claude/skills/` | Fast anti-pattern scan of a diff |
| [`skills/test-check/`](../skills/test-check/) | `~/.claude/skills/` | Run the test suite and report |
| [`skills/deploy-check/`](../skills/deploy-check/) | `~/.claude/skills/` | Pre-deploy checklist |
| [`skills/db-check/`](../skills/db-check/) | `~/.claude/skills/` | Schema integrity check |
| [`skills/changelog/`](../skills/changelog/) | `~/.claude/skills/` | Generate a changelog from git history |
| [`rules/testing.md`](../rules/testing.md) | `~/.claude/rules/` | Test conventions (loads only when editing test files) |
| [`rules/database-schema.md`](../rules/database-schema.md) | `~/.claude/rules/` | Schema patterns (loads only when editing schema files) |

### What you get (beyond Standard)

- Two read-only review agents: security review and test generation
- Six natural-language skills covering review, testing, deploy, DB, and changelog workflows
- Two path-scoped rules that cost zero context tokens until you actually edit a matching file
- A sensible middle ground: more capability than Standard, without installing the full 19-skill / 12-agent set you may never use

### What you don't get (and may not need)

- The stack-specific specialist agents (backend / frontend / DevOps / etc.): add via Full when your work calls for them
- The session/memory skills and the memory system: enable those when you want cross-session persistence

---

## Full

**For:** Team or power user wanting the complete production setup.
**Setup time:** 30 minutes.
**Impact:** Full specialist ecosystem with memory persistence.

### Files to copy (everything in Standard, plus)

| Category | Source | Destination |
|----------|--------|-------------|
| **All agents** | [`agents/*.md`](../agents/) | `~/.claude/agents/` |
| **All hooks** | [`hooks/*.sh`](../hooks/) | `~/.claude/hooks/` |
| **Skills you need** | [`skills/*/SKILL.md`](../skills/) | `~/.claude/skills/*/SKILL.md` |
| **Rules** | [`rules/*.md`](../rules/) | `~/.claude/rules/` |
| **Memory (opt-in)** | [`memory/`](../memory/) | Built-in, enabled via setup.sh |

### What you get (beyond Standard)

- 12 specialized agents (architecture, backend, frontend, DB, DevOps, security, QA, docs)
- 19 natural-language skills (review-full, pr-review, deploy-check, test-check, sprint-plan, etc.)
- Path-scoped rules (database conventions load only when editing schema files)
- Cross-session memory persistence via git-backed memory system
- Full lifecycle automation from session start to session end

### Customization

1. **Remove agents you don't need.** A Python project doesn't need `frontend-specialist.md`.
2. **Pick skills that match your workflow.** Start with `review-full`, `test-check`, and `deploy-check`. Add others as needed.
3. **Customize rules for your stack.** Edit `database-schema.md` for your ORM patterns, `api-endpoints.md` for your framework conventions.
4. **Enable memory persistence.** Answer Y when `./setup.sh` asks about memory, or read [memory/README.md](../memory/README.md) for the manual setup.

---

## CI/CD

**For:** Automated pipelines with no interactive use.
**Setup time:** 5 minutes.
**Impact:** Automated guardrails for CI-driven Claude Code sessions.

### Files to copy

| Source | Destination | Purpose |
|--------|-------------|---------|
| [`CLAUDE.md`](../CLAUDE.md) | Project root | Rules for the CI agent |
| [`hooks/block-git-push.sh`](../hooks/block-git-push.sh) | CI environment | Prevent pushes to protected branches |

### Settings

```json
{
  "permissions": {
    "defaultMode": "dontAsk"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"hooks/block-git-push.sh\""
          }
        ]
      }
    ]
  }
}
```

**macOS/Linux:** Replace `bash "hooks/block-git-push.sh"` with absolute paths, e.g., `bash "/Users/youruser/.claude/hooks/block-git-push.sh"`.

### Why `dontAsk` and not `auto` for CI/CD

- `dontAsk` is deterministic: same inputs always produce same permission decisions
- No classifier overhead (no extra token cost per action)
- No risk of classifier blocking a legitimate CI action mid-pipeline
- CI pipelines should be predictable; `auto` mode's contextual evaluation adds variability

### What you don't need in CI

- Cost tracker (use Anthropic's billing dashboard instead)
- Session memory (CI sessions are stateless)
- Interactive agents (no human to review plans)
- Notification hooks (CI has its own notification systems)

---

## Upgrading Between Presets

Moving from one preset to the next is additive: you never need to redo earlier steps.

```
Minimal → Standard:  Add 4 hooks + 2 agents + full settings.json
Standard → Core:     Add 2 review agents + 6 skills + 2 path-scoped rules
Core → Full:         Add remaining agents, skills, rules, memory
Any → CI/CD:         Separate concern; CI uses its own settings, not your dev settings
```

The recommended path: start Minimal, use it for a week, then upgrade to Standard when you notice gaps. Step up to Core when you want review/test/deploy skills without the full ecosystem. Move to Full only when you're actively using the specialist agents and the wider skill set in your workflow.
