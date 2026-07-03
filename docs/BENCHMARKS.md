# Benchmarks

Real-world performance data from production use of this blueprint. Results vary by workflow, project size, and usage patterns.

> **Disclaimer:** These numbers come from one developer's workflow across multiple projects. Your results will differ based on your stack, session length, and usage patterns. Use these as directional guidance, not guarantees.

---

## Token Efficiency

| Metric | Without Blueprint | With Blueprint | Improvement |
|--------|------------------|----------------|-------------|
| Playwright browser automation | ~114K tokens/task (MCP) | ~27K tokens/task (CLI) | **-76%** |
| Context preservation across compaction | Lost (no hooks) | Serialized to disk (PreCompact hook) | Prevents re-reading files |
| Redundant permission prompts | ~10-20 per session | 0 (allow list + auto mode) | Eliminates prompt fatigue |
| Agent context isolation | Shared (polluted) | Worktree isolation (fresh context) | Cleaner reviews |

### Playwright MCP vs CLI Detail

The Playwright MCP server streams full DOM accessibility trees into the context window on every interaction. After 15 browser actions, you're carrying 60-80K tokens of accumulated DOM state.

Running `npx playwright test` via the Bash tool saves results to disk. The model reads only the summary/failures, not the full DOM. This architectural difference produces the 76% token reduction.

**Recommendation:** Use MCP for interactive browser exploration. Use CLI (`npx playwright test`) for test execution.

---

## Token Cost Per Component

Verified measurements from actual blueprint files (March 2026). Token estimates use ~4 characters per token.

| Component | File Size | Token Cost | When Loaded | Frequency |
|-----------|-----------|-----------|-------------|-----------|
| **CLAUDE.md** | 9.3 KB | ~2,300 tokens | Every session start | Once per session |
| **rules/testing.md** | 5.8 KB | ~1,450 tokens | Editing test files only | 0-1 per session |
| **rules/database-schema.md** | 4.4 KB | ~1,100 tokens | Editing schema files only | 0-1 per session |
| **rules/api-endpoints.md** | 3.4 KB | ~850 tokens | Editing API route files only | 0-1 per session |
| **rules/session-lifecycle.md** | 2.8 KB | ~700 tokens | Always active | Once per session |
| **rules/memory-session.md** | 0.7 KB | ~185 tokens | Editing memory files only | Rare |
| **skills/review-full** | 4.3 KB | ~1,070 tokens | When you ask for a review | 0-1 per session |
| **skills/deploy-check** | 1.9 KB | ~480 tokens | When you mention deploying | 0-1 per session |
| **skills/test-check** | 1.9 KB | ~480 tokens | When you mention testing | 0-1 per session |
| **Hooks (all, zero-token)** | N/A | **Zero** | Run as external processes | Every relevant event |
| **Agents (per spawn)** | Varies | Full context window | Only when invoked | 0-3 per session |

> **Key insight:** Hooks are the blueprint's primary enforcement mechanism AND they cost zero tokens. This is by design: enforcement that costs nothing means you never have to choose between safety and budget.

### Typical Session Overhead

| Session Type | Blueprint Tokens Used | Breakdown | % of Typical Session |
|-------------|----------------------|-----------|---------------------|
| Quick fix (5-10 turns) | ~2,300 | CLAUDE.md only | ~3-5% |
| Feature build (20-50 turns) | ~3,500-4,500 | CLAUDE.md + 1 rule + 1 skill | ~2-4% |
| Complex refactor (50+ turns) | ~5,000-8,000 | CLAUDE.md + 2 rules + 1 skill + 1 agent | ~2-5% |

### Where It Saves Tokens

| Prevention | Tokens Saved | How |
|-----------|-------------|-----|
| One prevented redo cycle | 5,000-20,000 | Plan-First catches wrong approaches before implementation |
| One prevented "done but broken" loop | 3,000-8,000 | Verify-After-Complete catches false positives |
| One prevented "wrong diagnosis" investigation | 2,000-5,000 | Diagnose-First checks git state before investigating |
| Path-scoped rules vs global | ~2,000-4,000/session | Only loads database rules when editing schema, not in every session |

**Net token impact:** The blueprint is **token-negative** for any session longer than a few turns: it saves more tokens than it costs. The ~2,300-token upfront cost of CLAUDE.md pays for itself the first time it prevents a single redo cycle.

---

## Subscription Plans & The Blueprint

Different billing models mean different optimization strategies.

### Subscription Users (Pro, Max, Team, Enterprise)

