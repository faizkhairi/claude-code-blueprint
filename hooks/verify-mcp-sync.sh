#!/bin/bash
# Tool: MCP Config Sync Checker
# Compares the user-scope MCP servers in Claude Code (~/.claude.json, top-level
# "mcpServers") with Cursor (~/.cursor/mcp.json).
# The Claude Code CLI and the VS Code extension share one MCP configuration
# (`claude mcp add` and `/mcp` in the extension save to the same place), so
# there is no separate extension file to compare. Project-scope servers live in
# each project's .mcp.json and local-scope servers sit under that project's
# entry in ~/.claude.json; neither is compared here.
# A config file that does not exist means that tool is not installed, which is not
# drift: the comparison is skipped and says so, instead of reporting OUT OF SYNC.
# Run manually: bash ~/.claude/hooks/verify-mcp-sync.sh

# Use Windows-style paths for Python compatibility
USERPROFILE="${USERPROFILE:-$HOME}"
CLAUDE_CONFIG="$USERPROFILE/.claude.json"
CURSOR_CONFIG="$USERPROFILE/.cursor/mcp.json"

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
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
  HOOK_MCP_FILE="$file" "$PYTHON" -c "
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

# has_server <comma-list> <name>: exact match, so "git" does not match "github".
has_server() {
  echo "$1" | tr ',' '\n' | grep -qxF "$2"
}

CLAUDE_SERVERS=$(extract_servers "$CLAUDE_CONFIG")
CURSOR_SERVERS=$(extract_servers "$CURSOR_CONFIG")

echo "=== MCP Config Sync Check ==="
echo "Claude Code (~/.claude.json, user scope): $CLAUDE_SERVERS"
echo "Cursor (~/.cursor/mcp.json)             : $CURSOR_SERVERS"
echo ""

# An absent file is not drift. Say which tool is missing and skip the comparison.
if [ "$CLAUDE_SERVERS" = "(file missing)" ] || [ "$CURSOR_SERVERS" = "(file missing)" ]; then
  [ "$CLAUDE_SERVERS" = "(file missing)" ] && echo "Claude Code config not found, comparison skipped"
  [ "$CURSOR_SERVERS" = "(file missing)" ] && echo "Cursor not installed, comparison skipped"
elif [ "$CLAUDE_SERVERS" = "$CURSOR_SERVERS" ]; then
  echo "Status: IN SYNC"
else
  echo "Status: OUT OF SYNC"
  echo ""
  # Show detailed diff: which servers are where
  ALL_SERVERS=$(echo "$CLAUDE_SERVERS,$CURSOR_SERVERS" | tr ',' '\n' | sort -u | grep -v '^$' | grep -v '(')
  echo "  Server               Claude  Cursor"
  echo "  ------               ------  ------"
  for srv in $ALL_SERVERS; do
    claude_has=" -"
    cur_has=" -"
    has_server "$CLAUDE_SERVERS" "$srv" && claude_has=" Y"
    has_server "$CURSOR_SERVERS" "$srv" && cur_has=" Y"
    printf "  %-20s %s      %s\n" "$srv" "$claude_has" "$cur_has"
  done
fi

exit 0
