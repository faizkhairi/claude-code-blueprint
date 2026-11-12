#!/bin/bash
# Hook: PreToolUse (Write|Edit|MultiEdit|NotebookEdit|Bash|PowerShell) - keeps
# read-only agents read-only.
#
# Why this exists: `permissionMode: plan` in an agent's frontmatter is ignored when
# the main session runs in bypassPermissions, acceptEdits or auto mode (the subagent
# inherits the session's mode), and an agent that sets `memory` gets Write and Edit
# automatically, which `tools:` cannot take away. So "review agents never modify code"
# is prompt text only. A PreToolUse hook runs in every permission mode and its deny is
# honoured in all of them, so this script turns the intent into a boundary.
#
# How it decides: hook input carries `agent_type` when the tool call comes from a
# subagent, or from a session started with `claude --agent <name>` (code.claude.com/
# docs/en/hooks, common input fields). With no agent_type (the normal main thread), or
# an agent that is not in the read-only list, it exits silently. A listed agent:
#   - Write/Edit/MultiEdit/NotebookEdit: allowed only inside its own memory dir
#     (~/.claude/agent-memory/<name>/, .claude/agent-memory/<name>/ or
#     .claude/agent-memory-local/<name>/), denied anywhere else.
#   - Bash/PowerShell: denied on a redirect into a file (> or >>, except /dev/null
#     and its memory dir), tee, sed -i, perl -i, rm/mv/cp/touch/mkdir and similar,
#     package installs, git beyond a read-only allowlist (status, log, diff, show,
#     blame, fetch, list forms of branch/tag/remote/stash, ...), PowerShell write cmdlets,
#     find -delete/-exec, and the same forms inside `bash -c`/`-lc`, `eval`,
#     `pwsh -Command`, `cmd /c`, loops and if bodies, and after wrappers such as
#     xargs, env, sudo and timeout. Reads, searches, tests and `2>&1` / `2>/dev/null`
#     stay allowed. git fetch is allowed: it moves remote-tracking refs only.
# Under `claude --agent <read-only name>` the whole session is guarded. That is
# intended: the session IS that agent.
#
# Configure: set AGENT_WRITE_GUARD_AGENTS (space-separated names, for example in the
# `env` block of settings.json) to replace the default list below. The defaults are
# the agents this blueprint ships with `permissionMode: plan`. memory-curator is left
# out because it writes its health report outside its memory dir.
#
# Limits, stated plainly: this stops honest mistakes, it is not a sandbox. An
# interpreter that writes a file itself (python -c, node -e), a download tool
# (curl -o, wget), an archive tool, a git alias, a script file run by name, or text
# piped into a shell is not seen.
#
# Fail-open trade-off: without Python, or on input that is not valid JSON, the hook
# exits 0 with no decision, so the call goes through unchecked. That matches every
# other hook here (a missing dependency never blocks work), and Claude Code always
# sends valid JSON, so in practice only a missing Python disables the guard. The
# missing-Python case prints a warning on stderr so it is visible in debug output.
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "agent-write-guard: Python not found, read-only agents are NOT guarded" >&2
  exit 0
fi

DEFAULT_AGENTS="verify-plan code-reviewer security-reviewer architecture-reviewer db-analyst devops-engineer"
export AGENT_WRITE_GUARD_LIST="${AGENT_WRITE_GUARD_AGENTS:-$DEFAULT_AGENTS}"

# The Python below is single-quoted on purpose: bash must not expand anything in it.
# shellcheck disable=SC2016
"$PYTHON" -c '
import json, os, posixpath, re, shlex, sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

agent = data.get("agent_type") or ""
if not agent or agent not in os.environ.get("AGENT_WRITE_GUARD_LIST", "").split():
    sys.exit(0)

tool = data.get("tool_name") or ""
tin = data.get("tool_input") or {}
if not isinstance(tin, dict):
    sys.exit(0)

FOLD = os.name == "nt" or sys.platform == "darwin"   # case-insensitive filesystems