Subscription plans measure usage in messages/interactions rather than raw tokens. The blueprint's impact on your usage quota is minimal because:

1. **CLAUDE.md loads once per session**: it's a fixed cost, not per-message
2. **Hooks consume zero usage**: they run outside Claude's context entirely
3. **Rules and skills load on-demand**: only when relevant, not every message
4. **The biggest usage consumers are agents**: each spawn is like starting a mini-session

| Plan Tier | Blueprint Impact | Recommended Preset | Why |
|-----------|-----------------|-------------------|-----|
| **Lower-tier subscription** | Minimal | **Minimal** (CLAUDE.md + hooks) | Hooks are free. CLAUDE.md is the highest-impact, lowest-cost component. |
| **Higher-tier subscription** | Negligible | **Standard or Full** | You have headroom. Use agents, skills, memory: the works. |
| **Team / Enterprise** | Negligible | **Full** | Budget for quality. The blueprint's redo prevention saves developer time. |

**Optimization tips for subscription users:**
1. Start with CLAUDE.md + hooks (zero to minimal usage impact)
2. Add `verify-plan` agent first, since it prevents the most expensive mistakes
3. Use path-scoped rules instead of putting everything in CLAUDE.md: rules only load when editing matching files
4. The Stop hook (security review on every response) uses the most usage of any single component. Disable it if you're on a tight quota, keep it if security matters

### API Billing Users

