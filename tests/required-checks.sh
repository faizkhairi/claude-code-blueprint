#!/bin/bash
# Verifies that every CI job which can block a merge is actually a required status
# check on the default branch, and that the docs which tell contributors what gates a
# merge (docs/ROADMAP.md, CONTRIBUTING.md; sections 4 and 5) agree with it.
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
# the case for every job here. If a job ever gains a `name:`, the check reports
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
ADVISORY="required-checks
shellcheck"

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
# shellcheck disable=SC2001 # multi-line variable; ${var//} can't anchor per-line prefixes
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
# shellcheck disable=SC2020 # replacing brace chars (not words) with newlines is intended here
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
# shellcheck disable=SC2001 # multi-line variable; ${var//} can't anchor per-line prefixes
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

# ---------------------------------------------------------------------------
# 4. The documented policy matches the enforced one.
# ---------------------------------------------------------------------------
# docs/ROADMAP.md tells readers which checks gate a merge. That sentence went
# stale the moment this repo made four checks required: it still said the CI was
# advisory and "does not gate merges" long after it did, and nothing caught it.
# tests/count-check.sh could not, because it binds numbers and this claim has no
# digit in it.
#
# The assertion is name-based, not sentence-based. It checks facts the bullet must
# CONTAIN, never the shape of the prose, so the paragraph can be reworded freely
# and only a wrong FACT fails. Dropping a job name or calling an advisory job a
# gate is a wrong fact.
echo ""
echo "--- Documented policy matches enforcement ---"

ROADMAP="docs/ROADMAP.md"
MARKER='\*\*CI gates\*\*'

if [ ! -f "$ROADMAP" ]; then
  fail "$ROADMAP not found, so the documented policy cannot be checked."
else
  # The bullet is one wrapped list item: from the marker to the first blank line.
  # A CRLF blank line still terminates the range, because [[:space:]] matches CR
  # (this file carries CRLF endings, so that is load-bearing, not theoretical).
  bullet=$(awk "/$MARKER/,/^[[:space:]]*\$/" "$ROADMAP")
  n_markers=$(grep -c 'CI gates' "$ROADMAP")

  if [ "$n_markers" -gt 1 ]; then
    # Same rule as bind() and card() in count-check.sh: more than one match is a
    # document the guard cannot reason about, so fail rather than pick one.
    # Without this the range above splices two bullets into one buffer and every
    # assertion below silently tests the wrong text.
    fail "$ROADMAP: AMBIGUOUS, the 'CI gates' marker matched $n_markers lines. The guard cannot tell which bullet states the policy."
  elif [ -z "$bullet" ]; then
    # Same rule as count-check.sh: a reworded document must fail loudly rather
    # than silently check nothing. Safe to fail here, the job is advisory.
    fail "$ROADMAP: MISSING_ANCHOR, no '**CI gates**' bullet found. If the section was renamed, update MARKER in this script rather than deleting the check."
  else
    while IFS= read -r ctx; do
      [ -n "$ctx" ] || continue
      if printf '%s' "$bullet" | grep -qF "$ctx"; then
        pass "$ROADMAP documents the required check $ctx"
      else
        fail "$ctx is a required check that gates merges, but $ROADMAP does not mention it. A contributor reading the roadmap will not know it must pass."
      fi
    done <<EOF
$required
EOF

    while IFS= read -r adv; do
      [ -n "$adv" ] || continue
      if printf '%s\n' "$required" | grep -qxF "$adv"; then
        continue  # Genuinely required now; direction 1 above already reported it.
      elif printf '%s' "$bullet" | grep -qF "$adv"; then
        # Named in the bullet while not required. That is correct only if the
        # bullet describes it as advisory.
        #
        # The bracket pattern avoids pairing -i with -F: GNU grep 3.0 as shipped
        # with Git for Windows aborts (exit 134) on that combination, and an
        # aborted grep reads as "no match", which would turn a correct document
        # into a failure.
        if printf '%s' "$bullet" | grep -q "[Aa]dvisory"; then
          pass "$ROADMAP names $adv and describes it as advisory"
        else
          fail "$ROADMAP names $adv among the gating checks, but it is not required and cannot block a merge. Describe it as advisory."
        fi
      else
        pass "$adv is advisory and $ROADMAP does not claim it gates merges"
      fi
    done <<EOF
$ADVISORY
EOF
  fi
fi

# ---------------------------------------------------------------------------
# 5. CONTRIBUTING.md's merge-gate claims match enforcement.
# ---------------------------------------------------------------------------
# CONTRIBUTING.md tells contributors which suites block a merge in two places: the
# count-check paragraph names its job, and "Automated checks" lists the suites as
# commands. Same name-based rule as section 4: only a wrong FACT fails, and a
# reworded anchor fails loudly (MISSING_ANCHOR) rather than checking nothing.
# A command maps to the job whose steps run it, named the way section 1 names it
# (`name:` when present, else the id).
echo ""
echo "--- CONTRIBUTING.md merge-gate claims match enforcement ---"

CONTRIB="CONTRIBUTING.md"

