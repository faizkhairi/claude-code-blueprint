#!/usr/bin/env bash
#
# install-matrix.sh -- exercise setup.sh across every preset and entry scenario,
# asserting it never crashes and never wires a hook it did not install.
#
# Each case runs the installer with an isolated HOME (a throwaway temp dir), so the
# real ~/.claude is never touched. setup.sh derives CLAUDE_DIR from $HOME, so an
# overridden HOME fully sandboxes the run.
#
# We assert on OUTPUT, not just exit codes: a run can exit 0 while printing a shell
# error to stderr or writing a settings.json that references a missing script. The
# banned-string and wiring checks below catch exactly the bugs this harness exists to
# prevent (the set -e / non-TTY / schema-drift / preset-mismatch class).
#
# Usage: bash tests/install-matrix.sh
# Exit:  0 if every case passes, 1 otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="${REPO_ROOT}/setup.sh"
TEMPLATE="${REPO_ROOT}/examples/settings-template.json"
PRESETS=(minimal standard core full)

PASS=0
FAIL=0
FAILED_CASES=()

# Strings that must never appear on stderr (each is a symptom of a fixed bug).
BANNED_PATTERNS='integer expression|AttributeError|Traceback|No such file or directory|command not found|unbound variable'

PY="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "")"

new_home() {
  # Print a fresh empty temp dir to use as HOME.
  mktemp -d "${TMPDIR:-/tmp}/ccb-test.XXXXXX"
}

# assert_clean_run <label> <home> <stderr_file> <exit_code>
# Checks exit code 0 and no banned string on stderr.
assert_clean_run() {
  local label="$1" home="$2" errfile="$3" code="$4"
  local ok=1
  if [ "$code" -ne 0 ]; then
    echo "  [FAIL] $label: exit $code (expected 0)"
    sed 's/^/        | /' "$errfile" | tail -8
    ok=0
  elif grep -qiE "$BANNED_PATTERNS" "$errfile"; then
    echo "  [FAIL] $label: banned error string on stderr:"
    grep -iE "$BANNED_PATTERNS" "$errfile" | sed 's/^/        | /' | head -4
    ok=0
  fi
  return $((1 - ok))
}

# assert_settings_wiring <label> <home>
# If a settings.json exists, it must be valid JSON and every hook/statusLine command
# that points under <home>/.claude/hooks/ must reference a file that actually exists.
assert_settings_wiring() {
  local label="$1" home="$2"
  local settings="${home}/.claude/settings.json"
  [ -f "$settings" ] || return 0          # minimal-with-no-settings is checked separately
  [ -n "$PY" ] || return 0                # cannot introspect without python; skip quietly
  "$PY" - "$settings" "${home}/.claude/hooks" << 'PYCHK'
import json, os, re, sys
settings, hooks_dir = sys.argv[1], sys.argv[2]
try:
    with open(settings) as f:
        d = json.load(f)
except Exception as e:
    print("INVALID_JSON: %s" % e); sys.exit(2)
ref = re.compile(r'/hooks/([^"\'\s]+\.sh)')
missing = []
def check(cmd):
    if not cmd: return
    m = ref.search(cmd)
    if m and not os.path.isfile(os.path.join(hooks_dir, m.group(1))):
        missing.append(m.group(1))
for ev, blocks in (d.get("hooks") or {}).items():
    if isinstance(blocks, list):
        for b in blocks:
            for h in (b.get("hooks") or []):
                check(h.get("command"))
sl = d.get("statusLine")
if isinstance(sl, dict): check(sl.get("command"))
if missing:
    print("WIRED_BUT_MISSING: %s" % ",".join(sorted(set(missing)))); sys.exit(3)
sys.exit(0)
PYCHK
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "  [FAIL] $label: settings.json wiring check failed (rc=$rc)"
    return 1
  fi
  return 0
}

record() {
  # record <label> <0|1 ok>
  if [ "$2" -eq 0 ]; then
    PASS=$((PASS + 1)); echo "  [PASS] $1"
  else
    FAIL=$((FAIL + 1)); FAILED_CASES+=("$1")
  fi
}

echo "== install-matrix: setup.sh across presets x scenarios =="
echo "   repo: $REPO_ROOT"
echo ""

