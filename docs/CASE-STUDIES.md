# Case Studies

Real-world adopter stories: before/after metrics, workflow changes, lessons learned, written by the people who actually used the blueprint in their projects.

---

## No Case Studies Submitted Yet: Be the First

This file ships empty intentionally. We don't fabricate case studies, and we don't list ourselves as the canonical example (we'd be marking our own homework).

If you've adopted the blueprint and have something to share, we'd love a PR. The bar is low: half a story honestly told beats a marketing-style post.

---

## How to Submit

1. **Fork** [the repo](https://github.com/faizkhairi/claude-code-blueprint) and create a branch.
2. **Add a new H2 section** below this one using the template below.
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
