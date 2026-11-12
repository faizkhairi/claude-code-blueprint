# Hooks

16 lifecycle hooks + 2 utility scripts (plus one companion tool, `check-no-dash-file.py`), covering 8 lifecycle events. Hooks are deterministic (they fire every time) vs CLAUDE.md instructions (followed most of the time, but not guaranteed).

## Hook Lifecycle

| Event | When It Fires | Our Hook | Purpose |
|-------|--------------|----------|---------|
| SessionStart | New session begins | session-start.sh | Inject workspace context |
| SessionStart (`compact`) | After any compaction | (inline `echo`) | Restore working habits: todo list, plan file, CLAUDE.md |
| InstructionsLoaded | CLAUDE.md / rules load into context | instructions-loaded.sh | Log which rules fired and why (observability) |
| PreToolUse (Bash) | Before any bash command | block-git-push.sh | Protect remote repos |
| PreToolUse (Bash) | Before any bash command | pre-commit-secret-scan.sh | Block commits containing secrets (gitleaks) |
| PreToolUse (Write/Edit) | Before any file edit | protect-config.sh | Guard linter/build configs |
| PreToolUse (Write/Edit) | Before any file edit | protect-claude-settings.sh | Confirm edits to safety keys in your own settings.json, and flag no-op allow rules for protected paths |
| PreToolUse (Write/Edit/Bash) | Before a write or shell call | agent-write-guard.sh | Keep read-only agents read-only in every permission mode (keyed on `agent_type`) |
| PreToolUse (ExitPlanMode) | Before leaving plan mode | guard-exit-plan.sh | Deny until the plan file carries the self-audit marker `AUDIT CLEAN` |
| PostToolUse (Write/Edit) | After file edits | notify-file-changed.sh | Verify reminder |
| PostToolUse (Write/Edit) | After file edits | no-dash-check.sh | Warn on a prose-style violation (example: em-dashes) |
| PostToolUse (Bash) | After bash commands | post-commit-review.sh | Post-commit review |
| PostToolUse (Agent/Task) | After a subagent finishes | verify-subagent-findings.sh | Treat subagent findings as hypotheses to verify |
| PostToolUseFailure (MCP) | When an MCP tool fails | mcp-failure-hint.sh | Fallback guidance |
| PreCompact | Before context compaction | precompact-state.sh | Serialize state to disk; its stdout tells the compaction summary what to keep |
| Stop | After each response | security and claim-evidence check + cost-tracker.sh + session-checkpoint.sh | Last defense + metrics + crash recovery |
| SessionEnd | Session terminates | session-checkpoint.sh | Guaranteed final save |
| CwdChanged | Working directory changes | *(not used)* | Auto-load project context on directory switch |
| FileChanged | External file modification detected | *(not used)* | React to .env changes, config reloads |
| PermissionDenied | Auto mode classifier denies an action | *(not used)* | React to auto-mode blocks (log, retry with `{retry: true}`) |
| TaskCreated | Background task spawned via TaskCreate | *(not used)* | Track or gate background agent spawning |

> `CwdChanged`, `FileChanged`, `PermissionDenied`, and `TaskCreated` are available but not used in this blueprint. They're useful for monorepo setups (auto-switching context on `cd`), reactive config reloading, auto-mode denial logging, and background agent governance.

## All hook events

