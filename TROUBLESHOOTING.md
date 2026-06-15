# Troubleshooting

Common issues and fixes. Search this page (Ctrl+F) for your error message or symptom.

---

## Hooks

### "Hooks aren't firing"

**Symptoms:** You configured a hook in `settings.json` but Claude doesn't mention it running, and the expected behavior doesn't happen.

**Causes and fixes:**

1. **Wrong file path in settings.json.** The `"command"` field must point to the actual script location. Check that the path resolves correctly:
   ```bash
   # Test it directly
   bash ~/.claude/hooks/protect-config.sh
   ```
   If the file isn't found, correct the path. On Windows, see [Windows Notes](GETTING-STARTED.md#windows-notes) for path format differences.

2. **Hook file doesn't exist at the expected location.** If you copied hooks from this blueprint, verify they're in `~/.claude/hooks/` (or wherever your settings.json points).

3. **Wrong matcher.** The `"matcher"` field must match the tool name exactly. Common mistakes:
   - `"bash"` (lowercase) won't match -- use `"Bash"`
   - `"write"` won't match -- use `"Write|Edit"` for file operations
   - For MCP tools, use `"mcp__*"` as the matcher

4. **JSON syntax error in settings.json.** A trailing comma, missing quote, or unclosed bracket silently breaks the entire hooks config. Validate your JSON:
   ```bash
   python -c "import json; json.load(open('$HOME/.claude/settings.json'))"
   ```

### "Hook runs but has no effect"

**Symptoms:** The hook fires but doesn't block or modify behavior.

**Causes and fixes:**

