#!/usr/bin/env python3
"""
Sanitizer gate for prose about to be POSTed to an EXTERNAL system (a pull-request
comment, a chat webhook, an issue body) from a shell command.

WHY THIS EXISTS: a PostToolUse style hook (like no-dash-check.sh) only inspects
content that passes through the Write/Edit tools. Composing a message as a shell
heredoc and POSTing it with curl bypasses that hook entirely, so a style policy
you thought was enforced silently is not enforced on that path. This script
closes the gap: pipe the file through here before posting, and refuse to post on
a non-zero exit.

It ships configured for one example policy (no em-dashes / curly quotes / the
'--' em-dash substitute); adapt BANNED_CHARS and DASH_SUB to whatever prose rule
your team enforces.

USAGE:
    python check-no-dash-file.py <file> [<file> ...]
    # exit 0 = all clean, safe to post
    # exit 1 = banned pattern found (prints file + pattern + line); DO NOT POST

BANNED: em-dash, en-dash, curly quotes, ellipsis char, and the ' -- ' / bare '--'
em-dash substitute (arrows '->' and CLI '--flag' are allowed).

The '--' check judges prose only. Text inside a Markdown code span (`like this`) and
inside a closed fenced block (``` or ~~~) is skipped, so a comment that quotes a command such
as `git log -- path` can be posted. The banned characters are checked everywhere,
code or not.

This file necessarily contains the characters it bans (in BANNED_CHARS below and
in this docstring); that is definitional, not a violation. If you point this
script at itself it will report those lines: that is expected. Exclude this file
(and no-dash-check.sh) when scanning your own repo.
"""
import re
import sys

BANNED_CHARS = {
    "—": "em-dash",
    "–": "en-dash",
    "‘": "curly single-open",
    "’": "curly single-close",
    "“": "curly double-open",
    "”": "curly double-close",
    "…": "ellipsis",
}
# ' -- ' between words, or a bare -- token on its own (not --flag, not a->b)
DASH_SUB = re.compile(r"(?:\w\s--\s\w)|(?<!\S)--(?!\S)")
# A line that could open or close a fenced block: a run of 3+ backticks or tildes.
FENCE = re.compile(r"\s*(`{3,}|~{3,})(.*)$")
CODE_SPAN = re.compile(r"`[^`]*`")


def fenced_lines(lines):
    """Indexes of lines inside a closed fenced block, fence lines included.

    A fence closes on the same marker character with at least the opener's length and
    nothing after it. A fence still open at the end of the file is not a fence: its
    lines are left out of the result, so they are judged as prose.
    """
    skip, start, ch, size = set(), None, "", 0
    for i, line in enumerate(lines):
        m = FENCE.match(line)
        if start is None:
            if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
                start, ch, size = i, m.group(1)[0], len(m.group(1))
        elif m and m.group(1)[0] == ch and len(m.group(1)) >= size and not m.group(2).strip():
            skip.update(range(start, i + 1))
            start = None
    return skip


def scan(path):
    problems = []
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    skip = fenced_lines(lines)
    for i, line in enumerate(lines):
        lineno = i + 1
        for ch, name in BANNED_CHARS.items():
            if ch in line:
                problems.append(f"  {path}:{lineno} contains {name} ({ch!r})")
        if i in skip:
            continue
        if DASH_SUB.search(CODE_SPAN.sub(" ", line)):
            problems.append(f"  {path}:{lineno} contains '--' em-dash substitute")
    return problems


def main(argv):
    if len(argv) < 2:
        print("usage: check-no-dash-file.py <file> [<file> ...]", file=sys.stderr)
        return 2
    all_problems = []
    for path in argv[1:]:
        try:
            all_problems.extend(scan(path))
        except OSError as exc:
            print(f"  cannot read {path}: {exc}", file=sys.stderr)
            return 2
    if all_problems:
        print("BANNED CHARACTERS FOUND, do NOT post this content:", file=sys.stderr)
        for p in all_problems:
            print(p, file=sys.stderr)
        print(
            "Rewrite the sentence (period, colon, comma, or parentheses) and re-check.",
            file=sys.stderr,
        )
        return 1
    print("clean: no banned characters")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
