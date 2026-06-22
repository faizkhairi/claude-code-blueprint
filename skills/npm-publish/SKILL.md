---
name: npm-publish
description: Publish an npm package end-to-end (pre-publish checklist, version bump, passkey/web-auth or token publish, post-publish verify, GitHub release). Triggers on 'publish to npm', 'npm publish', 'release the package', 'ship the npm package', 'cut an npm release'.
user-invocable: true
argument-hint: "[patch|minor|major | explicit version] [package-dir]"
paths:
  - "**/package.json"
---

Publishes a public npm package safely. A publish is irreversible (you can `npm unpublish` only within 72h, and it burns that version forever), so the checklist gates hard before the registry call.

## Step 0: Confirm target
- Confirm cwd (or `[package-dir]`) has a `package.json` and is a package you intend to publish publicly. Do not run this on a private/work package.

## Step 1: Pre-publish checklist (ALL must pass before publishing)
1. **Clean tree**: `git status` is clean (or only intended release changes staged).
2. **Build passes**: run the project's build (`npm run build` / `pnpm build`) -- must succeed.
3. **Tests pass**: run the project's test command -- must be green. (No publishing on red.)
4. **Secret + leak scan** (CRITICAL -- this is a PUBLIC publish):
   - Grep the files that will be published for anything that should not be public: your organization's confidential terms (client names, internal domains, project codenames), machine-local paths, secrets/tokens, and personal references.
   - `npm pack --dry-run` and inspect the file list -- confirm no `.env`, no secrets, no stray local files are bundled. `package.json` is always included even if not in `files[]`.
5. **Version is correct**: the version in `package.json` is NOT already published (`npm view <name> versions` -- confirm the target version is new).
6. **Scoped packages**: if the name is `@scope/pkg`, the publish MUST use `--access public` (default is private for scoped).

## Step 2: Version bump
- From `$ARGUMENTS`: `patch|minor|major` -> `npm version <level> -m "release: v%s"` (creates a commit + tag), OR set an explicit version.
- If the project keeps a CHANGELOG, prefer the `release` skill which sequences bump + CHANGELOG + tag together. For a bare publish, `npm version` is enough.

## Step 3: Publish
Prefer the token-free web-auth path (passkey-safe):
- **Primary (passkey/web)**: `npm publish --access public --auth-type=web` -> outputs a browser URL -> user authenticates with passkey -> publish completes. Passkey accounts have NO TOTP, so `--otp=CODE` does NOT work for them.
- **Automation fallback**: if the project's own `.env` has a valid (non-expired) `NPM_TOKEN` and `.npmrc` references `${NPM_TOKEN}`: `source .env && npm publish --access public`. VERIFY the token isn't expired first (granular tokens expire ~90 days). NEVER paste a token on the CLI as an argument.
- **E403 "cannot publish over"** = the previous publish actually SUCCEEDED (even if `npm view` 404s -- CDN propagation delay). Do NOT retry blindly; verify with Step 4.

## Step 4: Post-publish verification
- `npm view <name>@<version>` returns the new version (allow ~30-60s for CDN propagation; a transient 404 right after publish is normal).
- Confirm the published tarball contents are what you expected (`npm view <name> dist.tarball` / the file list from `npm pack --dry-run` in Step 1 matches).

## Step 5: GitHub release
- Push the version commit + tag: `git push && git push --tags`.
- Draft a GitHub release for the tag with notes (use the `changelog` skill to generate the notes, or the `release` skill which wires this end-to-end): `gh release create v<version> --title "v<version>" --notes "<generated notes>"`.

## What this skill does NOT do
- It does not bypass the leak/secret scan -- a public publish is irreversible.
- It does not hardcode any token; tokens come from the project `.env` at publish-time only.
