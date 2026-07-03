---
name: tech-radar
description: "MUST use when user asks 'what's new?', 'any updates?', 'latest versions?', 'breaking changes?', 'should we upgrade?', 'what changed in X?', or when starting a new project. Detects dependencies dynamically from `package.json` / `requirements.txt` / `go.mod` / `composer.json` first, then reports per-package: latest version (vs. installed), breaking changes since installed version, security advisories (CRITICAL/HIGH), and deprecation warnings. Falls back to a generic stack table only when no manifest file is found."
user-invocable: true
argument-hint: "[optional: specific package or framework name]"
---

# Tech Radar: Stack Update Scanner

Checks for latest versions, breaking changes, deprecations, and security advisories across the user's core stack.

## Core Stack to Monitor

> **Example only, replace with your own stack.** The table below reflects one project's dependencies (a JS/TS stack). The skill detects your actual dependencies from the project manifest at runtime (`package.json`, `requirements.txt`, `go.mod`, `composer.json`, etc., see the description); this table is just a fallback of well-known packages to watch.

| Category | Packages |
|----------|----------|
| **Frontend** | nuxt, vue, next, react, tailwindcss, formkit, pinia |
| **Backend** | @nestjs/core, express, fastify |
| **Database** | prisma, @prisma/client, knex, better-auth |
| **Testing** | vitest, @vue/test-utils, @testing-library/react |
| **Mobile** | expo, react-native, nativewind |
| **AI** | ai (vercel ai-sdk), @ai-sdk/openai, @ai-sdk/anthropic |
| **CLI** | commander, chalk, ora, inquirer |
| **Build** | typescript, tsup, turbo, vite |
| **Cloud** | @aws-sdk/client-s3, @aws-sdk/client-ec2 |

## Execution Steps

1. **Parse arguments**: If user specified a package/framework, focus on that. Otherwise scan full stack.

2. **Check latest versions** using WebSearch:
   - Search: `"{package} latest version {current_year}"`
   - Compare against currently installed version (check the project manifest: `package.json`, `requirements.txt`, `go.mod`, `composer.json`, etc.)
   - Flag major version bumps (potential breaking changes)

3. **Check for breaking changes**:
   - For major version bumps: search `"{package} v{new_major} migration guide"`
   - Summarize key breaking changes that affect our patterns
   - Cross-reference against known patterns in MEMORY.md

4. **Check security advisories**:
   - Search: `"{package} CVE {current_year}"` or `"{package} security advisory"`
   - Flag any HIGH or CRITICAL severity issues

5. **Check deprecations**:
   - Search: `"{package} deprecated features {current_year}"`
   - Note any APIs we currently use that are deprecated

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

- Only report packages actually used in the active project (check the project manifest)
- Skip patch/minor version bumps unless they contain security fixes
- Prioritize: Security > Breaking Changes > Major Upgrades > Minor Upgrades
- If checking all projects: deduplicate (report each package once with all affected projects)
