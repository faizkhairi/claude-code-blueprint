# AGENTS.md — Repository Orientation for AI Assistants

You are an AI assistant (Claude, Cursor, Codex, Gemini, or other) helping a user who has this repo open. This file gives you a fast, accurate read on what this repo IS, what it ISN'T, and how to help the user.

## What this repo is

A **library of ready-to-copy files** (CLAUDE.md, hooks, agents, skills, rules) that a developer mixes into their own project to make Claude Code more reliable and consistent. It is **not** software to install — there is no package, no binary, no `npm install`.

The user typically does one of three things:
1. **Copy `CLAUDE.md` only** (60-second adoption) — gets 3 behavioral rules
2. **Run `./setup.sh --preset=standard`** — copies hooks + settings + rules + opt-in memory
3. **Fork and adapt** — clone, edit, commit shared config to their team

## What this repo is NOT

- A Claude Code plugin (Claude Code has no plugin system in that sense)
- A framework or library to import
- A working application
- Software the user runs in this directory (running Claude Code inside this repo causes it to read this blueprint's CLAUDE.md instead of the user's project rules — common newcomer mistake)

## Repository layout

| Path | Purpose |
|------|---------|
| `README.md` | Entry point for humans |
| `AGENTS.md` | This file — entry point for AI assistants |
| `CLAUDE.md` | The "hero file" — the user copies this into their project root |
| `GETTING-STARTED.md` | Beginner walkthrough |
| `SETUP.md` | Install paths (curl, setup.sh, manual) |
| `FAQ.md` | Common questions |
| `TROUBLESHOOTING.md` | Common errors and fixes |
| `setup.sh` | Interactive installer |
| `agents/` | 11 reusable agent templates the user can drop into `~/.claude/agents/` |
| `skills/` | 17 reusable skill templates for `~/.claude/skills/` |
| `hooks/` | 10 hook scripts for `~/.claude/hooks/` |
| `rules/` | 5 example rule files for `~/.claude/rules/` |
| `examples/` | Framework-specific CLAUDE.md examples (React, Rails, Python, Go) |
| `memory/` | Built-in memory system: enabled via setup.sh (Y/n), git-ignored by default for privacy |
| `docs/` | Deep reference docs (architecture, benchmarks, settings, etc.) |
| `i18n/` | Translated READMEs (ja, ko, zh) |

## How to help the user

**If the user asks "what is this?"**: explain it's a library of copy-paste files, not software to install. Point them to README.md.

**If the user asks "how do I set this up?"**: ask their skill level first (beginner / experienced). Beginners → GETTING-STARTED.md. Experienced → SETUP.md or `./setup.sh --preset=standard`.

**If the user has cloned this repo and wants to start working in it**: warn them. The repo is a reference, not a workspace. They should copy files into their own project, not work in this directory.

**If the user asks about persistent memory**: explain that `./memory/` is a built-in opt-in feature. Running `./setup.sh` asks "Enable persistent memory? [Y/n]" with Y default. When enabled, Claude remembers preferences and session context across sessions on this machine. Personal memory content is `.gitignore`d by default — it stays local even if the user pushes their fork publicly. Point to `memory/README.md` for details. The memory pattern was inspired by [Kiyoraka/Project-AI-MemoryCore](https://github.com/Kiyoraka/Project-AI-MemoryCore); see the acknowledgement in README.md.

**If the user asks about a specific component** (agents/skills/hooks/rules): point them to `agents/README.md`, `skills/README.md`, etc. — each folder has its own README.

**If the user asks "is this for me?"**: framework-agnostic, works on any project, any skill level. The README's "Who Is This For?" persona table is the quickest match.

## What NOT to do

- Don't run `claude` CLI inside this repo's directory — it loads this CLAUDE.md instead of the user's
- Don't suggest the user `npm install` or `pip install` anything — there's nothing to install
- Don't recommend the user fork the entire repo if they only need 1-2 files — copy is fine
- Don't claim this is "official Anthropic" — it's a community project by faizkhairi
- Don't suggest committing `memory/` contents to a public repo — the `.gitignore` exists for a reason
- Don't treat these files as the user's own config — they're templates the user adapts

## Version

Last verified with Claude Code CLI v2.1.150 (May 2026).