Claude Code currently exposes 33 hook events. The table lists every one, marks the ones this blueprint wires, and shows which handler types each accepts. Source: the [hooks reference](https://code.claude.com/docs/en/hooks), sections "Hook lifecycle" and "Prompt-based hooks"; re-check it when you upgrade, because events are added often.

| Event | Fires | Used here | Handler types |
|-------|-------|-----------|---------------|
| `SessionStart` | Session begins or resumes (matcher `compact` after compaction) | Yes | command, mcp_tool |
| `Setup` | `--init-only`, or `--init` / `--maintenance` in `-p` mode | | command, mcp_tool |
| `InstructionsLoaded` | A CLAUDE.md or `.claude/rules/*.md` file loads | Yes | command, http, mcp_tool |
| `UserPromptSubmit` | A prompt is submitted, before Claude sees it | | all five |
| `UserPromptExpansion` | A typed command expands into a prompt | | all five |
| `MessageDisplay` | Assistant text is displayed | | command, http, mcp_tool |
| `PreToolUse` | Before a tool call; can block it | Yes | all five |
| `PermissionRequest` | A tool call needs a permission decision | | command, http, mcp_tool, prompt |
| `PermissionDenied` | Auto mode denies a tool call | | all five |
| `PostToolUse` | After a tool call succeeds | Yes | all five |
| `PostToolUseFailure` | After a tool call fails | Yes | all five |
| `PostToolBatch` | After a batch of parallel tool calls resolves | | all five |
| `Notification` | Claude Code sends a notification | | command, http, mcp_tool |
| `SubagentStart` | A subagent is spawned | | command, http, mcp_tool |
| `SubagentStop` | A subagent finishes | | all five |
| `TaskCreated` | A task is created via `TaskCreate` | | all five |
| `TaskCompleted` | A task is marked completed | | all five |
| `Stop` | Claude finishes responding | Yes | all five |
| `StopFailure` | The turn ends on an API error | | command, http, mcp_tool |
| `TeammateIdle` | An agent-team teammate is about to go idle | | all five |
| `ConfigChange` | A configuration file changes mid-session | | command, http, mcp_tool |
| `CwdChanged` | The working directory changes | | command, http, mcp_tool |
| `DirectoryAdded` | A directory is added with `/add-dir` | | command, http, mcp_tool |
| `FileChanged` | A watched file changes on disk | | command, http, mcp_tool |
| `WorktreeCreate` | A worktree is being created | | command, http, mcp_tool |
| `WorktreeRemove` | A hook-created worktree is removed | | command, http, mcp_tool |
| `PreCompact` | Before context compaction | Yes | command, http, mcp_tool |
| `PostCompact` | After compaction completes | | command, http, mcp_tool |
| `PreModelSwitch` | Before a requested model switch; can block it | | command, http, mcp_tool |
| `PostModelSwitch` | After the session's model changes | | command, http, mcp_tool |
| `Elicitation` | An MCP server asks for user input | | command, http, mcp_tool |
| `ElicitationResult` | After the user answers an MCP elicitation | | command, http, mcp_tool |
| `SessionEnd` | Session terminates | Yes | command, http, mcp_tool |

"All five" means `command`, `http`, `mcp_tool`, `prompt` and `agent`.

## Handler types and fields

Each entry in a matcher's `hooks` array is one handler, and `type` picks what runs:

| `type` | What runs | Use it for |
|--------|-----------|------------|
| `command` | A shell command; JSON input on stdin, results via exit code and stdout | Everything in this blueprint except the Stop check: deterministic guards, logging, context injection |
| `http` | A POST of the JSON input to a URL; the response body uses the same JSON output format | Central policy or audit services shared by a team |
| `mcp_tool` | A tool on a configured MCP server; its text output is read like command stdout | Reusing logic you already expose over MCP |
| `prompt` | One model call that returns a decision as JSON (`{ok, reason}`) | Yes/no judgements on decision events such as `Stop`, `SubagentStop` and `PreToolUse` |
| `agent` | A subagent with Read, Grep and Glob that verifies before deciding (experimental) | Decisions that need to look at files; the docs recommend command hooks for production |

Fields worth knowing beyond `type` and `command`:

- **`if`**: one permission rule, such as `"Bash(git *)"` or `"Edit(*.ts)"`, that filters when the handler runs. It is evaluated only on tool events (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`); on any other event a handler with `if` never runs. There is no `&&` or list syntax, and matching is best-effort, so enforce hard allow or deny rules with the permission system, not with `if`. A matcher of `Bash` plus `if: "Bash(git commit *)"` would let `pre-commit-secret-scan.sh` skip its Python start-up on every non-commit command.
- **`onFailure: "block"`** (command and http hooks, Claude Code v2.1.295 or later): by default a hook that fails to start, crashes, times out or prints invalid JSON lets the action proceed. With `"block"`, a failure acts like exit code 2 on that event (a `PreToolUse` failure blocks the tool call). It has no effect on `Stop`, `SubagentStop`, `TaskCompleted`, `TeammateIdle`, or `async` hooks. This blueprint leaves it unset on purpose: every guard here fails open (see "Exit 0 always" below), so a missing Python never locks you out. Set it on a guard you would rather fail closed.
- **`timeout`**: seconds before the handler is cancelled. Defaults are 600 for command, http and mcp_tool (lower on a few events such as `UserPromptSubmit`), 30 for prompt, 60 for agent.
- **`async: true`**: run a command hook in the background; see "Which output reaches Claude" below for where its output goes.

**When is a prompt hook the right tool?** Only when you want a model to make a yes/no decision on an event that accepts one (`Stop`, `SubagentStop`, `PreToolUse` and the other "all five" rows above). The evaluator answers `{ok, reason}` and sees only the hook input, not the conversation, so a prompt hook cannot deliver advice and cannot judge anything it is not given. Each one is also a model call every time it fires. For guidance, context or logging, use a command hook.

## Scoping a hook to specific projects

A hook wired in `~/.claude/settings.json` fires for **every** project you open. If you want a hook (say `protect-config.sh`) active in some projects but not others, you have two options.

**Pattern A: allowlist inside the hook (shared, conditionally active).** Keep the single copy in `~/.claude/hooks/` and add a working-directory guard at the top of the script. When the current project is not in your allowlist, the hook exits 0 (no-op) before doing anything. This keeps ONE copy of the hook while scoping its effect:

```bash
# Only act inside allowlisted project roots; no-op everywhere else.
ALLOWED_ROOTS="/home/you/work/api /home/you/work/web"
CURRENT="$PWD"
IN_SCOPE=0
for ROOT in $ALLOWED_ROOTS; do
  case "$CURRENT" in
    "$ROOT"|"$ROOT"/*) IN_SCOPE=1; break;;
  esac
done
[ "$IN_SCOPE" -eq 1 ] || exit 0   # not an allowlisted project: allow/no-op
```

This matches the "exit 0 = allow/no-op" convention every hook here follows, so a scoped-out project behaves exactly as if the hook were not installed.

**Pattern B: wire the hook per-project (isolated).** Instead of `~/.claude/settings.json`, wire the hook in a specific project's own `.claude/settings.json`. It then loads only for that project. The trade-off: it is NOT shared, so if you want the same hook in three projects you wire it in three places. Pattern A is better when you want one shared hook active in a chosen subset; Pattern B is better when a hook is genuinely specific to one project.

**For context injection, prefer a path-scoped rule over a hook.** If your goal is to load guidance only when certain files are open (not to block or act on a command), the [rules](../rules/) mechanism already does this natively: a rule's `paths:` frontmatter loads it only when a matching file is in play. Reach for a scoped hook when you need to gate an *action*; reach for a path-scoped rule when you need to inject *context*.

**Utility scripts** (not lifecycle hooks, run manually):
- `verify-mcp-sync.sh`: Compares the user-scope MCP servers in Claude Code (`~/.claude.json`, shared by the CLI and the VS Code extension) with Cursor (`~/.cursor/mcp.json`). Run with `bash ~/.claude/hooks/verify-mcp-sync.sh`
- `status-line.sh`: Generates a status line showing project name, branch, and dirty state

**Companion tool** (a helper for the `no-dash-check.sh` hook, not itself a hook or counted in the hook total):
- `check-no-dash-file.py`: A sanitizer gate for prose about to be POSTed to an external system (a PR comment, a webhook) from a shell command, which bypasses the Write/Edit hooks. Run `python hooks/check-no-dash-file.py <file>` before posting; a non-zero exit means do not post.

## Design Principles

1. **Command hooks for guidance and action; prompt hooks for decisions**: a prompt hook sends its text to an evaluator model that answers `{ok, reason}`, so it fits a yes/no judgement (the Stop security check) and is the wrong tool for delivering advice. Guidance goes through a command hook's output instead (see below). PreCompact and PostCompact do not run prompt hooks at all (see [Handler types and fields](#handler-types-and-fields)).
2. **Async for non-blocking**: Post-commit review and file notifications run async to avoid slowing Claude down.
3. **Sync for critical**: SessionEnd checkpoint is synchronous to guarantee it completes before exit.
4. **Exit 0 always**: Hook scripts should never block Claude. Even on errors, exit 0 and log the issue.

## Which output reaches Claude

A hook can run perfectly and still say nothing to Claude. Where its output goes depends on the field and on whether the hook is synchronous:

| Output | Synchronous hook | `async: true` hook |
|--------|------------------|--------------------|
| `systemMessage` | Shown to **you** only; Claude never sees it | Delivered to Claude on the next turn (not shown to you) |
| `hookSpecificOutput.additionalContext` | Added to **Claude's** context (PostToolUse, PostToolUseFailure, SessionStart, UserPromptSubmit, and others) | Delivered to Claude on the next turn |
| Plain stdout, exit 0 | Context for Claude on SessionStart and UserPromptSubmit; **instructions for the compaction summary** on PreCompact; debug log only on most other events | Not a documented channel; return a JSON field instead |

So a synchronous PostToolUse hook that wants Claude to act must return `additionalContext`. `verify-subagent-findings.sh` returns both: `additionalContext` for Claude, a short `systemMessage` so you can see it fired. `mcp-failure-hint.sh` returns `additionalContext` only. The async hooks that talk to Claude (`notify-file-changed.sh`, `no-dash-check.sh`, `post-commit-review.sh`) use `systemMessage`, which async delivery already routes to Claude. Source: the hooks reference sections on JSON output, "Add context for Claude", and "How async hooks execute".

## Requirements

All command-type hooks require **Python 3.6+** on your PATH (f-strings are used in error messages). Each script auto-detects with:

```bash
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
```

If neither `python3` nor `python` is found, the hook prints a warning to stderr and exits cleanly (no blocking). The inline SessionStart `compact` command and the Stop prompt hook have no dependencies.

**Why Python?** Bash cannot safely parse or construct JSON. All hook input/output uses JSON, so Python handles the serialization boundary. This is a deliberate choice: one dependency for correctness, rather than fragile string manipulation.

## Optional: gitleaks (for the secret-scan hook)

`pre-commit-secret-scan.sh` requires [gitleaks](https://github.com/gitleaks/gitleaks) on your PATH to scan staged content. Without it, the hook is a no-op: it warns once and allows the commit (fail-open), so it never blocks you for a missing tool.

```bash
winget install gitleaks   # Windows
brew install gitleaks     # macOS
```

This is the one hook that intentionally **blocks** (exit 2) on a detected secret, the same documented exception to "exit 0 always" that `block-git-push.sh` uses. A committed credential is the one mistake worth stopping.

## Testing Hooks

You can test any hook locally by piping JSON to stdin:

```bash
# Test a PreToolUse hook (e.g., block-git-push.sh)
echo '{"tool_input":{"command":"git push origin main"}}' | bash hooks/block-git-push.sh
echo $?  # 2 = blocked, 0 = allowed

# Test a PostToolUse hook (e.g., notify-file-changed.sh)
echo '{"tool_input":{"file_path":"src/app.ts"}}' | bash hooks/notify-file-changed.sh

# Test with empty/malformed input (should exit 0, not crash)
echo '{}' | bash hooks/block-git-push.sh
echo 'not json' | bash hooks/block-git-push.sh
```

**Expected behavior on bad input:** Every hook exits 0 (allow/no-op). No hook should crash, block, or produce error output on malformed input. This is by design: hooks failing open is safer than hooks failing closed.

**Automated smoke test:** Run `bash hooks/test-hooks.sh` to verify all hooks pass syntax checks and handle empty/malformed/missing-field input gracefully. Run this after making any changes to hook scripts. It also replays named allow and deny cases through `agent-write-guard.sh` and `guard-exit-plan.sh`, so a guard that stops deciding fails the run.

**The Stop prompt is evaluated separately, by hand.** `test-hooks.sh` cannot see what a prompt hook decides. `tests/judge-eval.sh` replays the labelled messages in `tests/judge-fixtures/` through the Stop prompt in `examples/settings-template.json` and reports how often the judge agreed with each label. It calls the Anthropic API, so it needs `ANTHROPIC_API_KEY`, costs money, and is manual only, never a CI job. Run it after you edit the Stop prompt; `JUDGE_DRY_RUN=1` builds every request without a key or a call.

## Guard notes

- **agent-write-guard.sh** reads `agent_type` from the hook input, which is present only inside a subagent or a `claude --agent <name>` session. The default read-only list is the agents shipped with `permissionMode: plan` except memory-curator; set `AGENT_WRITE_GUARD_AGENTS` (space-separated names, for example in the `env` block of `settings.json`) to replace it. It stops honest mistakes, not a determined bypass: an interpreter that writes a file itself (`python -c`, `node -e`) is not seen.
- **guard-exit-plan.sh** denies `ExitPlanMode` until the plan text contains `AUDIT CLEAN`, which the `self-audit` skill writes into the plan file, or the line `self-audit: not required (trivial)`. Install both together (full preset).
- Both fail open: without Python they print a warning on stderr and allow the call, like every other hook here.
