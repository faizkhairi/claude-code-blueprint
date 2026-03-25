# Rules

5 path-scoped behavioral constraints that load only when Claude is working with matching files.

## How Path-Scoped Rules Work

Rules in `.claude/rules/` use `paths:` frontmatter with glob patterns. Claude Code loads a rule **only** when the current task involves files matching those patterns. This keeps irrelevant rules out of context -- database conventions don't load during frontend work.

```yaml
---
paths:
  - "**/prisma/**"
  - "**/migrations/**"
---
```

## Rules in This Blueprint

| Rule | Activates On | Purpose |
|------|-------------|---------|
| [api-endpoints.md](api-endpoints.md) | `**/server/api/**/*.{js,ts}` | API route conventions (naming, error handling, response structure) |
| [database-schema.md](database-schema.md) | `**/prisma/**`, `**/drizzle/**`, `**/migrations/**` | Schema design patterns (soft delete, timestamps, naming) |
| [testing.md](testing.md) | `**/*.test.*`, `**/*.spec.*`, `**/tests/**` | Test writing conventions (structure, assertions, coverage) |
| [session-lifecycle.md](session-lifecycle.md) | Always (no path filter) | Session start/end behaviors (memory loading, state persistence) |
| [memorycore-session.md](memorycore-session.md) | `**/memory-core/**` | External memory system integration rules |

## Design Principles

1. **Scope tightly** -- a rule that matches `**/*.ts` loads on every TypeScript file. Be as specific as possible.
2. **One domain per rule** -- don't mix API conventions with database patterns. Separate files keep context lean.
3. **Rules complement CLAUDE.md** -- put universal rules in CLAUDE.md, domain-specific rules here. A rule should only exist if it's irrelevant to 50%+ of your work.

## Customization

These rules are templates. Replace the conventions inside with your project's actual patterns -- naming conventions, error handling approaches, test frameworks, etc.
