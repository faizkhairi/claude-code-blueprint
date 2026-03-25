# Cross-Tool Guide — Using These Concepts Beyond Claude Code

While this blueprint is built for Claude Code, the **principles are universal**. This guide maps each concept to its equivalent in other AI coding tools.

## Concept Mapping

| Concept | Claude Code | Cursor | Codex CLI | Gemini CLI | Windsurf |
|---------|------------|--------|-----------|------------|----------|
| **Behavioral rules** | `CLAUDE.md` | `.cursor/rules/*.mdc` | `AGENTS.md` / `codex.md` | `GEMINI.md` | `.windsurfrules` |
| **Subagents** | `.claude/agents/*.md` | Cursor agents (`.cursor/agents/`) | — | — | — |
| **Skills/commands** | `.claude/skills/*/SKILL.md` | `@commands` | Custom instructions | — | — |
| **Hooks (lifecycle)** | `settings.json` hooks | — | — | — | — |
| **Path-scoped rules** | `.claude/rules/*.md` (paths frontmatter) | `.cursor/rules/*.mdc` (globs) | — | — | — |
| **Memory persistence** | `.claude/projects/*/memory/` | — | — | — | — |
| **MCP servers** | `.claude.json` mcpServers | `mcp.json` | — | MCP support | MCP support |
| **Output styles** | `settings.json` outputStyles | — | — | — | — |
| **Permissions** | `settings.json` permissions | — | — | — | — |
| **Model selection** | Per-agent `model:` frontmatter | Model dropdown | `--model` flag | `--model` flag | Model selector |

**Legend:** "—" means the tool does not have a direct equivalent for this feature.

---

## Translating the Blueprint

### 1. Behavioral Rules (Every Tool Has This)

This is the most portable concept. Every AI coding tool reads a project-level instruction file.

**Claude Code** → `CLAUDE.md` in project root
```markdown
# Project Rules
## Verify-After-Complete (MANDATORY)
After finishing any implementation...
```

**Cursor** → `.cursor/rules/*.mdc` files with frontmatter
```markdown
---
description: Verify after completing any implementation
globs: ["**/*.ts", "**/*.tsx"]
alwaysApply: true
---
After finishing any implementation...
```

**Codex CLI** → `AGENTS.md` or `codex.md` in project root
```markdown
# Codex Instructions
After finishing any implementation...
```

**Gemini CLI** → `GEMINI.md` in project root
```markdown
# Project Rules
After finishing any implementation...
```

**What to copy:** Take the [CLAUDE.md](CLAUDE.md) template from this blueprint. Paste the rules into your tool's equivalent file. The content is tool-agnostic — only the file name changes.

---

### 2. Model Tiering (Partially Portable)

Claude Code lets you assign different models to different agents via frontmatter (`model: opus`, `model: sonnet`, `model: haiku`). This is a powerful cost optimization.

**Other tools:** Most tools let you select a model globally but not per-task. You can still apply the *principle*:
- Use the strongest model for architecture and planning tasks
- Use a balanced model for implementation
- Use the cheapest model for documentation and formatting

If your tool supports model switching mid-session, apply the tiering strategy from [ARCHITECTURE.md](ARCHITECTURE.md).

---

### 3. Hooks (Claude Code Exclusive — But the Principle Transfers)

Hooks are the most Claude Code-specific feature. No other tool currently offers lifecycle automation at this level.

**The principle still applies:** If something MUST happen, don't rely on instructions alone. Find the enforcement mechanism your tool offers:

| Goal | Claude Code | Other Tools |
|------|------------|-------------|
| Block dangerous commands | PreToolUse hook | Git hooks (`pre-push`), CI checks |
| Protect config files | PreToolUse hook | `.gitattributes` merge drivers, CODEOWNERS |
| Post-commit review | PostToolUse hook | Git hooks (`post-commit`) |
| Cost tracking | Stop hook | External CLI wrappers, API billing dashboards |
| Session state preservation | PreCompact hook | Manual save habits, external scripts |

**Key insight:** Many of the hook scripts in this blueprint (e.g., `block-git-push.sh`, `protect-config.sh`) can be repurposed as **git hooks** that work with any tool.

---

### 4. Agent-Scoped Knowledge (Partially Portable)

Claude Code agents let you create specialized subagents with their own instructions, model, and tool access. This keeps domain knowledge scoped instead of bloating the global context.

**Cursor** has a similar concept with `.cursor/rules/*.mdc` files that activate based on glob patterns — so you can scope rules to specific file types.

**Other tools:** Even without formal agent support, you can apply the principle:
- Keep your behavioral rules file lean (under 100 lines)
- Create separate instruction documents for different domains
- Reference the right document when asking the AI to work on a specific area

---

### 5. Memory System (Claude Code Native — Pattern is Portable)

The dual memory system (auto-memory + git-backed) is Claude Code specific. But the **pattern** works everywhere:

- **Any tool:** Create a git repo with `session.md`, `decisions.md`, `reminders.md`
- **Any tool:** At the start of each session, paste relevant context from your memory files
- **Any tool:** At the end of each session, update the files with what happened

The [memory-template/](memory-template/) directory provides the scaffold. The manual step is that you'll need to copy/paste context rather than having it auto-loaded.

---

### 6. Path-Scoped Rules (Claude Code + Cursor)

Path-scoped rules let you load different instructions for different parts of the codebase.

**Claude Code** uses `paths:` frontmatter in `.claude/rules/*.md` files.

**Cursor** uses `globs:` in `.cursor/rules/*.mdc` files — very similar concept.

**Other tools:** Structure your instructions with clear sections so the AI can self-select relevant rules based on the files being edited.

---

## Feature Comparison Matrix

| Feature | Claude Code | Cursor | Codex CLI | Gemini CLI | Windsurf |
|---------|:-----------:|:------:|:---------:|:----------:|:--------:|
| Behavioral rules file | Yes | Yes | Yes | Yes | Yes |
| Path-scoped rules | Yes | Yes | — | — | — |
| Custom agents/subagents | Yes | Yes | — | — | — |
| Lifecycle hooks | Yes | — | — | — | — |
| MCP server support | Yes | Yes | — | Yes | Yes |
| Auto-memory persistence | Yes | — | — | — | — |
| Model tiering per-agent | Yes | — | — | — | — |
| Permission system | Yes | — | — | — | — |
| Natural language skills | Yes | — | — | — | — |
| Worktree isolation | Yes | — | — | — | — |

---

## The Universal Takeaways

Regardless of which tool you use, these principles from the blueprint apply everywhere:

1. **Write your rules down.** Every tool has a rules file. Use it.
2. **Enforce, don't suggest.** Find your tool's enforcement mechanism (hooks, git hooks, CI) for critical rules.
3. **Scope your context.** Don't load everything into every session. Organize by domain.
4. **Verify outputs.** Never trust "done" without checking the actual result. This is tool-agnostic.
5. **Track decisions.** An append-only decision log prevents "why did we do this?" across sessions.
6. **Match model to task.** Use expensive models for hard problems, cheap models for routine work.

---

*This guide reflects the state of these tools as of early 2025. AI coding tools evolve rapidly — features listed as unavailable may be added in future releases.*
