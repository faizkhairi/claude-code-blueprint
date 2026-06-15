# Setup Guide

Action-focused setup for the Claude Code Blueprint. For explanations and background, see [GETTING-STARTED.md](GETTING-STARTED.md). For preset details, see [PRESETS.md](docs/PRESETS.md).

---

## Quick Setup (60 seconds)

Copy one file. Three behavioral rules. No installation needed.

```bash
# In your project root
curl -o CLAUDE.md https://raw.githubusercontent.com/faizkhairi/claude-code-blueprint/main/CLAUDE.md
```

This gives Claude Code: **Verify-After-Complete**, **Diagnose-First**, **Plan-First**. That's enough to start. Add more when you're ready.

---

## Automated Setup (recommended)

Clone or fork the repo, then run the installer:

```bash
git clone https://github.com/faizkhairi/claude-code-blueprint.git
cd claude-code-blueprint
./setup.sh
```

The script will ask you to choose a preset, then install everything to `~/.claude/`.

### Presets

| Preset | Files | What You Get |
|--------|-------|--------------|
| **Minimal** | 3 | CLAUDE.md + 2 hooks (config protection, edit verification) |
| **Standard** | 10 | + 4 more hooks, 2 agents (verify-plan, code-reviewer), settings.json |
| **Core** | 20 | + 2 review agents, 6 universal skills, 2 path-scoped rules (curated, broadly useful) |
| **Full** | 45 | + all 11 agents, 17 skills, 5 rules (everything in the blueprint) |

### Usage examples

```bash
./setup.sh                          # Interactive preset selection
./setup.sh --preset=standard        # Install standard (skip menu)
./setup.sh --preset=core            # Install the curated core set
./setup.sh --preset=full --dry-run  # Preview full installation (no changes)
./setup.sh --preset=minimal --yes   # Minimal, auto-confirm all prompts
```

The script handles: directory creation, file copying with conflict detection, settings.json merge, placeholder variable replacement, and post-install verification.

**Requirements:** Bash + standard unix tools. Optional: Python 3 (for JSON merge and validation). Works on macOS, Linux, and Windows (Git Bash).

---

## AI-Assisted Setup

Let Claude Code configure itself. Paste this into a Claude Code session:

```
I want to set up the Claude Code Blueprint from this repository.
Please help me:
1. Copy the CLAUDE.md behavioral rules into my current project root (this is the only project-level file)
2. Set up hooks in my USER-LEVEL config at ~/.claude/hooks/ (NOT in the project directory)
3. Set up permissions in ~/.claude/settings.json (NOT in .claude/settings.json in the project)
Show me what you're doing at each step so I can learn.
IMPORTANT: Do NOT modify any project-level .claude/ directory. All hooks, permissions, and personal settings belong in ~/.claude/ (your home directory).
```

Claude Code will walk you through the setup interactively -- creating files, explaining what each one does, and wiring everything together.

---

## Setup Checklist

After any setup method, verify these items:

- [ ] `CLAUDE.md` exists in your project root
- [ ] `~/.claude/hooks/` contains hook scripts (`ls ~/.claude/hooks/`)
- [ ] `~/.claude/settings.json` exists and is valid JSON
- [ ] `~/.claude/agents/` contains agent definitions (Standard, Core, or Full)
- [ ] `~/.claude/skills/` contains skill directories (Core or Full)
- [ ] Placeholder variables are replaced (`grep -r './memory' ~/.claude/`)
- [ ] Hooks pass syntax check (see Verify section below)

---

## Verify Your Setup

```bash
# Check hooks are installed
ls ~/.claude/hooks/*.sh 2>/dev/null | wc -l

# Syntax check all hooks
for f in ~/.claude/hooks/*.sh; do bash -n "$f" && echo "OK: $f"; done

# Validate settings.json
python3 -m json.tool ~/.claude/settings.json > /dev/null && echo "settings.json: valid"

# Check for unreplaced placeholders
grep -r './memory\|{PROJECTS_ROOT}' ~/.claude/ 2>/dev/null || echo "No placeholders remaining"

# Run the full hook test suite (from the blueprint repo)
cd claude-code-blueprint && bash hooks/test-hooks.sh
```

---

## Where Config Goes

| File Type | Location | Why |
|-----------|----------|-----|
| CLAUDE.md | Project root | Team behavioral rules -- commit to your repo |
| Hooks, settings, agents, skills, rules | `~/.claude/` | Personal/machine-specific -- never commit |
| Memory | `~/.claude/projects/*/memory/` | Auto-generated -- never commit |

For the full config placement guide with cross-platform paths, see [GETTING-STARTED.md](GETTING-STARTED.md#where-config-belongs-project-vs-personal).

---

## Troubleshooting

**Hooks not firing?** Check that `~/.claude/settings.json` has the hooks wired under the correct event names. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#hooks-arent-firing).

**Permission denied on setup.sh?** Run `chmod +x setup.sh` or use `bash setup.sh` directly.

**Windows: line ending issues?** Run `git config --global core.autocrlf input` and re-clone. See [GETTING-STARTED.md](GETTING-STARTED.md#windows-notes).

**settings.json merge failed?** The template was saved as `settings.json.blueprint-template`. Merge hooks and permissions manually.
