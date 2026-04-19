---
name: tech-radar
description: "Scans project dependencies for available upgrades, breaking changes, security advisories (CVEs), and deprecations by reading package.json and searching release notes. Produces a prioritised upgrade report. Use when the user asks 'what's new?', 'any updates?', 'latest versions?', 'breaking changes?', 'should we upgrade?', 'what changed in X?', or at the start of a new project or major upgrade session."
user-invocable: true
argument-hint: "[optional: specific package or framework name]"
---

# Tech Radar — Stack Update Scanner

Scans project dependencies for latest versions, breaking changes, deprecations, and security advisories. Reads `package.json` to detect the actual stack — no hardcoded package list.

## Execution Steps

1. **Detect stack**: Read `package.json` (or `package.json` files in monorepo workspaces). Build a list of dependencies and their installed versions. If `$ARGUMENTS` names a specific package, focus on that one only.

2. **Check latest versions** using WebSearch:
   - Search: `"{package} latest version {current_year}"`
   - Compare against installed version
   - Flag major version bumps (potential breaking changes)
   - If search returns no results or stale data, fall back to `npm view {package} version` or the package's GitHub releases page.

3. **Check for breaking changes** (major bumps only):
   - Search: `"{package} v{new_major} migration guide"`
   - Summarize key breaking changes that affect patterns in the current project
   - Cross-reference against known patterns in MEMORY.md

4. **Check security advisories**:
   - Search: `"{package} CVE {current_year}"` or `"{package} security advisory"`
   - Flag any HIGH or CRITICAL severity issues

5. **Check deprecations**:
   - Search: `"{package} deprecated features {current_year}"`
   - Note any APIs the project currently uses that are deprecated

6. **Validate findings**: Cross-check at least one version number against `npm view {package} version` to confirm search results are current.

## Output Format

```
## Tech Radar Report — {date}

### Upgrades Available
| Package | Current | Latest | Breaking? | Priority |
|---------|---------|--------|-----------|----------|
| nuxt    | 4.0.0   | 4.1.0  | No        | Low      |
| prisma  | 6.2.0   | 7.0.0  | YES       | High     |

### Breaking Changes (Action Required)
- **prisma 7.0**: No `url` in datasource block, driver adapter required [details]

### Security Advisories
- (none found / list any CVEs)

### Deprecation Warnings
- (none / list deprecated APIs we use)

### Recommendation
[1-2 sentences: upgrade now / wait / specific actions needed]
```

## Smart Filtering

- Only report packages actually used in the active project (from package.json)
- Skip patch/minor version bumps unless they contain security fixes
- Prioritize: Security > Breaking Changes > Major Upgrades > Minor Upgrades
- If checking all projects: deduplicate (report each package once with all affected projects)
