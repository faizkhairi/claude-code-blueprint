---
name: test-check
description: "MUST use after implementing new features or bug fixes, when user asks 'run the tests', 'are tests passing?', 'test this', or before any deployment step. Also trigger when tests were previously failing and fixes were applied."
user-invocable: true
---

Run the full test suite and provide analysis:

1. Detect active project from current working directory or recent context:
   - Check `CLAUDE.md` or the project manifest (package.json, pyproject.toml, Gemfile, pom.xml, etc.) for the test command
   - Common patterns: `yarn test:unit`/`npm test`/`npx vitest run` (JS), `pytest` (Python), `bundle exec rspec` (Ruby), `go test ./...` (Go), `mvn test` (Java), `cargo test` (Rust), `dotnet test` (.NET)
   - Default (no context): ask which project
2. Run the appropriate test command and capture output
3. Report summary: total tests, passed, failed, skipped, duration
4. If failures exist: analyze root cause of each failing test
5. Compare against known baselines:
   - Check `CLAUDE.md` for the documented test baseline count for the active project
   - If no baseline is documented: parse the test summary output line for total count; compare against previous runs if agent memory has a baseline
   - If actual count is higher than baseline, the test suite grew; if lower, investigate missing tests
6. Check if recently modified files have corresponding tests
7. Identify test coverage gaps for critical paths
8. Suggest new tests if coverage is insufficient
9. **E2E tests** (run if user says "e2e", "all", or "full"):
   - Check `CLAUDE.md` for the dev server port and E2E test command
   - Check if dev server is running on that port before proceeding
   - Run E2E test command from `CLAUDE.md` (e.g., `yarn test:e2e` or `npm run test:e2e`, or the project's E2E command)
   - E2E baselines: documented in `CLAUDE.md`
   - Parse the E2E runner's output (Playwright, Cypress, Selenium, Capybara, etc.): passed/failed/skipped counts
   - On failure: note which spec file and test name failed
   - If dev server is NOT running, report and skip (do NOT auto-start)

Present results in a clear dashboard format.
