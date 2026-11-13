#!/bin/bash
# Hook: Stop (async). Cost Tracker
# Appends a JSONL entry per stop event for session cost visibility.
#
# The session id comes from the hook's stdin JSON ("session_id"). The model comes
# from the last transcript entry that carries one (stdin "transcript_path", newest
# 1 MB only; a placeholder such as <synthetic> is skipped); Claude Code sets no
# CLAUDE_SESSION_ID or CLAUDE_MODEL variable. Either value is "unknown" when it
# cannot be read. The 10 MB size cut writes a temp file and renames it over the
# log, keeping the log's file mode, so an interrupted cut never leaves half a log.
#
# Requires: python3 or python on PATH
# Exit code: always 0 (never blocks responses)

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
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

# Capture session metadata (session_id and model are read from stdin in Python below)
HOOK_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export HOOK_TIMESTAMP
export HOOK_METRICS_FILE="$METRICS_FILE"
export HOOK_METRICS_DIR="$METRICS_DIR"

# Monthly rotation + append, all in Python for safe JSON handling
"$PYTHON" -c "
import os, json, sys, tempfile

# Hook payload from stdin: session_id, and transcript_path for the model.
try:
    payload = json.loads(sys.stdin.read())
except Exception:
    payload = {}
if not isinstance(payload, dict):
    payload = {}
session_id = payload.get('session_id')
if not isinstance(session_id, str) or not session_id:
    session_id = 'unknown'

# Model: the last JSON line of the transcript whose message has a model field.
model = 'unknown'
transcript = payload.get('transcript_path')
if isinstance(transcript, str) and transcript:
    try:
        TAIL = 1024 * 1024
        with open(transcript, 'rb') as f:
            f.seek(0, 2)
            start = max(0, f.tell() - TAIL)
            f.seek(start)
            data = f.read().decode('utf-8', 'replace')
        lines = data.splitlines()
        if start > 0:
            lines = lines[1:]  # the first line of a mid-file read is partial
        for line in reversed(lines):
            try:
                entry = json.loads(line)
            except Exception:
                continue
            msg = entry.get('message') if isinstance(entry, dict) else None
            found = msg.get('model') if isinstance(msg, dict) else None
            if isinstance(found, str) and found and not found.startswith('<'):
                model = found
                break
    except Exception:
        pass  # model stays unknown

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
        # Keep the most recent half. Write a temp file in the same directory, then
        # rename it over the log, so the cut is all or nothing.
        try:
            old_mode = os.stat(metrics_file).st_mode & 0o777
        except OSError:
            old_mode = 0o644
        fd, tmp = tempfile.mkstemp(prefix='costs-', suffix='.tmp', dir=metrics_dir)
        try:
            with os.fdopen(fd, 'w') as f:
                f.writelines(lines[len(lines)//2:])
            os.chmod(tmp, old_mode)  # mkstemp makes it 0600; keep the log's own mode
            os.replace(tmp, metrics_file)
        except Exception:
            try:
                os.remove(tmp)
            except OSError:
                pass
            raise
    except Exception:
        pass  # truncation is best-effort

# Append JSONL entry
entry = {
    'session_id': session_id,
    'model': model,
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
