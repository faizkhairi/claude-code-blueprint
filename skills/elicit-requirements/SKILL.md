---
name: elicit-requirements
description: "Gathers pre-feature requirements through structured questions, producing a scoped summary with acceptance criteria, technical constraints, dependencies, and out-of-scope items. Use when the user says 'spec out', 'plan a feature', 'define requirements', 'new endpoint', 'before I start coding', or before writing any new feature or API endpoint."
user-invocable: true
argument-hint: "[feature or integration name]"
---

# Elicit Requirements — Structured Pre-Feature Clarification

Run this before writing any new feature to avoid scope creep, missed edge cases, and
mid-implementation discoveries that force rewrites.

## Elicitation Workflow

Work through these sections with the user. Ask grouped questions — do not ask one at a time.

---

### 1. Problem Statement

Ask:
- What problem are we solving, and for whom?
- What triggers this feature? (user action, external system push, scheduled job, webhook)
- What is the expected outcome when it works correctly?
- What is the expected behaviour when it fails?

---

### 2. User Roles and Stakeholders

Ask:
- Which user roles interact with this directly? (admin, developer, end user, external system)
- Which roles are indirectly affected? (e.g., reports they see change, notifications they receive)
- For integration features: which external system is involved? (identify from project context or ask)

---

### 3. Technical Constraints

For integration or API features, always clarify:

| Constraint | Questions |
|---|---|
| System | Which external system? |
| Direction | INBOUND (system pushes to us) or OUTBOUND (we push to system)? |
| Trigger | API call, webhook, scheduled job, file arrival? |
| Data format | JSON? XML? CSV? Other? |
| Auth | JWT? API key? mTLS? None (internal only)? |
| Error handling | Retry? Dead-letter queue? Alert? Silent fail? |
| Idempotency | Must duplicate calls be safe? |

---

### 4. Acceptance Criteria

For each piece of functionality, define:
- What HTTP endpoint (method + path) if applicable
- What the success response looks like (status code, key fields)
- What DB rows are created/updated and with which values
- What external calls are made (APIs, storage, queues)
- What happens on error (validation fail, external system down, duplicate)

Acceptance criteria must be **verifiable without human judgement**. If it says "looks good" or "works correctly" it is not an acceptance criterion.

Good: `POST /api/v1/orders returns 202 with { "jobId": "<uuid>" } and creates job row with status='PENDING'`

Bad: "The endpoint should handle the data correctly"

---

### 5. Out of Scope

Explicitly list what is NOT included in this feature to prevent scope creep:
- Which related endpoints are deferred?
- Which error scenarios are explicitly not handled yet?
- Which UI/dashboard elements are not part of this backend feature?

---

### 6. Dependencies and Ordering

- Does this feature depend on another feature being complete first?
- Does another feature depend on this being complete?
- What environment is needed to test? (running dev server, specific DB records, external system mock?)

---

## Output

After elicitation, produce a structured summary:

```markdown
## Requirements Summary: [Feature Name]

### Problem
[1-2 sentences]

### Scope
- System: [external system if applicable]
- Direction: [inbound/outbound]
- Trigger: [how it starts]

### Stories (ordered by dependency)
1. [Story 1 title] — [one-line description]
2. [Story 2 title] — [one-line description]

### Acceptance Criteria (per story)
**Story 1:**
- ...

### Out of Scope
- ...

### Open Questions
- ...
```

Present the summary to the user and confirm all sections are accurate before saving. If the user identifies gaps, return to the relevant section and re-elicit.

Then save the requirements to a structured markdown file the user can reference during implementation.
