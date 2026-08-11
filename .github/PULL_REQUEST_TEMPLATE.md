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
  | xargs -0 -r grep -inE '(internal\.example|real-project-name)' /dev/null
```

Expected result: **no output**.

The `-r` on `xargs` matters: without it, an empty file list still runs `grep -r`, which then
recurses the whole repo and reports the intentional examples below as if they were your leak.
The trailing `/dev/null` keeps filenames in the output when only one file changed.

If a placeholder like `internal.example.com` is genuinely required in a file you added (a
documented example domain, not a real one), say so in the PR description. Four files already
carry these strings deliberately, so a whole-repo `grep -riE ... .` returns hits by design and
is not a useful gate: `.github/PULL_REQUEST_TEMPLATE.md` (this file), `.lycheeignore`,
`docs/SETTINGS-GUIDE.md`, and `hooks/block-git-push.sh`.

</details>

## Testing

<!-- How did you verify this works? -->

- [ ] Tested in Claude Code locally
- [ ] NDA/personal data sweep performed
- [ ] Documentation updated (if applicable)

## Related Issues

<!-- Link related issues: Fixes #123, Relates to #456 -->
