---
name: sprint-plan
description: "Creates a structured implementation plan by breaking multi-step features into ordered tasks with dependencies, size estimates, and risk analysis. Use when the user describes a multi-step feature to build, says 'let's build', 'new project', 'let's implement', or when a task requires more than 3 steps and no plan exists yet. Do NOT trigger for simple additions like renaming a variable or single-file changes."
user-invocable: true
argument-hint: "[feature description or issue URL]"
---

Create a sprint plan for: $ARGUMENTS

1. **Analyze the requirement**: Understand scope, constraints, dependencies
2. **Check existing code**: Search codebase for related implementations that can be reused
   - Use `Grep` to find related patterns, e.g. `Grep('pattern', type='ts')` for TypeScript projects
   - Use `Glob` to locate relevant files, e.g. `Glob('src/**/*feature*.*')`
   - Check `CLAUDE.md` for project conventions that affect the plan
3. **Break into tasks**:
   - Each task should be independently deliverable
   - Include file paths that will be modified or created
   - Estimate size: S (< 1hr), M (1-4hr), L (4-8hr), XL (> 1 day)
4. **Sequence tasks**: Identify dependencies, mark blocking tasks, find parallelizable work
5. **Identify risks**: What could go wrong? What needs clarification?
6. **Present plan and confirm**: Show the plan to the user and wait for approval before proceeding to implementation.

## Output Format

```
## Sprint Plan: [Feature Name]

### Tasks
| # | Task | Size | Depends On | Files |
|---|------|------|-----------|-------|
| 1 | ... | S | - | path/to/file |

### Risks
- [Risk description and mitigation]

### Definition of Done
- [ ] All tasks completed
- [ ] Tests written and passing
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] No security vulnerabilities introduced
```
