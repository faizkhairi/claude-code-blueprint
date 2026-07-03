#!/bin/bash
# Tool: MCP Config Sync Checker
# Compares MCP server configs across CLI (~/.claude.json), VS Code extension
# (~/.claude/mcp.json), and Cursor (~/.cursor/mcp.json).
# Run manually: bash ~/.claude/hooks/verify-mcp-sync.sh

# Use Windows-style paths for Python compatibility
USERPROFILE="${USERPROFILE:-$HOME}"
CLI_CONFIG="$USERPROFILE/.claude.json"
EXT_CONFIG="$USERPROFILE/.claude/mcp.json"
CURSOR_CONFIG="$USERPROFILE/.cursor/mcp.json"

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "verify-mcp-sync: python not found" >&2
  exit 0
fi

extract_servers() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "(file missing)"
    return
  fi
  HOOK_MCP_FILE="$file" $PYTHON -c "
import os, json
try:
    filepath = os.environ.get('HOOK_MCP_FILE', '')
    with open(filepath) as f:
        d = json.load(f)
    servers = d.get('mcpServers', {})
    print(','.join(sorted(servers.keys())) if servers else '(none)')
except Exception as e:
    print(f'(error: {e})')
" 2>/dev/null
}

CLI_SERVERS=$(extract_servers "$CLI_CONFIG")
EXT_SERVERS=$(extract_servers "$EXT_CONFIG")
CURSOR_SERVERS=$(extract_servers "$CURSOR_CONFIG")

echo "=== MCP Config Sync Check ==="
echo "CLI (~/.claude.json)     : $CLI_SERVERS"
echo "Extension (~/.claude/mcp): $EXT_SERVERS"
echo "Cursor (~/.cursor/mcp)   : $CURSOR_SERVERS"
echo ""

if [ "$CLI_SERVERS" = "$EXT_SERVERS" ] && [ "$EXT_SERVERS" = "$CURSOR_SERVERS" ]; then
  echo "Status: IN SYNC"
else
  echo "Status: OUT OF SYNC"
  echo ""
  # Show detailed diff: which servers are where
  ALL_SERVERS=$(echo "$CLI_SERVERS,$EXT_SERVERS,$CURSOR_SERVERS" | tr ',' '\n' | sort -u | grep -v '^$' | grep -v '(')
  echo "  Server             CLI  Ext  Cursor"
  echo "  ------             ---  ---  ------"
  for srv in $ALL_SERVERS; do
    cli_has=" -"
    ext_has=" -"
    cur_has=" -"
    echo "$CLI_SERVERS" | grep -q "$srv" && cli_has=" Y"
    echo "$EXT_SERVERS" | grep -q "$srv" && ext_has=" Y"
    echo "$CURSOR_SERVERS" | grep -q "$srv" && cur_has=" Y"
    printf "  %-20s %s    %s    %s\n" "$srv" "$cli_has" "$ext_has" "$cur_has"
  done
fi

exit 0
