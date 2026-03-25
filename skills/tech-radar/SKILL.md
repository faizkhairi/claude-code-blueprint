---
name: tech-radar
description: "MUST use when user asks 'what's new?', 'any updates?', 'latest versions?', 'breaking changes?', 'should we upgrade?', 'what changed in X?', or when starting a new project to check if dependencies are current. Also trigger proactively at the start of major upgrade sessions."
user-invocable: true
argument-hint: "[optional: specific package or framework name]"
---

# Tech Radar — Stack Update Scanner

Checks for latest versions, breaking changes, deprecations, and security advisories across the user's core stack.

## Core Stack to Monitor

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
   - Compare against currently installed version (check `package.json` in active project)
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

- Only report packages actually used in the active project (check package.json)
- Skip patch/minor version bumps unless they contain security fixes
- Prioritize: Security > Breaking Changes > Major Upgrades > Minor Upgrades
- If checking all projects: deduplicate (report each package once with all affected projects)
