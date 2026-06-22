---
name: release
description: Cut a versioned release for a GitHub project (semver bump, CHANGELOG update, tag, push, GitHub release with generated notes). Triggers on 'cut a release', 'tag a release', 'make a release', 'release version', 'draft a github release'. For npm packages, run npm-publish after (or instead).
user-invocable: true
argument-hint: "[patch|minor|major | explicit version] [repo-path]"
---

This skill ORCHESTRATES a GitHub release; it reuses the `changelog` skill for note generation. For npm packages, this handles the git/GitHub side; the `npm-publish` skill handles the registry side (run release first, then npm-publish, or use npm-publish's Step 5 which calls back here).

## Step 0: Confirm state
- This is for your own GitHub repos where you have push rights. Do not run it on a shared/work repo with a protected release process.
- `git status` clean. On the default branch (or the intended release branch). Up to date with origin.

## Step 1: Determine the new version
- From `$ARGUMENTS`: `patch|minor|major` (semver bump from current `package.json` version) or an explicit version.
- Read the current version. Compute the target. Confirm it's not already tagged (`git tag -l v<version>` empty).

## Step 2: Generate release notes
- Invoke the `changelog` skill since the last tag (`git describe --tags --abbrev=0`) to produce categorized notes (Features / Fixes / Other).
- Review the notes -- trim noise, ensure they speak to USERS of the release, not internal churn.

## Step 3: Update CHANGELOG + bump version
- If the repo has a `CHANGELOG.md`: prepend a new `## [<version>] - <date>` section with the Step-2 notes. (Date from git, not memory.)
- Bump `package.json` version (if a JS project): `npm version <version> --no-git-tag-version` (so we control the commit), OR edit the version field directly for non-JS projects.
- Commit: `git commit -am "release: v<version>"`.

## Step 4: Tag + push
- Tag: `git tag -a v<version> -m "v<version>"`.
- Push commit + tag: `git push && git push --tags`.

## Step 5: GitHub release
- `gh release create v<version> --title "v<version>" --notes "<Step-2 notes>"`.
- Verify: `gh release view v<version>` shows the release with the correct tag + notes.

## Step 6: (npm packages only) publish
- If this is an npm package, run the `npm-publish` skill now (its Step 1 checklist re-verifies build/tests/leaks before the irreversible registry publish). Do NOT publish from this skill directly -- npm-publish owns the registry side + the leak gate.

## What this skill does NOT do
- It does not publish to npm (that's `npm-publish`).
- It does not invent release notes -- they come from `changelog` over the real git range.
