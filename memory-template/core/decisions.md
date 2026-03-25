# Architectural Decision Log
*Append-only record of non-obvious decisions. Future sessions reference this to understand "why did we do it this way?"*

<!-- Format for new entries:

## YYYY-MM-DD — [Short title]

**Context:** [What was the situation?]

**Decision:** [What was chosen?]

**Rationale:** [Why this approach over alternatives?]

**Alternatives considered:**
- [Option A — rejected because...]
- [Option B — rejected because...]

-->

<!-- Example entry:

## 2025-01-15 — Use Vitest over Jest

**Context:** Setting up testing for the new project. Both Vitest and Jest are viable.

**Decision:** Use Vitest as the test runner.

**Rationale:** Native ESM support, faster execution via Vite's transform pipeline, compatible with the existing Vite build setup. Jest would require additional ESM configuration.

**Alternatives considered:**
- Jest — rejected because ESM config overhead and slower cold starts
- Bun test — rejected because team isn't on Bun yet

-->
