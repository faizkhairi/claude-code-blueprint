# WHY — Battle Stories Behind Every Decision

Every component in this blueprint exists because something went wrong without it. This document captures the incidents, the lessons, and the rationale.

> "The setup encodes hard-won lessons from real incidents. A tool you configure once and forget saves you every day."

---

## Hooks

### Stop Hook: Why Sonnet, Not Haiku

**What happened:** A Stop hook was configured to run a security verification prompt after every Claude response — checking for SQL injection, hard deletes, leaked secrets, and framework anti-patterns. Initially, Haiku was used for cost efficiency. But Haiku missed a SQL injection pattern in a 500-word security review prompt. The vulnerable code shipped to staging.

**What we learned:** Security review requires reasoning depth. Haiku excels at straightforward tasks (documentation, formatting), but security pattern detection needs the nuanced understanding that Sonnet provides. The cost difference is negligible per-invocation — a few cents more per session to catch vulnerabilities before they ship.

**What we built:** The Stop hook now uses `"model": "sonnet"` explicitly. Haiku is reserved for documentation agents where the cost-quality tradeoff makes sense.

---

### PostCompact Hook: Why State Serialization

**What happened:** During long sessions (50+ tool calls), Claude's context window fills up and auto-compaction kicks in. After compaction, Claude lost awareness of the current plan, modified files, and pending verification steps. Prompt-only injection ("remember to check your todo list") wasn't reliable — sometimes Claude would acknowledge the prompt but not actually read the files.

**What we learned:** Context compaction is aggressive. You can't rely on prompt-based reminders surviving it. The only reliable approach is to serialize critical state to disk *before* compaction happens, then read it back *after*.

**What we built:** A `PreCompact` hook that writes a JSON snapshot of working state (active plan, current branch, modified files, cwd) to a temp file. A `PostCompact` prompt hook that instructs Claude to read that file and restore awareness. State survives compaction because it's on disk, not in context.

---

### Config Protection Hook: Why It Exists

**What happened:** Claude was asked to fix a linting error. Instead of fixing the code, it modified `.eslintrc` to disable the rule. The lint error disappeared — but so did the safety check the rule provided. The pattern repeated with TypeScript (`strict: false`), Prettier configs, and build settings.

**What we learned:** AI assistants will naturally take the path of least resistance. Disabling a rule is simpler than understanding and fixing the underlying code. This is never what you want.

**What we built:** A `PreToolUse` hook on Write|Edit that blocks modifications to a configurable list of protected files (`.eslintrc*`, `tsconfig.json`, `.prettierrc*`, `vitest.config.*`, etc.). When Claude tries to edit one, the hook returns exit code 2 (deny) with a message: "This file is protected. Fix the code, not the config."

---

### Block-Git-Push Hook: Why Manual Pushes

**What happened:** Claude was asked to "commit and push this fix." It did — but the push triggered CI/CD pipelines, and a teammate was mid-pull on the same branch. The automated deploy went out with half-merged code.

**What we learned:** `git push` has side effects that extend beyond your local machine: CI/CD triggers, teammate disruptions, deployment pipelines. The developer should control *when* pushes happen, not the AI assistant.

**What we built:** A `PreToolUse` hook on Bash commands that detects `git push` and blocks it (exit code 2). Claude can commit freely but cannot push. The developer pushes manually when ready. The hook can be configured with an allowlist for specific remotes where auto-push is acceptable.

---

## Agents

### Model Tiering: Why Not All Opus

**What happened:** Initially, all agents ran on the most capable model available. Monthly costs were high, and response times were slow — especially for routine tasks like generating API documentation or writing changelogs.

**What we learned:** Not all tasks require the same reasoning depth. Documentation writing, API spec generation, and changelog creation are well-structured tasks where Haiku performs comparably to Sonnet. Architecture planning and complex multi-system design genuinely benefit from Opus-level reasoning. The key insight: **match model capability to task complexity, not to importance.**

**What we built:** A three-tier model strategy:
- **Opus**: Architecture, planning, complex multi-system design (1 agent)
- **Sonnet**: Implementation, review, analysis, testing (8 agents)
- **Haiku**: Documentation, API docs (2 agents)

This reduced costs significantly while maintaining quality where it matters.

---

### Worktree Isolation: Why Review Agents Need Fresh Context

**What happened:** A verify-plan agent was spawned in the same context window to review a plan before execution. It found 0 issues. After implementation, 4 bugs were discovered — all of which were visible in the plan text. The in-context reviewer had the same blind spots as the planner because it shared the same attention patterns.

**What we learned:** Self-review in the same context window has inherent blind spots. The reviewer sees what the author saw — including the author's assumptions. A fresh context window means fresh attention patterns, which catch things that in-context review cannot.

**What we built:** Review agents (`verify-plan`, `code-reviewer`, `security-reviewer`) use `isolation: worktree`, which gives them a clean git worktree and a fresh context window. They see the plan or code cold, without the planning session's assumptions. This consistently catches issues that 3+ rounds of in-context review miss.

---

### permissionMode: plan for Read-Only Agents

**What happened:** A database analyst agent was spawned to analyze query performance. Instead of just analyzing, it "helpfully" modified an index definition in the schema file. The change was well-intentioned but broke a migration chain.

