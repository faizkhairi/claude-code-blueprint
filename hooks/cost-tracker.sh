#!/bin/bash
# Hook: Stop (async). Cost Tracker
# Appends a JSONL entry per stop event for session cost visibility.
#
# Requires: python3 or python on PATH
# Exit code: always 0 (never blocks responses)

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "cost-tracker: python not found: cost not logged" >&2
  exit 0
fi

METRICS_DIR="$HOME/.claude/metrics"
METRICS_FILE="$METRICS_DIR/costs.jsonl"

# Create directory if needed
mkdir -p "$METRICS_DIR" 2>/dev/null || {
  echo "cost-tracker: cannot create $METRICS_DIR" >&2
  exit 0
}

# Capture session metadata
export HOOK_SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
export HOOK_MODEL="${CLAUDE_MODEL:-unknown}"
export HOOK_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export HOOK_METRICS_FILE="$METRICS_FILE"
export HOOK_METRICS_DIR="$METRICS_DIR"

# Monthly rotation + append, all in Python for safe JSON handling
$PYTHON -c "
import os, json, sys

metrics_file = os.environ.get('HOOK_METRICS_FILE', '')
metrics_dir = os.environ.get('HOOK_METRICS_DIR', '')
timestamp = os.environ.get('HOOK_TIMESTAMP', '')
current_month = timestamp[:7] if len(timestamp) >= 7 else ''

# Monthly rotation: archive when month changes
if os.path.isfile(metrics_file):
    try:
        with open(metrics_file, 'r') as f:
            first_line = f.readline().strip()
        if first_line:
            first_entry = json.loads(first_line)
            first_month = first_entry.get('timestamp', '')[:7]
            if first_month and first_month != current_month:
                archive = os.path.join(metrics_dir, f'costs-{first_month}.jsonl')
                os.rename(metrics_file, archive)
    except Exception:
        pass  # rotation is best-effort

# Size guard: cap at 10MB to prevent unbounded growth
MAX_SIZE = 10 * 1024 * 1024  # 10 MB
if os.path.isfile(metrics_file) and os.path.getsize(metrics_file) > MAX_SIZE:
    try:
        with open(metrics_file, 'r') as f:
            lines = f.readlines()
        # Keep the most recent half
        with open(metrics_file, 'w') as f:
            f.writelines(lines[len(lines)//2:])
    except Exception:
        pass  # truncation is best-effort

# Append JSONL entry
entry = {
    'session_id': os.environ.get('HOOK_SESSION_ID', 'unknown'),
    'model': os.environ.get('HOOK_MODEL', 'unknown'),
    'timestamp': timestamp,
    'event': 'stop'
}
try:
    with open(metrics_file, 'a') as f:
        f.write(json.dumps(entry) + '\n')
except Exception as e:
    print(f'cost-tracker: write failed: {e}', file=sys.stderr)
" 2>/dev/null

exit 0
