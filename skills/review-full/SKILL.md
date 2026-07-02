---
name: review-full
description: "Run a comprehensive multi-perspective code review on recent changes. Also triggers on 'is this secure?', 'security review', 'check for vulnerabilities', 'could this be exploited?' for security-focused review. Produces: GO/NO-GO verdict + findings table (Severity | Category | File:Line | Issue | Recommendation) grouping CRITICAL/HIGH/MEDIUM/LOW across code quality (patterns, error handling, types), security (OWASP Top 10, auth gaps, hardcoded secrets), and database logic (N+1 queries, soft-delete violations, missing models)."
user-invocable: true
argument-hint: "[file, branch, git-range, or 'security' for security-only]"
---

This is a COMPREHENSIVE multi-agent code review. For quick anti-pattern scanning (seconds, not minutes), use review-diff instead.

## Step 0: Detect scope and project

- If `$ARGUMENTS` is empty: review uncommitted changes (staged + unstaged via `git diff` + `git diff --cached`)
- If `$ARGUMENTS` is a file path: review that file only
- If `$ARGUMENTS` is a branch or range: review diff against that ref
- If `$ARGUMENTS` is "security": run security-only review (skip to step 3)
- Detect project type from cwd/CLAUDE.md and the project manifest (any language/framework), or fall back to inspecting the file structure

## Step 1: Spawn review agents in parallel

Launch up to 4 agents based on what the changes touch:

| Changes Touch | Agent to Spawn | Focus |
|--------------|----------------|-------|
| Any code | `code-reviewer` | Quality, patterns, naming, DRY, error handling, consistency |
| API endpoints, auth, user input | `security-reviewer` | OWASP Top 10, injection, auth gaps, secrets, CORS |
| Database queries, ORM models, migrations | `db-analyst` | N+1, undefined vs null, missing models, query performance |
| New modules, moved files, cross-layer imports, large refactors | `architecture-reviewer` | Dependency direction, circular deps, god files, dead code, modularity |

If changes are small (<50 lines), run code-reviewer only. If security argument, run security-reviewer only. Add `architecture-reviewer` when the change reshapes structure (new module boundaries, files moved across layers, a refactor spanning several directories) rather than editing within existing files.

## Step 2: Code quality review (via code-reviewer agent)

The agent checks:
- Readability and naming conventions (matches project patterns?)
- DRY -- duplicated logic that should be extracted
- Error handling -- all async paths covered? Consistent error shapes?
- Component/function size -- single responsibility?
- TypeScript types -- proper typing, no `any` leaks?

## Step 3: Security review (via security-reviewer agent)

The agent checks OWASP Top 10 plus project-specific patterns (read from `CLAUDE.md`):
- **Injection**: SQL injection (raw queries without parameterization), command injection, XSS (unsanitized user input in templates)
- **Auth gaps**: New endpoints/handlers without auth middleware (@UseGuards, defineMiddleware, session check)
- **Soft-delete violations**: Hard DELETE/destroy used instead of soft-delete pattern (check `CLAUDE.md` for convention, e.g., `is_active=false + deleted_at=new Date()`)
- **Secrets exposure**: Hardcoded tokens, passwords, API keys in code (not .env)
- **API call patterns**: Direct low-level fetch calls instead of the project's API composable (check `CLAUDE.md`)
- **Navigation patterns**: Raw router calls instead of the framework-specific navigation function (check `CLAUDE.md`)
- **CORS/headers**: Missing security headers, overly permissive CORS
- **Dependency CVEs**: Check for known vulnerabilities in changed dependencies

## Step 4: Database review (via db-analyst agent, if applicable)

The agent checks:
- **ORM null-handling**: many ORMs distinguish "skip field" from "set NULL" (e.g. Prisma's `undefined` vs `null`) -- mixing them causes bugs
- **Schema/code drift**: unmodeled tables can be dropped by destructive sync commands (e.g. `prisma db push`) -- verify every table is represented
- **N+1 queries**: findMany/findFirst inside loops -- should use `include` or batch queries
- **Relation loading**: Missing `include` for needed relations, or over-fetching with deep includes
- **Migration safety**: Schema changes that could drop data, rename columns, or break existing queries

## Step 4b: Structural review (via architecture-reviewer agent, if applicable)

Run only when the change reshapes structure (new modules, files moved across layers, a multi-directory refactor). The agent checks:
- **Dependency direction**: do inner layers avoid importing outer ones? (domain/core should not depend on UI/framework)
- **Circular dependencies**: modules that import each other, directly or through a cycle
- **God files/modules**: single files accumulating unrelated responsibilities
- **Dead code**: exports/modules no longer imported anywhere
- **Modularity**: are boundaries between features/layers clear, or is logic leaking across them?

This is language-agnostic — it calibrates to the project's own conventions (read from `CLAUDE.md` and the manifest), so it applies equally to any stack.

## Step 5: Synthesize findings

Collect all agent findings into a single severity-rated table:

```
| # | Severity | Category | File:Line | Finding | Recommendation |
|---|----------|----------|-----------|---------|----------------|
```

Severity levels:
- **CRITICAL**: Security vulnerability, data loss risk, auth bypass
- **HIGH**: Logic bug, missing error handling, N+1 query, soft-delete violation
- **MEDIUM**: Code quality, naming, DRY, missing types
- **LOW**: Style, minor improvements, suggestions

## Step 6: GO/NO-GO verdict

- **NO-GO**: Any CRITICAL or HIGH finding present → must fix before merge/deploy
- **GO with notes**: Only MEDIUM/LOW findings → safe to proceed, address in follow-up
- **GO**: No findings → clean review
