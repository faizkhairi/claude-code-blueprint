# Hooks

10 hook scripts covering 10 lifecycle events. Hooks are deterministic (100% compliance) vs CLAUDE.md instructions (~80%).

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
| Stop | After each response | security check + cost-tracker.sh | Last defense + metrics |
| SessionEnd | Session terminates | session-checkpoint.sh | Guaranteed final save |

## Design Principles

1. **Prompt hooks for guidance, command hooks for action** — PreCompact/PostCompact inject prompts. Stop/SessionEnd run scripts.
2. **Async for non-blocking** — Post-commit review and file notifications run async to avoid slowing Claude down.
3. **Sync for critical** — SessionEnd checkpoint is synchronous to guarantee it completes before exit.
4. **Exit 0 always** — Hook scripts should never block Claude. Even on errors, exit 0 and log the issue.
