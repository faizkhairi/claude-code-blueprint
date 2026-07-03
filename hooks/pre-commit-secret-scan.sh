#!/bin/bash
# Hook: PreToolUse (Bash). Secret Scan Before Commit
# Scans staged git content with gitleaks before any `git commit`.
# Blocks the commit (exit 2) if gitleaks detects a secret. This is a security
# gate, the same documented exception to "exit 0 always" that block-git-push.sh uses.
# Allows the commit (exit 0) when: gitleaks is clean, gitleaks isn't installed
# (fail-open), the command isn't a commit, or the input is malformed.
#
# Requires gitleaks on PATH to actually scan. Without it the hook is a no-op + warns:
#   winget install gitleaks   (Windows)   |   brew install gitleaks   (macOS)

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

# Only intercept git commit commands
if ! echo "$COMMAND" | grep -qE 'git commit( |$)'; then
  exit 0
fi

# Skip metadata-only commits (no new staged content) and explicit bypass
if echo "$COMMAND" | grep -qE 'git commit --amend --no-edit'; then
  exit 0
fi
if echo "$COMMAND" | grep -qE 'git commit.*--no-verify'; then
  echo "Note: commit invoked with --no-verify; gitleaks pre-commit scan skipped." >&2
  exit 0
fi

# gitleaks must be on PATH; fail open (warn, allow) if absent
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "Note: gitleaks not installed; pre-commit secret scan skipped." >&2
  echo "      Install to enable: 'winget install gitleaks' or 'brew install gitleaks'." >&2
  exit 0
fi

# Determine the directory to scan: 'cd <dir> && git commit' -> <dir>, else CWD.
# Handles quoted paths with spaces (double, then single, then bare).
SCAN_DIR=$(echo "$COMMAND" | sed -n 's/.*cd "\([^"]*\)".*/\1/p' | head -1)
[ -z "$SCAN_DIR" ] && SCAN_DIR=$(echo "$COMMAND" | sed -n "s/.*cd '\([^']*\)'.*/\1/p" | head -1)
[ -z "$SCAN_DIR" ] && SCAN_DIR=$(echo "$COMMAND" | sed -n 's/.*cd \([^ &;|]*\).*/\1/p' | head -1)
if [ -z "$SCAN_DIR" ] || [ ! -d "$SCAN_DIR" ]; then
  SCAN_DIR="$(pwd)"
fi

# Only scan inside a git repo (avoid noisy errors on non-repo dirs)
if ! git -C "$SCAN_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Scan staged content. --staged: only what's about to be committed;
# --redact: hide secret values (show pattern + file); --exit-code 1: non-zero on findings.
GITLEAKS_OUTPUT=$(cd "$SCAN_DIR" && gitleaks protect --staged --no-banner --redact --exit-code 1 2>&1)
GITLEAKS_EXIT=$?

if [ $GITLEAKS_EXIT -ne 0 ]; then
  echo "Blocked: gitleaks detected potential secret(s) in staged content for $SCAN_DIR" >&2
  echo "$GITLEAKS_OUTPUT" | head -30 >&2
  echo "" >&2
  echo "To resolve:" >&2
  echo "  1) Unstage the secret (git reset <file>) and remove it from the file" >&2
  echo "  2) Rotate the leaked credential (assume it is compromised)" >&2
  echo "  3) If it is a false positive, add an allowlist rule to .gitleaks.toml in the repo root" >&2
  echo "  4) Only if absolutely necessary, bypass with: git commit --no-verify" >&2
  exit 2
fi

exit 0