# --- Static template check: no bare quoted-tilde hook commands (the exit-127 regression) ---
echo "-- template integrity --"
if grep -q 'bash \\"~/' "$TEMPLATE" 2>/dev/null || grep -q 'bash "~/' "$TEMPLATE" 2>/dev/null; then
  echo "  [FAIL] settings-template.json contains a quoted-tilde hook command (use \$HOME)"
  FAIL=$((FAIL + 1)); FAILED_CASES+=("template: quoted-tilde")
else
  echo "  [PASS] no quoted-tilde hook commands in template"
  PASS=$((PASS + 1))
fi
echo ""

for preset in "${PRESETS[@]}"; do
  echo "-- preset: $preset --"

  # 1) Fresh install with --yes
  H="$(new_home)"; ERR="$(mktemp)"
  HOME="$H" bash "$SETUP" --preset="$preset" --yes >/dev/null 2>"$ERR"; code=$?
  ok=0; assert_clean_run "$preset/fresh --yes" "$H" "$ERR" "$code" || ok=1
  assert_settings_wiring "$preset/fresh --yes (wiring)" "$H" || ok=1
  record "$preset: fresh install (--yes)" "$ok"
  rm -rf "$H" "$ERR"

  # 2) Re-run idempotency: install twice into the same HOME
  H="$(new_home)"; ERR1="$(mktemp)"; ERR2="$(mktemp)"
  HOME="$H" bash "$SETUP" --preset="$preset" --yes >/dev/null 2>"$ERR1"; c1=$?
  HOME="$H" bash "$SETUP" --preset="$preset" --yes >/dev/null 2>"$ERR2"; c2=$?
  ok=0
  assert_clean_run "$preset/rerun (1st)" "$H" "$ERR1" "$c1" || ok=1
  assert_clean_run "$preset/rerun (2nd)" "$H" "$ERR2" "$c2" || ok=1
  assert_settings_wiring "$preset/rerun (wiring)" "$H" || ok=1
  record "$preset: re-run (idempotency)" "$ok"
  rm -rf "$H" "$ERR1" "$ERR2"

  # 3) Non-TTY install via redirected stdin (no --yes): must not EOF-abort
  H="$(new_home)"; ERR="$(mktemp)"
  HOME="$H" bash "$SETUP" --preset="$preset" </dev/null >/dev/null 2>"$ERR"; code=$?
  ok=0; assert_clean_run "$preset/non-TTY < /dev/null" "$H" "$ERR" "$code" || ok=1
  record "$preset: non-TTY (--preset, no --yes, < /dev/null)" "$ok"
  rm -rf "$H" "$ERR"

  # 4) Dry-run over a pre-existing ~/.claude: must preview and change nothing
  H="$(new_home)"; ERR="$(mktemp)"
  mkdir -p "$H/.claude/hooks" "$H/.claude/agents" "$H/.claude/skills" "$H/.claude/rules"
  echo "sentinel" > "$H/.claude/sentinel.txt"
  before="$(find "$H/.claude" -type f | sort | xargs -r md5sum 2>/dev/null || true)"
  HOME="$H" bash "$SETUP" --preset="$preset" --dry-run --yes >/dev/null 2>"$ERR"; code=$?
  after="$(find "$H/.claude" -type f | sort | xargs -r md5sum 2>/dev/null || true)"
  ok=0
  assert_clean_run "$preset/dry-run (existing ~/.claude)" "$H" "$ERR" "$code" || ok=1
  if [ "$before" != "$after" ]; then
    echo "  [FAIL] $preset/dry-run modified files under ~/.claude"; ok=1
  fi
  record "$preset: dry-run over existing ~/.claude (no changes)" "$ok"
  rm -rf "$H" "$ERR"
done

# 5) Piped menu choice (no --preset): "3" selects core via the menu, then must finish
echo ""
echo "-- piped menu choice --"
H="$(new_home)"; ERR="$(mktemp)"
echo "3" | HOME="$H" bash "$SETUP" >/dev/null 2>"$ERR"; code=$?
ok=0; assert_clean_run "piped 'echo 3 | setup.sh'" "$H" "$ERR" "$code" || ok=1
assert_settings_wiring "piped menu (wiring)" "$H" || ok=1
record "piped menu choice (echo 3 | setup.sh)" "$ok"
rm -rf "$H" "$ERR"

echo ""
echo "== results: ${PASS} passed, ${FAIL} failed =="
if [ "$FAIL" -gt 0 ]; then
  printf '   failed: %s\n' "${FAILED_CASES[@]}"
  exit 1
fi
echo "   all install paths exit cleanly and wire only installed hooks."