def norm(p, base=""):
    """Absolute, forward-slash, .. resolved. Pure string work, no filesystem access."""
    p = (p or "").strip().replace("\\", "/")
    home = os.environ.get("HOME") or os.path.expanduser("~")
    if p == "~" or p.startswith("~/"):
        p = home.replace("\\", "/") + p[1:]
    m = re.match(r"^/([A-Za-z])(/|$)", p)          # Git Bash /c/... form
    if m:
        p = m.group(1) + ":/" + p[3:]
    drive = ""
    m = re.match(r"^([A-Za-z]):(/.*)?$", p)
    if m:
        drive, p = m.group(1) + ":", m.group(2) or "/"
    elif not p.startswith("/"):
        b = norm(base) if base else "/"
        return norm(b.rstrip("/") + "/" + p)
    p = drive + posixpath.normpath(p)
    return p.lower() if (FOLD or drive) else p

cwd = data.get("cwd") or os.getcwd()
project = os.environ.get("CLAUDE_PROJECT_DIR") or cwd
home = os.environ.get("HOME") or os.path.expanduser("~")
roots = {norm(r) for r in (
    home.replace("\\", "/") + "/.claude/agent-memory/" + agent,
    project.replace("\\", "/") + "/.claude/agent-memory/" + agent,
    project.replace("\\", "/") + "/.claude/agent-memory-local/" + agent,
    cwd.replace("\\", "/") + "/.claude/agent-memory/" + agent,
    cwd.replace("\\", "/") + "/.claude/agent-memory-local/" + agent,
)}

def allowed_path(p):
    n = norm(p, cwd)
    return any(n == r or n.startswith(r + "/") for r in roots)

def deny(why):
    msg = ("agent-write-guard: %s is a read-only agent, so %s It may write only in its "
           "own memory dir (~/.claude/agent-memory/%s/). Report the change in your final "
           "message so the caller can apply it." % (agent, why, agent))
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
        "permissionDecision": "deny", "permissionDecisionReason": msg}}))
    sys.exit(0)

if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    target = tin.get("file_path") or tin.get("notebook_path") or ""
    if target and not allowed_path(target):
        deny("%s on %s is blocked." % (tool, target))
    sys.exit(0)

if tool not in ("Bash", "PowerShell"):
    sys.exit(0)

GIT_READ = {"status", "log", "show", "diff", "blame", "grep", "ls-files", "ls-tree",
            "rev-parse", "rev-list", "cat-file", "describe", "shortlog", "fetch",
            "merge-base", "for-each-ref", "show-ref", "ls-remote", "name-rev",
            "range-diff", "whatchanged", "help", "version", "check-ignore", "reflog",
            "diff-tree", "diff-index", "diff-files", "cherry", "count-objects", "var",
            "verify-commit", "verify-tag"}
WRITE_CMDS = {"tee", "rm", "rmdir", "mv", "cp", "touch", "mkdir", "truncate", "ln",
              "chmod", "chown", "dd", "install", "unlink", "rsync", "patch", "shred"}
PS_WRITE = {"set-content", "add-content", "out-file", "new-item", "remove-item",
            "move-item", "copy-item", "rename-item", "clear-content", "set-item",
            "set-itemproperty", "tee-object", "export-csv", "export-clixml", "set-acl",
            "del", "erase", "rd", "ri", "move", "copy", "cpi", "mi", "ni", "sc", "ac",
            "ren", "rni", "epcsv"}
PKG = {"npm", "pnpm", "yarn", "bun", "pip", "pip3", "uv", "poetry", "cargo", "gem"}
PKG_SUB = {"install", "i", "add", "remove", "rm", "uninstall", "ci", "update",
           "upgrade", "up", "sync", "link"}
# Shell words that come before a command without being one (if x; then rm y; fi).
KEYWORDS = {"if", "then", "do", "else", "elif", "while", "until", "{", "}", "!",
            "fi", "done", "esac"}
