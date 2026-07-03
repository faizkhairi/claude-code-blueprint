---
name: e2e-check
description: "Run E2E tests or interactive browser verification. Triggers on: 'run e2e', 'e2e test', 'browser test', 'check in browser', 'verify UI', 'interactive test'."
user-invocable: true
argument-hint: "[project] [test-filter] [--interactive]"
---

Run E2E tests or perform interactive browser-based verification using Playwright.

## Mode Detection

Parse `$ARGUMENTS` to determine mode:
- **Runner mode** (default): Run the Playwright test suite via CLI
- **Interactive mode**: If `--interactive` or `interactive` appears in args, use Playwright MCP tools for manual browser walkthrough

---

## Runner Mode

### 1. Detect project

From `$ARGUMENTS` or current working directory:
- Match project name from cwd (e.g., `my-app` if cwd contains `my-app`)
- Check `CLAUDE.md` in the project root for the configured dev port and test command
- No match: ask which project to target

### 2. Pre-flight check

Check if the dev server is running on the expected port (read from `CLAUDE.md` or the project manifest):

Use: `bash -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:{port}/ 2>/dev/null"` or equivalent.

If the server is NOT running:
- Report: "Dev server not running on port {port}. Start it with your project's dev command (e.g. `yarn dev`/`npm run dev`, `python manage.py runserver`, `bundle exec rails s`, `go run`, etc.), then re-run /e2e-check."
- **Do NOT auto-start the dev server.** Stop here.

### 3. Run tests

Run the E2E test command from `CLAUDE.md` or the project manifest (e.g., `yarn test:e2e` or `npm run test:e2e` for JS, or `pytest tests/e2e` for Python).

If a test filter was provided (e.g., `auth`), resolve it to the spec file path:
- `auth` → `tests/e2e/auth.spec.ts`
- Full path → use as-is

### 4. Parse output

Extract from Playwright output:
- Total, passed, failed, skipped counts
- Duration
- On failure: spec file name, test name, error message

### 5. Report

```
E2E Test Results -- {project}
================================
Total: X | Passed: X | Failed: X | Skipped: X
Duration: Xs
Baseline: {expected from CLAUDE.md} tests

[If failures:]
FAILURES:
- {spec-file} > {test-name}: {error summary}

[If screenshots saved:]
Screenshots: test-results/{spec-file}/
```

### 6. On failure

- Check `test-results/` directory for saved screenshots
- Analyze failure type: timeout? Element not found? Assertion mismatch? Network error?
- Suggest fix based on the failure pattern

---

## Interactive Mode

Use Playwright MCP tools to manually verify a user journey in the browser.

### 1. Navigate

Use `mcp__playwright__browser_navigate` to open `http://localhost:{port}` (port from `CLAUDE.md`).

**ALWAYS use `localhost`, NEVER `127.0.0.1`** (cookie domain mismatch issues).

### 2. Default journey (if no specific flow in args)

1. Navigate to login page
2. Fill credentials using `mcp__playwright__browser_fill_form` (use dev test credentials from `.env` or `.env.test`)
3. Submit login form via `mcp__playwright__browser_click`
4. Wait for dashboard to load via `mcp__playwright__browser_wait_for`
5. Take snapshot via `mcp__playwright__browser_snapshot` to verify dashboard renders data (not empty state)
6. Navigate to a key page (e.g., main feature list, report list)
7. Verify data is present (not loading spinner, not error)
8. Take screenshot via `mcp__playwright__browser_take_screenshot` as evidence

### 3. Custom journey

If args specify a flow (e.g., `--interactive reports`), walk through that specific flow step by step using:
- `mcp__playwright__browser_navigate` for page navigation
- `mcp__playwright__browser_snapshot` to read current page state (DOM)
- `mcp__playwright__browser_fill_form` for form inputs
- `mcp__playwright__browser_click` for button/link clicks
- `mcp__playwright__browser_select_option` for dropdowns
- `mcp__playwright__browser_wait_for` for loading/transition states
- `mcp__playwright__browser_take_screenshot` for visual evidence

### 4. Report

Summarize:
- What pages were visited
- What was verified (data rendered, forms worked, navigation succeeded)
- Any issues found (errors, empty states, broken elements)
- Screenshot paths for evidence

---

## Rules

- **Always `localhost`, never `127.0.0.1`**, due to cookie domain issues
- **Dev port**: read from `CLAUDE.md` or the project manifest for the active project
- **Package manager**: check `CLAUDE.md` or detect from lockfile (`yarn.lock` → yarn, `package-lock.json` → npm) (non-Node stacks: detect the build/install tool from the manifest type, e.g. Gemfile.lock, poetry.lock, Cargo.lock, go.sum, etc.)
- **Never auto-start dev servers**: report and stop if not running
- **E2E baselines**: compare against baseline documented in `CLAUDE.md`
