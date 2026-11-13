# Case Studies

Real-world adopter stories: before/after metrics, workflow changes, lessons learned, written by the people who actually used the blueprint in their projects.

---

## About This File

We don't fabricate case studies. The one entry so far is the maintainer's own setup, clearly labelled as such. It shows the blueprint in daily use, but it is not independent evidence: we'd be marking our own homework. Stories from other adopters are what this file is really for.

If you've adopted the blueprint and have something to share, we'd love a PR. The bar is low: half a story honestly told beats a marketing-style post.

---

## Maintainer's own setup: one tech lead, daily use across work and open-source repos

> Disclosure: this is the maintainer's own setup, not an independent adopter. Read it as a worked example of the blueprint in daily use, not as third-party evidence that it works. Numbers were measured on 2026-11-13.

**Context**
- Team size: one developer running the setup, working inside a team of several developers who review each other's pull requests
- Project type: multi-repo web platform work at a day job (backend services, a frontend, integrations), plus personal open-source repos
- Stack: TypeScript (NestJS, Nuxt, Next.js), Prisma with MySQL, Bash hooks, GitHub and a self-hosted Git server
- Adoption date: the blueprint repo started in 2026-03; the private config it was extracted from is older and keeps evolving alongside it

**Which blueprint components you adopted**
- All of them, since the blueprint is extracted from this config. The private config is larger than the public one: 19 agents, 35 skills and 36 hook scripts, against the blueprint's 12 agents, 20 skills and 18 hooks.
- The extra pieces are project-specific (internal deploy targets, ticket workflows, database access rules), which is why they stay private.

**What you changed from the original**
- Guard hooks are stricter than the blueprint's: production database writes, cloud mutations and pushes to protected branches are denied or need an explicit per-command approval.
- A file-based memory (880 small markdown files plus an index) instead of the blueprint's starter memory layout.

**Before / After**
- No controlled before/after numbers. What can be measured is how much of the setup is under test: 50 hook test suites. Twelve of the guard-hook suites alone run 1,828 assertions.
- 295 session transcripts sit in the 90-day search window, so "what did we decide last time" is a search, not a guess.
- The felt difference: fewer "done" claims that turn out to be untested, because the rules and the Stop hook ask for evidence before a task is closed.

**What worked well**
- Plan first, then a cold review by a subagent that sees only the plan. It regularly catches gaps the author could not see, such as a check that would have failed forever because two tables formatted one cell differently.
- Treating every subagent report and review finding as a hypothesis to verify, not a conclusion.
- Hooks for the rules that must never be skipped. A hook fires every time; a sentence in CLAUDE.md is advice the model can deprioritize.

**What didn't work, or what you'd do differently**
- A hook that asks for confirmation hangs a background subagent forever, because nobody can answer the prompt. The fix was to turn "ask" into "deny" with a reason whenever the call comes from a subagent. Design guard hooks with subagents in mind from the start.
- Audits that only searched the target repo missed references in the config's own skills and memory. Changing a shared name once left 12 stale references behind. The consumer audit now always includes the config itself.
- Cleaning up test data is not an undo. Soft-deleting one test record on a shared dev environment once blocked every new registration, because "latest row" logic still saw the deleted row. Re-run the create path after any cleanup.

**Links (optional)**
- The blueprint itself: [faizkhairi/claude-code-blueprint](https://github.com/faizkhairi/claude-code-blueprint)

---

## How to Submit

1. **Fork** [the repo](https://github.com/faizkhairi/claude-code-blueprint) and create a branch.
2. **Add a new H2 section** after the existing entries, using the template below.
3. **Open a PR** with the title `case-study: [your project's one-line name]`.

For less formal sharing, post in [Discussions > Show & Tell](https://github.com/faizkhairi/claude-code-blueprint/discussions/categories/show-and-tell) first. We can later promote a Discussion into a case-study PR with your permission.

---

## Submission Template

Copy this and fill it in. Skip any field that doesn't apply.

```markdown
## [Project / Team name]: [One-line summary]

**Context**
- Team size: [solo / 2-5 / 5-15 / 15+]
- Project type: [SaaS, internal tool, agency client, OSS, research, etc.]
- Stack: [whatever's relevant, since Claude Code's value is mostly stack-agnostic]
- Adoption date: [YYYY-MM or "rolling over N weeks"]

**Which blueprint components you adopted**
- [List the agents, skills, hooks, rules you actually use. It's OK if it's a small subset.]
- [Mention which ones you tried and dropped, if any.]

**What you changed from the original**
- [The whole point is fork-and-adapt. Share what you customized and why.]
- [E.g., replaced the example database-schema rule with your team's actual conventions.]

**Before / After**
- [Concrete observations beat vague claims. Examples:]
  - "We used to redo about 2 in 10 Claude tasks because verification was missing. After adding the Verify-After-Complete rule, that dropped to roughly 1 in 30."
  - "Session-start hook saved us ~5 minutes per dev per day on context-loading."
  - "Cost: per-session tokens up by ~5% (CLAUDE.md is ~2,300 tokens), but we save more by avoiding rework."
- [Don't have hard numbers? Describe the felt difference. That's still useful.]

**What worked well**
- [Specific patterns or components that earned their keep.]

**What didn't work, or what you'd do differently**
- [Equally valuable. Failed experiments help others.]

**Links (optional)**
- [Public branch, blog post, talk recording, or "happy to chat at @handle"]
```

---

## What We Hope to See

Honest, specific stories. Not endorsements. Not marketing. The blueprint exists because someone learned hard lessons in production; case studies pay that forward.

Anonymized adopters are welcome; you don't have to name your employer. Just say enough about the shape of the team and the work that readers can decide whether your context resembles theirs.
