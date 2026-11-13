# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and the project uses date-based releases.

## [Unreleased]

### Fixed
- All 16 Python-based hooks, `setup.sh`, `tests/judge-eval.sh`, `tests/install-matrix.sh` and `hooks/test-hooks.sh` now skip the Windows Store `python3` stub (a `python3` under `WindowsApps` that exits 49 without running anything). Before, the guards ran nothing and let the call through. A candidate on that path is run once with `-c ''`, then `python` and `py` are tried. The detection snippet in `hooks/README.md`, `TROUBLESHOOTING.md` and `GETTING-STARTED.md` is updated.
- `hooks/verify-subagent-findings.sh` no longer says a report was received when a background agent has only been launched (`tool_response.status` of `async_launched`). It sends Claude a short "launched, no report yet" note instead.
- `hooks/cost-tracker.sh` now logs the real `session_id` (from the hook's stdin JSON) and the model (from the last transcript entry that has one) instead of `unknown`, and cuts an oversize log through a temp file and a rename.
- `hooks/instructions-loaded.sh` rotates its log at 1 MB, keeping one `.1` generation, so it no longer grows without bound.
- `hooks/verify-mcp-sync.sh` prints "Cursor not installed, comparison skipped" when the Cursor config does not exist, instead of reporting OUT OF SYNC.
- `hooks/check-no-dash-file.py` skips Markdown code spans and fenced blocks when it looks for the double-dash substitute, so a comment that quotes `git log -- path` can be posted. Banned characters are still checked everywhere.
- `hooks/no-dash-check.sh` judges each double-dash occurrence in `.md`, `.markdown` and `.txt` files (code spans blanked, fenced blocks skipped) instead of excluding a whole line that holds a flag or a code span. Other file types keep the line filter.
- `hooks/protect-config.sh` and `hooks/protect-claude-settings.sh` return a deny, not an ask, when the call comes from a subagent (non-empty top-level `agent_id`), because a subagent cannot answer a prompt. The deny tells it to ask the user to make the change.
- `hooks/block-git-push.sh`, `hooks/pre-commit-secret-scan.sh` and `hooks/post-commit-review.sh` now judge the git command that would actually run, not the text of the command line. A shared parser (the same text in all three, diffed by `hooks/test-hooks.sh`) splits on `; && || |` and newlines outside quotes, ignores heredoc bodies, unwraps `env`, `sudo`, `command`, `nohup`, `time` and `VAR=val`, follows `bash -c`, `eval`, `$(...)` and backticks, understands `git` and `git.exe` with `-C`, `-c` and other global options, and tracks `cd` per part. `echo "git push"` and a commit message that quotes `; git push` are not pushes. Unparseable text that still mentions the subcommand fails closed.
- `block-git-push.sh` resolves the real target: `--repo`, else the first argument after `push` (values of `-o`, `--push-option`, `--receive-pack` and `--exec` skipped), else `pushRemote`, `remote.pushDefault`, the branch's remote, then `origin`, through `git remote get-url --push`, or a literal URL as given. A push to a target that cannot be resolved (no such remote, a missing directory, a variable) is blocked with a message. If git is not on PATH it warns and allows.
- `pre-commit-secret-scan.sh` now scans a `git -C dir commit`, `git -c k=v commit`, `git  commit` and `cd dir && git commit`, in the right directory. The `--amend --no-edit` and `--no-verify` skips are gone (`--no-verify` skips git's hooks, not this one). It scans the index, plus the tracked working-tree changes for `-a`, `--all` or a pathspec, plus the files an earlier `git add` in the same command would stage, using a throwaway copy of the index so the real one is untouched. A clean gitleaks result is re-run up to twice while the diff is non-empty, because gitleaks 8.30.1 has been seen to report no leaks intermittently. The block message now says to allowlist a false positive in `.gitleaks.toml` or ask the user to commit it. `$GITLEAKS_BIN` names the binary (the test seam).
- `post-commit-review.sh` reviews the right repository for `-C`, `-c` and `cd`, lists a merge commit's files with `git diff --name-only HEAD^1 HEAD` (`diff-tree` reports none), matches `schema\.prisma` with the dot escaped, and reports only a commit that is the newest HEAD reflog entry and under 120 seconds old.
- `hooks/protect-config.sh` and `hooks/protect-claude-settings.sh` normalise the path before matching: `\` to `/`, `//` and `/./` collapsed, `x/..` resolved, trailing dots and spaces stripped, case folded, and an 8.3 short name such as `SETTIN~1.JSO` read as `settings.json`. A different spelling of the same file now asks. A shell command that writes the file (`sed -i`, `echo >`) is still out of scope for both hooks, and the headers and `hooks/README.md` say so.
- `examples/settings-template.json` wires `block-git-push.sh` and `pre-commit-secret-scan.sh` under a new `PowerShell` PreToolUse matcher as well as `Bash`, so a push or commit run through the PowerShell tool is guarded too. The docs say "Bash, PowerShell" for those two hooks.
- The shared git parser also reads PowerShell as PowerShell (`$x = git push` and `$x=git push` are assignments, a backslash is a path character, also at the end of a line and inside double quotes, a backtick escapes the next character so ``git pu`sh`` and ``git comm`it`` are a push and a commit, `{` and `}` open and close blocks, `Set-Location` is tracked) and Bash as bash (an unquoted backslash is dropped, `$'...'` ANSI-C quoting is decoded, so `g\it push` and `git pu\sh` are pushes, `env -S 'git push'` is walked as a command string, and a push inside braces or an `if` and `then` body is seen). Shell keywords and braces no longer hide a push or a commit. A subcommand built at run time (`S=push; git $S origin`, `git pu$()sh`, `git {push,pull}`) and a shell alias given on the command line (`git -c 'alias.x=!git push origin main' x`, an unknown subcommand while an alias is defined) are treated as a push or a commit that cannot be judged: the push guard blocks, the secret scan scans and the review reports.
- `block-git-push.sh` applies the `-c` pairs whose key starts with `remote.`, `url.`, `branch.` or `push.` (any case) to the git calls that resolve the remote, so `-c remote.origin.pushurl=...`, `-c url.<base>.insteadOf=...` and `-c remote.pushDefault=...` change the answer. No other command-supplied `-c` pair reaches a git call of any of the three hooks, so `git -c core.fsmonitor=<program> commit -a` cannot make a hook run the program before the permission decision, and expands a literal URL through `git ls-remote --get-url` (insteadOf), checking both the literal and the expanded URL. Leading `GIT_DIR` and `GIT_WORK_TREE` assignments (also after `env`) count like `--git-dir` and `--work-tree`.
- The git guards fail closed on errors. `pre-commit-secret-scan.sh` checks the Python exit status: when a commit was detected but its scan cannot be prepared (the throwaway scan directory cannot be created, a git call times out, the parser dies) it blocks with a message instead of letting the commit through with an empty job list. A gitleaks run that fails (exit status other than 0 or 1) blocks with its own message. `block-git-push.sh` blocks on an unexpected error after a push was detected, and on a parser that exits abnormally for a command that mentions push or commit, also behind quotes, backslashes or backticks (`git pu""sh`). `pre-commit-secret-scan.sh` blocks a commit whose directory cannot be resolved (`cd "$DIR"`, `cd ~user`, `cd -`) instead of scanning the payload directory, and without Python it prints a warning on stderr before allowing. Only a missing gitleaks (or git, for a remote name) still allows, with a note.
- `pre-commit-secret-scan.sh` treats `git stage` like `git add`, and skips `--trailer`, `-m`, `-F`, `-C`, `-c`, `--author`, `--date`, `--cleanup`, `--fixup`, `--squash`, `--template` and `--pathspec-from-file` with their separate values, so `git commit --trailer "k: v" -m x file` scans `file` instead of treating the trailer as a pathspec.
- `hooks/protect-config.sh` and `hooks/protect-claude-settings.sh` cut an NTFS stream suffix (`::$DATA`, `:$DATA`, `:name`, `:name:$DATA`) from the last path component before matching, and keep a leading drive letter colon, so `settings.json::$DATA` asks like `settings.json`.
- Known limits are written down in the `block-git-push.sh` and `pre-commit-secret-scan.sh` headers and in `hooks/README.md`: `echo "git push" | bash`, `find -exec git push`, `su -c`, PowerShell `iex` and `Start-Process`, `pwsh -EncodedCommand` and abbreviated pwsh parameters, the glued `cmd /c"..."` form, `popd` and `Pop-Location`, a hook that Claude Code stops at its timeout (it does not block), and, for the secret scan, a secret written to a new file earlier in the same command line. The headers and the README also state the threat model: the hooks stop accidental pushes and accidental secret commits, they are not a sandbox against deliberately obfuscated commands. `block-git-push.sh` and `pre-commit-secret-scan.sh` run their parser from a temp file (`python -I`, with `python -c` as the fallback) because it no longer fits a safe command line.
- `hooks/agent-write-guard.sh` closes read-only gaps. It denies a `GIT_*=` variable on the command (prefix word, `env`, `export`, PowerShell `$env:`), `git fetch` and `git ls-remote` with `--upload-pack` or `--exec`, `git fetch --recurse-submodules`, `git grep -O` and `--open-files-in-pager`, a leading `git --exec-path`, and `env -S` strings that hide a command. Backtick substitution and `$(...)` inside double quotes are judged like an unquoted `$(...)`. `npx`, `bunx`, `pnpx`, `uvx`, `pnpm dlx`, `yarn dlx`, `npm exec` and `bun x` count as package runners. Package-manager parsing skips value options (`npm --prefix . install x`) and adds `version`, `pkg`, `publish`, `init`, `create` and similar, plus `python -m pip install` and `uv pip install`.
- `hooks/agent-write-guard.sh` treats `curl -o`/`-O`/`-D`/`-c` and the other output options, `wget` (any download) and `sort -o` as writes, and denies `sort --compress-program`. A target inside the agent's own memory dir stays allowed. `tool_name` `Monitor` is judged like Bash, and PowerShell `[IO.File]::Write*`, `Append*`, `Create*`, `Copy`, `Move`, `Delete` and `StreamWriter` count as writes.
- `hooks/agent-write-guard.sh` no longer denies a heredoc body as if it were commands (`cat <<EOF` with `rm` text inside is a read). A heredoc fed to a shell on the same line, or with an unquoted delimiter and `$(...)` in the body, is still judged, and a redirect on the heredoc line still counts. `$HOME`, `${HOME}` and `~` expand in a redirect or write target, and `rm`, `cp`, `touch` and `mkdir` are allowed when every target is inside the agent's own memory dir, as the header says (any target outside it, a brace list, an unknown variable or an unknown option is denied). The script now runs its Python from a temp file because the source no longer fits a safe Windows command line.
- `hooks/agent-write-guard.sh` closes the bypasses a cold review found in the first round. The memory-dir allowance no longer applies under `xargs`, `parallel` or `find -exec`, and only a plain path qualifies (a quote, backslash, `$`, glob, brace, `..` component or, in PowerShell, a comma is refused). `cp -s`, `-l`, `-a` and the link options are denied. A heredoc body is text only for a plain reader with a closed delimiter and no pipe; an escaped or variable receiver, a shell, `tee`, `<<` inside `$[...]` or `a[...]=`, and an unclosed delimiter mean the body is judged, and `$(...)`, `${...}` and backticks in an unquoted body are found even after an apostrophe. Deeply nested input, or a Python that cannot run, now gives a deny for a guarded agent instead of a silent allow, and the temp-file trap is set before the file is written.
- `hooks/agent-write-guard.sh` also stops `env -S'cmd'` and `env -iS`, `python -mpip install`, the npm install and remove aliases (`in`, `isntall`, `un`, `r`, `ln` and the rest), `yarn global add`, pnpm and bun equivalents, an unknown option value hiding the subcommand (`npm --maxsockets 5 install x`), prefixes of `--open-files-in-pager` and `--upload-pack`, `curl -w '%output{file}'`, and PowerShell `[IO.File]::Open*`, `IO.FileStream` and `IO.FileInfo` writes. It no longer denies `git grep -eOpen`, `npm pkg get` or a bare `npm version`, and the deny for a `GIT_` variable says why (`GIT_TERMINAL_PROMPT=0` stays denied). A quoted `"$HOME"/.claude/agent-memory/<agent>/...` target is read as `$HOME/...`.
- `hooks/agent-write-guard.sh` replaces the paren and quote counting for heredoc bodies with a strict rule: the body is text only when the line holding `<<` is `<reader> [args] <<[-]DELIM` with at most `> file` or `>> file` after it, no `( ) $` backtick, backslash, `| ; & <` or quote before the `<<`, and no trailing backslash. Decoys such as `echo "))" $((cat <<3))`, `bash <(echo ")" >&2; cat <<EOF` and a pipe behind a backslash-newline no longer hide a body that runs. It also matches command names on the bare name (`/usr/bin/xargs`, `\xargs`, `/usr/bin/env -S`), judges `env -S`, `--split` and a prefix of `--split-string` together with the words after it, judges `<(...)` and `>(...)` bodies, skips the values of `stdbuf -i -o -e`, unwraps `chrt`, `taskset` and `busybox`, judges the command of `watch` and `script -c`, and denies `flock`, `robocopy`, `xcopy`, `Expand-Archive`, `Compress-Archive`, `rg --pre`, `npm config set|delete|edit`, `npm cache clean`, `npm pack`, `cargo fmt`, `cargo clippy --fix`, `cargo package`, `cp --preserve=mode` and a PowerShell `.Delete(`, `.MoveTo(` or `.CopyTo(` call. A string method on a `[IO.FileInfo]` (`.Name.Replace(...)`) is no longer a write. The hook reads its input as UTF-8 bytes, so a non-ASCII command no longer fails open on a Windows code page, and a test seam (`AGENT_WRITE_GUARD_TEST_NO_CHECKER`) proves the deny when the checker cannot run. The header lists the limits that remain: interpreters and script files run by name, a `HOME` reassigned in the same command, `curl --output-dir`, `less !cmd`, other launchers, and a copied executable keeping its mode.
- The `hooks/agent-write-guard.sh` header and `hooks/README.md` list what is covered and what is still not seen: interpreters writing files, archive tools, git aliases, script files, a `curl -K` config, symlinks in the memory dir and text piped into a shell. Add `Monitor` to the guard's settings matcher if your Claude Code version does not route Monitor through the Bash entry.
- `docs/SELF-MONITORING.md` no longer shows a script that skips on `--no-verify` or advises bypassing with it, `assets/card-architecture.html` and `docs/WHY.md` say Bash and PowerShell for `block-git-push.sh`, and the `hooks/README.md` rows say "Before any Bash or PowerShell command".
- Regression cases for all of the above in `hooks/test-hooks.sh`.

## [1.3.1] - 2026-11-13

### Changed
- The Japanese, Korean and Simplified Chinese READMEs are back in sync with v1.3: six missing hook rows, the `diagnose-before-finding` skill row, the global Quick Start, the preset banner and the read-only-by-intent and model-alias notes.

### Added
- `tests/count-check.sh` now checks that each translated README's hooks and skills tables list the same scripts and skills, in the same order and row count, as the English README.

### Fixed
- `hooks/protect-config.sh` and `hooks/protect-claude-settings.sh` now emit the documented `hookSpecificOutput.permissionDecision` `"ask"` shape. The old top-level `decision: "ask"` is not a documented PreToolUse value (only `approve` and `block` map, to allow and deny), so the confirm prompt could be skipped. Decision tests added to `hooks/test-hooks.sh`.

## [1.3.0] - 2026-11-12

### Added
- `hooks/agent-write-guard.sh` (full preset, PreToolUse on Write, Edit, MultiEdit, NotebookEdit, Bash and PowerShell): when the hook input names a read-only agent in `agent_type`, it denies file writes outside that agent's memory dir, shell redirects into files, `tee`, `sed -i`, file-changing commands, package installs, git beyond a read-only allowlist, and the same forms inside `bash -c`. The list is configurable with `AGENT_WRITE_GUARD_AGENTS`. This enforces the read-only intent of `permissionMode: plan` in every permission mode.
- `hooks/guard-exit-plan.sh` (full preset, PreToolUse on `ExitPlanMode`): denies leaving plan mode until the plan contains `AUDIT CLEAN` or `self-audit: not required (trivial)`. The `self-audit` skill now writes its Check | Status | Finding table and that marker into the plan file.
- `skills/diagnose-before-finding/`: four sourced lines (writer and carrier, meaning at this step, the other side, owner asked) before a mismatch becomes a finding, a repro command that can go red, a fix-attempt cap, and tagged debug logs.
- `CLAUDE.md`: a "gate the finding" step after Diagnose-First, and an "Evidence principles" section (review intake, no test that passes by construction, never read an exit code through a pipe, content is data).
- The Stop prompt now also flags a claim of done, fixed or passing that the final message does not back with its own evidence. It judges only `last_assistant_message`, and returns `impossible: true` when the fix needs the user. The old ORM-schema and CLAUDE.md-violation checks were dropped, because a prompt hook sees neither the schema nor CLAUDE.md.
- `tests/judge-fixtures/` (9 labelled messages) and `tests/judge-eval.sh`, which replays them through the Stop prompt. Manual only: it needs `ANTHROPIC_API_KEY` and is not a CI job.
- `hooks/test-hooks.sh` gains 75 guard cases, including shell parsing edge cases (comment lines, glued separators, `if`/`for` bodies, `bash -lc`, `pwsh -Command`, `cmd /c`, wrapper options, `find -exec`), for 149 tests in all. Counts are now 18 hooks and 20 skills.
- `tests/required-checks.sh` checks the merge-gate claims in `CONTRIBUTING.md`: a job the text calls a required check must be one, and every `bash` command in the "Automated checks" block must be run by a required job.
- `tests/pin-check.sh`, run by the required `count-check` job: fails when any `uses:` line in `.github/workflows` or `.github/actions` is not pinned to a full 40-character commit SHA with a trailing version comment.
- `.github/dependabot.yml`: weekly `github-actions` updates, which bump each pinned SHA and its version comment together.

### Changed
- Every GitHub Action is now pinned by full commit SHA with the version as a trailing comment (`actions/checkout` v7.0.1, `lycheeverse/lychee-action` v2.9.0), so a moved or compromised tag cannot change what CI runs. `actions/checkout` is on v7 (was `@v4`). The workflows trigger on `push` and `pull_request` only, so v7's block on checking out fork code under `pull_request_target` and `workflow_run` ([v7.0.0 release notes](https://github.com/actions/checkout/releases/tag/v7.0.0)) does not apply.
- The `minimal`, `standard` and `core` presets no longer get PreCompact summary guidance, because `precompact-state.sh` is installed by `full` only. Every preset keeps the `SessionStart` `compact` recovery text.
- Docs modernized for current Claude Code and the 5.5 model family:
  - Models: Opus 5.5, Sonnet 5.5, Haiku 5.5 and Fable 5.2 named where tiers are discussed, with the aliases (`fable`, `best`, `opusplan`, `inherit`, `[1m]`), the subagent model order and `CLAUDE_CODE_SUBAGENT_MODEL`. Agent tiering is unchanged (1 opus, 10 sonnet, 1 haiku).
  - Pricing: dollar tables removed from `docs/ARCHITECTURE.md`, `docs/SETTINGS-GUIDE.md`, `docs/BENCHMARKS.md`, `agents/README.md` and `FAQ.md`. They now give relative tiers and link the official pricing and costs pages.
  - Hooks: `hooks/README.md` lists all 33 hook events with the handler types each accepts, documents the five handler types, `if`, `onFailure` and `timeout`, and says when a prompt hook is the right tool.
  - Agents and skills: current frontmatter fields documented in `agents/README.md` and `skills/README.md`; skills are described as natural-language triggered and also runnable as `/name`; the worktree claim in `agents/README.md` is corrected.
  - Settings: the permission section adds the project-file scope limits, subagent mode inheritance, and the `blockWritesOutsideWorkingDirectories`, `denyInsteadOfPrompting` and `sandbox.enabled` keys; auto mode classifier facts updated.
  - Memory: the auto memory limit is the first 200 lines or 25KB of `MEMORY.md`; `docs/ARCHITECTURE.md` explains `@path` imports and native `AGENTS.md` reading.
  - `GETTING-STARTED.md` gains Output Styles, Workflows and "Packaging Your Fork as a Plugin" sections; the ROADMAP keeps the plugin marketplace under Not Planned with an updated rationale.

### Fixed
- D1: `verify-subagent-findings` now delivers its warning to Claude through `additionalContext`. A synchronous hook's `systemMessage` is shown to the user only.
- D2: Removed the prompt hooks on PreCompact and PostCompact, which Claude Code does not support (only command, http and mcp_tool handlers run there). Compaction guidance now comes from `precompact-state.sh` stdout, plus an inline `SessionStart` hook with the `compact` matcher for recovery after compaction. The MCP failure guidance moved to the new `hooks/mcp-failure-hint.sh` (Standard preset).
- D3: Removed the agent-teams flag from the template and corrected the docs. Subagents need no env flag; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enables the separate, experimental agent teams feature.
- D4: Corrected the read-only reviewer claims. `permissionMode: plan` holds only when the main session runs in `default` or `dontAsk` mode, and agents that set `memory` can still write.
- D5: Removed `effortLevel` from the template. It is ignored for Opus 5.5 and later; use `/effort`.
- D6: Corrected stale facts: the plugin system, the MCP config path (`~/.claude.json`), the permission modes (six, not four), the model id in the cross-tool guide, the version string in `setup.sh`, and the ROADMAP.

### Upgrading from 1.2

The installer merges into your existing `~/.claude/settings.json` and never removes entries, so remove these by hand:

- The `PreCompact` entry of type `prompt`. Keep the `precompact-state.sh` command entry.
- The whole `PostCompact` block.
- The `PostToolUseFailure` prompt entry (and its old `mcp__*` matcher). `mcp-failure-hint.sh` replaces it.
- `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. Keep it only if you use agent teams.
- `effortLevel`.

## [1.2.0] - 2026-09-26

### Added
- `Wiring (new symbol)` row in `CLAUDE.md`'s Verify-After-Complete table: a new symbol must be imported/registered/called and data must flow end to end, not just pass tests.
- Fresh-angle principle folded into `CLAUDE.md` check 7: cross-check any non-trivial conclusion from outside the context that produced it (cold subagent, whole-tree grep, authoritative source, adversarial pass).
- Stop condition on check 7: two passes on the same artifact with no new finding means stop and escalate to the user, not loop indefinitely.
- A skip-excuse clause on each of the four mandatory `CLAUDE.md` rules, naming and rebutting the rationalization most likely to precede skipping it.
- "A prose rule is not a hook" section in `CLAUDE.md`: if a check must never be skipped and a script can decide it, make it a hook.
- `self-audit` skill (19 total), installed by `full`: runs the `verify-plan` checklist against your own plan before ExitPlanMode.
- `memory-curator` agent (12 total), installed by `full`: audits a memory directory against its index whole-tree and writes a dated health report.
- Three hooks (15 total, from 12), each wired in `examples/settings-template.json`: `protect-claude-settings.sh`, `verify-subagent-findings.sh`, `no-dash-check.sh`.
- `hooks/check-no-dash-file.py`: a manual sanitizer for prose posted to external systems from a shell command, closing the shell-to-network path the Write/Edit hooks can't reach.
- "Scoping a hook to specific projects" section in `hooks/README.md`.
- `tests/count-check.sh` guard and CI job: derives every published component count from the filesystem and asserts each copy agrees.
- Eight further `count-check.sh` bindings covering per-preset file totals (4/10/20/55) in `setup.sh` and the walkthrough deck cards.
- `tests/required-checks.sh` guard and advisory `required-checks` CI job: compares workflow job ids against the branch ruleset's required status checks.
- A fourth `required-checks.sh` section: asserts `docs/ROADMAP.md`'s CI bullet matches the enforcement actually in effect.
- "Why this rule exists" intent preamble on the five path-scoped rule files.
- Advisory `shellcheck` CI job (in Install Test), linting `hooks/*.sh`, `setup.sh`, and `tests/*.sh` on every push and pull request.

### Changed
- `CONTRIBUTING.md` now documents the automated checks: `tests/count-check.sh`, a "Component Counts" section, and the commands to run before opening a PR.
- Link-check CI now runs lychee with `--include-fragments`, validating `#anchor` targets against real headings.
- `post-commit-review.sh` now explains WHY auth/guard/middleware/schema/env files are higher-risk, not just that they are.

### Fixed
- Corrected the CI description in `docs/ROADMAP.md`, which still said checks "do not gate merges" after four had become required status checks.
- Removed the last 15 em-dashes from six tracked files (`docs/SELF-MONITORING.md` and five skills).
- Repaired the sanitization gate in `.github/PULL_REQUEST_TEMPLATE.md`, which scanned the whole repo instead of only the PR's changed files.
- Corrected the preset menu in `setup.sh` ("11 agents, 18 skills" to the actual 12 and 19).
- Updated the visual assets (overview/social cards, architecture card, walkthrough deck) to current component counts.
- Corrected the "43 automated tests" figure to 55 in `README.md`, `docs/ROADMAP.md`, and the three translated READMEs.
- Corrected seven stale component counts across the documentation and translations that the earlier count sweep's pattern could not match.

## [1.1.0] - 2026-07-11

### Added

- A `hook-tests` CI job (in the Install Test workflow) that runs `hooks/test-hooks.sh` on every pull request, so a hook that fails the smoke suite (syntax, or mishandling empty / malformed / missing-field stdin) now blocks merge instead of only being checked when a contributor remembers to run it locally.
- `pr-review` skill: fetches a GitHub or Gitea pull request's diff, runs the same multi-agent analysis as `review-full` plus any project-specific rules the target repo documents, then posts the verdict (approve/request-changes/comment) as a real PR review via the platform's API, with reviewer-identity-aware self-review handling and a mandatory self-verification pass before posting.
- An "When to Use an Agent vs a Skill vs the Main Thread" decision framework in `agents/README.md`, teaching when to reach for each, the "wire it, don't just define it" rule, and how to right-size an agent roster for your own stack. Cross-linked from the architecture diagram and the getting-started glossary. [PR #37]
- `testing-general` rule: framework-agnostic testing conventions (discover-don't-assume, Arrange/Act/Assert, deterministic tests) that complement the stack-specific testing.md. [PR #29]
- `pre-commit-secret-scan.sh` hook, which runs gitleaks on staged content before `git commit` and blocks the commit if a secret is detected (fails open if gitleaks is not installed). [PR #28]
- `instructions-loaded.sh` hook, which logs which CLAUDE.md and rules files load into context and why, making path-scoped rule injection observable. [PR #28]
- `architecture-reviewer` agent, providing structural review (dependency direction, circular deps, god files, dead code, modularity) that complements the line-level code-reviewer. [PR #28]
- `core` install preset: a curated middle tier between `standard` and `full`, adding two review agents (security-reviewer, qa-tester), six broadly-useful skills (review-full, review-diff, test-check, deploy-check, db-check, changelog), and two path-scoped rules (testing, database-schema). [PR #14]
- A token-budget table in the README showing the context cost of each component and when it loads, so you can decide what to copy on a per-token basis. [PR #13]
- A CI link check (lychee) that verifies every Markdown link on each push and pull request. [PR #13]

### Changed

- CLAUDE.md now installs globally to `~/.claude/CLAUDE.md` by default instead of a per-project root copy, so its four behavioral rules apply to every project on your machine. The `setup.sh` installer prompts for the global path and backs up any existing `~/.claude/CLAUDE.md` before writing. The quick-start, SETUP, GETTING-STARTED, FAQ, AGENTS, and cross-tool docs were updated to match; a project-level `CLAUDE.md` remains documented as an optional team-shared, repo-committed convention.
- Made the agent roster framework-agnostic: the "check package.json" convention is now "check the project manifest" across every agent, and database-review guidance no longer hardcodes Prisma (ORM-specific behavior is now shown as examples, with the ORM list covering Eloquent, ActiveRecord, Hibernate/JPA, EF Core, SQLAlchemy, Django ORM, and GORM). [PR #37]
- The `review-full` skill now wires the `architecture-reviewer` agent, spawning up to four review agents by what changed; the architecture diagram was rewritten to mark which agent flows are actually wired versus illustrative. [PR #37]
- The `full` install preset now installs all 12 hooks; it previously omitted `instructions-loaded.sh` and `pre-commit-secret-scan.sh`. [PR #37]
- Consolidated the README calls-to-action into one clear path and fixed remaining "three rules" stragglers so the on-ramp is unambiguous. [PR #34]
- Reworked the on-ramp into a single linear flow (README CTA plus a hands-on-first GETTING-STARTED) so new readers have one obvious starting point. [PR #33]
- Re-encoded the hero walkthrough GIF about 23% smaller (5.6 MB to 4.3 MB) with no visible quality loss; same dimensions and runtime. [PR #15]
- Right-sized the compliance wording: the unmeasured "~80%" figure is replaced with honest qualitative phrasing, while the accurate "hooks fire deterministically" property is kept. [PR #13]
- The two example-only rule files (`api-endpoints`, `testing`) now carry a clear "replace with your own conventions" banner so adopters know they reflect one project's patterns. [PR #13]

### Fixed

- Removed `isolation: worktree` from the four read-only review agents (`verify-plan`, `code-reviewer`, `security-reviewer`, `architecture-reviewer`). Worktree isolation requires a git repository at the workspace root, so these agents failed with "Cannot create agent worktree" for anyone whose Claude Code root is a non-git parent directory (for example, one folder holding several project repos). Because the agents are read-only (`Read`, `Grep`, `Glob`) under `permissionMode: plan`, the isolation guarded against writes they can never make; the unbiased "cold" review they provide comes from each subagent's fresh context window, not from a fresh checkout. The agents now run at any workspace root with no loss of review quality. `agents/README.md` and `docs/WHY.md` were updated to describe worktree isolation as a tool for write-capable agents only.
- Corrected a second identity name, heading casing, and completed gaps in the three translations. [PR #32]
- Fixed consistency drift across component counts, pricing figures, tables, and the translated READMEs so every surface agrees. [PR #31]
- Memory `session.md` and `reminders.md` are no longer tracked by git despite being described as "git-ignored for privacy"; they now ship as `.example` templates that `setup.sh` seeds locally on install. [PR #12]
- Renamed two skills that shadowed built-in slash commands: `review` to `review-full`, and `init-project` to `scaffold-project`. [PR #12]
- Repaired broken relative links across the docs and the three translated READMEs. [PR #12, PR #13]
- Corrected a dead `WHY.md` reference in the installer and the issue template (now `docs/WHY.md`). [PR #12]

### Removed

- Consolidated the `api-documenter` agent into `docs-writer` (which already covered API docs and OpenAPI), bringing the roster from 12 agents to 11. [PR #37]
- Dropped the `release`, `oss-contribute`, and `npm-publish` skills, which were out of scope for a Claude Code configuration reference (they target package publishing and OSS contribution workflows, not harness setup). [PR #30]

## [1.0.0] - 2026-03-25

Initial public release.

### Added

- 11 specialized agents with model tiering (opus / sonnet / haiku) and permission modes.
- 17 natural-language-triggered skills covering code review, testing, deployment, session management, and more.
- 10 lifecycle hooks for deterministic automation across the session lifecycle.
- 5 path-scoped behavioral rules (API endpoints, database schema, testing, session lifecycle, memory).
- A CLAUDE.md template with four behavioral rules: Verify-After-Complete, Diagnose-First, Plan-First, and Verify-Before-Exit-Plan.
- A built-in opt-in memory system template and a full settings template.
- A `setup.sh` installer with minimal, standard, and full presets, cross-platform OS detection, and safe file copying.
- A beginner guide, cross-tool guide, FAQ, troubleshooting guide, and four framework-specific CLAUDE.md examples.
- Battle-story documentation (`docs/WHY.md`) explaining the reasoning behind each component.

[Unreleased]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.3.1...HEAD
[1.3.1]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/faizkhairi/claude-code-blueprint/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/faizkhairi/claude-code-blueprint/releases/tag/v1.0.0
