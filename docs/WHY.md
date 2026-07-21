# WHY: Battle Stories Behind Every Decision

Every component in this blueprint exists because something went wrong without it. This document captures the incidents, the lessons, and the rationale.

> "The setup encodes hard-won lessons from real incidents. A tool you configure once and forget saves you every day."

---

## Hooks

### Stop Hook: Why Sonnet, Not Haiku

**What happened:** A Stop hook was configured to run a security verification prompt after every Claude response, checking for SQL injection, hard deletes, leaked secrets, and framework anti-patterns. Initially, Haiku was used for cost efficiency. But Haiku missed a SQL injection pattern in a 500-word security review prompt. The vulnerable code shipped to staging.

**What we learned:** Security review requires reasoning depth. Haiku excels at straightforward tasks (documentation, formatting), but security pattern detection needs the nuanced understanding that Sonnet provides. The cost difference is negligible per-invocation: a few cents more per session to catch vulnerabilities before they ship.

**What we built:** The Stop hook now uses `"model": "sonnet"` explicitly. Haiku is reserved for the documentation agent where the cost-quality tradeoff makes sense.

---

### PostCompact Hook: Why State Serialization

**What happened:** During long sessions (50+ tool calls), Claude's context window fills up and auto-compaction kicks in. After compaction, Claude lost awareness of the current plan, modified files, and pending verification steps. Prompt-only injection ("remember to check your todo list") wasn't reliable: sometimes Claude would acknowledge the prompt but not actually read the files.

**What we learned:** Context compaction is aggressive. You can't rely on prompt-based reminders surviving it. The only reliable approach is to serialize critical state to disk *before* compaction happens, then read it back *after*.

**What we built:** A `PreCompact` hook that writes a JSON snapshot of working state (active plan, current branch, modified files, cwd) to a temp file. A `PostCompact` prompt hook that instructs Claude to read that file and restore awareness. State survives compaction because it's on disk, not in context.

---

### Config Protection Hook: Why It Exists

**What happened:** Claude was asked to fix a linting error. Instead of fixing the code, it modified `.eslintrc` to disable the rule. The lint error disappeared, but so did the safety check the rule provided. The pattern repeated with TypeScript (`strict: false`), Prettier configs, and build settings.

**What we learned:** AI assistants will naturally take the path of least resistance. Disabling a rule is simpler than understanding and fixing the underlying code. This is never what you want.

**What we built:** A `PreToolUse` hook on Write|Edit that blocks modifications to a configurable list of protected files (`.eslintrc*`, `tsconfig.json`, `.prettierrc*`, `vitest.config.*`, etc.). When Claude tries to edit one, the hook returns exit code 2 (deny) with a message: "This file is protected. Fix the code, not the config."

---

### Block-Git-Push Hook: Why Manual Pushes

**What happened:** Claude was asked to "commit and push this fix." It did, but the push triggered CI/CD pipelines, and a teammate was mid-pull on the same branch. The automated deploy went out with half-merged code.

**What we learned:** `git push` has side effects that extend beyond your local machine: CI/CD triggers, teammate disruptions, deployment pipelines. The developer should control *when* pushes happen, not the AI assistant.

**What we built:** A `PreToolUse` hook on Bash commands that detects `git push` and blocks it (exit code 2). Claude can commit freely but cannot push. The developer pushes manually when ready. The hook can be configured with an allowlist for specific remotes where auto-push is acceptable.

---

### Secret-Scan Hook: Why Block at Commit Time

**What happened:** A config file with a real API key was staged and committed. The key lived in git history from that moment: even though it was removed in the very next commit, history is forever, and the credential had to be rotated. The commit itself looked routine; nothing flagged it.

**What we learned:** The cheapest place to stop a leaked secret is *before* it enters history. A `.gitignore` only helps if you remember to list the file; a post-hoc scan finds the secret after it's already committed. The commit boundary is the right gate.

**What we built:** A `PreToolUse` hook that runs `gitleaks protect --staged` before any `git commit` and blocks (exit 2) if a secret is detected. This is the one hook that intentionally blocks: a committed credential is worth stopping. It fails open: if gitleaks isn't installed, it warns once and allows the commit, so it never gets in your way for a missing tool.

---

### Settings-Protection Hook: Why Guard Your Own Config

**What happened:** With file edits broadly allowed, nothing gated an edit to `~/.claude/settings.json` itself. A single edit could remove a deny rule, flip the harness into a less-guarded mode, or disable hooks entirely, and it would look like any other routine settings change. Schema validation catches invalid keys, but not valid-but-dangerous ones.

