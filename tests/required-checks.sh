#!/bin/bash
# Verifies that every CI job which can block a merge is actually a required status
# check on the default branch.
#
# WHY THIS EXISTS
#
# Branch protection stores required checks as a list of NAMES. Nothing links that
# list to the workflows, so a job added later inherits no enforcement, silently.
# This repo shipped exactly that: the ruleset was written when install-test.yml had
# two jobs, and both hook-tests and count-check were later added and left unenforced.
# A green tick on an unenforced check looks identical to a green tick on an enforced
# one, which is what makes the gap invisible in the PR UI.
#
# The inverse case is worse. A required check whose name matches no job never
# reports at all, so every PR waits on it forever. A typo here does not fail loudly,
# it wedges the repository. That is why the comparison runs in both directions.
#
# HOW IT WORKS
#
# Job ids come from the workflow files; required contexts come from the GitHub API.
# The /rules/branches/{branch} endpoint returns which rules apply to a branch and is
# public on a public repo, so this needs no token, no secret, and no admin scope.
# (The /rulesets/{id} endpoint does need admin, but it is not used here.)
#
# Job id vs check name: with no `name:` key, the check name IS the job id, which is
# the case for all four jobs here. If a job ever gains a `name:`, the check reports
# under that instead, so this reads `name:` when present and falls back to the id.
#
# ADVISORY JOBS
#
# Jobs listed in ADVISORY below are expected NOT to be required, and are reported
# as such rather than failed. required-checks is itself advisory: making it a
# required check would deadlock, because adding it to the ruleset is the act that
# makes it pass, so until it is added it fails, and while failing it blocks the PR
# that would add it. It would also fail on every fork, which has no copy of this
# repo's branch protection.
#
# This is an allowlist, not a silent skip. An advisory job that somehow IS required
# still gets reported, because that is a real change in merge behaviour.
#
# SKIPPED, NOT FAILED, WHEN OFFLINE
#
# Exits 0 with a notice when the API is unreachable or returns no ruleset. A network
# blip must not fail a PR, and a fork will not have the parent's protection.
#
# Run: bash tests/required-checks.sh

set -u

REPO="${GITHUB_REPOSITORY:-faizkhairi/claude-code-blueprint}"
BRANCH="${DEFAULT_BRANCH:-main}"
API="https://api.github.com/repos/${REPO}/rules/branches/${BRANCH}"

# Jobs that are expected not to be required. See ADVISORY JOBS above.
ADVISORY="required-checks"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Required Status Check Guard ==="
echo "Repo:   $REPO"
echo "Branch: $BRANCH"
echo ""

# ---------------------------------------------------------------------------
# 1. Job ids (or explicit names) declared in the workflows.
# ---------------------------------------------------------------------------
# Workflow YAML here is flat and conventional: jobs are the 2-space keys under
# `jobs:`, and any `name:` belongs to the job it is indented under. Parsed with
# awk so the guard needs no python or yq in CI.
declared=$(
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    awk '
      /^jobs:[[:space:]]*$/ { injobs = 1; next }
      injobs && /^[^[:space:]]/ { injobs = 0 }
      injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
        if (job != "") print (label != "" ? label : job)
        job = $1; sub(/:$/, "", job); label = ""
        next
      }
      injobs && job != "" && /^    name:[[:space:]]*/ {
        label = $0
        sub(/^    name:[[:space:]]*/, "", label)
        gsub(/^["'"'"']|["'"'"']$/, "", label)
      }
      END { if (job != "") print (label != "" ? label : job) }
    ' "$wf"
  done | sort -u
)

if [ -z "$declared" ]; then
  echo "  NOTICE: no workflow jobs found, nothing to compare."
  exit 0
fi

echo "Jobs declared in .github/workflows:"
echo "$declared" | sed 's/^/  - /'
echo ""

# ---------------------------------------------------------------------------
# 2. Required contexts, from the API.
# ---------------------------------------------------------------------------
response=$(curl -sS -f --max-time 20 \
  -H "Accept: application/vnd.github+json" \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "$API" 2>/dev/null) || {
    echo "  NOTICE: could not reach $API, skipping (this must not fail a PR)."
    exit 0
  }

# Pull required_status_checks contexts without needing jq: the payload is a flat
# array of rule objects, so grep the contexts out of the one rule that has them.
required=$(printf '%s' "$response" \
  | tr '{}' '\n\n' \
  | grep -oE '"context"[[:space:]]*:[[:space:]]*"[^"]+"' \
  | sed -E 's/.*"context"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' \
  | sort -u)

if [ -z "$required" ]; then
  echo "  NOTICE: no required status checks configured on $BRANCH, skipping."
  echo "  (If this is unexpected, check the branch ruleset.)"
  exit 0
fi

echo "Required status checks on $BRANCH:"
echo "$required" | sed 's/^/  - /'
echo ""

# ---------------------------------------------------------------------------
# 3. Compare, in both directions.
# ---------------------------------------------------------------------------
echo "--- Every job is enforced ---"
while IFS= read -r job; do
  [ -n "$job" ] || continue
  if printf '%s\n' "$required" | grep -qxF "$job"; then
    if printf '%s\n' "$ADVISORY" | grep -qxF "$job"; then
      pass "$job is required (listed as advisory, so this is a deliberate change worth noting)"
    else
      pass "$job is a required check"
    fi
  elif printf '%s\n' "$ADVISORY" | grep -qxF "$job"; then
    pass "$job is advisory by design, not required"
  else
    fail "$job runs in CI but is NOT required, so it cannot block a merge. Add it to the branch ruleset."
  fi
done <<EOF
$declared
EOF

echo ""
echo "--- Every required check exists ---"
while IFS= read -r ctx; do
  [ -n "$ctx" ] || continue
  if printf '%s\n' "$declared" | grep -qxF "$ctx"; then
    pass "$ctx is produced by a workflow job"
  else
    fail "$ctx is required but no workflow job produces it. Every PR will wait on it forever. Fix the name in the ruleset or restore the job."
  fi
done <<EOF
$required
EOF

echo ""
echo "=== Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Required checks are configured in the repository ruleset, not in this repo."
  echo "Settings > Rules > Rulesets > main-protection > Require status checks."
  exit 1
fi

echo ""
echo "CI jobs and required checks agree."
