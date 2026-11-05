#!/bin/bash
# Fails when a GitHub Actions `uses:` line references anything other than a full
# 40-character commit SHA, or has no trailing version comment.
#
# WHY THIS EXISTS
#
# A tag such as `actions/checkout@v7` is mutable: whoever controls the action's
# repository can move it, and the next CI run executes whatever it now points at,
# with this repo's GITHUB_TOKEN. A commit SHA cannot be moved. Pinning by SHA makes
# an upstream compromise or a retag invisible to this repo until a human reviews the
# bump. The trailing version comment keeps the pin readable and lets Dependabot
# (.github/dependabot.yml) rewrite the SHA and the comment together.
#
# Nothing else stops a mutable ref coming back: a contributor copying an example
# from an action's README writes `@v4`, CI stays green, and the pin is gone. So the
# rule is enforced here, in a required status check (the count-check job runs this).
#
# WHAT COUNTS AS PINNED
#
#   owner/repo@<40 lowercase hex> # v1.2.3         pinned (also owner/repo/path@sha
#                                                  and reusable workflows)
#   docker://image@sha256:<64 hex> # 1.2.3         pinned by image digest
#   ./local/action                                 exempt: lives in this repo, no ref
#
# Anything else fails: a tag (@v4), a branch (@main), a short SHA, a missing ref, or
# a pinned ref with no trailing comment containing a version digit.
#
# SCOPE
#
# Every .yml and .yaml under .github/workflows and .github/actions. Lines that are
# YAML comments are ignored. If no `uses:` line is found at all, the guard fails
# rather than passing on nothing, the same rule as count-check.sh MISSING_ANCHOR:
# a moved directory must not turn a security guard into a no-op.
#
# Run: bash tests/pin-check.sh

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

RE_SHA_REF='^[^@[:space:]]+@[0-9a-f]{40}$'
RE_DOCKER_REF='^docker://[^@[:space:]]+@sha256:[0-9a-f]{64}$'
RE_VERSION='[0-9]'

echo "=== Action Pin Guard ==="
echo ""

files=$(find .github/workflows .github/actions -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)

if [ -z "$files" ]; then
  fail "MISSING_ANCHOR: no workflow or action files under .github/workflows or .github/actions. If they moved, update this script rather than deleting the check."
fi

scanned=0
while IFS= read -r wf; do
  [ -n "$wf" ] || continue
  # `grep -n` yields `<line>:<text>`; a comment line starts with `#`, so the anchor
  # below never matches one. tr strips CR so a CRLF checkout cannot corrupt a ref.
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    ln="${hit%%:*}"
    text="${hit#*:}"
    scanned=$((scanned + 1))

    # Everything after the first `uses:`, left-trimmed.
    value="${text#*uses:}"
    value="${value#"${value%%[![:space:]]*}"}"

    # Split `<ref> # <comment>` on the first whitespace-then-hash.
    ref="${value%%[[:space:]]#*}"
    comment=""
    if [ "$ref" != "$value" ]; then
      comment="${value#"$ref"}"
      comment="${comment#"${comment%%[![:space:]]*}"}"
      comment="${comment#\#}"
    fi
    ref="${ref%"${ref##*[![:space:]]}"}"
    ref="${ref#[\"\']}"
    ref="${ref%[\"\']}"

    where="$wf:$ln"
    case "$ref" in
      ./*|../*)
        pass "$where uses a local action ($ref), nothing to pin"
        continue
        ;;
      docker://*)
        if ! [[ $ref =~ $RE_DOCKER_REF ]]; then
          fail "$where '$ref' is not pinned by @sha256:<64 hex> image digest."
          continue
        fi
        ;;
      *)
        if ! [[ $ref =~ $RE_SHA_REF ]]; then
          fail "$where '$ref' is not pinned to a 40-character commit SHA. Resolve it with: git ls-remote https://github.com/<owner>/<repo> 'refs/tags/<tag>' 'refs/tags/<tag>^{}' (the ^{} line, when present, is the commit), then write uses: <owner>/<repo>@<sha> # <tag>"
          continue
        fi
        ;;
    esac

    if [[ $comment =~ $RE_VERSION ]]; then
      pass "$where $ref pinned, version comment:$comment"
    else
      fail "$where '$ref' is pinned but has no trailing version comment (expected '# v1.2.3'). Dependabot and reviewers need it to see what the SHA is."
    fi
  done <<EOF
$(tr -d '\r' < "$wf" | grep -nE '^[[:space:]]*(-[[:space:]]+)?uses:' || true)
EOF
  # Flow-style or quoted-key forms the block-style match above cannot parse. Fail them
  # rather than skip them, so no form of uses: escapes the check.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    fail "$wf:${line%%:*} uses: in flow style or with a quoted key; write it block style (- uses: owner/repo@<sha> # vX.Y.Z) so it can be checked."
  done <<EOF2
$(tr -d '\r' < "$wf" | grep -nE '[{,][[:space:]]*["'"'"']?uses["'"'"']?[[:space:]]*:|^[[:space:]]*(-[[:space:]]+)?["'"'"']uses["'"'"'][[:space:]]*:' || true)
EOF2
done <<EOF
$files
EOF

if [ -n "$files" ] && [ "$scanned" -eq 0 ]; then
  fail "MISSING_ANCHOR: workflow files exist but no 'uses:' line was found in any of them. If the syntax changed, update the match in this script rather than deleting the check."
fi

echo ""
echo "=== Results ==="
echo "Checked: $scanned uses: line(s)"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Every action must be pinned by full commit SHA with a trailing version comment."
  exit 1
fi

echo ""
echo "All actions are pinned by commit SHA."
