# Agents

11 specialized subagents with model tiering, permission modes, and worktree isolation.

## The EXCELLENT Pattern

Every agent follows this structure:
1. **Frontmatter**: name, description, model, tools, maxTurns, permissionMode, memory
2. **Role statement**: 1-2 sentences establishing expertise
3. **Context loading**: "Before starting work: read CLAUDE.md, check package.json, search patterns"
4. **Responsibilities**: Specific, numbered, actionable items
5. **Best practices**: Domain-specific guidelines
6. **Memory guidance**: "Consult before / update after"

## Model Assignment

| Agent Type | Model | Rationale |
|-----------|-------|-----------|
| Architecture/planning | opus | Needs strongest reasoning for multi-system design |
| Implementation/review | sonnet | Balanced quality for iterative code work |
| Documentation | haiku | Straightforward prose, cost-efficient |

## Permission Modes

| Mode | Agents | Why |
|------|--------|-----|
| (default) | backend, frontend, qa-tester | Need write access to implement |
| plan | verify-plan, db-analyst, devops-engineer, api-documenter | Read-only analysis — should never modify files |

## Worktree Isolation

Review agents (verify-plan, code-reviewer, security-reviewer) use `isolation: worktree` for fresh-context reviews.
