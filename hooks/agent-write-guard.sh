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
#     and the same forms inside `bash -c "..."`. Reads, searches, tests and
#     `2>&1` / `2>/dev/null` stay allowed.
# Under `claude --agent <read-only name>` the whole session is guarded. That is
# intended: the session IS that agent.
#
# Configure: set AGENT_WRITE_GUARD_AGENTS (space-separated names, for example in the
# `env` block of settings.json) to replace the default list below. The defaults are
# the agents this blueprint ships with `permissionMode: plan`. memory-curator is left
# out because it writes its health report outside its memory dir.
#
# Limits, stated plainly: this stops honest mistakes, it is not a sandbox. An
# interpreter that writes a file itself (python -c, node -e), an archive tool, a git
# alias, or text piped into a shell is not seen.
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
            "range-diff", "whatchanged", "help", "version", "check-ignore", "reflog"}
WRITE_CMDS = {"tee", "rm", "rmdir", "mv", "cp", "touch", "mkdir", "truncate", "ln",
              "chmod", "chown", "dd", "install", "unlink", "rsync", "patch", "shred"}
PS_WRITE = {"set-content", "add-content", "out-file", "new-item", "remove-item",
            "move-item", "copy-item", "rename-item", "clear-content", "set-item",
            "set-itemproperty", "tee-object", "del", "erase", "rd", "ri", "move",
            "copy", "cpi", "mi", "ni", "sc", "ac", "ren", "rni"}
PKG = {"npm", "pnpm", "yarn", "bun", "pip", "pip3", "uv", "poetry", "cargo", "gem"}
PKG_SUB = {"install", "i", "add", "remove", "rm", "uninstall", "ci", "update",
           "upgrade", "up", "sync", "link"}
SEPARATORS = {";", "&&", "||", "|", "&", "|&", "(", ")", ";;"}
WRAPPERS = {"sudo", "env", "command", "nohup", "time", "exec", "xargs"}

def unq(t):
    if len(t) >= 2 and t[0] == t[-1] and t[0] in "\"\x27":
        return t[1:-1]
    return t

def tokens(cmd):
    lex = shlex.shlex(cmd.replace("\n", " ; "), posix=False, punctuation_chars=True)
    lex.whitespace_split = True
    try:
        return list(lex)
    except ValueError:            # unbalanced quotes: fall back to a plain split
        return cmd.split()

def check_git(args):
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
    if sub == "config" and any(r in ("--get", "--get-all", "--list", "-l",
                                     "--get-regexp") for r in rest):
        return
    if sub == "worktree" and rest[:1] == ["list"]:
        return
    deny("git %s can change the repository; only read-only git is allowed." % sub)

def check_segment(words, ps):
    while words:
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
            words = words[1:]
        elif unq(words[0]).lower() in WRAPPERS:
            words = words[1:]
            while words and words[0].startswith("-"):
                words = words[1:]           # wrapper options such as xargs -0
        else:
            break
    if not words:
        return
    name = posixpath.basename(unq(words[0]).replace("\\", "/")).lower()
    if name.endswith(".exe"):
        name = name[:-4]
    args = words[1:]
    if name in WRITE_CMDS:
        deny("`%s` writes or removes files." % name)
    if ps and name in PS_WRITE:
        deny("`%s` writes or removes files." % words[0])
    if name in ("sed", "perl") and any(re.match(r"^-[A-Za-z]*i", unq(a)) or
                                       unq(a).startswith("--in-place") for a in args):
        deny("`%s -i` edits files in place." % name)
    if name in PKG and any(unq(a).lower() in PKG_SUB for a in args[:2]):
        deny("`%s %s` changes installed packages." % (name, unq(args[0])))
    if name == "git":
        check_git(args)
    if name in ("bash", "sh", "zsh", "dash") and "-c" in args:
        i = args.index("-c")
        if i + 1 < len(args):
            check_command(unq(args[i + 1]), ps=False)

def check_command(cmd, ps):
    toks = tokens(cmd)
    seg = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if t in SEPARATORS:
            check_segment(seg, ps); seg = []; i += 1; continue
        if t and set(t) <= set("<>&|") and ">" in t:
            nxt = toks[i + 1] if i + 1 < len(toks) else ""
            if t in (">&", "&>") or t.endswith("&"):
                if t != "&>" and re.match(r"^(\d+|-)$", nxt):
                    i += 2; continue        # fd duplication such as 2>&1
            target = unq(nxt)
            if target.lower() in ("/dev/null", "nul", "$null") or allowed_path(target):
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
