# Hooks

8 lifecycle hooks + 2 utility scripts, covering 10 lifecycle events. Hooks are deterministic (they fire every time) vs CLAUDE.md instructions (followed most of the time, but not guaranteed).

## Hook Lifecycle

| Event | When It Fires | Our Hook | Purpose |
|-------|--------------|----------|---------|
| SessionStart | New session begins | session-start.sh | Inject workspace context |
| PreToolUse (Bash) | Before any bash command | block-git-push.sh | Protect remote repos |
| PreToolUse (Write/Edit) | Before any file edit | protect-config.sh | Guard linter/build configs |
| PostToolUse (Write/Edit) | After file edits | notify-file-changed.sh | Verify reminder |
| PostToolUse (Bash) | After bash commands | post-commit-review.sh | Post-commit review |
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

**Utility scripts** (not lifecycle hooks -- run manually):
- `verify-mcp-sync.sh` — Compares MCP server configs across CLI, VS Code extension, and Cursor. Run with `bash ~/.claude/hooks/verify-mcp-sync.sh`
- `status-line.sh` — Generates a status line showing project name, branch, and dirty state

## Design Principles

1. **Prompt hooks for guidance, command hooks for action** — PreCompact/PostCompact inject prompts. Stop/SessionEnd run scripts.
2. **Async for non-blocking** — Post-commit review and file notifications run async to avoid slowing Claude down.
3. **Sync for critical** — SessionEnd checkpoint is synchronous to guarantee it completes before exit.
4. **Exit 0 always** — Hook scripts should never block Claude. Even on errors, exit 0 and log the issue.

## Requirements

All command-type hooks require **Python 3.6+** on your PATH (f-strings are used in error messages). Each script auto-detects with:

```bash
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
```

If neither `python3` nor `python` is found, the hook prints a warning to stderr and exits cleanly (no blocking). Prompt-type hooks (PostToolUseFailure, PostCompact) have no dependencies.

**Why Python?** Bash cannot safely parse or construct JSON. All hook input/output uses JSON, so Python handles the serialization boundary. This is a deliberate choice: one dependency for correctness, rather than fragile string manipulation.

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

**Expected behavior on bad input:** Every hook exits 0 (allow/no-op). No hook should crash, block, or produce error output on malformed input. This is by design -- hooks failing open is safer than hooks failing closed.

**Automated smoke test:** Run `bash hooks/test-hooks.sh` to verify all hooks pass syntax checks and handle empty/malformed/missing-field input gracefully. Run this after making any changes to hook scripts.
