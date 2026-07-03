---
name: deploy-check
description: "MUST use before any git push to main/master/production, or when user mentions 'deploy', 'going live', 'push to prod', 'ready to ship', 'merge to main', 'release'. Also trigger before any npm publish for CLI tools, or on 'audit', 'check vulnerabilities', 'are our deps safe?', 'npm audit', 'yarn audit'. Performs: test suite validation, dev-artifact scan (`console.log`, `TODO`/`FIXME`, hardcoded secrets like `password:` / `token:` / API keys), dependency audit (npm audit, pip-audit, bundle audit, cargo audit, govulncheck, etc.), build verification, ORM/schema safety check, auth-middleware coverage on new endpoints. Verdict: GO / NO-GO with per-check checklist."
user-invocable: true
argument-hint: "[environment: dev|stg|prod] or ['audit' for deps-only]"
---

Pre-deployment validation for $ARGUMENTS environment:

1. **Tests**: Run full test suite, all must pass
2. **Git status**: Check for uncommitted changes across all repos
3. **Schema sync**: Verify the project's ORM/DB schema definition matches expectations (e.g. Prisma schema, Django models, Rails schema.rb, migrations directory)
4. **Secrets check**: Scan for hardcoded credentials, API keys, passwords
5. **Dev artifacts**: Check for language-appropriate debug/print statements (console.log, print(), System.out.println, fmt.Println, etc.), debugger statements, TODO/FIXME in production paths
6. **Env vars**: Verify required environment variables are documented
7. **Auth coverage**: Validate all API endpoints have auth middleware
8. **Dependency audit**: Run the ecosystem's dependency audit (`npm audit`/`yarn audit`, `pip-audit`, `bundle audit`, `cargo audit`, `govulncheck`, etc., detected from the manifest/lockfile). Classify: CRITICAL/HIGH (action required) vs MODERATE/LOW (note). Separate production vs dev-only vulnerabilities. Check for auto-fixable with `--dry-run`.
9. **Build**: Verify project builds without errors
10. **Migration safety**: Check if any ORM models/migrations are missing (risk of tables dropped by destructive sync)

If argument is "audit" → run only step 8 (dependency vulnerability scan) across the current project.

## GO/NO-GO Criteria
- **NO-GO**: Any test failure, hardcoded secret found, ORM model/migration missing, build failure, or CRITICAL/HIGH vulnerability in production deps
- **GO**: All steps pass. MODERATE/LOW vulnerabilities in dev-only deps are acceptable with note.
- **GO with warnings**: All critical steps pass but non-blocking issues exist (dev-only vulns, TODO items in non-critical paths)

Output: GO / NO-GO status with detailed checklist results.
