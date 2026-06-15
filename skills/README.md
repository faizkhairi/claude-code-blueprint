# Skills

17 domain-specific skills triggered by natural language (no slash commands needed).

## Skill Categories

| Category | Skills | Triggers |
|----------|--------|----------|
| **Code Quality** | review-full, review-diff | "is this secure?", "scan diff", "check for vulnerabilities" |
| **Testing** | test-check, e2e-check | "run the tests", "browser test", "are tests passing?" |
| **Deployment** | deploy-check | "deploy", "push to prod", "ready to ship", "npm audit" |
| **Planning** | sprint-plan, elicit-requirements | "let's build", "new feature", multi-step tasks |
| **Session** | load-session, save-session, session-end, save-diary | Session start/end, "save", "bye", "done" |
| **Project** | scaffold-project, register-project, status, changelog | "new project", "register project", "status" |
| **Database** | db-check | "check the schema", "database health", "validate models" |
| **Utilities** | tech-radar | "what's new?", "any updates?", "should we upgrade?" |

## Design Principles

1. **Natural language triggers** — Skills detect intent from conversation, not slash commands
2. **Step-by-step workflows** — Each skill has numbered steps that Claude follows mechanically
3. **GO/NO-GO verdicts** — Review and deploy skills end with clear pass/fail decisions
4. **Multi-agent orchestration** — The review-full skill spawns code-reviewer + security-reviewer + db-analyst in parallel

## Required: Replace Placeholder Variables

Before using skills that reference external paths, you **must** replace these placeholders in your copy:

| Variable | Replace With | Example (macOS/Linux) | Example (Windows) |
|----------|-------------|----------------------|-------------------|
| `{CLAUDE_CONFIG_PATH}` | Path to your Claude config | `~/.claude` | `C:/Users/you/.claude` |
| `{PROJECTS_ROOT}` | Path to your projects directory | `~/projects` | `C:/Users/you/projects` |
| `{MEMORY_MD_PATH}` | Path to your auto-memory MEMORY.md | `~/.claude/projects/*/memory/MEMORY.md` | `C:/Users/you/.claude/projects/*/memory/MEMORY.md` |
| `{BOILERPLATE_NAME}` | Name of your boilerplate template directory | `nuxt-boilerplate` | `nuxt-boilerplate` |
| `{USER_NAME}` | Your name (used in skill descriptions) | `Jane` | `Jane` |

> **Note on memory paths**: skills like `load-session`, `save-session`, `session-end`, `save-diary`, and `register-project` reference `./memory/` directly — that's the built-in opt-in memory folder shipped with the blueprint, not a placeholder you substitute. If you enabled memory via `./setup.sh`, those paths already work. No replacement needed.

**Skills that need placeholder replacement:** scaffold-project (uses `{PROJECTS_ROOT}` and `{BOILERPLATE_NAME}`), plus any skill that references `{CLAUDE_CONFIG_PATH}`, `{MEMORY_MD_PATH}`, or `{USER_NAME}`.

**How to check:** Search your skills directory for unreplaced `{NAME}`-style variables:
```bash
grep -rE '\{CLAUDE_CONFIG_PATH\}|\{PROJECTS_ROOT\}|\{MEMORY_MD_PATH\}|\{BOILERPLATE_NAME\}|\{USER_NAME\}' ~/.claude/skills/
```
If you see results with curly braces still present, those variables haven't been replaced yet — Claude will try to read literal paths and fail with "file not found."

## Extending Skills for Your Stack

Skills are designed to be generic, but you'll get more value by adding stack-specific checks. Here are examples of what to add — adapt these for YOUR stack's failure modes.

### review-full skill — Add ORM query check

In `review-full/SKILL.md`, add to the code review checklist:

```
- Check for N+1 queries: any loop that calls a database query (e.g., findMany inside a map/forEach) should use eager loading or a batch query instead
```

### deploy-check skill — Add ORM pre-build step

In `deploy-check/SKILL.md`, add to the pre-deployment validation:

```
- Verify ORM client is generated: run the ORM's generate/build command (e.g., `prisma generate`, `drizzle-kit generate`) and confirm it succeeds before building the application
```

### test-check skill — Add coverage threshold

In `test-check/SKILL.md`, add to the test validation steps:

```
- Check coverage meets project threshold: run tests with coverage flag and verify the output meets the minimum set in CLAUDE.md (e.g., 80% line coverage). Flag any drop from the previous baseline.
```

### db-check skill — Add migration drift detection

In `db-check/SKILL.md`, add to the schema validation:

```
- Check for migration drift: compare the current database state against the ORM's schema definition. If the ORM supports it (e.g., `prisma migrate diff`, `drizzle-kit check`), run the diff and report any untracked changes.
```

> These are examples, not prescriptions. Add checks for YOUR stack's failure modes — the ones that have actually burned you.
