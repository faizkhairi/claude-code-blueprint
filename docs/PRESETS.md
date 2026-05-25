# Starter Presets

Not sure where to start? Pick the preset that matches your situation. Each lists exactly which files to copy and the minimal settings.json to wire them up.

See [README.md](README.md#who-is-this-for) for which preset matches your profile.

---

## Minimal

**For:** Solo dev, small project, just want basic protection.
**Setup time:** 5 minutes.
**Impact:** Config protection + edit verification reminders.

### Files to copy

| Source | Destination | Purpose |
|--------|-------------|---------|
| [`CLAUDE.md`](CLAUDE.md) | Your project root | Behavioral rules (biggest single impact) |
| [`hooks/protect-config.sh`](hooks/protect-config.sh) | `~/.claude/hooks/` | Block accidental config weakening |
| [`hooks/notify-file-changed.sh`](hooks/notify-file-changed.sh) | `~/.claude/hooks/` | Remind to verify after source edits |

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
- CLAUDE.md rules guide Claude's behavior (~80% compliance)

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
| [`hooks/block-git-push.sh`](hooks/block-git-push.sh) | `~/.claude/hooks/` | Protect specific remotes from accidental pushes |
| [`hooks/cost-tracker.sh`](hooks/cost-tracker.sh) | `~/.claude/hooks/` | Track token spending to JSONL |
| [`hooks/session-checkpoint.sh`](hooks/session-checkpoint.sh) | `~/.claude/hooks/` | Crash recovery timestamps |
| [`hooks/post-commit-review.sh`](hooks/post-commit-review.sh) | `~/.claude/hooks/` | Post-commit review reminders |
| [`agents/verify-plan.md`](agents/verify-plan.md) | `~/.claude/agents/` | 7-point mechanical plan verification |
| [`agents/code-reviewer.md`](agents/code-reviewer.md) | `~/.claude/agents/` | Independent code review agent |
| [`examples/settings-template.json`](examples/settings-template.json) | `~/.claude/settings.json` | Full settings (customize paths + permissions) |

### Settings

Use the full [`settings-template.json`](examples/settings-template.json) as your base. Customize:

1. Replace all `YourUser` paths with your actual username (Windows: `C:/Users/YourUser/`, macOS: `/Users/youruser/`, Linux: `/home/youruser/`)
2. Adjust the `allow` list for your stack (remove tools you don't use)
3. Edit `block-git-push.sh` to match your protected remote URLs
4. Review hook paths -- ensure they match your OS (forward slashes on all platforms)

### What you get (beyond Minimal)

- Git push protection for specific remotes
- Token spending tracked to `~/.claude/metrics/costs.jsonl`
- Session checkpoints for crash recovery
- Post-commit review reminders with high-risk file detection
- Plan verification before implementation (catches count errors, missing wiring, stale paths)
- Independent code review from a fresh context window

---

## Full

**For:** Team or power user wanting the complete production setup.
**Setup time:** 30 minutes.
**Impact:** Full specialist ecosystem with memory persistence.

### Files to copy (everything in Standard, plus)

| Category | Source | Destination |
|----------|--------|-------------|
| **All agents** | [`agents/*.md`](agents/) | `~/.claude/agents/` |
| **All hooks** | [`hooks/*.sh`](hooks/) | `~/.claude/hooks/` |
| **Skills you need** | [`skills/*/SKILL.md`](skills/) | `~/.claude/skills/*/SKILL.md` |
| **Rules** | [`rules/*.md`](rules/) | `~/.claude/rules/` |
| **Memory template** | [`memory-template/`](memory-template/) | Your memory repo |

### What you get (beyond Standard)

- 11 specialized agents (architecture, backend, frontend, DB, DevOps, security, QA, docs)
- 17 natural-language skills (review, deploy-check, test-check, sprint-plan, etc.)
- Path-scoped rules (database conventions load only when editing schema files)
- Cross-session memory persistence via git-backed memory system
- Full lifecycle automation from session start to session end

### Customization

1. **Remove agents you don't need.** A Python project doesn't need `frontend-specialist.md`.
2. **Pick skills that match your workflow.** Start with `review`, `test-check`, and `deploy-check`. Add others as needed.
3. **Customize rules for your stack.** Edit `database-schema.md` for your ORM patterns, `api-endpoints.md` for your framework conventions.
4. **Set up your memory repo.** Follow [memory-template/README.md](memory-template/README.md) to initialize your cross-session persistence.

---

## CI/CD

**For:** Automated pipelines with no interactive use.
**Setup time:** 5 minutes.
**Impact:** Automated guardrails for CI-driven Claude Code sessions.

### Files to copy

| Source | Destination | Purpose |
|--------|-------------|---------|
| [`CLAUDE.md`](CLAUDE.md) | Project root | Rules for the CI agent |
| [`hooks/block-git-push.sh`](hooks/block-git-push.sh) | CI environment | Prevent pushes to protected branches |

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

- `dontAsk` is deterministic -- same inputs always produce same permission decisions
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

Moving from one preset to the next is additive -- you never need to redo earlier steps.

```
Minimal → Standard:  Add 4 hooks + 2 agents + full settings.json
Standard → Full:     Add remaining agents, skills, rules, memory
Any → CI/CD:         Separate concern -- CI uses its own settings, not your dev settings
```

The recommended path: start Minimal, use it for a week, then upgrade to Standard when you notice gaps. Move to Full only when you're actively using agents and skills in your workflow.

---

## Stack Rule Templates

The presets above tell you **how much** of the blueprint to adopt. These templates tell you **what framework-specific rules** to add to your CLAUDE.md.

> These are structural starting points. Replace with battle-tested rules from your own incidents as you discover them. The pattern matters more than the content.

### Backend API

Add these to your CLAUDE.md when building server-side APIs (any framework — Express, NestJS, FastAPI, Django, Go, etc.):

```markdown
## Stack Rules

### API Conventions
- All endpoints follow RESTful naming: plural nouns, no verbs (e.g., `/api/users`, not `/api/getUsers`)
- Every endpoint returns a consistent response envelope: `{ data, error, meta }`
- Validate all request input at the handler boundary — never trust unvalidated data deeper in the stack
- Use middleware for cross-cutting concerns (auth, logging, rate limiting) — not inline checks per route
- Soft delete only — never use hard DELETE. Set `is_active = false` + `deleted_at = now()`

### Error Handling
- All errors return structured JSON with status code, error code, and human-readable message
- Never expose stack traces, internal paths, or database details in error responses
- Log the full error internally; return a sanitized version to the client

### Database Access
- All database access goes through a service/repository layer — never query directly from route handlers
- Use a singleton connection pool — never instantiate a new connection per request
- Run migrations explicitly (`[your ORM] migrate`) — never auto-migrate in production
```

### Full-Stack App

Add these when building apps with both server and client code (any meta-framework — Nuxt, Next.js, SvelteKit, Remix, etc.):

```markdown
## Stack Rules

### Server / Client Boundary
- Data fetching happens server-side — use the framework's server data-loading mechanism, not client-side fetch
- Sensitive logic (auth checks, database queries, API keys) never runs on the client
- Mark client-only code explicitly with the framework's directive (e.g., `'use client'`, `<ClientOnly>`, etc.)

### State Management
- Server state and client state are separate concerns — don't mix them in one store
- Use the framework's built-in state mechanism before reaching for external state libraries
- Form state stays local to the form component unless it needs to be shared

### Navigation & Routing
- Use the framework's navigation primitive — not raw `window.location` or `<a href>`
- Dynamic routes use the framework's parameter syntax — never construct URLs by string concatenation
- Protect authenticated routes with middleware/guards, not per-page checks

### Rendering
- Default to server rendering — opt into client rendering only when interactivity requires it
- Keep page components thin — extract logic into composables/hooks, UI into subcomponents
- Images use the framework's optimized image component — not raw `<img>` tags
```

### Database + ORM

Add these when your project has a database layer (any ORM — Prisma, Drizzle, TypeORM, SQLAlchemy, GORM, etc.):

```markdown
## Stack Rules

### Schema Conventions
- Table names: plural, snake_case (e.g., `user_roles`, not `UserRole`)
- Every table has: `id` (primary key), `created_at`, `updated_at`
- Soft-delete tables add: `is_active` (boolean, default true), `deleted_at` (nullable timestamp)
- Foreign keys are explicit — never rely on application-level joins without DB constraints

### Migrations
- Every schema change gets a migration — never edit the database directly
- Migrations are reviewed before running — treat them like production deployments
- Down migrations must be tested — if you can't roll back, document why in the migration file

### Query Patterns
- Use the ORM's query builder for standard operations — raw SQL only for performance-critical queries
- Always select only needed columns — no `SELECT *` equivalent in production code
- Watch for N+1 queries — use eager loading/joins for related data that will be accessed
- Connection pooling is mandatory — configure pool size based on your deployment (serverless vs. long-running)
```

> Don't see your stack? Copy the closest template and adapt. You can also combine templates — a full-stack app with a database layer would use both the "Full-Stack App" and "Database + ORM" templates together.
