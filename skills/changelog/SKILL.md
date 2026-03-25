---
name: changelog
description: Generate a changelog from git history since a tag, date, or commit
user-invocable: true
argument-hint: "[since: tag, date, or commit] [repo-path]"
---

Generate changelog from $ARGUMENTS:

1. **Parse arguments**: Extract the starting point (tag, date, or commit hash) and optional repo path (default: current directory)
2. **Read git log**: Run `git log --oneline --no-merges` since the specified point
3. **Categorize commits** by conventional commit prefixes:
   - **Features** (feat:, add:, new:)
   - **Bug Fixes** (fix:, bugfix:)
   - **Documentation** (docs:)
   - **Performance** (perf:)
   - **Refactoring** (refactor:)
   - **Other** (chore:, ci:, test:, style:, build:)
4. **If no conventional commits found**: Analyze commit messages and categorize by intent
5. **Format output**:

## [version/date range]

### Features
- Description (commit-hash)

### Bug Fixes
- Description (commit-hash)

### Other Changes
- Description (commit-hash)
