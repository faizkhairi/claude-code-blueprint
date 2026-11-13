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
# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)

FILE=$(echo "$INPUT" | "$PYTHON" -c "
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

# Prose double-dash: space-dash-dash-space between two words.
# Prose files (.md, .markdown, .txt): judge each occurrence, not the whole line.
# Fenced blocks (``` or ~~~, closed by the same marker at least as long as the opener; a
# fence left open at the end of the file is ignored) are skipped and inline backtick spans are blanked first,
# so `git log -- path` is clean. The old whole-line exclusion (any --flag or any
# backtick span on the line) also hid a real prose dash that shared a line with one.
# The word after the dashes may open with a parenthesis or a quote, and "npm test --
# --coverage" stays clean because the token after the dashes starts with "-".
# Other file types keep the coarse line filter: there a backtick is shell syntax, and
# `git diff --cached -- file` is normal in a script or a comment.
case "$FILE" in
  *.md|*.markdown|*.txt)
    # shellcheck disable=SC2016 # single-quoted Python is intentional: no shell expansion wanted here
    DD_LINES=$("$PYTHON" -c '
import re, sys
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # a cp1252 pipe must not crash on non-ASCII
except Exception:
    pass
CODE = re.compile(r"`[^`]*`")
DASH = re.compile(r"[^\s-] -- [\w(\x22\x27]")
OPEN = re.compile(r"\s*(`{3,}|~{3,})(.*)$")

def fenced(lines):
    # Line indexes inside a closed fenced block. A fence closes on the same marker
    # character with at least the opener length; one still open at the end of the
    # file is not a fence, so its lines are left to be judged as prose.
    skip, start, ch, size = set(), None, "", 0
    for i, line in enumerate(lines):
        m = OPEN.match(line)
        if start is None:
            if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
                start, ch, size = i, m.group(1)[0], len(m.group(1))
        elif m and m.group(1)[0] == ch and len(m.group(1)) >= size and not m.group(2).strip():
            skip.update(range(start, i + 1))
            start = None
    return skip

with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    lines = [l.rstrip("\r\n") for l in fh]
skip, hits = fenced(lines), 0
for i, line in enumerate(lines):
    if i not in skip and DASH.search(CODE.sub("x", line)):
        print("%d:%s" % (i + 1, line))
        hits += 1
        if hits >= 5:
            break
' "$FILE" 2>/dev/null) ;;
  *)
    # shellcheck disable=SC2016 # single-quoted regex is intentional: no shell expansion wanted here
    DD_LINES=$(grep -nE ' -- ' "$FILE" 2>/dev/null | grep -vE '`[^`]*--[^`]*`|--[a-zA-Z]' | head -5) ;;
esac

if [ -z "$EM_LINES" ] && [ -z "$DD_LINES" ]; then
  exit 0
fi

MSG="Style check: '$FILE' contains an em-dash or the '--' substitute. Reword the sentence (period, colon, comma, or parentheses) so no dash is needed."
[ -n "$EM_LINES" ] && MSG="$MSG"$'\n'"em-dash lines: $(printf '%s' "$EM_LINES" | tr '\n' ';')"
[ -n "$DD_LINES" ] && MSG="$MSG"$'\n'"double-dash lines (verify not code): $(printf '%s' "$DD_LINES" | tr '\n' ';')"

# Emit a non-blocking systemMessage. Build JSON with Python to stay safe on quoting.
echo "$MSG" | "$PYTHON" -c "import sys, json; print(json.dumps({'systemMessage': sys.stdin.read().rstrip(chr(10))}))" 2>/dev/null || true
exit 0
