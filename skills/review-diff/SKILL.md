---
name: review-diff
description: "Scan git diffs for project-specific anti-patterns. Triggers on: 'scan diff', 'check diff', 'anti-pattern check', 'pattern scan', 'review changes'."
user-invocable: true
argument-hint: "[branch | commit-range | empty=uncommitted]"
---

Scan a git diff for project-specific anti-patterns. This is a fast, targeted scan (seconds), not a full code review. Use `/review` for comprehensive analysis.

## Step 0: Detect project

Ensure you are inside a git repository before running diff commands:
- If cwd is a git repo: use it
- If recent context references a project: `cd` into it first
- Check `CLAUDE.md` or the project manifest (package.json, composer.json, pom.xml, Gemfile, *.csproj, go.mod, Cargo.toml, requirements.txt/pyproject.toml, etc.) in the project root to identify the framework and project-specific patterns
- If unclear: ask which project

## Step 1: Get the diff

Determine the diff source from `$ARGUMENTS`:
- **No arguments**: Run `git diff` (unstaged) + `git diff --cached` (staged). Combine both outputs.
- **Branch name** (e.g., `feat/xyz`): Run `git diff main...$ARGUMENTS`
- **Commit range** (e.g., `HEAD~3..HEAD`): Run `git diff $ARGUMENTS`
- **Single commit hash**: Run `git diff $ARGUMENTS~1..$ARGUMENTS`

If the diff is empty, report "No changes to scan." and stop.

## Step 2: Scan for anti-patterns

Analyze ONLY `+` lines (additions) in the diff. For each pattern below, search the added lines and the surrounding file context when needed.

### Pattern Table

| # | Pattern | What to look for | Severity |
|---|---------|-----------------|----------|
| 1 | **Filter logic mismatch** | String `===` comparisons where one value could be a prefix of the other (e.g., `'All' === value` when value could be `'All Categories'`). Also: inconsistent use of `startsWith()` vs `===` on the same field across the diff. This requires semantic understanding, not just regex. | HIGH |
| 2 | **Auth gaps** | New `defineEventHandler`, `@Get()`, `@Post()`, `@Put()`, `@Delete()`, `@Patch()` without a corresponding `@UseGuards()` or `defineMiddleware` in the same file. Read the full file if needed to check. | HIGH |
| 3 | **Soft-delete violations** | `DELETE FROM`, `.delete(`, `.deleteMany(`, `.destroy(` in any ORM/SQL (adapt the delete-method names to your ORM) without corresponding `is_active` or `deleted_at` in the same block. Many projects require soft-delete: `is_active=false` + `deleted_at=new Date()`. Check `CLAUDE.md` for the project's soft-delete convention. | CRITICAL |
| 4 | **(Nuxt/Vue projects, adapt for your framework)** API call pattern | `$fetch(` or `useFetch(` in `.vue` files when the project uses a custom API composable. Check `CLAUDE.md` for the project's API composable (e.g., a wrapper around `$fetch`). Exception: server-side code in `server/` directories may use `$fetch`. | MEDIUM |
| 5 | **(Nuxt/Vue projects, adapt for your framework)** Navigation pattern | `router.push(` or `router.replace(` in `.vue` files when the framework provides a preferred navigation function. Check `CLAUDE.md` for the framework-specific navigation function. | MEDIUM |
| 6 | **Secrets in diff** | Patterns like `password:`, `token:`, `secret:`, `apiKey:`, `DATABASE_URL` followed by a quoted string literal (not `process.env.`, `useRuntimeConfig()`, or env variable references). | CRITICAL |
| 7 | **(Nuxt/Vue projects, adapt for your framework)** External route gap | New files added under `server/routes/` or `server/api/`, check if corresponding frontend navigation uses `external: true` and `<a href>` instead of `<NuxtLink>`. Flag if unclear. | LOW |
| 8 | **N+1 queries** | `findMany`, `findFirst`, `findUnique` called inside `for`, `for...of`, `forEach`, `.map(`, `while` loops. Each iteration hits the DB separately instead of batching. | HIGH |
| 9 | **(Nuxt/Vue projects, adapt for your framework)** CJS default import | `import X from 'cron-parser'` or similar default imports from known CJS packages (`cron-parser`, `lodash`, `moment`). In Nuxt 4 + Vite, use named imports: `import { CronExpressionParser } from 'cron-parser'`. | MEDIUM |
| 10 | **(Nuxt/Vue projects, adapt for your framework)** DevServer binding | `0.0.0.0` appearing in config files (`vite.config`, `nuxt.config`, `devServer` sections). Binds to all network interfaces; security risk. | HIGH |

## Step 3: Build findings table

For each finding, extract:
- **File**: from the diff `+++ b/...` header
- **Line**: calculate from `@@ -X,Y +Z,W @@` hunk headers by counting `+` lines
- **Pattern**: the pattern name from the table above
- **Finding**: the specific line or code that triggered the match
- **Recommendation**: what to change

Output format:

```
| # | Severity | File | Line | Pattern | Finding | Recommendation |
|---|----------|------|------|---------|---------|----------------|
| 1 | CRITICAL | path/to/file.ts | 42 | Soft-delete | `.delete({ where: ... })` | Use `update({ is_active: false, deleted_at: new Date() })` |
```

If no findings: "No anti-patterns detected in the diff. GO."

## Step 4: Summary

```
Review-diff: X findings (Y critical, Z high, W medium, V low)
Verdict: GO / REVIEW NEEDED
```

- **GO**: 0 critical, 0 high findings
- **REVIEW NEEDED**: any critical or high findings present
