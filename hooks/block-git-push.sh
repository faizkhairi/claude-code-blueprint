#!/bin/bash
# PreToolUse hook (Bash matcher): Blocks git push to protected remotes.
# Purpose: Prevents accidental pushes that could trigger CI/CD pipelines
#          or disrupt teammates mid-pull.
#
# Configuration: Add your protected domains to BLOCKED_DOMAINS below.
# Exit code 2 = deny (blocks the command)
# Exit code 0 = allow

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# Only intercept git push commands
if ! echo "$COMMAND" | grep -qE 'git push'; then
  exit 0
fi

# Configure: add your protected remote domains below
# Example: "internal.example.com" or "gitea.mycompany.com"
BLOCKED_DOMAINS="internal.example.com"

# Check the remote URL of the current repo
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

# Block if remote matches a blocked domain
for DOMAIN in $BLOCKED_DOMAINS; do
  if echo "$REMOTE_URL" | grep -q "$DOMAIN"; then
    echo "Blocked: git push to $DOMAIN is not allowed. Push manually to control CI/CD timing." >&2
    exit 2
  fi
done

# Allow all other remotes
exit 0