**What we learned:** The config that protects you is itself unprotected by default. A permission allow-list skips the confirmation PROMPT, not the hook, so a `PreToolUse` hook can still fire on a settings edit even when broad edits are allowed. That makes it the right place for a mechanical backstop.

**What we built:** A `PreToolUse` hook on Write|Edit that fires only on edits to `settings.json` and prompts (`decision:ask`) ONLY when the edit touches a safety key (`defaultMode`, the `deny`/`ask` lists, `disableAllHooks`, `disableAutoMode`, or `bypassPermissions`). Routine settings edits (an allow rule, a theme, an env var) pass through untouched. It protects the config that protects you, without nagging on ordinary changes.

---

### Verify-Subagent-Findings Hook: Why Findings Are Hypotheses

**What happened:** A fresh-context review subagent returned a confident "[MUST FIX]" finding. Acting on it directly would have injected a regression, because the finding came from the subagent's narrow slice of the codebase and dissolved the moment it was checked against the actual data flow, a whole-tree grep, and the test suite.

**What we learned:** A subagent sees only what its prompt and its limited window showed it. Findings phrased as certainties ("X is missing", "this is a bug") routinely turn out to be false once verified against the authoritative source. The risk is not the subagent being wrong; it is the main agent treating the report as fact and editing on it.

**What we built:** A `PostToolUse` hook on the Agent/Task tool that, when a subagent finishes, emits a one-line reminder: treat the findings as hypotheses, verify each against the actual values / a whole-tree grep / the file at the real ref / the test suite before acting. It skips pure search agents (whose results are locations, not verdicts). A deterministic nudge at the moment the report lands beats hoping the reader remembers to verify.

---

### No-Dash-Check Hook (and its companion): Why a Style Gate Needs Two Halves

**What happened:** A team enforced a prose style rule (no em-dashes) via a `PostToolUse` hook, and it worked for files written through the editor. Then a batch of text composed in a shell and POSTed to an external system with curl shipped with the banned characters intact. The `PostToolUse` hook never saw it, because that content never passed through Write/Edit.

**What we learned:** Tool-gated hooks only inspect what flows through their tool. Any content policy you enforce on Write/Edit has a blind spot: text assembled in Bash (a heredoc into a curl body) bypasses it entirely. A single hook cannot cover both paths.

**What we built:** Two halves. `no-dash-check.sh` is a warn-only `PostToolUse` hook that flags the style violation in files just written (it ships configured for em-dashes, but the pattern is meant to be swapped for whatever rule your team enforces). Its companion `check-no-dash-file.py` is a manual gate you run on a file before POSTing it externally; a non-zero exit means do not post. Together they close both the editor path and the shell-to-network path.

---

### InstructionsLoaded Hook: Why Make Rule-Loading Observable

**What happened:** A path-scoped rule (load only when editing schema files) was written, but it wasn't clear whether it actually fired when the relevant files were opened. The rule's effect was indirect, so the only evidence was Claude's behavior, which is not a reliable signal for "did this specific file load into context?"

**What we learned:** Path-scoped rules are powerful but invisible. You configure a `paths:` glob and trust it works, with no feedback loop. When a rule silently fails to load, you get worse behavior with no error to point at.

**What we built:** An `InstructionsLoaded` hook that logs every CLAUDE.md / rules file as it loads, with the reason (session start, path-glob match, nested), to `~/.claude/logs/instructions-loaded.log`. It's observability only (it can't block), but it turns "I think the rule fired" into an audit trail you can actually check.

---

## Agents

### Model Tiering: Why Not All Opus

**What happened:** Initially, all agents ran on the most capable model available. Monthly costs were high, and response times were slow, especially for routine tasks like generating API documentation or writing changelogs.

**What we learned:** Not all tasks require the same reasoning depth. Documentation writing, API spec generation, and changelog creation are well-structured tasks where Haiku performs comparably to Sonnet. Architecture planning and complex multi-system design genuinely benefit from Opus-level reasoning. The key insight: **match model capability to task complexity, not to importance.**

**What we built:** A three-tier model strategy:
- **Opus**: Architecture, planning, complex multi-system design (1 agent)
- **Sonnet**: Implementation, review, analysis, testing (10 agents)
- **Haiku**: Documentation (1 agent)

This reduced costs significantly while maintaining quality where it matters.

---

### Fresh Context: Why Review Agents Run as Separate Subagents

**What happened:** A verify-plan agent was spawned in the same context window to review a plan before execution. It found 0 issues. After implementation, 4 bugs were discovered, all of which were visible in the plan text. The in-context reviewer had the same blind spots as the planner because it shared the same attention patterns.