# Prefix commands, with the options of each that take a value (xargs -I {} rm {}).
WRAPPERS = {"sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "--user",
                     "--group", "--chdir"},
            "doas": {"-u", "-C"},
            "env": {"-u", "-C", "-S", "--unset", "--chdir", "--split-string"},
            "xargs": {"-I", "-i", "-L", "-l", "-n", "-P", "-s", "-d", "-E", "-e", "-a",
                      "--arg-file", "--delimiter", "--max-args", "--max-procs",
                      "--replace", "--max-lines"},
            "timeout": {"-s", "-k", "--signal", "--kill-after"},
            "nice": {"-n", "--adjustment"}, "ionice": {"-c", "-n", "-p"},
            "stdbuf": set(), "setsid": set(), "nohup": set(), "command": set(),
            "time": {"-f", "--format"}, "exec": {"-a"}}
SAFE_TARGETS = {"/dev/null", "/dev/stdout", "/dev/stderr", "nul", "$null"}

def unq(t):
    if len(t) >= 2 and t[0] == t[-1] and t[0] in "\"\x27":
        return t[1:-1]
    return t

def is_sep(t):
    return bool(t) and set(t) <= set(";&|()")

def open_quote(s):
    q = ""
    for c in s:
        if q:
            if c == q:
                q = ""
        elif c in "\"\x27":
            q = c
    return bool(q)

