---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
---

# Testing Rules & Conventions (framework-agnostic)

These apply to ANY project's tests (fires on all test files). A project-specific
`testing.md` can layer stack-specific conventions on top.

## First: discover, don't assume
- Read the project's own test config + `package.json` scripts (or `pyproject.toml`/
  `pytest.ini`, `go.mod`, `Cargo.toml`) BEFORE running anything. Use the project's
  declared test command, not a guessed one.
- Detect the framework from config/deps:
  - JS/TS: Vitest (`vitest.config.*`), Jest (`jest.config.*`), node:test, Playwright (E2E)
  - Python: pytest (`pytest.ini`/`pyproject.toml [tool.pytest]`), unittest
  - Go: `go test ./...`
  - Rust: `cargo test`
  - PHP: PHPUnit / Pest (`phpunit.xml`)
- Run the project's actual command (e.g. `npm test`, `pnpm test`, `yarn test`,
  `pytest`, `go test ./...`). Do not hardcode a project-specific command, read it
  from the project config.

## Core conventions (universal)
- **Arrange / Act / Assert** structure; one logical assertion focus per test.
- **Descriptive names**: `it('should X when Y')` / `test_x_when_y`.
- **Mock external boundaries** (network, DB, filesystem, time, randomness): never call
  real external APIs or production data in tests. Inject/stub the boundary.
- **Deterministic**: no hardcoded today-dates that rot; freeze time or use fixtures.
  No reliance on test execution order; no shared mutable state between tests.
- **Coverage of the change**: every new public function / endpoint / branch gets a test
  (happy path + at least one error/edge case: null, empty, max-length, invalid input).
- **Fast feedback**: unit suite should run in seconds; gate slow/integration/E2E behind
  a separate command or a running-server skip.

## Before declaring done
- Run the full suite; it must be GREEN (not "mostly passing").
- New feature/branch -> matching test exists in the diff.
- No skipped tests left unexplained; no `console.log`/debug debris in test files.
- For a public/OSS project, match the repo's OWN lint+test conventions exactly,
  not these defaults, where they differ.