You pay per token, so exact costs matter. Based on [current pricing](https://docs.anthropic.com/en/docs/about-claude/pricing):

| Blueprint Component | Per-Session Cost (Sonnet) | Per-Session Cost (Opus) |
|--------------------|--------------------------|------------------------|
| CLAUDE.md (input) | ~2,300 x $3/MTok = **$0.007** | ~2,300 x $15/MTok = **$0.035** |
| 1 rule (input) | ~1,000 x $3/MTok = **$0.003** | ~1,000 x $15/MTok = **$0.015** |
| 1 skill (input) | ~700 x $3/MTok = **$0.002** | ~700 x $15/MTok = **$0.011** |
| **Typical session overhead** | **~$0.01-0.02** | **~$0.05-0.06** |

For API users, the blueprint adds roughly 1-6 cents per session in context loading costs (Sonnet at the low end, Opus at the high end). A single prevented redo cycle saves 10-60 cents. The ROI is immediate.

**API optimization tips:**
1. Model tiering is your biggest lever: Haiku for docs ($0.80/$4 MTok) vs Opus for everything ($15/$75 MTok) saves 80%
2. Path-scoped rules prevent loading unnecessary context
3. The Playwright CLI-over-MCP pattern saves 76% tokens on browser automation
4. Use `cost-tracker.sh` to monitor per-session costs in `~/.claude/metrics/costs.jsonl`

### Upgrading from Pro to Max

**What you keep: everything.** All Claude Code configuration is stored locally on your machine: `~/.claude/`, CLAUDE.md, settings.json, hooks, agents, skills, rules, auto-memory. None of this is tied to your subscription tier. Upgrading changes nothing about your existing setup.

What survives an upgrade:
- CLAUDE.md files in all your projects
- `~/.claude/settings.json` (hooks, permissions, env vars)
- `~/.claude/hooks/`, `~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/rules/`
- Auto-memory (`~/.claude/projects/*/memory/`)
- External memory repo (git-backed)
- MCP server configurations

**What to do after upgrading** (nothing is required, but now you CAN expand):

1. **Move from Minimal to Standard preset**: add `verify-plan` and `code-reviewer` agents (see [PRESETS.md](PRESETS.md#standard))
2. **Enable the Stop hook**: Sonnet security review on every response (was potentially too usage-heavy on a lower tier)
3. **Add more agents**: `security-reviewer`, `db-analyst`, `frontend-specialist` as your workflow demands
4. **Use Opus for architecture**: set `project-architect` agent to Opus model for complex system design
5. **Move from Standard to Full preset**: add all skills, rules, and memory system

Think of upgrading as removing a speed limit, not changing the car. Your entire setup carries over; you just get more road.

### The Pro User's Blueprint Journey

A gradual adoption timeline for budget-conscious users:

| When | What to Add | Usage Impact | Preset Level |
|------|------------|-------------|--------------|
| **Day 1** | CLAUDE.md only | ~2,300 tokens/session | Below Minimal |
| **Week 1** | Add hooks (protect-config, notify-file-changed, cost-tracker) | Zero additional | **Minimal** |
| **Week 2** | Add `block-git-push` and `session-checkpoint` hooks | Zero additional | Minimal+ |
| **Month 1** | Add `verify-plan` agent | ~1 agent spawn/session | Moving toward Standard |
| **Month 2** | Add `code-reviewer` agent + `review-full` skill | ~1-2 spawns/session | **Standard** |
| **Month 3+** | Evaluate: am I hitting usage limits? | N/A | Decision point |

**At the decision point:**
- **Not hitting limits?** Stay on your current plan. The Standard preset works fine within most subscription quotas for solo developers.
- **Hitting limits regularly?** Two options:
  - Optimize first: disable the Stop hook, reduce agent spawns, use Haiku where possible
  - Upgrade: unlocks Full preset with all agents, skills, and memory system

**Signs you're ready for a higher tier:**
- You're spawning 3+ agents per session regularly
- You want parallel review agents (code-reviewer + security-reviewer simultaneously)
- You need the full memory system for cross-session continuity
- The Stop hook's security review is catching real issues and you don't want to disable it
- Your sessions regularly exceed 50+ turns

The blueprint is designed to scale with you. Start small, add components as you feel the need, and upgrade your plan only when the tools themselves demand more headroom.

*Subscription plan details and pricing change over time. Visit [claude.com/pricing](https://docs.anthropic.com/en/docs/about-claude/pricing) for current plans, pricing, and usage limits.*

---

## Cost

Based on [Anthropic's pricing](https://docs.anthropic.com/en/docs/about-claude/pricing) as of March 2026.

| Usage Pattern | Estimated Daily Cost | Notes |
|--------------|---------------------|-------|
| Light (5-10 responses, no agents) | ~$1-3 | CLAUDE.md + hooks only |
| Standard (20-50 responses, occasional agents) | ~$5-8 | Standard preset |
| Heavy (100+ responses, parallel agents) | ~$10-15 | Full preset with review-full skill |
| Stop hook overhead | ~$1-2/day additional | Sonnet security review on every response |

### Model Tiering Impact

| Configuration | Relative Cost | Description |
|--------------|---------------|-------------|
| All Opus agents | 5x baseline | Every agent uses the most expensive model |
| All Sonnet agents | 1x baseline | Standard pricing |
| Blueprint tiering (1 Opus + 9 Sonnet + 2 Haiku) | ~1.1x baseline | Minimal premium for architecture quality |

The blueprint's model tiering keeps costs close to all-Sonnet pricing while reserving Opus reasoning for architecture decisions (project-architect agent only).

---

## Quality

| Metric | Without Blueprint | With Blueprint | Enforcement |
|--------|------------------|----------------|-------------|
| Config accidentally weakened | Risk on every edit | **Blocked** | `protect-config.sh` (PreToolUse hook) |
| Accidental push to wrong remote | Risk on every push | **Blocked** | `block-git-push.sh` (PreToolUse hook) |
| Post-edit verification forgotten | Common | **Automatic reminder** | `notify-file-changed.sh` (PostToolUse hook) |
| Post-commit review skipped | Common | **Automatic reminder** | `post-commit-review.sh` (PostToolUse hook) |
| Plan verification thoroughness | Self-review only (~80%) | **7-point mechanical check** (100%) | `verify-plan` agent |
| Security review on every response | None | **Automatic** (SQL injection, XSS, secrets) | Stop hook (Sonnet model) |
| Session context lost on crash | Lost completely | **Serialized to disk** | PreCompact + SessionEnd hooks |
| Cost tracking | Unknown spending | **JSONL metrics per session** | `cost-tracker.sh` |

### Hook Compliance: deterministic vs best-effort

CLAUDE.md instructions are followed most of the time, but not always: the model occasionally forgets or deprioritizes a rule. Hooks execute deterministically on every matching event, with no exceptions. This is why enforcement belongs in hooks, and guidance belongs in CLAUDE.md.

---

## How to Measure Your Own

1. **Token usage:** Check your Anthropic dashboard or use the `cost-tracker.sh` hook data at `~/.claude/metrics/costs.jsonl`
2. **Hook blocks:** Add logging to `block-git-push.sh` and `protect-config.sh` to count how often they prevent mistakes
3. **Session cost:** Compare daily Anthropic bills before and after adopting the blueprint (give it a week for meaningful data)
4. **Quality:** Track how many bugs are caught by the Stop hook's security review vs found later in production

---

## Contributing Your Data

If you've measured your own before/after numbers, we'd love to include them. Open a [Discussion](../../discussions) or submit a PR with your data point. Anonymous data is fine; we care about the numbers, not the project name.
