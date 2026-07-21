---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
---

<!-- This template uses Vitest + Vue as examples. Adapt framework references, directory structure,
     and mock patterns to match your project's test stack. -->

<!--
  Why this rule exists: a testing checklist that only lives in someone's head gets
  skipped under deadline pressure. Writing out the required coverage (happy path,
  auth failure, validation failure, edge cases) and the mocking rules for external
  systems means AI and human contributors follow the same bar, and it's the layer
  that adds stack-specific detail on top of testing-general.md.
-->

# Testing Rules & Conventions

> **Example only, replace with your own conventions.** This file uses Vitest + Vue, and the deeper
> sections (the `tests/contracts/` directory layout, the integration-contract coverage list, and the
> specific mock targets and test identifiers) reflect one project's stack. The universal parts
> (arrange/act/assert, mock external dependencies, no hardcoded dates) transfer anywhere; the
> project-specific examples should be rewritten wholesale, not copied.

These rules apply when writing or modifying tests for your project.

## Test Framework

- **Framework**: [Your test runner, e.g., Vitest, Jest, Pytest, Go test, RSpec]
- **Run command**: Check CLAUDE.md for test command
- **Watch mode**: Append `--watch` to the test command (auto-runs on file changes)
- **Current baseline**: Check CLAUDE.md for current test baseline, all must pass (bundle-size suite auto-skips if .output/ absent; run build first to include it)

## Test Organization

### Directory Structure
```
tests/
├── contracts/          # Integration contract tests
│   ├── service-a-contract.test.js
│   ├── service-b-contract.test.js
│   └── handler.test.js
├── security/          # Security vulnerability tests
│   ├── xss-prevention.spec.js
│   ├── sql-injection.spec.js
│   ├── authentication-security.spec.js
│   └── file-upload.spec.js
└── performance/       # Performance benchmarks
    ├── bundle-size.spec.js
    ├── load-time.spec.js
    └── memory-leaks.spec.js

server/
├── api/__tests__/     # API handler tests
├── services/__tests__/ # Service layer tests
└── utils/__tests__/   # Utility function tests

components/
└── __tests__/         # Vue component tests

composables/
└── __tests__/         # Vue composables tests
```

## Test Naming Conventions

```javascript
describe('Module or Component Name', () => {
  describe('functionName()', () => {
    it('should do X when Y', () => {
      // Arrange
      // Act
      // Assert
    });

    it('should throw error when invalid input', () => {
      // Error case
    });
  });
});
```

## Required Test Coverage

### For API Endpoints
1. **Happy path** (200 success)
2. **Authentication failure** (401 unauthorized)
3. **Validation failure** (400 bad request)
4. **Not found** (404 if applicable)
5. **Server error** (500 internal error)
6. **Edge cases** (empty strings, null values, max lengths)

### For Integration Contracts
1. **Request schema validation** (valid + invalid inputs)
2. **Response schema validation**
3. **Identifier normalization** (e.g., stripping whitespace, padding)
4. **Date format handling** (check CLAUDE.md for system-specific date formats)
5. **External system authentication**
6. **Database state updates** (INSERT, UPDATE, ON DUPLICATE KEY)
7. **Activity logging** (audit trail)
8. **Error handling** (external API failures, DB unavailable)

### For Security Tests
1. **SQL injection** (raw queries, string interpolation)
2. **XSS** (unescaped output, v-html usage)
3. **Command injection** (shell commands with user input)
4. **Authentication bypass** (missing middleware, weak tokens)
5. **Authorization flaws** (privilege escalation, IDOR)
6. **File upload vulnerabilities** (path traversal, unrestricted types)

## Mocking External Systems

**NEVER call real external APIs in tests**. Mock all external dependencies:

```javascript
// CORRECT: Mock external API client
vi.mock('~/server/services/api-clients/external-client', () => ({
  callExternalApi: vi.fn().mockResolvedValue({
    responseCode: '1',
    responseMessage: 'Success'
  })
}));

// CORRECT: Mock database utility
vi.mock('~/server/utils/integration-database', () => ({
  executeIntegrationDatabase: vi.fn().mockResolvedValue(undefined)
}));

// CORRECT: Mock secondary database query utility
vi.mock('~/server/utils/secondary-database', () => ({
  queryDatabaseOne: vi.fn().mockResolvedValue({
    id: 123,
    identifier: '000000000001'
  })
}));
```

## Test Data Best Practices

### Use Realistic but Safe Data
- **PII**: Use test identifiers (e.g., `000000000001`)
- **Dates**: Use `2026-01-01` (current year + future dates)
- **Amounts**: Use `1000.50` (realistic amounts)
- **UUIDs**: Use `crypto.randomUUID()` or fixed test UUIDs
- **Names**: Use `Test User`, `Sample Record`, etc.

### Avoid Hardcoding Dates
```javascript
// BAD: Hardcoded date (breaks over time)
const testDate = '2024-01-01';

// GOOD: Dynamic date
const testDate = new Date().toISOString().split('T')[0];

// BETTER: Explicit test fixture
const fixtures = {
  validDate: '2026-01-01',
  futureDate: '2027-12-31',
  pastDate: '2020-06-15'
};
```

## Performance Test Requirements

### Tests Requiring Running Server
Some performance tests require the dev server to be running (check CLAUDE.md for dev port):
- Load time tests
- Memory leak tests
- E2E browser tests

These tests **skip gracefully** when server is unavailable. Run them in CI/CD or locally:

```bash
# Terminal 1
npm run dev

# Terminal 2
<check CLAUDE.md for test command>
```

## Test Execution Checklist

Before committing:
- [ ] Run the project test command (check CLAUDE.md) and verify all passing
- [ ] No skipped tests (except performance tests requiring server)
- [ ] New features have corresponding tests
- [ ] Edge cases covered (null, empty, max length, invalid format)
- [ ] External APIs are mocked
- [ ] No hardcoded credentials or production data
- [ ] Tests run in under 10 seconds (fast feedback loop)

## Common Testing Mistakes

1. **Calling real external APIs** → Tests fail when API is down, can corrupt production data
2. **Using production database** → Data corruption, slow tests
3. **Hardcoding dates** → Tests break over time
4. **Missing error case tests** → Bugs slip through
5. **Testing implementation details** → Tests break on refactor
6. **No assertions** → False positives
7. **Shared mutable state** → Flaky tests