1. **Exit code is always 0.** For PreToolUse hooks that should block actions, the script must return exit code 2 (deny). Exit code 0 means "allow." Check that your error paths use `exit 2`, not `exit 1` (which means "error" and shows a warning but doesn't block).

2. **Output goes to stdout instead of stderr.** Hook messages to the user must go to stderr (`>&2`). Messages to stdout are consumed by Claude as tool input.

### "Hook blocks everything"

**Symptoms:** A PreToolUse hook blocks more actions than intended.

**Causes and fixes:**

1. **Matcher is too broad.** `"matcher": "Bash"` fires on *every* shell command. If your hook logic doesn't filter properly, it blocks everything. Add specific command filtering inside the script (e.g., check for `git push` before blocking).

---

## Agents

### "Agents keep failing" / "Agent tool not available"

**Symptoms:** Claude says it can't spawn agents, or agent invocations fail with errors about missing tools.

**Causes and fixes:**

1. **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` not set.** This is the most common cause. Add to your `settings.json`:
   ```json
   "env": {
     "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
   }
   ```
   Then restart Claude Code. See [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md#claude_code_experimental_agent_teams) for details.

2. **Model not available on your Anthropic plan.** If an agent specifies `model: opus` but your API key doesn't have Opus access, the agent will fail. Check your plan at [console.anthropic.com](https://console.anthropic.com). As a workaround, change the agent's frontmatter to `model: sonnet`.

3. **Agent .md file not found.** Custom agents must be in `.claude/agents/` (project-level) or `~/.claude/agents/` (global). Claude Code won't find agents in other locations.

### "Agent modifies files it shouldn't"

**Symptoms:** An analysis-only agent (like verify-plan or db-analyst) writes to files or runs shell commands.

**Fix:** Check the agent's frontmatter for `permissionMode: plan`. This restricts the agent to read-only tools (Read, Grep, Glob). If the field is missing or set to a different value, the agent has write access. See [agents/README.md](agents/README.md) for the permission mode table.

---

## MCP Servers

### "MCP server crashes" / "MCP tool call failed"

**Symptoms:** Tools like `mcp__playwright__browser_navigate` or `mcp__context7__query-docs` fail with connection errors.

**Causes and fixes:**

1. **Docker not running (Docker MCP).** The Docker MCP server requires Docker Desktop to be running. Start Docker Desktop, then restart Claude Code.

2. **npx cache stale.** MCP servers installed via `npx -y` can use a stale cached version. Clear the cache:
   ```bash
   npx clear-npx-cache
   ```
   Then restart Claude Code to reinstall the MCP server.

3. **Port conflict.** Some MCP servers bind to specific ports. If another process occupies the port, the server crashes on startup. Check with `netstat -an | grep <port>` or `lsof -i :<port>`.

4. **One-time flake.** MCP servers are external processes that occasionally crash. The blueprint includes a `PostToolUseFailure` hook for MCP tools that instructs Claude to retry once. If it still fails, Claude falls back to non-MCP alternatives (e.g., `curl` instead of Playwright).

### "MCP tools not appearing"

**Symptoms:** You added an MCP server to `.mcp.json` (or `~/.claude.json`) but the tools don't show up.

**Causes and fixes:**

1. **Wrong config file location.** Project-level MCP config goes in `.mcp.json` in the project root (not `.claude.json` or `.claude/settings.json`). User-level MCP config goes in `~/.claude.json`. Verify what's registered with `claude mcp list`.

2. **Tools not in the permissions allow list.** After adding an MCP server, its tools must be listed in `settings.json` under `permissions.allow`:
   ```json
   "mcp__context7__resolve-library-id",
   "mcp__context7__query-docs"
   ```
   Or let Claude ask for permission each time (don't add to the list).

3. **Restart required.** MCP servers are loaded at startup. After changing `.mcp.json` or `~/.claude.json`, restart Claude Code.

---

## Rules and CLAUDE.md

### "Claude ignores my rules"

**Symptoms:** You wrote specific instructions in CLAUDE.md but Claude doesn't follow them.

**Causes and fixes:**

1. **CLAUDE.md is too long.** Claude Code loads CLAUDE.md into the context window. Very long files (200+ lines) dilute attention -- rules at the bottom get less weight. Keep CLAUDE.md under 100 lines and extract details into topic files or [path-scoped rules](rules/).

2. **Conflicting plugin instructions.** Plugins can inject their own instructions that compete with yours. Audit installed plugins and disable any that override CLAUDE.md or inject prompts on SessionStart. See [README.md](README.md#plugin-compatibility).

3. **Rule is guidance, not enforcement.** CLAUDE.md rules are followed most of the time -- but they're guidelines, not guarantees. If something MUST happen, make it a [hook](hooks/). Hooks fire deterministically, every time.

### "Path-scoped rules not loading"

**Symptoms:** A rule file in `.claude/rules/` doesn't seem to take effect when editing relevant files.

**Fix:** Check the `paths:` frontmatter in the rule file. The glob pattern must match the files you're editing. For example:
```yaml
---
paths:
  - "server/**/*.ts"
  - "prisma/**"
---
```
This rule only loads when Claude is working with files under `server/` or `prisma/`.

---

## Settings

### "Settings not taking effect"

**Symptoms:** You changed `settings.json` but Claude's behavior doesn't change.

**Causes and fixes:**

1. **Wrong file location.** Claude Code reads settings from multiple locations with a precedence order:
   - `~/.claude/settings.json` -- global (user-level)
   - `.claude/settings.json` -- project-level (in project root)
   Make sure you're editing the right one. Check which settings are active:
   ```bash
   claude config list
   ```

2. **JSON syntax error.** A single syntax error (trailing comma, missing quote) silently breaks the entire file. Validate:
   ```bash
   python -c "import json; json.load(open('$HOME/.claude/settings.json'))"
   ```

3. **Restart required.** Some settings (especially `env` variables and MCP configurations) are only read at startup. Restart Claude Code after changing them.

### "Permissions not working as expected"

**Symptoms:** Claude either asks for permission when it shouldn't, or doesn't ask when it should.

**Fix:** Check the interaction between `defaultMode` and the `allow` list:
- `"defaultMode": "dontAsk"` + tool in `allow` list = executes silently
- `"defaultMode": "dontAsk"` + tool NOT in `allow` list = still blocked
- Default mode (no `defaultMode` set) = asks for everything not in `allow` list

See [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md#defaultmode) for the full explanation.

### Auto mode classifier blocks legitimate actions

**Symptom:** Claude says "the classifier blocked this action" for something you expected to work.

**Fixes:**
1. **Add the command to your allow list** -- allow-listed commands bypass the classifier entirely
2. **Add context to `autoMode.environment`** -- tell the classifier about your trusted infrastructure (e.g., your GitHub org, internal domains)
3. **Check `claude auto-mode config`** -- see what rules the classifier is applying
4. **Classifier fallback:** After 3 consecutive blocks, Claude will prompt you directly -- approve it once and the pattern is learned

---

## Cost

### "Cost is higher than expected"

**Symptoms:** Your Anthropic bill is larger than anticipated.

**Causes and how to reduce:**

1. **Stop hook runs Sonnet on every response.** This is the single biggest cost driver in the blueprint. Each response triggers a Sonnet security evaluation. In a 50-response session, that's 50 extra Sonnet calls. To reduce: remove the Stop hook's security prompt (not recommended) or run it only on code-producing responses.

2. **Parallel agent spawns.** Skills like `review-full` spawn up to 3 agents simultaneously, each with its own context window and token budget. Modify the skill to spawn fewer agents for lower-risk changes.

3. **Always-thinking + high effort.** `alwaysThinkingEnabled: true` with `effortLevel: "high"` maximizes reasoning depth but also token usage. Switch to `"medium"` effort or disable always-thinking for routine tasks.

4. **Agent teams.** Sessions with active agent teams use ~7x more tokens than standard sessions.

**How to track:** The [cost-tracker.sh](hooks/cost-tracker.sh) hook logs session costs to `~/.claude/metrics/costs.jsonl`. Review this file to see which sessions cost the most.

See [SETTINGS-GUIDE.md](docs/SETTINGS-GUIDE.md#cost-implications) for the full cost breakdown and model pricing table.

---

## Windows-Specific

### "bash: command not found"

**Symptoms:** Hook scripts fail because `bash` isn't recognized.

**Fix:** Claude Code hooks require a bash-compatible shell. On Windows:
- **Git Bash** (recommended): Installs automatically with [Git for Windows](https://git-scm.com/download/win). After installation, `bash` is available in Git Bash terminals and in VS Code's integrated terminal (select "Git Bash" as the shell).
- **WSL**: Works but the file system bridge between Windows and WSL adds latency for hook scripts.

See [GETTING-STARTED.md](GETTING-STARTED.md#windows-notes) for the full Windows setup guide.

### "python: command not found" or "python3: command not found"

**Symptoms:** Hook scripts fail because Python isn't found on PATH.

**Background:** All hooks auto-detect Python using `command -v python3 || command -v python`. You need either `python3` or `python` on your PATH -- not both. If neither is found, hooks print a warning to stderr and exit cleanly (no blocking).

**Fixes:**
1. **Windows:** Install Python: `winget install Python.Python.3` or download from [python.org](https://python.org). The installer adds `python` to PATH.
2. **macOS:** Python 3 is typically pre-installed as `python3`. If not: `brew install python`
3. **Linux:** Install via your package manager: `sudo apt install python3` (Debian/Ubuntu) or `sudo dnf install python3` (Fedora)
4. **Verify:** Run `python --version` or `python3 --version` to confirm

### "Permission denied" on hook scripts

**Symptoms:** Running a hook script shows "Permission denied."

**Fix:** On Windows, Unix file permissions (`chmod +x`) are a no-op. Hook scripts run via `bash "path/to/script.sh"` in the settings.json `command` field, which doesn't require execute permission. If you're getting this error, check that:
1. The file path is correct
2. You're running via `bash "path"`, not trying to execute the script directly

### "Hook path not found" / tilde expansion issues

**Symptoms:** Settings.json references `~/.claude/hooks/script.sh` but the hook isn't found.

**Fix:** Tilde (`~`) expansion depends on the shell. In Git Bash, `~` expands to `/c/Users/YourUser`. If hooks aren't found:
1. Try an absolute path: `"command": "bash \"/c/Users/YourUser/.claude/hooks/script.sh\""`
2. Or use the `$HOME` variable: `"command": "bash \"$HOME/.claude/hooks/script.sh\""`

---

## Skills and Memory

### "Skills show 'file not found' for ./memory"

**Symptoms:** A skill like load-session or save-session fails with an error about a path containing literal curly braces, e.g., `./memory/core/session.md not found`.

**Cause:** Placeholder variables in skill files haven't been replaced with your actual paths.

**Fix:** Search your skills directory for unreplaced variables:

```bash
grep -r './memory' ~/.claude/skills/
grep -r '{CLAUDE_CONFIG_PATH}' ~/.claude/skills/
grep -r '{PROJECTS_ROOT}' ~/.claude/skills/
```

Replace each placeholder with your actual path. See [skills/README.md](skills/README.md#required-replace-placeholder-variables) for the full list and platform-specific examples.

---

## Agents (continued)

### "Agent generates analysis but won't modify files"

**Symptoms:** You asked an agent to fix something, but it only analyzes and reports -- it never actually edits files or runs commands.

**Cause:** The agent has `permissionMode: plan` in its frontmatter, which restricts it to read-only tools (Read, Grep, Glob).

**These agents are read-only by design:**
- `verify-plan` — plan verification
- `code-reviewer` — code review
- `security-reviewer` — security audit
- `db-analyst` — database schema analysis
- `devops-engineer` — infrastructure review
- `api-documenter` — API documentation generation

**Fix:** If you need code changes, use an agent with write access (e.g., `backend-specialist`, `frontend-specialist`, `qa-tester`). If you want to give a read-only agent write access, change `permissionMode: plan` to remove it in your copy of the agent file -- but be aware this removes a safety guardrail.

### "Agent stopped before finishing"

**Symptoms:** An agent was mid-task and suddenly stopped. No error message, just incomplete work.

**Cause:** The agent hit its `maxTurns` limit. Each agent has a maximum number of turns (tool calls + responses) defined in its frontmatter. When reached, the agent stops gracefully.

**Fix:**
1. Check what was completed: `git diff` to see changes made, `git status` for uncommitted work
2. To continue: spawn a new agent of the same type with a prompt like "Continue the work from the previous agent. Here's what was already done: [summary]"
3. Or continue manually in the main session

See [agents/README.md](agents/README.md#what-happens-when-maxturns-is-reached) for each agent's maxTurns value.

---

## Configuration

### "Config was created in project directory instead of ~/.claude/"

**Symptoms:** After asking Claude to set up the blueprint, you find hooks, settings, or permissions were written to `.claude/` in your project directory instead of `~/.claude/` (your home directory).

**Why this matters:** Project-level config (`.claude/`) is shared with your team via git. Personal hooks, permissions, and settings should be in `~/.claude/` so they don't affect teammates.

**Fix:**
1. Check what was created: `ls -la .claude/` in your project
2. Move personal files to user-level:
   ```bash
   # Move hooks (if any were created in project)
   mv .claude/hooks/* ~/.claude/hooks/ 2>/dev/null
   # Move settings (merge manually -- don't overwrite)
   # Compare .claude/settings.json with ~/.claude/settings.json
   ```
3. Remove the project-level files that should be personal: `rm -rf .claude/hooks/ .claude/settings.json`
4. Keep only shared config in `.claude/`: agents, skills, and rules that the whole team should use

**Prevention:** When asking Claude to set up the blueprint, always specify: "Install hooks and settings in my user-level config at `~/.claude/`, not in the project directory." See [GETTING-STARTED.md](GETTING-STARTED.md#where-config-belongs-project-vs-personal) for the full placement guide.

### "Hooks work on Mac but not Windows"

**Symptoms:** Hook scripts that work on macOS or Linux fail silently or produce errors on Windows.

**5-Point Checklist:**

1. **Bash is installed:** Hooks require bash. Install [Git for Windows](https://git-scm.com/download/win) which includes Git Bash. Verify: `bash --version`

2. **Line endings are LF:** Hook scripts must use LF (Unix) line endings, not CRLF (Windows). Check with `file hooks/*.sh` -- look for "CRLF" in the output. Fix with:
   ```bash
   git config --global core.autocrlf input
   ```
   Or add `*.sh text eol=lf` to your `.gitattributes`.

3. **Python is on PATH:** Run `python --version` or `python3 --version`. If neither works, install Python: `winget install Python.Python.3`

4. **Path format:** In `settings.json`, use `$HOME` or a forward-slash absolute path for hook commands:
   - Works: `bash "$HOME/.claude/hooks/protect-config.sh"`
   - Works: `bash "/c/Users/YourUser/.claude/hooks/protect-config.sh"`
   - Fails: `bash "~/.claude/hooks/protect-config.sh"` (a quoted `~` is a literal character -- it does not expand)
   - Fails: `bash "C:\Users\YourUser\.claude\hooks\protect-config.sh"`

5. **Tilde expansion:** A `~` inside double quotes is NOT expanded by the shell, so `bash "~/.claude/..."` fails to find the file. Use `$HOME` (expands inside double quotes) or an absolute forward-slash path: `bash "$HOME/.claude/hooks/script.sh"`

---

## Shell Compatibility

### "I use Fish / Zsh / another shell -- will hooks work?"

Hook scripts use `#!/bin/bash` and are invoked via `bash "path/to/hook.sh"` in settings.json. **Your default shell does not matter** -- Claude Code always runs hooks through bash explicitly. The hooks do not depend on your login shell, shell aliases, or shell-specific syntax.

However, if you write custom hooks that source your shell profile (`~/.bashrc`, `~/.zshrc`), those will not be loaded during hook execution. Keep hooks self-contained.

### "I cloned the repo and got the full git history"

If you `git clone` (instead of fork or cherry-pick), you get the blueprint's entire git history. This is harmless -- it just adds ~1MB to your `.git/` directory. If you want a clean start:

```bash
# Remove blueprint history, keep only files
rm -rf .git
git init
git add .
git commit -m "Initial setup from claude-code-blueprint"
```

---

## Syntax Changes

### Deprecated colon wildcard syntax

**Symptom:** Old permission entries like `Bash(npm:*)` stop matching commands.

**Fix:** Replace colons with spaces in wildcard patterns:

```
Before: "Bash(npm:*)"     -- deprecated
After:  "Bash(npm *)"     -- current syntax
```

The legacy colon syntax still works in most versions but may be removed in future releases. The space syntax is the documented standard.
