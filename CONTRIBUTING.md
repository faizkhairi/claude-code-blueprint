# Contributing to Claude Code Blueprint

Thank you for taking the time to contribute. This blueprint is a living reference — contributions from real-world Claude Code usage make it more valuable for everyone.

## Table of Contents

- [What We Welcome](#what-we-welcome)
- [What We Don't Accept](#what-we-dont-accept)
- [How to Contribute](#how-to-contribute)
- [File Naming Conventions](#file-naming-conventions)
- [Testing Your Contribution](#testing-your-contribution)
- [PR Guidance](#pr-guidance)
- [Code of Conduct](#code-of-conduct)

---

## What We Welcome

### New Battle Stories
Additions to `WHY.md` that document a real incident — what went wrong, what was learned, and what component was built as a result. The more specific and grounded in an actual problem, the better.

### Hook Scripts
Shell scripts for `hooks/` that automate lifecycle events (PreToolUse, PostToolUse, Stop, Notification, etc.). Must be general-purpose — not tied to a specific project, company, or environment.

### Agent Templates
New `.md` files for `agents/` that define a specialized subagent role. Should include a clear `description` field (for Claude's tool selection), a well-scoped system prompt, and an appropriate model tier recommendation.

### Skill Templates
New skill directories under `skills/` with a `SKILL.md` entry point. Skills should be triggered by natural language, not slash commands, and should solve a problem that recurs across projects.

### Cross-Tool Mappings
Additions to `CROSS-TOOL-GUIDE.md` mapping a Claude Code concept to its equivalent in Cursor, Codex CLI, Gemini CLI, Windsurf, or other AI coding tools.

### Bug Fixes
Corrections to broken scripts, incorrect instructions, misleading documentation, or commands that don't work on a supported platform (macOS, Linux, Windows/WSL).

### Documentation Improvements
Clarifications, expanded explanations, better examples, or corrections to any `.md` file. Typo fixes are welcome.

---

## What We Don't Accept

- **Project-specific configurations** — `.env` files, database URLs, internal hostnames, team-specific conventions that don't generalize
- **Untested components** — Hooks, agents, or skills that haven't been run against real Claude Code sessions
- **Promotional content** — Links to paid tools, commercial products, or self-promotional material unrelated to the blueprint's purpose
- **Platform-only solutions** — Scripts that only work on one OS without a stated reason or fallback
- **Credentials of any kind** — API keys, tokens, passwords, or connection strings (even example/fake ones that could be mistaken for real)

---

## How to Contribute

### 1. Fork the repository

```bash
git clone https://github.com/your-username/claude-code-blueprint.git
cd claude-code-blueprint
```

### 2. Create a feature branch

Use a descriptive branch name:

```bash
git checkout -b add/hook-cost-limiter
git checkout -b fix/notify-hook-windows-path
git checkout -b docs/battle-story-context-bleed
```

### 3. Make your changes

Follow the naming conventions and structure outlined below.

### 4. Run the NDA sweep (required)

Before opening a PR, search your changes for anything that could be traced to a real person, company, or internal system:

```bash
# Check for internal URLs
grep -r "\.internal\." .
grep -r "localhost:[0-9]" .

# Check for company/project names that aren't the blueprint itself
# Replace YOURCOMPANY with actual names you may have accidentally included
grep -ri "YOURCOMPANY" .
```

Remove or genericize anything found.

### 5. Open a pull request

Use the PR template. Fill in all sections — especially the NDA checklist.

---

## File Naming Conventions

| Component | Convention | Example |
|-----------|-----------|---------|
| Agents | `kebab-case.md` | `agents/security-reviewer.md` |
| Hooks | `kebab-case.sh` | `hooks/cost-tracker.sh` |
| Skills | `skill-name/SKILL.md` | `skills/save-session/SKILL.md` |
| Rules | `kebab-case.md` | `rules/session-lifecycle.md` |
| Examples | `descriptive-name.json` or `.md` | `examples/settings-template.json` |

### Agent file structure

```markdown
---
name: agent-name
description: One sentence used by Claude for tool selection. Be specific about when this agent should be invoked.
model: claude-opus-4-5  # or claude-sonnet-4-5, claude-haiku-4-5
---

[System prompt content]
```

### Skill file structure

Skills live in a named directory under `skills/`:

```
skills/
  my-skill/
    SKILL.md       # Entry point — trigger phrase + instructions
    helpers.md     # Optional supporting content
```

### Hook script conventions

- Use `#!/usr/bin/env bash` as the shebang
- Exit 0 on success, non-zero to block (for PreToolUse hooks that enforce policy)
- Write errors to stderr: `echo "Error: ..." >&2`
- Include a comment block at the top explaining when the hook fires and what it does

---

## Testing Your Contribution

### Hooks

1. Wire the hook into a local `settings.json` under the appropriate event
2. Trigger the event in a real Claude Code session
3. Confirm the hook fires and produces the expected behavior
4. Test on at least one platform (macOS, Linux, or Windows/WSL)

### Agents

1. Add the agent file to `~/.claude/agents/`
2. In a Claude Code session, invoke the agent explicitly or rely on description-based selection
3. Confirm the agent behaves within its scoped role and doesn't bleed into unintended areas

### Skills

1. Place the skill directory under `~/.claude/skills/`
2. In a Claude Code session, use natural language that should trigger the skill
3. Confirm the skill executes correctly end-to-end

### NDA sweep (mandatory for all contributions)

Before submitting:
- No real company names, project names, or internal product names
- No internal hostnames or IP addresses (including `*.internal`, `*.corp`, `*.lan`)
- No real personal names in example content
- No API keys, tokens, or credentials — even placeholder-looking ones
- Example output should use `your-project`, `your-company`, `example.com`, or similar generic values

---

## PR Guidance

Use the PR template provided at `.github/PULL_REQUEST_TEMPLATE.md`. Key requirements:

- **Title**: Use a verb phrase — `Add cost-limiter hook`, `Fix notify hook on Windows`, `Document battle story: context bleed`
- **Description**: What does this change and why?
- **NDA checklist**: All items must be checked before review begins
- **Related issues**: Link any issue this resolves with `Closes #N`

PRs without a completed NDA checklist will not be reviewed until it is filled in.

---

## Code of Conduct

This project follows the [Contributor Covenant v2.1](CODE_OF_CONDUCT.md). By participating, you agree to uphold these standards.
