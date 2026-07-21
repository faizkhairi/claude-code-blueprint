#!/bin/bash
# Hook: PostToolUse (Write|Edit), warn-only - flags a prose-style violation in
# the file Claude just wrote, so it gets reworded before it ships.
#
# This ships configured for one common policy: no em-dashes and no " -- " ASCII
# substitute, because many teams find they read as machine-generated. It is a
# worked EXAMPLE of a broader pattern: a deterministic style-consistency nudge.
# Swap the character/pattern below for whatever prose rule your team enforces
# (a banned word, a spelling convention, a required phrasing).
#
# Why a hook and not just a written rule: an instruction in your config is
# followed most of the time; a hook fires every time. This one only WARNS
# (exit 0 with a systemMessage), never blocks, since a style slip is cosmetic,
# not a safety risk.
#
# NOTE: PostToolUse hooks only see content that passes through Write/Edit. Text
# you compose in a shell and POST with curl (a heredoc into a PR comment, for
# example) bypasses this hook entirely. For that path, see the companion
# check-no-dash-file.py, which you run explicitly before posting.
#
# JSON parsing uses Python (see hooks/README "Why Python"); fail-open on any
# trouble, so a style check never breaks the session.
#
# (This file necessarily contains the " -- " pattern it detects, in the comment
# above and in the grep below. That is by design: a detector names what it
# detects. Do not "fix" those occurrences.)
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

FILE=$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

# Only inspect text-ish files. Skip binaries, images, and rendered assets.
case "$FILE" in
  *.md|*.markdown|*.txt|*.sh|*.bash|*.json|*.yml|*.yaml|*.html|*.htm|*.css|*.py|*.ts|*.tsx|*.js|*.jsx|*.vue|*.toml|*.ini|*.cfg|*.example|*.gitignore) : ;;
  *) exit 0 ;;
esac

# Em-dash: always a prose violation for this policy. Grep the literal character.
EM_LINES=$(grep -nF "$(printf '\342\200\224')" "$FILE" 2>/dev/null | head -5)

# Prose double-dash: space-dash-dash-space. Exclude obvious code contexts (a CLI
# flag like --word, or text inside a backtick span). Lightweight filter; a few
# false positives are acceptable for a warn.
DD_LINES=$(grep -nE ' -- ' "$FILE" 2>/dev/null | grep -vE '`[^`]*--[^`]*`|--[a-zA-Z]' | head -5)

if [ -z "$EM_LINES" ] && [ -z "$DD_LINES" ]; then
  exit 0
fi

MSG="Style check: '$FILE' contains an em-dash or the '--' substitute. Reword the sentence (period, colon, comma, or parentheses) so no dash is needed."
[ -n "$EM_LINES" ] && MSG="$MSG"$'\n'"em-dash lines: $(printf '%s' "$EM_LINES" | tr '\n' ';')"
[ -n "$DD_LINES" ] && MSG="$MSG"$'\n'"double-dash lines (verify not code): $(printf '%s' "$DD_LINES" | tr '\n' ';')"

# Emit a non-blocking systemMessage. Build JSON with Python to stay safe on quoting.
echo "$MSG" | $PYTHON -c "import sys, json; print(json.dumps({'systemMessage': sys.stdin.read().rstrip(chr(10))}))" 2>/dev/null || true
exit 0
