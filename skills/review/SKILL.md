---
name: review
description: "Runs a multi-perspective code review covering code quality, security vulnerabilities (OWASP Top 10), and database query analysis on recent changes. Spawns parallel review agents and produces a severity-rated findings table with a GO/NO-GO verdict. Use when the user asks for 'code review', 'is this secure?', 'security review', 'check for vulnerabilities', or 'could this be exploited?'."
user-invocable: true
argument-hint: "[file, branch, git-range, or 'security' for security-only]"
---

This is a COMPREHENSIVE multi-agent code review. For quick anti-pattern scanning (seconds, not minutes), use review-diff instead.

## Step 0: Detect scope and project

- If `$ARGUMENTS` is empty: review uncommitted changes (staged + unstaged via `git diff` + `git diff --cached`)
- If `$ARGUMENTS` is a file path: review that file only
- If `$ARGUMENTS` is a branch or range: review diff against that ref
- If `$ARGUMENTS` is "security": run security-only review (skip to step 3)
- Detect project type from cwd/CLAUDE.md: Framework (e.g., Nuxt/NestJS/Prisma, Next.js/React, Node/TypeScript), or Other

## Step 1: Spawn review agents in parallel

Launch up to 3 agents based on what the changes touch:

| Changes Touch | Agent to Spawn | Focus |
|--------------|----------------|-------|
| Any code | `code-reviewer` | Quality, patterns, naming, DRY, error handling, consistency |
| API endpoints, auth, user input | `security-reviewer` | OWASP Top 10, injection, auth gaps, secrets, CORS |
| Database queries, Prisma schema, migrations | `db-analyst` | N+1, undefined vs null, missing models, query performance |

If changes are small (<50 lines), run code-reviewer only. If security argument, run security-reviewer only.

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
- **Prisma undefined vs null**: `undefined` = skip field, `null` = set NULL -- mixing them causes bugs
- **Missing models**: Every table needs a Prisma model or `prisma db push` drops it
- **N+1 queries**: findMany/findFirst inside loops -- should use `include` or batch queries
- **Relation loading**: Missing `include` for needed relations, or over-fetching with deep includes
- **Migration safety**: Schema changes that could drop data, rename columns, or break existing queries

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
