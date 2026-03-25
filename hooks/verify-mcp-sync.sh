#!/bin/bash
# Tool: MCP Config Sync Checker
# Compares MCP server configs across CLI, extension, and Cursor.
# Run manually: bash ~/.claude/hooks/verify-mcp-sync.sh

# Use Windows-style paths for Python compatibility
USERPROFILE="${USERPROFILE:-C:\\Users\\User}"
CLI_CONFIG="$USERPROFILE/.claude.json"
EXT_CONFIG="$USERPROFILE/.claude/mcp.json"
CURSOR_CONFIG="$USERPROFILE/.cursor/mcp.json"

extract_servers() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "(file missing)"
    return
  fi
  python3 -c "
import json, sys
try:
    with open('$file') as f:
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
echo "CLI     : $CLI_SERVERS"
echo "Extension: $EXT_SERVERS"
echo "Cursor  : $CURSOR_SERVERS"
echo ""

if [ "$CLI_SERVERS" = "$EXT_SERVERS" ] && [ "$EXT_SERVERS" = "$CURSOR_SERVERS" ]; then
  echo "Status: IN SYNC"
else
  echo "Status: OUT OF SYNC"
  echo ""
  # Show detailed diff — which servers are where
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
