---
name: db-check
description: Validate database schema integrity and check for common issues
user-invocable: true
---

Database health check for the current project:

1. Read the ORM schema file (e.g., `prisma/schema.prisma`, `drizzle/schema.ts`, SQLAlchemy models, ActiveRecord schema, Entity Framework DbContext, GORM structs, or equivalent) and analyze all models
2. **CRITICAL**: Check all database tables have ORM models (unmodeled tables may be dropped on schema sync, e.g. Prisma db push; know whether your ORM's sync command is destructive)
3. Check for missing indexes on foreign keys and frequently queried columns
4. Scan services for N+1 query patterns (missing eager loading / includes in queries)
5. Verify `undefined` vs `null` usage in all ORM create/update operations
6. Check raw SQL queries for injection vulnerabilities (parameterized queries required)
7. Verify referential integrity (cascade rules, orphan prevention)
8. Check for date handling issues (check CLAUDE.md for system-specific date formats)
9. Review migration history for risky operations

Report findings with severity: CRITICAL / HIGH / MEDIUM / LOW.
