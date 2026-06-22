#!/bin/bash
# Hook: InstructionsLoaded (observability-only)
# Logs which CLAUDE.md / rules/*.md files load into context, and WHY
# (session_start / path_glob_match / nested / etc). Primary value: makes
# path-scoped rule injection (the `paths:` frontmatter on rules) observable --
# it closes the "did the database-schema rule actually fire when I opened the
# schema file?" gap with an audit trail. The event has no decision control, so
# this hook cannot block; it only records. Fail-open, exit 0 always.
#
# Inspect the trail with: cat ~/.claude/logs/instructions-loaded.log

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then exit 0; fi

LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/instructions-loaded.log"

INPUT=$(cat)

# Build a compact log line via Python (safe JSON parsing; never crashes).
LINE=$(echo "$INPUT" | $PYTHON -c "
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