jobs_running() { # <script path>: every job (by check name) with a non-comment line running it
  local s="${1#./}"
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    awk -v s="$s" '
      function flush() { if (job != "" && hit) print (label != "" ? label : job); hit = 0 }
      { sub(/\r$/, "") }
      /^jobs:[[:space:]]*$/ { injobs = 1; next }
      injobs && /^[^[:space:]#]/ { flush(); injobs = 0; job = "" }
      !injobs || /^[[:space:]]*#/ { next }
      /^  [A-Za-z0-9_-]+:[[:space:]]*(#.*)?$/ { flush(); job = $1; sub(/:$/, "", job); label = ""; next }
      job != "" && /^    name:[[:space:]]*/ {
        label = $0; sub(/^    name:[[:space:]]*/, "", label); gsub(/^["'"'"']|["'"'"']$/, "", label)
      }
      job != "" {
        line = $0; gsub(/\.\//, "", line)
        if (match(line, "(^|[[:space:]])bash[[:space:]]+" s "([[:space:]\"'"'"';&|]|$)")) hit = 1
      }
      END { flush() }
    ' "$wf"
  done | sort -u
}

if [ ! -f "$CONTRIB" ]; then
  fail "$CONTRIB not found, so its merge-gate claims cannot be checked."
else
  # (a) Each clause that calls a named job a required check. The line is cut at ". "
  # and "; " first, so "`a` is a required check; `b` is advisory" claims only `a`.
  claims=$(grep -n 'is a required check' "$CONTRIB" | awk -F': ' '{
    n = $0; sub(/:.*/, "", n); rest = substr($0, length(n) + 2)
    k = split(rest, part, /[.;] /)
    for (i = 1; i <= k; i++) if (index(part[i], "is a required check")) print n ":" part[i]
  }')
  if [ -z "$claims" ]; then
    fail "$CONTRIB: MISSING_ANCHOR, no sentence says a job 'is a required check'. If it was reworded, update this section rather than deleting the check."
  else
    while IFS= read -r claim; do
      [ -n "$claim" ] || continue
      ln="${claim%%:*}"; named=0
      # shellcheck disable=SC2016 # the backticks are literal Markdown code spans, not expansions
      for tok in $(printf '%s' "${claim#*:}" | grep -oE '`[A-Za-z0-9_][A-Za-z0-9_-]*`' | tr -d '`'); do
        printf '%s\n' "$declared" | grep -qxF -- "$tok" || continue
        named=1
        if printf '%s\n' "$required" | grep -qxF -- "$tok"; then
          pass "$CONTRIB:$ln calls $tok a required check, and it is"
        else
          fail "$CONTRIB:$ln calls $tok a required check, but it is not required and cannot block a merge."
        fi
      done
      [ "$named" = 1 ] || fail "$CONTRIB:$ln says 'is a required check' but names no workflow job in backticks."
    done <<EOF
$claims
EOF
  fi

  # (b) The commands in the first fenced block under "### Automated checks", up to
  # the next heading. Every non-blank, non-comment line must be `bash <script>`.
  n_heads=$(grep -c '^### Automated checks' "$CONTRIB")
  block=$(awk '{ sub(/\r$/, "") }
               /^### Automated checks/ { on = 1; next }
               on && /^#{1,3} / { exit }
               on && /^```/ { fences++; if (fences == 2) exit; next }
               on && fences == 1 { print }' "$CONTRIB")
  scripts=$(printf '%s\n' "$block" | sed -nE 's/^bash([[:space:]]+-[A-Za-z]+)*[[:space:]]+([^[:space:]-][^[:space:]]*).*/\2/p')
  if [ "$n_heads" -gt 1 ]; then
    fail "$CONTRIB: AMBIGUOUS, '### Automated checks' appears $n_heads times. The guard cannot tell which block states the policy."
  elif [ -z "$scripts" ]; then
    fail "$CONTRIB: MISSING_ANCHOR, no 'bash <script>' lines in the '### Automated checks' block. If the section moved, update this section rather than deleting the check."
  else
    while IFS= read -r l; do
      case "$l" in ''|'#'*|bash\ *) ;; *) fail "$CONTRIB: '$l' in the Automated checks block is not a 'bash <script>' line, so the guard cannot check it." ;; esac
    done <<EOF
$block
EOF
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      runners=$(jobs_running "$s")
      req_runner=""
      while IFS= read -r j; do
        [ -n "$j" ] && printf '%s\n' "$required" | grep -qxF -- "$j" && { req_runner="$j"; break; }
      done <<EOF
$runners
EOF
      if [ -z "$runners" ]; then
        fail "$CONTRIB lists $s as a CI suite that blocks merge, but no workflow job runs it."
      elif [ -n "$req_runner" ]; then
        pass "$CONTRIB lists $s; job $req_runner runs it and is a required check"
      else
        fail "$CONTRIB lists $s as blocking merge, but no required job runs it (run by: $(printf '%s' "$runners" | tr '\n' ' '))."
      fi
    done <<EOF
$scripts
EOF
  fi
fi

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
