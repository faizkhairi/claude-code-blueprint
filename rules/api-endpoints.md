---
paths:
  - "**/server/api/**/*.js"
  - "**/server/api/**/*.ts"
---

<!--
  Why this rule exists: API endpoints are a common place for validation gaps, auth
  bypasses, and silent error handling to slip in unnoticed. This rule keeps every
  endpoint on the same checklist (validation, auth, logging, error handling) so
  security and audit requirements do not depend on remembering them each time.
-->

# API Endpoint Development Rules

> **Example only, replace with your own conventions.** The patterns below (a central endpoint
> registry, INBOUND/OUTBOUND integration direction, `externalSystem`/`systemCode` auth, updating DB
> state on every error path) reflect one specific integration-gateway project. They are NOT universal.
> Do not copy them verbatim, treat this file as a template and rewrite the rules to match how your
> own API layer actually works. Keep the idea (encode your API conventions as a path-scoped rule),
> discard the specifics.

These rules apply when working on API endpoints in your project.

## Required Patterns

### 1. Input Validation
- **ALWAYS** validate input with Zod schemas from `server/schemas/`
- Import schema: `import { schemaName } from '~/server/schemas/{domain}'`
- Parse before use: `const body = schemaName.parse(await readBody(event))`
- Return validation errors with HTTP 400

### 2. OpenAPI Registration
- **MUST** register all endpoints in `server/schemas/registry.ts`
- Include request/response schemas
- Document authentication requirements
- Specify integration type and direction (INBOUND/OUTBOUND)

### 3. Event Handler Pattern
```javascript
export default defineEventHandler(async (event) => {
  const startTime = Date.now();
  const requestId = event.context.requestId || crypto.randomUUID();

  // Authentication check
  const ext = event.context.externalSystem;
  if (!ext?.systemCode) {
    setResponseStatus(event, 401);
    return failureResponse('Authentication required');
  }

  try {
    // Validation
    const body = schema.parse(await readBody(event));

    // Business logic

    // Activity logging (fire-and-forget)
    await logActivity({...});

    return successResponse(data);
  } catch (err) {
    // Error handling with DB state updates
    logger.error(...);
    return failureResponse(err.message);
  }
});
```

### 4. Error Handling
- **ALL error paths must update DB state** before returning
- Use `logger.error()` for exceptions, `logger.warn()` for validation failures
- Never expose sensitive data (PII, credentials) in error responses
- Set proper HTTP status codes (400 for validation, 401 for auth, 500 for server errors)

### 5. Activity Logging
- **MUST** call an activity logging function for audit trail
- Use fire-and-forget pattern (wrap in try-catch)
- Never block API response on logging failure
- Include: systemId, systemCode, endpointPath, requestId, responseCode, responseTimeMs

## Database Operations

### Prisma Usage
- Prefer Prisma client over raw SQL
- Use `?? null` for nullable fields, never `|| ''`
- Handle `undefined` vs `null` correctly
- Include proper error handling for DB failures

### Raw SQL (when necessary)
- **ALWAYS use parameterized queries** via a database utility function (e.g., `executeDatabase(sql, [params])`)
- Never concatenate user input into SQL strings
- Validate all inputs before passing to raw SQL

## Framework-Specific Patterns

### Nuxt (H3 / Nitro)
```javascript
// server/api/resource/[id].get.ts
export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id');
  const body = await readBody(event);
  // ...
});
```

### NestJS
```typescript
@Controller('resource')
export class ResourceController {
  @Get(':id')
  async findOne(@Param('id') id: string) {
    // ...
  }
}
```

### Express
```javascript
router.post('/resource', validateMiddleware(schema), async (req, res, next) => {
  try {
    // ...
  } catch (err) {
    next(err);
  }
});
```

## Security Checklist

Before committing endpoint code:
- [ ] Input validated with Zod schema
- [ ] Authentication enforced via middleware
- [ ] Parameterized SQL queries (if using raw SQL)
- [ ] Activity logging implemented
- [ ] Error messages don't expose PII
- [ ] OpenAPI schema registered
- [ ] Tests cover happy path + error cases
