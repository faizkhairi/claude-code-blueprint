## Description

<!-- What does this PR add or change? -->

## Component(s) Affected

- [ ] Agent(s)
- [ ] Skill(s)
- [ ] Hook(s)
- [ ] Rule(s)
- [ ] Settings template
- [ ] Memory template
- [ ] Documentation
- [ ] Assets / images

## Sanitization Checklist

<!-- MANDATORY: All PRs must pass this checklist before merge. -->

- [ ] No project-specific names (company names, internal tools, team member names)
- [ ] No internal URLs or domains
- [ ] No real credentials, API keys, or tokens
- [ ] No specific session numbers or dates that trace to a person's work
- [ ] Grep sweep passes on **your changed files** (see below)

<details>
<summary>Grep sweep command</summary>

Scan only what this PR touches, so pre-existing intentional examples do not mask a real leak:

```bash
git diff --name-only --diff-filter=d -z origin/main...HEAD \
  | grep -zv '^\.github/PULL_REQUEST_TEMPLATE\.md$' \
  | xargs -0 -r grep -inE '(internal\.example|real-project-name)' /dev/null
```

Expected result: **no output**.

Three details that matter:

- `xargs -r` stops an empty file list from running a bare `grep -r`, which would recurse the
  whole repo and report intentional examples as if they were your leak.
- This file is filtered out because it defines the search patterns and would always match itself.
- The trailing `/dev/null` keeps filenames in the output when only one file changed.

A few tracked files carry these placeholder strings on purpose (`.lycheeignore`,
`docs/SETTINGS-GUIDE.md`, `hooks/block-git-push.sh`), which is why a whole-repo sweep is not a
useful gate. If your PR genuinely needs a new placeholder domain, say so in the description.

</details>

## Testing

<!-- How did you verify this works? -->

- [ ] Tested in Claude Code locally
- [ ] NDA/personal data sweep performed
- [ ] Documentation updated (if applicable)

## Related Issues

<!-- Link related issues: Fixes #123, Relates to #456 -->
