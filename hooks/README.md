# Hooks

16 lifecycle hooks + 2 utility scripts (plus one companion tool, `check-no-dash-file.py`), covering 8 lifecycle events. Hooks are deterministic (they fire every time) vs CLAUDE.md instructions (followed most of the time, but not guaranteed).

## Hook Lifecycle

| Event | When It Fires | Our Hook | Purpose |
|-------|--------------|----------|---------|
| SessionStart | New session begins | session-start.sh | Inject workspace context |
| SessionStart (`compact`) | After any compaction | (inline `echo`) | Restore working habits: todo list, plan file, CLAUDE.md |
| InstructionsLoaded | CLAUDE.md / rules load into context | instructions-loaded.sh | Log which rules fired and why (observability) |
| PreToolUse (Bash, PowerShell) | Before any Bash or PowerShell command | block-git-push.sh | Protect remote repos |
| PreToolUse (Bash, PowerShell) | Before any Bash or PowerShell command | pre-commit-secret-scan.sh | Block commits containing secrets (gitleaks) |
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

> `protect-config.sh` and `protect-claude-settings.sh` ask you to confirm. Inside a subagent (the payload has a non-empty `agent_id`) they deny instead, with the same reason plus a request to ask you to make the change, because a subagent cannot answer a prompt.

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
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
```

On Windows, `python3` can be the Microsoft Store stub: a launcher under `WindowsApps` that prints a notice and exits 49 without running anything. The `case` line runs only that path with `-c ''` and moves on to `python`, then `py`, when it fails, so no extra process starts on other systems. If no working interpreter is found, the hook prints a warning to stderr and exits cleanly (no blocking). The inline SessionStart `compact` command and the Stop prompt hook have no dependencies.

**Why Python?** Bash cannot safely parse or construct JSON. All hook input/output uses JSON, so Python handles the serialization boundary. This is a deliberate choice: one dependency for correctness, rather than fragile string manipulation.

## Optional: gitleaks (for the secret-scan hook)

`pre-commit-secret-scan.sh` requires [gitleaks](https://github.com/gitleaks/gitleaks) on your PATH to scan staged content. Without it, the hook is a no-op: it warns once and allows the commit (fail-open), so it never blocks you for a missing tool.

```bash
winget install gitleaks   # Windows
brew install gitleaks     # macOS
```

This is the one hook that intentionally **blocks** (exit 2) on a detected secret, the same documented exception to "exit 0 always" that `block-git-push.sh` uses. A committed credential is the one mistake worth stopping.

### Known limits of the git guards

`block-git-push.sh` and `pre-commit-secret-scan.sh` read the command text. Threat model: these hooks stop accidental pushes to protected remotes and accidental secret commits; they are not a sandbox against deliberately obfuscated commands, so a parser cannot follow every shell expansion. These routes are not covered:

- Text handed to another interpreter through a pipe or a launcher: `echo "git push" | bash`, `find . -exec git push {} \;`, `su -c 'git push'`, and the PowerShell `iex` and `Start-Process` forms.
- PowerShell launched with `pwsh -EncodedCommand` (base64 text) or an abbreviated parameter (only `-Command`, `-c` and `-cmd` are read), and the glued `cmd /c"..."` form.
- A directory change by `popd` or `Pop-Location` (`cd`, `pushd` and `Set-Location` are tracked).
- A push URL that only comes from a config file pulled in by a command-supplied `-c include.path=<file>`, or from `GIT_CONFIG_*` variables: only `remote.`, `url.`, `branch.` and `push.` keys given with `-c` are applied when the target is resolved.
- A hook that Claude Code stops at its timeout does not block: the command then runs.
- For the secret scan only: a secret written to a new file earlier in the same command line (`echo "$KEY" > .env && git add .env && git commit`). The file does not exist yet when the hook runs, so there is nothing to scan.

When the hook cannot tell what a push or commit would do (a variable or a substitution as the command or the subcommand, a shell alias given with `-c alias.x=!...`, a commit directory that comes from a variable, `~user` or `cd -`, text that does not parse, an error while judging it), it blocks rather than guesses. An error while a commit scan is being prepared, or a parser that exits abnormally on a command that mentions `push` or `commit`, blocks too: an error never allows the command.

The hooks' own git calls never receive a command-supplied `-c` pair, with one exception: `block-git-push.sh` passes pairs whose key starts with `remote.`, `url.`, `branch.` or `push.` (any case) to the calls that resolve the push target, so `git -c core.fsmonitor=<program> commit` cannot make a hook run a program before you decide. Without Python, `pre-commit-secret-scan.sh` prints a warning on stderr and allows the commit (fail-open, like `block-git-push.sh`).

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

- **agent-write-guard.sh** reads `agent_type` from the hook input, which is present only inside a subagent or a `claude --agent <name>` session. The default read-only list is the agents shipped with `permissionMode: plan` except memory-curator; set `AGENT_WRITE_GUARD_AGENTS` (space-separated names, for example in the `env` block of `settings.json`) to replace it. It also judges `Monitor` commands like Bash (add `Monitor` to the settings matcher if your Claude Code version does not already run the Bash entry for them). It denies a `GIT_*=` variable set on the command, `git fetch --upload-pack` and `--recurse-submodules`, `git grep -O`, `git --exec-path`, backtick and quoted `$(...)` substitutions, package runners (`npx`, `bunx`, `pnpm dlx`, `yarn dlx`), package-manager changes found after value options (`npm --prefix . install x`, `npm version`, `npm publish`, `python -m pip install`), `curl -o`/`-O`, `wget` and `sort -o`, and PowerShell `[IO.File]::Write*`. A heredoc body is text only for the plain one-line shape `<reader> [args] <<[-]DELIM` (a reader is the bare name `cat`, `grep`, `egrep`, `fgrep`, `head`, `tail`, `wc`, `jq`, `sort`, `nl` or `:`, first on its line, with no path, quote or leading backslash, and nothing before it such as `VAR=value`, `PATH=...` or `!`; the delimiter may be quoted, also as `\EOF`; `cat<<EOF` with no space is the same heredoc) with at most `> file` or `>> file` after it, a delimiter that closes, with no `( ) $` backtick, backslash, `| ; & <` or quote before the `<<` (a `$HOME`, `${HOME}` or `"$HOME"` expansion is fine), and no trailing backslash. `less` and `more` are not readers (`less -o`, `--log-file` and `+!cmd` write or run). A command that defines a function or alias (`function`, `name() {`, `alias`, `shopt`, `enable`, `hash`, `Set-Alias`) or sets `PATH`, `LD_PRELOAD`, `BASH_ENV` or `IFS` has no heredoc data at all, because a reader name could then be anything. So does a command that uses `eval`, and so does an unquoted body that has a line ending in an odd number of backslashes (a continuation can end the heredoc early). Any other shape is judged as commands, as bash may run the body (so is a `$(...)` in an unquoted body that is text). A `<<<` here-string is text for a bare reader, `read` or a plain text filter (`tr`, `cut`, `rev`, `fold`, `fmt`, `tac`, `column`, `paste`, `base64`, `od` and the checksum tools; not `sed` or `awk`, which can run text), and a pipe may carry it on only to another reader or filter, so `bash <<< 'rm x'` and `cut -c1 <<< 'rm x' | sh` are denied, and so is a loop fed by `done <<<`. `trap` with an action is denied (a bare `trap`, `trap -l` and `trap -p` are reads). `start` is denied in Bash, and in PowerShell so are `iex`, `Invoke-Expression`, `Start-Process`, `saps`, `Invoke-Command`, `icm`, `Start-Job`, `sajb`, `Start-ThreadJob`, `Invoke-Item`, `ii`, `Invoke-WmiMethod`, `Invoke-CimMethod`, `[scriptblock]::Create` and `New-Object -ComObject`. Command names are matched on the bare name (`/usr/bin/xargs`, `\xargs`), `env -S` (and `--split`, or any prefix of `--split-string`) judges the split string with the words after it, the bodies of `<(...)` and `>(...)` are commands, `watch` and `script -c` have their command string judged, and `stdbuf`, `chrt`, `taskset` and `busybox` unwrap like `nice` and `timeout`. `flock`, `robocopy`, `xcopy`, `Expand-Archive`, `Compress-Archive`, `rg --pre`, `npm config set|delete|edit`, `npm cache clean`, `npm pack`, `cargo fmt` (without `--check`) and a PowerShell `.Delete(`, `.MoveTo(` or `.CopyTo(` call count as writes, and `npm config get|list` stay reads. `$HOME`, `${HOME}`, `"$HOME"/...` and `~` expand in a target path, and `rm`, `cp`, `touch`, `mkdir`, `curl -o`, `wget -O` and `sort -o` are allowed when every target is a plain absolute path (or one rooted at `$HOME`, `${HOME}`, `"$HOME"` or `~`) inside the agent's own memory dir. A relative path, a quoted path, a backslash, a glob, a brace, another variable, a `..` component, a `~` or `:` inside the path, or a component made only of dots and spaces is not judged and is denied. The whole allowance is off for a command that changes the directory (`cd`, `pushd`, `popd`, `Set-Location`, `sl`, `Push-Location`, `chdir`, `env -C`, `sudo -D`) or uses the word `HOME` (or `USERPROFILE`, `HOMEDRIVE`, `HOMEPATH`) in any way other than a `$HOME` or `${HOME}` expansion (an assignment, `for HOME in`, `read HOME`, `unset HOME`, `printf -v HOME`, `$env:HOME`, `Set-Variable HOME`; case-insensitive in PowerShell), because a path then means another place. These checks run on the raw text and on a copy with quotes, backslashes and line continuations removed (and, for PowerShell, backticks), so a name split as `HO''ME` or a keyword split as `fun"ction` is seen. The allowance is also off when the command uses `eval`, `read`, `mapfile`, `readarray`, `printf -v`, `declare`, `typeset` or `local` with `-n`, `${!name}`, or PowerShell `Set-Variable`, `sv`, `New-Variable`, `nv`, `Set-Item` or `si` on `variable:` or `env:`, or `SetEnvironmentVariable`, which set a variable by a name the text does not show. Bash splits and globs an unquoted `$HOME` or `${HOME}`, so it qualifies only when the resolved HOME has no whitespace and none of `*?[`; `~` and `"$HOME"` always qualify (PowerShell does not split). It never applies under `xargs`, `parallel` or `find -exec`, and `cp` takes only `-r -R -p -f -v -n -t` and `--preserve=<list>` without `mode` or `all` in it. Nothing in the agent memory dir is ever run: a path under `.claude/agent-memory` (any spelling, `..` resolved) is denied as the command, as the argument of `source` or `.`, as the program file of an interpreter (`bash`, `sh`, `zsh`, `dash`, `ksh`, `fish`, `python*`, `py`, `node`, `deno`, `bun`, `perl`, `ruby`, `php`, `pwsh`, `powershell`, `cmd`, `wsl`; options and their values are skipped), as a file it loads through an option (`node -r`, `--require`, `--import`, `--loader`, `bash --rcfile`, `--init-file`, `ruby -r`), as the `-f` program of `sed`, `awk` or `make` (also `gawk -E` and `-i`, and `-f -` with the file on `<`), and as an interpreter's `<` input unless `-c` or `-e` gives the code, so a script or binary written there cannot be started. Link creation is denied everywhere: `ln`, `mklink` (also through `cmd /c`), `junction`, `fsutil hardlink` and `fsutil reparsepoint`, and `New-Item` of any item type. `npm pkg get` and a bare `npm version` are reads. If the checker itself fails (very deeply nested input, no usable Python invocation) a guarded agent gets a deny, and only a missing Python allows. It stops honest mistakes, not a determined bypass: an interpreter that writes a file itself (`python -c`, `node -e`), a script file run by name outside the memory dir, a memory-dir file reached through `eval "$(cat file)"`, a glob spelling of the memory path, a `sed` or `awk` program (`sed e`, `sed w`, `awk` `system()` and redirects), an archive tool, a git alias, a `curl -K` config file, `curl --output-dir`, other launchers (`strace`, `chroot`, `unshare`, `systemd-run`, `su -c`), a symlink inside the memory dir (links cannot be made here, but one made earlier is not followed), or text piped into a shell (other than a heredoc) is not seen. Deliberately obfuscated commands are out of scope: the allowances are kept narrow so that obfuscation falls back to deny where it can be seen. A word such as `eval`, `read` or `cd` anywhere in the command turns the memory-dir allowance off, but words inside the body of a plain heredoc with a quoted delimiter (`<<'EOF'`, `<<"EOF"`, `<<\EOF`, a bare reader starting the line, a delimiter that closes) do not count, since bash never expands or runs that body, so `cat > ~/.claude/agent-memory/<agent>/n.md <<'EOF'` stays allowed for a note that mentions `cd`, `HOME` or `eval`. An unquoted body, and any word outside the body, still counts. A file copied into the memory dir keeps its mode, so a copied executable stays executable. `git fetch` is allowed on purpose: it updates remote-tracking refs, never the working tree.
- **guard-exit-plan.sh** denies `ExitPlanMode` until the plan text contains `AUDIT CLEAN`, which the `self-audit` skill writes into the plan file, or the line `self-audit: not required (trivial)`. Install both together (full preset).
- Both fail open: without Python they print a warning on stderr and allow the call, like every other hook here.
- **block-git-push.sh**, **pre-commit-secret-scan.sh** and **post-commit-review.sh** share one command parser (the same text between the `BEGIN SHARED CMDPARSE` and `END SHARED CMDPARSE` lines in each; hooks stay standalone, and `test-hooks.sh` diffs the copies, so edit all three together). It judges the git command that would run: parts split on `; && || |` and newlines outside quotes, `env`, `sudo`, `VAR=val`, `bash -c`, `eval` and `$(...)` unwrapped, `git` and `git.exe` with `-C`, `-c` and other global options, `cd` tracked per part. A target it cannot resolve (a variable, a missing directory, an unknown remote) blocks with a message instead of guessing, and block-git-push.sh allows with a warning when git is not on PATH. The first two are wired under both a `Bash` and a `PowerShell` matcher in `examples/settings-template.json`. The secret scan has no skip for `--no-verify` or `--amend` (those skip git's hooks, not this one); `$GITLEAKS_BIN` names the gitleaks binary.
- **protect-config.sh** and **protect-claude-settings.sh** normalise the file path before matching it (`\`, `//`, `/./`, `x/..`, trailing dots, case, 8.3 short names). They see the Write and Edit tools only: a shell command that writes the same file (`sed -i`, `echo >`) is out of scope for both. Guard shell writes with a Bash-side hook or the permission rules.
