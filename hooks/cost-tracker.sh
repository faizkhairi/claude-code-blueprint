#!/bin/bash
# Hook: Stop (async) — Cost Tracker
# Appends a JSONL entry per stop event for session cost visibility.

METRICS_DIR="$HOME/.claude/metrics"
METRICS_FILE="$METRICS_DIR/costs.jsonl"

# Create directory if needed
mkdir -p "$METRICS_DIR"

# Capture session metadata
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
MODEL="${CLAUDE_MODEL:-unknown}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Monthly rotation — archive when month changes
CURRENT_MONTH=$(date +"%Y-%m")
if [ -f "$METRICS_FILE" ]; then
  FIRST_LINE_MONTH=$(head -1 "$METRICS_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('timestamp','')[:7])" 2>/dev/null)
  if [ -n "$FIRST_LINE_MONTH" ] && [ "$FIRST_LINE_MONTH" != "$CURRENT_MONTH" ]; then
    mv "$METRICS_FILE" "$METRICS_DIR/costs-$FIRST_LINE_MONTH.jsonl"
  fi
fi

# Append JSONL entry
echo "{\"session_id\":\"$SESSION_ID\",\"model\":\"$MODEL\",\"timestamp\":\"$TIMESTAMP\",\"event\":\"stop\"}" >> "$METRICS_FILE"

exit 0
