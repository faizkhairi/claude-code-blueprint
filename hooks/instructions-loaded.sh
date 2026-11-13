#!/bin/bash
# Hook: InstructionsLoaded (observability-only)
# Logs which CLAUDE.md / rules/*.md files load into context, and WHY
# (session_start / path_glob_match / nested / etc). Primary value: makes
# path-scoped rule injection (the `paths:` frontmatter on rules) observable --
# it closes the "did the database-schema rule actually fire when I opened the
# schema file?" gap with an audit trail. The event has no decision control, so
# this hook cannot block; it only records. Fail-open, exit 0 always.
# The log rotates at 1 MB: the full log moves to instructions-loaded.log.1 (one
# older generation is kept, anything before that is overwritten).
#
# Inspect the trail with: cat ~/.claude/logs/instructions-loaded.log

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then exit 0; fi

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/instructions-loaded.log"

# Rotate at 1 MB. This fires on every instruction load, so the log would otherwise
# grow for as long as the machine is used.
MAX_BYTES=1048576
if [ -f "$LOG_FILE" ]; then
  SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')
  if [ "${SIZE:-0}" -gt "$MAX_BYTES" ] 2>/dev/null; then
    mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null
  fi
fi

INPUT=$(cat)

# Build a compact log line via Python (safe JSON parsing; never crashes).
LINE=$(echo "$INPUT" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
fp     = d.get('file_path', '?')
reason = d.get('load_reason', '?')
mtype  = d.get('memory_type', '?')
globs  = d.get('globs', '')
base   = fp.split('/')[-1].split('\\\\')[-1] if fp else '?'
parts  = [reason, mtype, base]
if globs:
    parts.append('globs=' + (json.dumps(globs) if not isinstance(globs, str) else globs))
parts.append(fp)
print(' | '.join(str(p) for p in parts))
" 2>/dev/null)

mkdir -p "$LOG_DIR" 2>/dev/null
TS=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TS | $LINE" >> "$LOG_FILE" 2>/dev/null

exit 0