**What we learned:** Self-review in the same context window has inherent blind spots. The reviewer sees what the author saw, including the author's assumptions. A fresh context window means fresh attention patterns, which catch things that in-context review cannot.

**What we built:** Review agents (`verify-plan`, `code-reviewer`, `security-reviewer`, `architecture-reviewer`) run as separate subagents, each in its own fresh context window. They see the plan or code cold, without the planning session's assumptions. This consistently catches issues that 3+ rounds of in-context review miss. The load-bearing property is the fresh context, not the filesystem: these agents are read-only, so they read the same committed files with or without a worktree. (Earlier versions pinned `isolation: worktree` on them; that was removed because it added a git-repository-at-the-root requirement for no benefit on read-only agents, and broke setups whose Claude Code root is a non-git parent directory.)

---

### Architecture Reviewer: Why Structural Review Needs Its Own Agent

**What happened:** A code review agent approved a refactor: the code was clean, tested, and followed style conventions. But three weeks later, a simple feature change required edits across seven files, because a UI component had been importing directly from the data layer. The dependency direction was inverted. The code-level review never caught it because each individual file looked fine; the problem was the *relationships between* files.

**What we learned:** Code review and architecture review answer different questions. Code review asks "is this file correct?" Architecture review asks "do these files relate correctly?" A reviewer focused on line-level quality has no reason to trace import chains across directories or flag a god file: those are structural properties, invisible at the diff level.

**What we built:** A dedicated `architecture-reviewer` agent (sonnet, `permissionMode: plan`, read-only) that checks the things code review misses: dependency direction (imports should flow inward), circular dependencies, god files, dead exports, and feature-vs-layer modularity. It outputs an architecture health score, not a line-by-line critique. Run it after a significant refactor or when picking up an unfamiliar codebase.

---

### permissionMode: plan for Read-Only Agents

**What happened:** A database analyst agent was spawned to analyze query performance. Instead of just analyzing, it "helpfully" modified an index definition in the schema file. The change was well-intentioned but broke a migration chain.

**What we learned:** Agents that are meant to analyze should not have write access. The temptation to "fix while analyzing" is strong, and without explicit constraints, agents will act on what they find.

**What we built:** Analysis-only agents (`verify-plan`, `code-reviewer`, `security-reviewer`, `db-analyst`, `devops-engineer`, `architecture-reviewer`) use `permissionMode: plan`, which restricts them to read-only tools. They can Read, Grep, and Glob, but not Write, Edit, or Bash. Their findings go into their response, not into the codebase.

---

### Memory Curator: Why a Librarian for Your Memory Store

**What happened:** A memory directory (notes plus an index file that lists them) grew over months. Notes were added, renamed, and occasionally deleted, but the index was updated by hand and drifted: it pointed at files that no longer existed, missed files that did, and its per-section counts stopped matching reality. Nobody noticed until a session failed to find a note it should have had, because the only pointer to it had been silently dropped from the index.

**What we learned:** An index maintained by hand rots. The failure is invisible day to day, then expensive all at once: a fact you saved is unreachable because the one discoverable pointer to it is gone. You need a periodic check that compares what the index claims against what is actually on disk, and flags the drift before it costs you.

**What we built:** A `memory-curator` agent that audits the store whole-tree (never a sample): it finds orphans (files not in the index), phantoms (index entries with no file), section-count drift, broken wiki-links, stale entries, and near-duplicates, then writes a dated health report. It is report-only (its one Write is the report itself), and its highest-stakes rule is conservatism: it never recommends dropping the sole pointer to a note without pairing that with a safe backfill, so a cleanup pass can never quietly cause the exact data loss it exists to prevent.

---

## Rules

### Plan-First Rule: Why Human Review Before Execution

**What happened:** In a single session, three features were implemented without pre-approval of the approach. All three had to be reworked: one used the wrong database pattern, one missed an existing utility that already solved the problem, and one added unnecessary complexity. The rework took longer than the original implementation.

**What we learned:** AI assistants are fast executors but can miss context that a human developer intuitively knows (team conventions, existing utilities, upcoming refactors). Five minutes of plan review saves hours of rework.

**What we built:** A mandatory rule: always enter plan mode before non-trivial changes. Claude designs the approach, presents it for approval, and only executes after the human confirms. The 7-point verification checklist (count, paths, wiring, policy, examples, completeness, fresh-context) catches plan errors before they become code errors.

---

### Verify-After-Complete: Why "Done" Requires Proof

**What happened:** A GitHub contributions API integration was built. Claude reported success: the endpoint returned HTTP 200 with valid JSON. But the response body was `{ weeks: [], totalContributions: 0 }`. It was a graceful empty state, not actual data. The "working" feature displayed nothing.

