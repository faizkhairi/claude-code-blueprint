# Hooks

13 lifecycle hooks + 2 utility scripts (plus one companion tool, `check-no-dash-file.py`), covering 9 lifecycle events. Hooks are deterministic (they fire every time) vs CLAUDE.md instructions (followed most of the time, but not guaranteed).

## Hook Lifecycle

| Event | When It Fires | Our Hook | Purpose |
|-------|--------------|----------|---------|
| SessionStart | New session begins | session-start.sh | Inject workspace context |
| InstructionsLoaded | CLAUDE.md / rules load into context | instructions-loaded.sh | Log which rules fired and why (observability) |
| PreToolUse (Bash) | Before any bash command | block-git-push.sh | Protect remote repos |
| PreToolUse (Bash) | Before any bash command | pre-commit-secret-scan.sh | Block commits containing secrets (gitleaks) |
| PreToolUse (Write/Edit) | Before any file edit | protect-config.sh | Guard linter/build configs |
| PreToolUse (Write/Edit) | Before any file edit | protect-claude-settings.sh | Confirm edits to safety keys in your own settings.json |
| PostToolUse (Write/Edit) | After file edits | notify-file-changed.sh | Verify reminder |
| PostToolUse (Write/Edit) | After file edits | no-dash-check.sh | Warn on a prose-style violation (example: em-dashes) |
| PostToolUse (Bash) | After bash commands | post-commit-review.sh | Post-commit review |
| PostToolUse (Agent/Task) | After a subagent finishes | verify-subagent-findings.sh | Treat subagent findings as hypotheses to verify |
| PostToolUseFailure | When MCP tools fail | (prompt hook) | Fallback guidance |
| PreCompact | Before context compaction | precompact-state.sh | Serialize state to disk |
| PostCompact | After compaction | (prompt hook) | Restore awareness |
| Stop | After each response | security check + cost-tracker.sh + session-checkpoint.sh | Last defense + metrics + crash recovery |
| SessionEnd | Session terminates | session-checkpoint.sh | Guaranteed final save |
| CwdChanged | Working directory changes | *(not used)* | Auto-load project context on directory switch |
| FileChanged | External file modification detected | *(not used)* | React to .env changes, config reloads |
| PermissionDenied | Auto mode classifier denies an action | *(not used)* | React to auto-mode blocks (log, retry with `{retry: true}`) |
| TaskCreated | Background task spawned via TaskCreate | *(not used)* | Track or gate background agent spawning |

> `CwdChanged`, `FileChanged`, `PermissionDenied`, and `TaskCreated` are available but not used in this blueprint. They're useful for monorepo setups (auto-switching context on `cd`), reactive config reloading, auto-mode denial logging, and background agent governance.

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
- `verify-mcp-sync.sh`: Compares MCP server configs across CLI, VS Code extension, and Cursor. Run with `bash ~/.claude/hooks/verify-mcp-sync.sh`
- `status-line.sh`: Generates a status line showing project name, branch, and dirty state

**Companion tool** (a helper for the `no-dash-check.sh` hook, not itself a hook or counted in the hook total):
- `check-no-dash-file.py`: A sanitizer gate for prose about to be POSTed to an external system (a PR comment, a webhook) from a shell command, which bypasses the Write/Edit hooks. Run `python hooks/check-no-dash-file.py <file>` before posting; a non-zero exit means do not post.

## Design Principles

1. **Prompt hooks for guidance, command hooks for action**: PreCompact/PostCompact inject prompts. Stop/SessionEnd run scripts.
2. **Async for non-blocking**: Post-commit review and file notifications run async to avoid slowing Claude down.
3. **Sync for critical**: SessionEnd checkpoint is synchronous to guarantee it completes before exit.
4. **Exit 0 always**: Hook scripts should never block Claude. Even on errors, exit 0 and log the issue.

## Requirements

All command-type hooks require **Python 3.6+** on your PATH (f-strings are used in error messages). Each script auto-detects with:

```bash
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
```

If neither `python3` nor `python` is found, the hook prints a warning to stderr and exits cleanly (no blocking). Prompt-type hooks (PostToolUseFailure, PostCompact) have no dependencies.

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

**Automated smoke test:** Run `bash hooks/test-hooks.sh` to verify all hooks pass syntax checks and handle empty/malformed/missing-field input gracefully. Run this after making any changes to hook scripts.
