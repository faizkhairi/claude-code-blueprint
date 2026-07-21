---
paths:
  - "**/prisma/**"
  - "**/drizzle/**"
  - "**/migrations/**"
  - "**/schema.*"
  - "**/models/**"
---

<!--
  Why this rule exists: an ORM that does not know about a table can silently drop
  it on the next schema sync (e.g. Prisma db push). These rules keep your schema
  and ORM models in agreement so a migration never destroys data you forgot to model.
-->

# Database Schema & Migration Rules

These rules apply when working with database schemas, ORM models, and migrations. Adapt to your project's ORM (Prisma, Drizzle, TypeORM, Sequelize, Knex, etc.).

## Critical Constraints

### Schema-Model Sync
- **Your ORM must know about every table it manages.** Some ORMs (e.g., Prisma `db push`) will DROP tables without a corresponding model. Always verify before syncing.
- Before adding raw SQL that creates tables, add the ORM model first.
- Check existing tables against the schema before running migrations.

### Undefined vs Null (ORM-specific)
- In Prisma: `undefined` = skip field, `null` = set to NULL
- In Drizzle/TypeORM: similar, check your ORM's handling of missing vs explicit null
- Use `?? null` for nullable fields, never `|| ''`
- Example: `amount: body.amount ?? null` (correct)
- Example: `amount: body.amount || ''` (WRONG: can't distinguish empty vs not provided)

### Database Engine Gotchas
Check your engine and note limitations in CLAUDE.md:
- **MariaDB**: No `createManyAndReturn` in Prisma, so use `createMany()` then `findMany()`
- **SQLite**: No concurrent writes, limited ALTER TABLE support
- **PostgreSQL**: Most feature-rich, fewer gotchas
- **MySQL**: Check `GROUP BY` strictness (`ONLY_FULL_GROUP_BY`)

## Schema Best Practices

### Indexing Strategy
- **Index ALL foreign keys** (single column)
- Add composite indexes for common query patterns
- Index status/state columns used in WHERE clauses
- Index timestamp fields for range queries

### Naming Conventions
- Be consistent within your project, check CLAUDE.md for naming standards
- Common patterns: `snake_case` for table/column names, `PascalCase` for model names
- Document your naming convention so all team members and AI assistants follow it

### Relations
- Always specify `onDelete` and `onUpdate` behavior
- Use `CASCADE` for parent-child relationships
- Use `NO ACTION` or `RESTRICT` for lookup/reference tables
- Use `SET NULL` carefully (can create orphaned records)

### Common Field Patterns
- **IDs**: UUID for distributed systems, auto-increment for single-database
- **Timestamps**: `created_at` (default now), `updated_at` (auto-updated)
- **Soft deletes**: `deleted_at` (nullable datetime) + `is_active` (boolean, default true)
- **JSON fields**: Use sparingly, prefer structured fields for queryable data

## Migration Safety

### Before Creating a Migration
1. Read current schema
2. Check if new tables already exist in the database
3. Verify no tables will be dropped (compare schema vs DB)
4. Plan rollback strategy
5. Check CLAUDE.md for system-specific date formats and constraints

### Migration Checklist
- [ ] All existing tables have ORM models
- [ ] New tables added to schema BEFORE migration
- [ ] Foreign keys are indexed
- [ ] Nullable fields use proper types
- [ ] Date formats match system requirements (check CLAUDE.md)
- [ ] Migration is reversible
- [ ] No data loss expected
- [ ] ORM client regenerated after schema changes (e.g., `prisma generate`)

## Query Patterns

### Avoid N+1 Queries
```javascript
// BAD: N+1 query
const users = await orm.user.findMany();
for (const user of users) {
  const posts = await orm.post.findMany({ where: { userId: user.id } });
}

// GOOD: Single query with eager loading / include / join
const users = await orm.user.findMany({
  include: { posts: true }
});

// ALSO GOOD: Batch query with Map
const users = await orm.user.findMany();
const userIds = users.map(u => u.id);
const posts = await orm.post.findMany({
  where: { userId: { in: userIds } }
});
```

### Transaction Safety
```javascript
// Use transactions for multi-step operations
await orm.$transaction(async (tx) => {
  await tx.model1.create({...});
  await tx.model2.update({...});
});
```

## Common Mistakes to Avoid

1. **Missing ORM model** → Table may be dropped on schema sync
2. **Using `|| ''` instead of `?? null`** → Can't distinguish empty vs not provided
3. **Forgetting foreign key indexes** → Slow query performance
4. **String interpolation in raw SQL** → SQL injection vulnerability
5. **Skipping client regeneration** → ORM client out of sync with schema
6. **Not testing migrations on a copy** → Risky to run untested migrations on production