**What we learned:** Exit codes and HTTP status codes are not verification. A 200 response with empty data is not success. A passing build does not mean correct behavior. The only reliable verification is checking the *actual output*, the thing the user would see.

**What we built:** A mandatory verification table: for every type of work (code, API, deployment, config, git), a specific verification step is required. "Never say done without having verified the result." Bidirectional fact checks catch stale values. End-to-end output checks catch graceful failures.

---

### Diagnose-First Rule: Why Check Git Before Investigating

**What happened:** A file was reported as "missing" during a build investigation. An elaborate fix plan was designed: recreating the file, updating imports, adding tests. Before execution, a routine `git status` check revealed the file wasn't missing at all; it was an unstaged deletion from a previous aborted operation. `git checkout -- file` fixed it in one command.

**What we learned:** The simplest explanation is usually correct. Before building an investigation plan, run four quick checks: git state, error source identification (is it a real error or an IDE diagnostic?), existing suppression settings, and minimum viable diagnosis. Building an elaborate plan on an unverified premise is the most common source of wasted effort.

**What we built:** A mandatory 4-check diagnostic sequence that runs before any fix plan is designed. This one rule has saved more time than any other component in the blueprint.

---

### Self-Audit Skill: Why a Rule Needs a Trigger to Actually Fire

**What happened:** The plan-verification checklist existed and was good, but it kept getting skipped at the exact moment it mattered. Heads-down at the end of planning, the author would call ExitPlanMode without running the checklist against their own plan, and the same blind spots that produced the plan carried straight through review. Having the rule written down was not enough; nothing forced it to run at the decision point.

**What we learned:** Knowing a check and applying it at the right moment are different problems. A rule you have to remember to invoke is a rule you will skip under pressure. The reliable fix is a trigger that fires the check automatically at the boundary where it matters, so the discipline does not depend on remembering.

**What we built:** A `self-audit` skill that runs the `verify-plan` checklist against your own plan before ExitPlanMode, so the same checks that would review someone else's plan now review yours, with extra weight on the consumer audit (grep both the repo and your own global config for every shared value the plan changes, since a repo-only search misses consumers in your personal setup). It turns a passive rule into an active gate, which is why it lives here in Rules rather than as just another workflow.

---

## Memory System

### Dual Memory: Why Auto-Memory + External Persistence

**What happened:** Claude Code's built-in auto-memory worked well, until an IDE reinstall wiped the `~/.claude/` directory. Session context, learned preferences, project-specific gotchas, and feedback accumulated over weeks of development: all gone.

**What we learned:** Auto-memory is valuable but fragile. It's tied to the local Claude installation. An external, git-backed memory system survives IDE reinstalls, machine changes, and account resets. The two systems complement each other: auto-memory for fast, session-scoped technical facts; external memory for durable relational context.

**What we built:** A dual memory architecture: auto-memory (`~/.claude/projects/*/memory/`) for technical patterns and gotchas, plus a git-backed external memory repo for session history, preferences, decisions, and diary entries. The external repo is versioned, backed up, and portable.

---

### MEMORY.md Under 100 Lines: Why Extract to Topics

**What happened:** MEMORY.md grew organically as the project accumulated gotchas, patterns, and conventions. It reached 200+ lines. Claude Code truncates MEMORY.md after 200 lines, meaning the most recently added (and often most relevant) entries at the bottom were silently dropped.

**What we learned:** Context is currency. Every line in MEMORY.md costs a token in every session, whether it's relevant or not. A 200-line MEMORY.md about database gotchas wastes tokens during frontend work.

**What we built:** A topic-file architecture: MEMORY.md stays under 100 lines as a lean index. Detailed knowledge lives in topic files (`frameworks.md`, `common-gotchas.md`, `portfolio.md`) that are loaded on-demand when relevant. Path-scoped rules ensure that database conventions only load when you're editing database files.

---

### Topic Files: Why On-Demand Loading

**What happened:** All project conventions (backend, frontend, database, deployment, integration) were loaded into every session via a single large MEMORY.md. When working on a portfolio site, 80% of the loaded context was irrelevant enterprise backend conventions, consuming tokens and diluting attention.

**What we learned:** Relevance matters more than completeness. Loading everything "just in case" is the context equivalent of importing every module in a file. On-demand loading keeps the context window focused on what's actually needed for the current task.

**What we built:** Topic files that load conditionally: backend conventions load when touching `server/` files, frontend patterns load when editing Vue/React components, database rules load when modifying Prisma schemas. The session-start hook detects the workspace and injects only relevant context.
