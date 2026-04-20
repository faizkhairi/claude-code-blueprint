---
name: deploy-check
description: "Runs pre-deployment safety checks including test suite validation, secrets scanning, dependency auditing, schema verification, and build confirmation. Produces a GO/NO-GO verdict. Use before any git push to main/production, when the user mentions 'deploy', 'going live', 'push to prod', 'ready to ship', 'merge to main', or 'release'. Also triggers on 'audit', 'check vulnerabilities', 'npm audit', 'yarn audit' for dependency-only scans."
user-invocable: true
argument-hint: "[environment: dev|stg|prod] or ['audit' for deps-only]"
---

Pre-deployment validation for $ARGUMENTS environment:

1. **Tests**: Run full test suite — all must pass
2. **Git status**: Check for uncommitted changes (`git status`)
3. **Schema sync**: Verify Prisma schema matches expectations (`npx prisma validate`)
4. **Secrets check**: Scan for hardcoded credentials, API keys, passwords
   ```bash
   grep -rE '(password|secret|api_key|token)\s*[:=]\s*["\x27][^"\x27]{8,}' --include='*.ts' --include='*.js' --include='*.env*' .
   ```
5. **Dev artifacts**: Check for debug statements in production paths
   ```bash
   grep -rn 'console\.log\|debugger\b' --include='*.ts' --include='*.js' src/
   ```
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
