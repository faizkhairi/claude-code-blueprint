# Frequently Asked Questions

These are the questions we hear most from the community. If yours isn't here, [open a Discussion](https://github.com/faizkhairi/claude-code-blueprint/discussions) or check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for technical issues.

---

## General

### "What framework or language does this work with?"

**Any.** The blueprint configures Claude Code's behavior; it doesn't touch your project's stack.

- The rules ([CLAUDE.md](CLAUDE.md)), hooks (`.sh` scripts), and agents (`.md` files) contain zero framework-specific code.
- Works with any language Claude Code supports: JavaScript/TypeScript, Python, Rust, Go, Java, C#, Ruby, PHP, Swift, and more.
- The battle stories in [WHY.md](docs/WHY.md) come from a production NestJS/Nuxt/Prisma system, but the patterns (verify your work, diagnose before fixing, plan before executing) apply universally.
- Path-scoped rules (e.g., `**/prisma/**`) activate by file pattern, not framework. Swap `prisma` for `drizzle`, `sqlalchemy`, or `migrations` by changing the glob.

---

### "I'm a junior/intermediate developer. Is this for me?"

**Yes.** The blueprint has a graduated adoption path: you don't need to understand all 11 agents on day one.

- **Level 1 (60 seconds):** Copy [CLAUDE.md](CLAUDE.md) into your project root. This single file gives Claude Code four behavioral rules that prevent the most common AI coding mistakes. No configuration, no terminal commands, no dependencies.
- **Level 2 (5 minutes):** Add 2-3 hooks for automated safety (config protection, edit verification). See [PRESETS.md](docs/PRESETS.md#minimal) for the minimal preset.
- **Level 3 (ongoing):** Add agents, skills, rules, and memory as your workflow matures. You'll know when you need them.
- The [Getting Started guide](GETTING-STARTED.md#new-to-claude-code-start-here) assumes zero prior experience and walks you through everything step by step.
- The **Diagnose-First** rule in CLAUDE.md specifically forces Claude to explain its reasoning before fixing things; that's where you learn, not just get code handed to you.

---

### "Which Claude Code plan do I need? Does this work with Pro / Max / API?"

**All plans work.** The blueprint itself is free and doesn't require any specific subscription.

- **CLAUDE.md** works on every Claude Code plan. It's just a text file Claude reads.
- **Hooks** cost zero tokens on any plan: they run outside Claude's context as shell scripts.
- **Agents** use different models (Opus, Sonnet, Haiku). Sonnet handles 90% of tasks and is available on all plans. Opus agents (like `project-architect`) benefit from Pro or Max plans.
- The total token overhead of the full blueprint is ~1-5% per session. For most sessions, it's **net token-negative** because it prevents redo cycles that waste far more tokens.
- See [BENCHMARKS.md](docs/BENCHMARKS.md#subscription-plans--the-blueprint) for a detailed plan-by-plan breakdown.

---

### "11 agents, 17 skills, 12 hooks, 6 rules: I'm overwhelmed. Where do I actually start?"

**With one file.** The blueprint is a menu, not a mandatory checklist.

- Start with [CLAUDE.md](CLAUDE.md) only: it's the single highest-impact component. Copy it into your project root. Done.
- Don't add anything else until you feel the need. You might never need all 11 agents.
- When ready, add hooks next (zero token cost, automated safety). See [PRESETS.md](docs/PRESETS.md#minimal) for the minimal 3-file setup.
- Then add agents one at a time. Start with `verify-plan` (catches plan mistakes) or `code-reviewer` (catches code mistakes).
- The [recommended adoption path](README.md#recommended-adoption-path) lays out the progression in 5 steps.
- Read [WHY.md](docs/WHY.md) to understand which components solve problems you actually have; skip the ones that don't apply.

---

## Tool Compatibility

### "Does this work with Cursor / Copilot / Codex CLI / Windsurf?"

**The concepts transfer. The implementation files are Claude Code-specific.**

- [CROSS-TOOL-GUIDE.md](docs/CROSS-TOOL-GUIDE.md) maps every blueprint concept to its equivalent in 10 other tools: Copilot, Cursor, Cline, Roo Code, OpenCode, Codex CLI, Gemini CLI, Amazon Q, Windsurf, and Aider.
- The behavioral rules philosophy (verify, diagnose, plan) works in any AI coding tool; you just express them differently.
- **Cursor users:** Dual config is supported. The Cross-Tool Guide has a dedicated "Cursor in depth" section covering `hooks.json`, `permissions.json`, `.cursorignore`, and the `cli-config` bridge.
- **Copilot users:** Copilot now has hooks (8 events, Preview), custom agents (`.agent.md`), and memory. The Cross-Tool Guide has a dedicated "Copilot in depth" section.
- **Windsurf users:** Supports behavioral rules and memory but not custom subagents. See the Cross-Tool Guide for specifics.

---

### "Can I use this alongside MCP plugins?"

**Yes.** MCP server plugins add tools, not rules; there's no conflict.

- MCP plugins (Playwright, Context7, Docker) work well alongside the blueprint because they provide capabilities, not behavioral constraints.
- Plugins that modify CLAUDE.md or inject prompts can interfere. Audit any plugin that touches hooks, session start, or behavioral rules.
- See the [Plugin Compatibility](README.md) section in the README for specific guidance.

---

## Getting Started

### "A colleague sent me this link. What do I do first?"

Welcome. Here's your fastest path:

1. **Right now (60 seconds):** Open [CLAUDE.md](CLAUDE.md) in this repo. Click "Raw" (top-right), copy everything, and paste it into a new file called `CLAUDE.md` in your project's root folder.
2. **Start using Claude Code normally.** No special prompts needed. Claude automatically reads your CLAUDE.md and follows the four rules inside it (Verify-After-Complete, Diagnose-First, Plan-First, Verify-Before-Exit-Plan).
3. **When ready for hooks and agents:** Run `./setup.sh --preset=standard` from a cloned copy, or [let Claude set it up for you](GETTING-STARTED.md#let-claude-code-set-up-for-you) interactively. See [SETUP.md](SETUP.md) for all options.
4. **When curious:** Read the [beginner guide](GETTING-STARTED.md#new-to-claude-code-start-here) to understand what Claude Code is and how to access it (Desktop app, VS Code extension, CLI, or web).
5. **If something breaks:** Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

No installation required. No dependencies. No package manager. Just one markdown file to start.

---

### "Will AI replace the need to learn coding?"

**No.** This blueprint makes AI coding assistants more predictable and safe; not a substitute for understanding.

- The **Diagnose-First** rule forces Claude to investigate errors before jumping to fixes. You see the diagnosis process, not just the result.
- The **Plan-First** rule makes Claude explain its approach before writing code. You review and approve the plan, which builds your understanding of the architecture.
- The battle stories in [WHY.md](docs/WHY.md) teach you what goes wrong in real software projects; these are learning opportunities, not black boxes.
- The "Learning to code" persona is explicitly supported in the [adoption table](README.md#who-is-this-for). The recommendation is to start with CLAUDE.md and GETTING-STARTED.md only, ignoring agents/skills/memory until you're comfortable.
- AI helps you move faster, but understanding what you're building and why is still your responsibility.

---

## Cost and Token Usage

### "Will this slow down my sessions or cost more?"

**No measurable slowdown. Marginal token cost that pays for itself.**

- **Hooks are free.** All 12 hooks run as shell scripts outside Claude's context: zero tokens consumed.
- **CLAUDE.md adds ~2,300 tokens per session**, roughly 1-5% overhead. That's less than a single medium-sized source file.
- **Net impact is token-negative** for sessions longer than a few turns. One prevented redo cycle (fixing a mistake Claude made because it didn't verify) saves 5,000-20,000 tokens, far more than the blueprint costs.
- **Agents use model tiering** to control costs: Opus for complex planning (rare), Sonnet for most work, Haiku for docs (cheapest). Average cost multiplier is ~1.1x baseline.
- See [BENCHMARKS.md](docs/BENCHMARKS.md#token-cost-per-component) for the full cost-per-component breakdown and [GETTING-STARTED.md](GETTING-STARTED.md#will-this-affect-my-token-usage) for the beginner-friendly cost FAQ.

---

## Still Have Questions?

- **Technical issues:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Full beginner guide:** [GETTING-STARTED.md](GETTING-STARTED.md)
- **Cost and performance data:** [BENCHMARKS.md](docs/BENCHMARKS.md)
- **Using other AI tools:** [CROSS-TOOL-GUIDE.md](docs/CROSS-TOOL-GUIDE.md)
- **Community discussion:** [GitHub Discussions](https://github.com/faizkhairi/claude-code-blueprint/discussions)