def tokens(cmd):
    cmd = cmd.replace("\r", "").replace("\n", " ; ")
    lex = shlex.shlex(cmd, posix=False, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""           # comments are handled in check_command, per word
    try:
        toks = list(lex)
    except ValueError:            # unbalanced quotes: split on shell punctuation only
        return re.findall(r"[;&|()<>]+|[^\s;&|()<>]+", cmd)
    # posix=False opens a quote only at the start of a word, so --grep="a > b" comes
    # back in pieces. Glue the pieces until the quotes balance again.
    out = []
    for t in toks:
        if out and open_quote(out[-1]):
            out[-1] += " " + t
        else:
            out.append(t)
    return out

def check_git(args):
    if any(unq(a).startswith("--output") for a in args):
        deny("git --output writes a file.")
    i = 0
    while i < len(args):
        a = unq(args[i])
        if a in ("-C", "--git-dir", "--work-tree", "--namespace"):
            i += 2; continue
        if a == "-c" or a.startswith("-c") or a.startswith("--config"):
            deny("git -c can run arbitrary programs and is blocked.")
        if a.startswith("-"):
            i += 1; continue
        break
    sub = unq(args[i]) if i < len(args) else ""
    rest = [unq(x) for x in args[i + 1:]]
    if sub in GIT_READ or sub == "":
        return
    if sub in ("branch", "tag"):
        changes = {"-d", "-D", "--delete", "-m", "-M", "--move", "-c", "-C", "--copy",
                   "-f", "--force", "-u", "--set-upstream-to", "--unset-upstream",
                   "--edit-description", "-t", "--track", "--no-track"}
        if sub == "tag":
            changes |= {"-a", "--annotate", "-s", "--sign", "-m", "-F", "--file"}
        listing = {"-l", "--list", "--contains", "--no-contains", "--merged",
                   "--no-merged", "--points-at", "--format", "--sort"}
        positional = [r for r in rest if not r.startswith("-")]
        if not any(r.split("=")[0] in changes for r in rest) and (
                not positional or any(r.split("=")[0] in listing for r in rest)):
            return
    if sub == "stash" and rest[:1] in (["list"], ["show"]):
        return
    if sub == "remote" and (not rest or rest[0] in ("-v", "--verbose", "show", "get-url")):
        return
    if sub == "config":
        if any(r in ("--get", "--get-all", "--list", "-l", "--get-regexp") for r in rest):
            return
        writes = {"--add", "--unset", "--unset-all", "--replace-all", "--rename-section",
                  "--remove-section", "-e", "--edit", "set", "unset"}
        if not any(r.split("=")[0] in writes for r in rest) and \
                len([r for r in rest if not r.startswith("-")]) <= 1:
            return                          # git config <key> only reads it
    if sub in ("worktree", "submodule") and rest[:1] in (["list"], ["status"]):
        return
    deny("git %s can change the repository; only read-only git is allowed." % sub)

def check_segment(words, ps):
    while words:
        w = unq(words[0]).lower()
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]) or w in KEYWORDS:
            words = words[1:]
        elif w == "command" and len(words) > 1 and unq(words[1]) in ("-v", "-V"):
            return                          # command -v NAME only looks NAME up
        elif w in WRAPPERS:
            opts = WRAPPERS[w]
            words = words[1:]
            while words and unq(words[0]).startswith("-"):
                raw = unq(words[0])
                words = words[1:]
                if raw.split("=")[0] in opts and "=" not in raw and words:
                    words = words[1:]       # the option value, as in xargs -I {}
            if w == "timeout" and words:
                words = words[1:]           # the duration
        else:
            break
    if not words:
        return
    name = posixpath.basename(unq(words[0]).replace("\\", "/")).lower()
    if name.endswith(".exe"):
        name = name[:-4]
    args = words[1:]
    uargs = [unq(a) for a in args]
    if name in WRITE_CMDS:
        deny("`%s` writes or removes files." % name)
    if ps and name in PS_WRITE:
        deny("`%s` writes or removes files." % words[0])
    if ps and any(a.lower() == "-outfile" for a in uargs):
        deny("`-OutFile` writes a file.")
    if name in ("sed", "perl") and any(re.match(r"^-[A-Za-z]*i", a) or
                                       a.startswith("--in-place") for a in uargs):
        deny("`%s -i` edits files in place." % name)
    if name in PKG and any(a.lower() in PKG_SUB for a in uargs[:2]):
        deny("`%s %s` changes installed packages." % (name, uargs[0]))
    if name in PKG and uargs[:1] == ["audit"] and "fix" in uargs:
        deny("`%s audit fix` changes installed packages." % name)
    if name == "yarn" and not uargs:
        deny("a bare `yarn` installs packages.")
    if name == "git":
        check_git(args)
    if name == "find":
        for i, a in enumerate(uargs):
            if a == "-delete" or a.startswith("-fprint") or a == "-fls":
                deny("`find %s` writes or removes files." % a)
            if a in ("-exec", "-execdir", "-ok", "-okdir"):
                check_segment(args[i + 1:], ps)
    if name == "eval":
        check_command(" ".join(uargs), ps=False)
    if name in ("bash", "sh", "zsh", "dash", "ksh"):
        for i, a in enumerate(uargs):       # -c, or -c inside combined flags (-lc, -ec)
            if re.match(r"^-[A-Za-z]*c[A-Za-z]*$", a):
                if i + 1 < len(uargs):
                    check_command(uargs[i + 1], ps=False)
                break
    if name in ("pwsh", "powershell"):
        for i, a in enumerate(uargs):
            low = a.lower()
            if low in ("-e", "-ec", "-encodedcommand", "-enc"):
                deny("an encoded PowerShell command cannot be checked.")
            if re.match(r"^-c(o(m(m(a(n(d)?)?)?)?)?)?$", low):
                check_command(" ".join(uargs[i + 1:]), ps=True)
                break
    if name == "cmd":
        for i, a in enumerate(uargs):
            if a.lower() in ("/c", "/k"):
                check_command(" ".join(uargs[i + 1:]), ps=True)
                break

def check_command(cmd, ps):
    toks = tokens(cmd)
    seg = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if is_sep(t):
            check_segment(seg, ps); seg = []; i += 1; continue
        if t.startswith("#"):               # a comment runs to the end of the line
            while i < len(toks) and not is_sep(toks[i]):
                i += 1
            continue
        if t and set(t) <= set("<>&|") and ">" in t:
            nxt = toks[i + 1] if i + 1 < len(toks) else ""
            if t in (">&", "&>") or t.endswith("&"):
                if t != "&>" and re.match(r"^(\d+|-)$", nxt):
                    i += 2; continue        # fd duplication such as 2>&1
            target = unq(nxt)
            if target.lower() in SAFE_TARGETS or allowed_path(target):
                i += 2; continue
            deny("the shell redirect into %s writes a file." % (target or "a file"))
        if t and set(t) <= set("<>&|"):
            i += 1; continue                # input redirect or heredoc marker
        seg.append(t)
        i += 1
    check_segment(seg, ps)

command = tin.get("command") or ""
if isinstance(command, str) and command.strip():
    check_command(command, ps=(tool == "PowerShell"))
sys.exit(0)
' 2>/dev/null
exit 0