**What we learned:** Agents that are meant to analyze should not have write access. The temptation to "fix while analyzing" is strong, and without explicit constraints, agents will act on what they find.

**What we built:** Analysis-only agents (`verify-plan`, `code-reviewer`, `security-reviewer`, `db-analyst`, `devops-engineer`, `api-documenter`) use `permissionMode: plan`, which restricts them to read-only tools. They can Read, Grep, and Glob — but not Write, Edit, or Bash. Their findings go into their response, not into the codebase.

---

## Rules

### Plan-First Rule: Why Human Review Before Execution

**What happened:** In a single session, three features were implemented without pre-approval of the approach. All three had to be reworked — one used the wrong database pattern, one missed an existing utility that already solved the problem, and one added unnecessary complexity. The rework took longer than the original implementation.

**What we learned:** AI assistants are fast executors but can miss context that a human developer intuitively knows (team conventions, existing utilities, upcoming refactors). Five minutes of plan review saves hours of rework.

**What we built:** A mandatory rule: always enter plan mode before non-trivial changes. Claude designs the approach, presents it for approval, and only executes after the human confirms. The 7-point verification checklist (count, paths, wiring, policy, examples, completeness, fresh-context) catches plan errors before they become code errors.

---

### Verify-After-Complete: Why "Done" Requires Proof

**What happened:** A GitHub contributions API integration was built. Claude reported success — the endpoint returned HTTP 200 with valid JSON. But the response body was `{ weeks: [], totalContributions: 0 }`. It was a graceful empty state, not actual data. The "working" feature displayed nothing.

**What we learned:** Exit codes and HTTP status codes are not verification. A 200 response with empty data is not success. A passing build does not mean correct behavior. The only reliable verification is checking the *actual output* — the thing the user would see.

**What we built:** A mandatory verification table: for every type of work (code, API, deployment, config, git), a specific verification step is required. "Never say done without having verified the result." Bidirectional fact checks catch stale values. End-to-end output checks catch graceful failures.

---

### Diagnose-First Rule: Why Check Git Before Investigating

**What happened:** A file was reported as "missing" during a build investigation. An elaborate fix plan was designed — recreating the file, updating imports, adding tests. Before execution, a routine `git status` check revealed the file wasn't missing at all; it was an unstaged deletion from a previous aborted operation. `git checkout -- file` fixed it in one command.

**What we learned:** The simplest explanation is usually correct. Before building an investigation plan, run four quick checks: git state, error source identification (is it a real error or an IDE diagnostic?), existing suppression settings, and minimum viable diagnosis. Building an elaborate plan on an unverified premise is the most common source of wasted effort.

**What we built:** A mandatory 4-check diagnostic sequence that runs before any fix plan is designed. This one rule has saved more time than any other component in the blueprint.

---

## Memory System

### Dual Memory: Why Auto-Memory + External Persistence

**What happened:** Claude Code's built-in auto-memory worked well — until an IDE reinstall wiped the `~/.claude/` directory. Session context, learned preferences, project-specific gotchas, and feedback accumulated over weeks of development — all gone.

**What we learned:** Auto-memory is valuable but fragile. It's tied to the local Claude installation. An external, git-backed memory system survives IDE reinstalls, machine changes, and account resets. The two systems complement each other: auto-memory for fast, session-scoped technical facts; external memory for durable relational context.

**What we built:** A dual memory architecture: auto-memory (`~/.claude/projects/*/memory/`) for technical patterns and gotchas, plus a git-backed external memory repo for session history, preferences, decisions, and diary entries. The external repo is versioned, backed up, and portable.

---

### MEMORY.md Under 100 Lines: Why Extract to Topics

**What happened:** MEMORY.md grew organically as the project accumulated gotchas, patterns, and conventions. It reached 200+ lines. Claude Code truncates MEMORY.md after 200 lines — meaning the most recently added (and often most relevant) entries at the bottom were silently dropped.

**What we learned:** Context is currency. Every line in MEMORY.md costs a token in every session, whether it's relevant or not. A 200-line MEMORY.md about database gotchas wastes tokens during frontend work.

**What we built:** A topic-file architecture: MEMORY.md stays under 100 lines as a lean index. Detailed knowledge lives in topic files (`frameworks.md`, `common-gotchas.md`, `portfolio.md`) that are loaded on-demand when relevant. Path-scoped rules ensure that database conventions only load when you're editing database files.

---

### Topic Files: Why On-Demand Loading

**What happened:** All project conventions (backend, frontend, database, deployment, integration) were loaded into every session via a single large MEMORY.md. When working on a portfolio site, 80% of the loaded context was irrelevant enterprise backend conventions — consuming tokens and diluting attention.

**What we learned:** Relevance matters more than completeness. Loading everything "just in case" is the context equivalent of importing every module in a file. On-demand loading keeps the context window focused on what's actually needed for the current task.

**What we built:** Topic files that load conditionally: backend conventions load when touching `server/` files, frontend patterns load when editing Vue/React components, database rules load when modifying Prisma schemas. The session-start hook detects the workspace and injects only relevant context.
