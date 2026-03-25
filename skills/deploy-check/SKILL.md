---
name: deploy-check
description: "MUST use before any git push to main/master/production, or when user mentions 'deploy', 'going live', 'push to prod', 'ready to ship', 'merge to main', 'release'. Also trigger before any npm publish for CLI tools. Also triggers on: 'audit', 'check vulnerabilities', 'are our deps safe?', 'npm audit', 'yarn audit'."
user-invocable: true
argument-hint: "[environment: dev|stg|prod] or ['audit' for deps-only]"
---

Pre-deployment validation for $ARGUMENTS environment:

1. **Tests**: Run full test suite — all must pass
2. **Git status**: Check for uncommitted changes across all repos
3. **Schema sync**: Verify Prisma schema matches expectations
4. **Secrets check**: Scan for hardcoded credentials, API keys, passwords
5. **Dev artifacts**: Check for console.log, debugger statements, TODO/FIXME in production paths
6. **Env vars**: Verify required environment variables are documented
7. **Auth coverage**: Validate all API endpoints have auth middleware
8. **Dependency audit**: Run `npm audit` or `yarn audit` (detect from lockfile). Classify: CRITICAL/HIGH (action required) vs MODERATE/LOW (note). Separate production vs dev-only vulnerabilities. Check for auto-fixable with `--dry-run`.
9. **Build**: Verify project builds without errors
10. **Migration safety**: Check if any Prisma models are missing (tables would be dropped)

If argument is "audit" → run only step 8 (dependency vulnerability scan) across the current project.

## GO/NO-GO Criteria
- **NO-GO**: Any test failure, hardcoded secret found, Prisma model missing, build failure, or CRITICAL/HIGH vulnerability in production deps
- **GO**: All steps pass. MODERATE/LOW vulnerabilities in dev-only deps are acceptable with note.
- **GO with warnings**: All critical steps pass but non-blocking issues exist (dev-only vulns, TODO items in non-critical paths)

Output: GO / NO-GO status with detailed checklist results.
