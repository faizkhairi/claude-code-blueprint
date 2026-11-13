#!/bin/bash
# Hook: PreToolUse (Write|Edit|MultiEdit|NotebookEdit|Bash|PowerShell|Monitor) - keeps
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
#   - Bash/PowerShell/Monitor (Monitor is judged by its `command`, like Bash): denied on
#     a redirect into a file (> or >>, except /dev/null and its memory dir), tee, sed -i,
#     perl -i, mv/ln/chmod and similar, rm/cp/touch/mkdir unless every target is in its
#     memory dir, curl -o/-O, wget and sort -o unless the target is in its memory dir,
#     package installs and runners (npm, pnpm, yarn, bun, pip, uv, cargo, npx, bunx,
#     pnpm dlx, python -m pip, ...), git beyond a read-only allowlist (status, log, diff,
#     show, blame, fetch, list forms of branch/tag/remote/stash, ...), any GIT_ variable
#     set on the command, PowerShell write cmdlets and [IO.File]:: writes, find
#     -delete/-exec, and the same forms inside `bash -c`/`-lc`, `eval`, `pwsh -Command`,
#     `cmd /c`, $(...) and backticks (also inside double quotes), loops and if bodies,
#     a heredoc fed to a shell, and after wrappers such as xargs, env, sudo and timeout.
#     A heredoc body is text only for the plain one-line shape `<reader> [args] <<[-]DELIM`
#     (a reader is cat, grep, egrep, fgrep, head, tail, wc, jq, sort, less, more, nl or `:`;
#     DELIM may be quoted, and so may the receiver word), optionally followed by > file or
#     >> file, and nothing else, with a delimiter that closes. The text before << has no
#     ( ) $ backtick backslash | ; & < or quote, and no line ends in a backslash (a
#     continuation can hide a pipe). Every other shape (a shell, tee, an interpreter, an
#     escaped or variable receiver, a heredoc inside $(...), <(...) or backticks, a pipe or
#     a second command on the line, `<<` inside $[...] or a[...]= arithmetic) means the body
#     is judged as commands, as bash may run it. The $(...), ${...} and backticks of an
#     unquoted body that is text are judged too. Nothing is counted: a decoy quote or
#     parenthesis cannot change the verdict, because any of them makes the shape not plain.
#     $HOME, ${HOME}, "$HOME"/... and ~ expand in a target path. A memory-dir target
#     must be a plain path (no quote, backslash, $, glob, brace, `..` component, or a
#     comma in PowerShell), the allowance never applies under xargs, parallel or find
#     -exec, and cp takes only -r -R -p -f -v -n and -t. Reads, searches, tests and
#     `2>&1` / `2>/dev/null` stay allowed. git fetch is allowed (it moves remote-tracking
#     refs only) without --upload-pack or --recurse-submodules. `GIT_TERMINAL_PROMPT=0`
#     is denied like any GIT_ variable (the hook cannot tell the harmless ones apart).
# Under `claude --agent <read-only name>` the whole session is guarded. That is
# intended: the session IS that agent.
#
# Configure: set AGENT_WRITE_GUARD_AGENTS (space-separated names, for example in the
# `env` block of settings.json) to replace the default list below. The defaults are
# the agents this blueprint ships with `permissionMode: plan`. memory-curator is left
# out because it writes its health report outside its memory dir.
#
# Command names are matched on the bare name (a directory, a leading backslash, quotes and
# .exe are removed), so /usr/bin/xargs and \xargs are wrappers. env -S, --split and any
# prefix of --split-string judge the split string together with the words after it. The
# bodies of <(...) and >(...) are commands. Wrappers include sudo, doas, env, xargs,
# parallel, timeout, nice, ionice, chrt, taskset, stdbuf, busybox, setsid, nohup and time;
# watch and script -c run a command string, which is judged. flock, robocopy, xcopy,
# Expand-Archive and Compress-Archive count as writes, and so do `rg --pre`, `npm config
# set|delete|edit`, `npm cache clean`, `npm pack`, `cargo fmt` (without --check) and a
# PowerShell .Delete(, .MoveTo( or .CopyTo( call. cp refuses a bare --preserve and one with mode or all.
#
# Limits, stated plainly: this stops honest mistakes, it is not a sandbox. An
# interpreter that writes a file itself (python -c, node -e, a heredoc fed to python),
# a script file run by name, an archive tool, a git alias, a curl -K config file (denied
# unseen), `curl --output-dir`, tools that name an output as a later operand (uniq in
# out), other launchers (strace, chroot, unshare, nsenter, systemd-run, su -c), or text
# piped into a shell from anything but a heredoc is not seen. A path is judged as text: a
# symlink inside the memory dir, a variable other than HOME and a `cd` before a relative
# path are not followed (an unresolved one is denied), and a HOME that the same command
# reassigns is not modelled. A file copied into the memory dir keeps its mode, so a copied
# executable stays executable. A heredoc is data only for a reader that does not run its
# input, but `less !cmd` runs a command when a person types it. Comment parsing follows
# bash; $'...' escapes and PowerShell backtick escapes are not modelled. Monitor is
# covered here, but the
# settings matcher must route it to this script: add Monitor to the matcher if your Claude
# Code version does not already run a Bash entry for Monitor commands.
#
# Fail-open trade-off: without Python, or on input that is not valid JSON, the hook
# exits 0 with no decision, so the call goes through unchecked. That matches every
# other hook here (a missing dependency never blocks work), and Claude Code always
# sends valid JSON, so in practice only a missing Python disables the guard. The
# missing-Python case prints a warning on stderr so it is visible in debug output.
# It fails closed for a guarded agent when the checker itself breaks: an uncaught error
# in the Python (such as deeply nested input) or a Python that cannot start (no temp file
# and an argument list too long for -c) prints a deny. The input is read as bytes and
# decoded as UTF-8, so a non-ASCII command cannot make the decode fail and let it through.
# A heredoc fed to an interpreter (python <<EOF), or to a reader on a line that is not the
# plain shape, is judged as shell commands, so a body with shell-looking text can be denied
# wrongly. Test seam: AGENT_WRITE_GUARD_TEST_NO_CHECKER=1 makes Python fail to start, to
# prove the deny path; never set it outside the tests.
# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then
  echo "agent-write-guard: Python not found, read-only agents are NOT guarded" >&2
  exit 0
fi

DEFAULT_AGENTS="verify-plan code-reviewer security-reviewer architecture-reviewer db-analyst devops-engineer"
export AGENT_WRITE_GUARD_LIST="${AGENT_WRITE_GUARD_AGENTS:-$DEFAULT_AGENTS}"

# The Python source sits in a quoted heredoc, so bash expands nothing in it. It is too long
# for a safe command line (a Windows one tops out near 32 KB), so it runs from a temp file,
# in isolated mode (-I: no script directory or PYTHON* variables on the import path). When no
# temp file can be made it falls back to -c. Do not add a line that holds only PYEOF to
# the Python source.
PY_SRC=$(cat <<'PYEOF'
import json, os, posixpath, re, shlex, sys

try:
    data = json.loads(sys.stdin.buffer.read().decode("utf-8", errors="replace"))
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

agent = data.get("agent_type") or ""
if not agent or agent not in os.environ.get("AGENT_WRITE_GUARD_LIST", "").split():
    sys.exit(0)

def _fail_closed(*_):
    """Any uncaught error (RecursionError on deeply nested input, MemoryError, a parser bug)
    must not turn into a silent allow for a guarded agent."""
    try:
        msg = ("agent-write-guard: this command could not be checked, so it is blocked for the "
               "read-only agent %s. Simplify it, or report the change in your final message." % agent)
        sys.stdout.write(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
            "permissionDecision": "deny", "permissionDecisionReason": msg}}) + "\n")
        sys.stdout.flush()
    finally:
        os._exit(0)
sys.excepthook = _fail_closed

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

if tool not in ("Bash", "PowerShell", "Monitor"):
    sys.exit(0)

GIT_READ = {"status", "log", "show", "diff", "blame", "grep", "ls-files", "ls-tree",
            "rev-parse", "rev-list", "cat-file", "describe", "shortlog", "fetch",
            "merge-base", "for-each-ref", "show-ref", "ls-remote", "name-rev",
            "range-diff", "whatchanged", "help", "version", "check-ignore", "reflog",
            "diff-tree", "diff-index", "diff-files", "cherry", "count-objects", "var",
            "verify-commit", "verify-tag"}
WRITE_CMDS = {"tee", "rm", "rmdir", "mv", "cp", "touch", "mkdir", "truncate", "ln",
              "chmod", "chown", "dd", "install", "unlink", "rsync", "patch", "shred",
              "robocopy", "xcopy", "flock"}
PS_WRITE = {"set-content", "add-content", "out-file", "new-item", "remove-item",
            "move-item", "copy-item", "rename-item", "clear-content", "set-item",
            "set-itemproperty", "tee-object", "export-csv", "export-clixml", "set-acl",
            "del", "erase", "rd", "ri", "move", "copy", "cpi", "mi", "ni", "sc", "ac",
            "ren", "rni", "epcsv", "expand-archive", "compress-archive",
            "robocopy", "xcopy"}
PKG = {"npm", "pnpm", "yarn", "bun", "pip", "pip3", "pipx", "uv", "poetry", "cargo", "gem"}
PKG_SUB = {"install", "i", "add", "remove", "rm", "uninstall", "ci", "update",
           "upgrade", "up", "sync", "link", "un", "unlink", "r", "ln"}
# Subcommands that only read. The word scan stops at one, so a later word such as the
# argument of `npm view x add` is not mistaken for a subcommand.
PKG_STOP = {"run", "run-script", "rum", "urn", "test", "t", "tst", "start", "stop", "restart",
            "view", "info", "show", "v", "ls", "list", "la", "ll", "outdated", "search", "s",
            "se", "find", "help", "config", "c", "get", "whoami", "ping", "doctor", "explain",
            "why", "fund", "bugs", "docs", "home", "repo", "root", "prefix", "bin", "cache",
            "diff", "pack", "audit", "completion", "query", "sbom", "freeze", "check",
            "inspect", "hash", "debug", "build", "tree", "metadata", "bench", "fmt", "clippy",
            "doc"}
# Subcommands that change packages, project files or the registry for one manager only.
PKG_EXTRA = {
    "npm": {"version", "pkg", "publish", "init", "create", "exec", "x", "unpublish",
            "deprecate", "dist-tag", "rebuild", "prune", "dedupe", "install-test", "it",
            "cit", "install-ci-test", "in", "ins", "inst", "insta", "instal", "isnt", "isnta",
            "isntal", "isntall", "udpate", "clean-install", "ic", "install-clean",
            "isntall-clean", "uni", "unlink", "rb", "set", "dedup", "find-dupes", "ddp"},
    "pnpm": {"dlx", "create", "publish", "version", "init", "rebuild", "prune", "dedupe",
             "import", "patch", "patch-commit", "patch-remove", "deploy", "self-update",
             "setup", "approve-builds", "install-test", "it", "uni", "unlink", "rb"},
    "yarn": {"dlx", "create", "publish", "version", "init", "set", "upgrade-interactive",
             "import", "unplug", "patch", "patch-commit", "plugin", "rebuild", "dedupe",
             "autoclean", "unlink"},
    "bun": {"x", "create", "publish", "init", "a", "patch", "build", "upgrade", "unlink"},
    "pip": {"download", "wheel"}, "pip3": {"download", "wheel"},
    "pipx": {"run", "inject", "reinstall", "reinstall-all", "upgrade-all", "uninstall-all"},
    "uv": {"init", "lock", "venv", "publish", "build", "tool"},
    "poetry": {"init", "new", "lock", "publish", "build", "self"},
    "cargo": {"publish", "new", "init", "clean", "fix", "yank", "login", "owner"},
}
# Options of each manager that take a value, so the subcommand is the first word after them
# (npm --prefix . install x).
PKG_VALUE = {
    "npm": {"--prefix", "--workspace", "-w", "--registry", "--cache", "--userconfig",
            "--globalconfig", "--loglevel", "--tag", "--otp", "--scope", "--location",
            "--omit", "--include", "--before", "--maxsockets", "--fetch-retries",
            "--fetch-timeout", "--proxy", "--https-proxy", "--node-options", "--script-shell",
            "--audit-level", "--install-strategy", "--ca", "--cafile", "--cert", "--key",
            "--noproxy", "--user-agent", "--message", "-m", "--tag-version-prefix",
            "--init-module", "--logs-dir", "--logs-max", "--umask", "--searchlimit",
            "--access", "--auth-type", "--cpu", "--os", "--libc", "--fetch-retry-factor",
            "--fetch-retry-mintimeout", "--fetch-retry-maxtimeout"},
    "pnpm": {"--filter", "-F", "--dir", "-C", "--registry", "--loglevel", "--reporter",
             "--store-dir", "--workspace-dir", "--config"},
    "yarn": {"--cwd", "--registry", "--cache-folder", "--modules-folder", "--link-folder",
             "--network-timeout", "--mutex", "--proxy", "--https-proxy", "--use-yarnrc"},
    "bun": {"--cwd", "-c", "--config", "--registry", "--cache-dir", "--backend"},
    "pip": {"--index-url", "-i", "--extra-index-url", "--target", "-t", "-r", "--requirement",
            "--proxy", "--cache-dir", "--python", "--log", "--retries", "--timeout",
            "--trusted-host", "-c", "--constraint", "--cert", "--client-cert",
            "--exists-action"},
    "uv": {"--directory", "--project", "--python", "-p", "--index-url", "--config-file",
           "--cache-dir", "--color"},
    "poetry": {"--directory", "-C", "--project", "-P"},
    "cargo": {"--manifest-path", "--target-dir", "--color", "--config", "-Z", "--registry",
              "-C", "--message-format"},
    "gem": {"--source", "-s", "--config-file", "--platform"},
}
PKG_VALUE["pip3"] = PKG_VALUE["pip"]
# Commands that fetch and run a registry package.
RUNNERS = {"npx", "bunx", "pnpx", "uvx"}
# Commands judged by target: allowed when every path they write is in the agent own memory
# dir. (flag letters, long flags, value letters, long options that take a value)
MEM_CMDS = {
    "rm": ("rRfivdI", {"recursive", "force", "verbose", "dir", "interactive",
                       "no-preserve-root", "preserve-root", "one-file-system"}, "", set()),
    "mkdir": ("pv", {"parents", "verbose"}, "m", {"mode"}),
    "touch": ("acmh", {"no-create", "no-dereference"}, "dtr", {"date", "reference", "time"}),
    # cp takes only a small safe flag set: no -s or -l (they make links), no -a or --parents.
    "cp": ("rRpfvn", {"recursive", "force", "verbose", "no-clobber", "preserve"},
           "t", {"target-directory"}),
}
# Commands that only read their heredoc. A heredoc body is text only when its receiver is one
# of these and the heredoc line has the plain shape heredoc_is_data describes; any other
# receiver or shape (a shell, tee, a variable name, an interpreter, a pipe) means the body is
# judged as commands.
READERS = {":", "cat", "grep", "egrep", "fgrep", "head", "tail", "wc", "jq", "sort", "less",
           "more", "nl"}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "pwsh", "powershell", "cmd", "source", "."}
PS_SHELLS = {"pwsh", "powershell", "cmd"}
GIT_VAR = re.compile(r"^GIT_[A-Za-z0-9_]*=", re.I)
GIT_DENY = ("setting a GIT_ variable on the command is blocked: GIT_SSH_COMMAND, GIT_PAGER, "
            "GIT_EXTERNAL_DIFF and others make git run a program, and the guard cannot tell "
            "the harmless ones (GIT_TERMINAL_PROMPT=0 too) apart. Set it in the environment "
            "instead.")
# Commands that append their own operands to the words after them (xargs rm), so a path they
# are given cannot be judged here.
APPENDING = {"xargs", "parallel"}
PS_FILE_WRITE = re.compile(
    r"\[(?:system\.)?io\.(?:file|directory)\]\s*::\s*(?:write|append|create|open(?!text|read)"
    r"|copy|move|delete|replace|set)|\bstreamwriter\b|\bio\.filestream\b"
    r"|\bio\.fileinfo\b[\s\S]*?\.\s*(?:create|open)\s*\("
    r"|\.\s*(?:delete|moveto|copyto|openwrite|createtext|appendtext)\s*\(", re.I)
PS_GIT_ENV = re.compile(
    r"\$env:GIT_\w*\s*=(?!=)|SetEnvironmentVariable\s*\(\s*[\"\x27]GIT_", re.I)
HOME_VAR = re.compile(r"^\$(\{HOME\}|HOME)(?=/|$)")
# "$HOME"/x reads as $HOME/x: the tokenizer would split it after the closing quote.
QHOME_SUB = re.compile(r"\"\$(?:HOME|\{HOME\})\"(?=/)")
# Shell words that come before a command without being one (if x; then rm y; fi).
KEYWORDS = {"if", "then", "do", "else", "elif", "while", "until", "{", "}", "!",
            "fi", "done", "esac"}
# Prefix commands, with the options of each that take a value (xargs -I {} rm {}).
WRAPPERS = {"sudo": {"-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "--user",
                     "--group", "--chdir"},
            "doas": {"-u", "-C"},
            "env": {"-u", "-C", "--unset", "--chdir"},
            "parallel": {"-j", "-a", "-S", "-N", "-n", "-L", "-I", "--jobs", "--arg-file",
                         "--sshlogin"},
            # -i, -l, -e and their long forms take an attached optional value only.
            "xargs": {"-I", "-L", "-n", "-P", "-s", "-d", "-E", "-a",
                      "--arg-file", "--delimiter", "--max-args", "--max-procs",
                      "--max-chars"},
            "timeout": {"-s", "-k", "--signal", "--kill-after"},
            "chrt": {"-T", "-P", "-D"}, "taskset": set(), "busybox": set(),
            "nice": {"-n", "--adjustment"}, "ionice": {"-c", "-n", "-p"},
            "stdbuf": {"-i", "-o", "-e", "--input", "--output", "--error"}, "setsid": set(), "nohup": set(), "command": set(),
            "time": {"-f", "--format"}, "exec": {"-a"}}
SAFE_TARGETS = {"/dev/null", "/dev/stdout", "/dev/stderr", "nul", "$null"}

def unq(t):
    if len(t) >= 2 and t[0] == t[-1] and t[0] in "\"\x27":
        return t[1:-1]
    return t

def shell_path(raw):
    """The path a shell word names. $HOME and ${HOME} expand (not inside single quotes), ~
    expands only unquoted, and a quoted $ or ~ stays literal text."""
    t = unq(raw)
    q = raw[:1] if raw[:1] in ("\"", "\x27") else ""
    if q == "\x27" or (q and t.startswith("~")):
        return "./" + t if t[:1] in ("~", "$") else t
    m = HOME_VAR.match(t)
    if m:
        return "~" + t[m.end():]
    return t

def shell_ok(raw, ps=False):
    """True when a shell word names a path inside the agent own memory dir. Only a plain
    path is judged: a quote, backslash (bash), $ (after the leading HOME), glob character,
    brace, backtick, a comma (PowerShell: it makes a list) or a .. component makes the word
    unresolvable here, so it is not allowed."""
    t = shell_path(raw)
    if re.search(r"[{}`$\"\x27*?\[]", t) or (ps and "," in t) or (not ps and "\\" in t):
        return False
    if ".." in re.split(r"[\\/]+", t):
        return False
    return allowed_path(t)

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

def subst_bodies(s, ps):
    """The text inside $(...), for bash <(...) and >(...) and backticks, outside single quotes.
    Quoted substitutions count: bash runs echo "$(rm x)". Nested ones are found when a body is
    judged."""
    out, q, i, n = [], "", 0, len(s)
    while i < n:
        c = s[i]
        if c == "\\" and q != "\x27" and not ps:
            i += 2; continue
        if q == "\x27":
            if c == "\x27":
                q = ""
        elif c == "\x27" and not q:
            q = "\x27"
        elif c == "\"":
            q = "" if q == "\"" else "\""
        elif c == "`" and not ps:
            j = i + 1
            while j < n and s[j] != "`":
                j += 2 if s[j] == "\\" else 1
            out.append(s[i + 1:j]); i = j
        elif s[i + 1:i + 2] == "(" and (c == "$" or (c in "<>" and not q and not ps)):
            # $(...), and the <(...) and >(...) of bash, run their body as a command
            depth, j, iq = 1, i + 2, ""
            while j < n and depth:
                d = s[j]
                if d == "\\" and iq != "\x27" and not ps:
                    j += 2; continue
                if iq:
                    if d == iq:
                        iq = ""
                elif d in "\"\x27":
                    iq = d
                elif d == "(":
                    depth += 1
                elif d == ")":
                    depth -= 1
                j += 1
            out.append(s[i + 2:j - 1] if depth == 0 else s[i + 2:]); i = j - 1
        i += 1
    return out

def heredoc_delim(s, i):
    """Parse what follows << at s[i]: (delimiter, quoted, strip_tabs), or None."""
    n = len(s)
    strip = s[i:i + 1] == "-"
    if strip:
        i += 1
    while i < n and s[i] in " \t":
        i += 1
    word, quoted, q = [], False, ""
    while i < n:
        c = s[i]
        if q:
            if c == q:
                q = ""
            else:
                word.append(c)
        elif c in "\"\x27":
            q = c; quoted = True
        elif c == "\\" and i + 1 < n:
            quoted = True; word.append(s[i + 1]); i += 1
        elif c in " \t\n;&|()<>":
            break
        else:
            word.append(c)
        i += 1
    return ("".join(word), quoted, strip) if word else None

def subst_raw(s):
    """The $(...), ${...} and backtick parts of an UNQUOTED heredoc body, found without
    quote awareness (an apostrophe in the text does not hide them). A backslash before a
    character makes it literal. Nested ones are found by recursion."""
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            i += 2; continue
        if c == "$" and s[i + 1:i + 2] in ("(", "{"):
            op, cl = ("(", ")") if s[i + 1] == "(" else ("{", "}")
            depth, j = 1, i + 2
            while j < n and depth:
                if s[j] == "\\":
                    j += 1
                elif s[j] == op:
                    depth += 1
                elif s[j] == cl:
                    depth -= 1
                j += 1
            body = s[i + 2:j - 1] if depth == 0 else s[i + 2:]
            out.append(body); out.extend(subst_raw(body)); i = j; continue
        if c == "`":
            j = i + 1
            while j < n and s[j] != "`":
                j += 2 if s[j] == "\\" else 1
            body = s[i + 1:j]
            out.append(body); out.extend(subst_raw(body)); i = j + 1; continue
        i += 1
    return out

HD_BAD = re.compile(r"[()$`\\|;&<\"\x27]")
HD_TAIL = re.compile(
    r"^-?[ \t]*(?:\x27[^\x27\"\\\s;&|()<>$`]+\x27|\"[^\x27\"\\\s;&|()<>$`]+\"|[A-Za-z0-9_.+-]+)"
    r"[ \t]*(?:>>?[ \t]*[^\s;&|()<>$`\\\x27\"=]+)?[ \t]*$")
HD_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=[^\s]*$")

def heredoc_is_data(cmd, i):
    """True only for the plain shape: the physical line that holds the << reads
    <reader> [args] <<[-]DELIM, DELIM optionally quoted, then at most > file or >> file.
    The text before << has no ( ) $ backtick backslash | ; & < or quote (a quoted receiver
    word such as "cat" is the one exception), and nothing follows the delimiter but that
    redirect. A backslash at the end of the line, or at the end of the line before it, means a
    continuation that may hide a pipe. Any other shape (a shell, tee, an interpreter, a
    variable receiver, a heredoc inside $(...), <(...) or backticks, a pipe or a second
    command on the line) means the body may run, so it is judged as commands."""
    p = cmd.rfind("\n", 0, i) + 1
    if p > 1 and cmd[p - 2] == "\\":
        return False
    eol = cmd.find("\n", i)
    line = cmd[p:len(cmd) if eol < 0 else eol]
    if line.rstrip(" \t").endswith("\\"):
        return False
    before, after = line[:i - p], line[i - p + 2:]
    words = before.split()
    while words and (words[0] in KEYWORDS or HD_ASSIGN.match(words[0])):
        words = words[1:]
    if not words:
        return False
    recv = words[0]
    m = re.match(r"^([\"\x27])([^\"\x27]*)\1$", recv)
    bare = m.group(2) if m else recv
    n = posixpath.basename(bare).lower()
    if n.endswith(".exe"):
        n = n[:-4]
    if n not in READERS:
        return False
    if HD_BAD.search(before.replace(recv, bare, 1)):
        return False
    return bool(HD_TAIL.match(after))

def strip_comments(cmd):
    """Drop shell comments (a # that starts a word, outside quotes, to end of line) and
    heredoc bodies that are plain text. Returns the text and the bodies that may run, each
    (text, ps) with ps None for the caller own setting: the whole body unless the receiver is
    a plain reader (see heredoc_is_data) with a closed delimiter, else, for an unquoted
    delimiter, its $(...), ${...} and backtick parts."""
    # prev is the last character bash sees, so an escaped space (a\ #b) or a line
    # continuation does not count as a word break. ")" is not a break either: after
    # $(...) a # is part of the word.
    out, q, i, n, prev = [], "", 0, len(cmd), "\n"
    pending, ls, bodies, brk = [], 0, [], 0
    while i < n:
        c = cmd[i]
        if c == "\\" and q != "\x27" and i + 1 < n:
            if cmd[i + 1] != "\n":           # a line continuation emits nothing
                out.append(cmd[i:i + 2]); prev = "x"
            i += 2; continue
        if q:
            if c == q:
                q = ""
        elif c in "\"\x27":
            q = c
        elif c == "#" and prev in " \t\n;&|(":
            while i < n and cmd[i] != "\n":
                i += 1
            continue
        elif cmd[i:i + 3] == "<<<":          # a here-string is not a heredoc
            out.append("<<<"); prev = "<"; i += 3; continue
        elif (cmd[i:i + 2] == "<<" and prev in " \t\n;&|(" and brk == 0
              and cmd[ls:i].count("((") <= cmd[ls:i].count("))")):
            # (not the << of $((1<<3)), $[1<<3] or a[1<<3]=1 arithmetic, nor x<<y)
            d = heredoc_delim(cmd, i + 2)
            if d:
                pending.append(d + (heredoc_is_data(cmd, i),))
            out.append("<<"); prev = "<"; i += 2; continue
        elif c == "[":
            brk += 1
        elif c == "]":
            brk = max(0, brk - 1)
        elif c == "\n" and pending:
            words = [posixpath.basename(w).lower() for w in re.split(r"[\s;&|()<>]+", cmd[ls:i]) if w]
            words = [w[:-4] if w.endswith(".exe") else w for w in words]
            shell = next((w for w in words if w in SHELLS), None)
            body_ps = None if shell is None else shell in PS_SHELLS
            out.append("\n"); i += 1
            for delim, quoted, strip, data in pending:
                body, found = [], False
                while i < n:
                    j = cmd.find("\n", i)
                    j = n if j < 0 else j
                    line = cmd[i:j]; i = j + 1
                    if (line.lstrip("\t") if strip else line) == delim:
                        found = True
                        break
                    body.append(line)
                text = "\n".join(body)
                if not (found and data):         # a body that may run, or no closing line
                    bodies.append((text, body_ps))
                elif not quoted:
                    bodies.extend((b, None) for b in subst_raw(text))
            pending, ls, prev, brk = [], i, "\n", 0
            continue
        out.append(c); prev = c
        if c == "\n":
            ls = i + 1
            brk = 0
        i += 1
    return "".join(out), bodies

def tokens(cmd):
    cmd = cmd.replace("\n", " ; ")
    lex = shlex.shlex(cmd, posix=False, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""           # comments were already removed by strip_comments
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
    if any(unq(a) == "--output" or unq(a).startswith("--output=") for a in args):
        deny("git --output writes a file.")
    i = 0
    while i < len(args):
        a = unq(args[i])
        if a in ("-C", "--git-dir", "--work-tree", "--namespace"):
            i += 2; continue
        if a == "--exec-path" or a.startswith("--exec-path="):
            deny("git --exec-path can run arbitrary programs and is blocked.")
        if a == "-c" or a.startswith("-c") or a.startswith("--config"):
            deny("git -c can run arbitrary programs and is blocked.")
        if a.startswith("-"):
            i += 1; continue
        break
    sub = unq(args[i]) if i < len(args) else ""
    rest = [unq(x) for x in args[i + 1:]]
    stop = rest.index("--") if "--" in rest else len(rest)
    opts = [r.split("=")[0] for r in rest[:stop] if r.startswith("-")]
    def abbr(o, full, n=4):             # git accepts an unambiguous prefix of a long option
        return o.startswith("--") and len(o) >= n and full.startswith(o)
    if sub in ("fetch", "ls-remote") and any(abbr(o, "--upload-pack", 3) for o in opts):
        deny("git %s --upload-pack runs a program." % sub)
    if sub == "ls-remote" and any(abbr(o, "--exec") for o in opts):
        deny("git ls-remote --exec runs a program.")
    if sub == "fetch" and any(abbr(o, "--recurse-submodules") for o in opts):
        deny("git fetch --recurse-submodules can run programs from the submodules.")
    if sub == "grep":
        k, body = 0, rest[:stop]
        while k < len(body):                # -O is read inside a short-option cluster only until
            a = body[k]; k += 1             # a letter that takes a value (-eOpen is -e Open)
            if a.startswith("--"):
                if abbr(a.split("=")[0], "--open-files-in-pager", 4):
                    deny("git grep --open-files-in-pager runs a pager program.")
            elif a.startswith("-") and len(a) > 1:
                for j, ch in enumerate(a[1:]):
                    if ch == "O":
                        deny("git grep -O runs a pager program.")
                    if ch in "efABCm":
                        k += 0 if a[2 + j:] else 1      # the value is the next word
                        break
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
        if rest[:1] in (["get"], ["list"]) or any(
                r in ("--get", "--get-all", "--list", "-l", "--get-regexp") for r in rest):
            return
        writes = {"--add", "--unset", "--unset-all", "--replace-all", "--rename-section",
                  "--remove-section", "-e", "--edit", "set", "unset"}
        positional, skip = [], False
        for r in rest:
            if skip:
                skip = False
            elif r in ("-f", "--file", "--blob"):
                skip = True                 # the value of --file is a path, not a key
            elif not r.startswith("-"):
                positional.append(r)
        if not any(r.split("=")[0] in writes for r in rest) and len(positional) <= 1:
            return                          # git config <key> only reads it
    if sub == "worktree" and rest[:1] == ["list"]:
        return
    if sub == "submodule" and rest[:1] in ([], ["status"]):
        return
    deny("git %s can change the repository; only read-only git is allowed." % sub)

def match_long(nm, names, minlen=1):
    """A long option name, or an unambiguous prefix of one (getopt style). None if unknown."""
    if nm in names:
        return nm
    c = [x for x in names if x.startswith(nm)] if len(nm) >= minlen else []
    return c[0] if len(c) == 1 else None

def target_ok(raw, ps=False):
    """An output target that is not a file the agent could damage: stdout, /dev/null, or a
    path inside its own memory dir."""
    t = unq(raw)
    return t.lower() in SAFE_TARGETS or t == "-" or shell_ok(raw, ps)

def check_mem_cmd(name, args, ps):
    """rm, cp, touch and mkdir are allowed when every path they write is in the agent own
    memory dir (every operand, or for cp the last one or the -t directory)."""
    shorts, longs, sval, lval = MEM_CMDS[name]
    why = "`%s` writes or removes files outside its own memory dir." % name
    pos, tdir, i, endopts = [], None, 0, False
    while i < len(args):
        raw = args[i]; a = unq(raw); i += 1
        if endopts or not a.startswith("-") or a == "-":
            pos.append(raw); continue
        if a == "--":
            endopts = True; continue
        if a.startswith("--"):
            nm, eq, val = a[2:].partition("=")
            full = match_long(nm, longs | lval)
            if full is None:
                deny(why)
            if name == "cp" and full == "preserve" and (
                    not eq or re.search(r"mode|all", val.lower())):
                deny("`cp --preserve` keeps the mode of the source, so it is not allowed.")
            if full in lval:
                v = val if eq else (args[i] if i < len(args) else "")
                if not eq:
                    i += 1
                if full == "target-directory":
                    tdir = v
            continue
        for j, ch in enumerate(a[1:]):
            if ch in sval:
                v = a[2 + j:] or (args[i] if i < len(args) else "")
                if not a[2 + j:]:
                    i += 1
                if ch == "t" and name == "cp":
                    tdir = v
                break
            if ch not in shorts:
                deny(why)
    targets = [tdir] if tdir is not None else (pos[-1:] if name == "cp" else pos)
    # No operand means the paths come from elsewhere (xargs rm), so they cannot be judged.
    if not targets or not all(shell_ok(t, ps) for t in targets):
        deny(why)

CURL_VALUE = set("AbcCdDeEFHKmoPQrtTuUwxXyYz")        # short options that take a value
CURL_OUT = {"output", "dump-header", "cookie-jar", "trace", "trace-ascii", "stderr",
            "libcurl", "etag-save", "hsts", "alt-svc"}

def check_curl(args, ps):
    why = "`curl` writes a file."
    names = CURL_OUT | {"remote-name", "remote-name-all", "output-dir", "config", "write-out"}
    i = 0
    while i < len(args):
        a = unq(args[i]); i += 1
        if a == "--":
            break
        if a.startswith("--"):
            nm, eq, val = a[2:].partition("=")
            full = match_long(nm, names, 3)
            if full in ("remote-name", "remote-name-all", "config"):
                deny(why if full != "config" else "a curl config file can name output files.")
            if full == "write-out":
                v = val if eq else (args[i] if i < len(args) else "")
                if not eq:
                    i += 1
                if "%output{" in v.lower():
                    deny("`curl --write-out` with %output{} writes a file.")
            if full in CURL_OUT:
                v = val if eq else (args[i] if i < len(args) else "")
                if not eq:
                    i += 1
                if not target_ok(v, ps):
                    deny(why)
        elif a.startswith("-") and len(a) > 1:
            for j, ch in enumerate(a[1:]):
                if ch == "O":
                    deny(why)
                if ch == "K":
                    deny("a curl config file can name output files.")
                if ch in CURL_VALUE:
                    rest = a[2 + j:]
                    v = rest or (args[i] if i < len(args) else "")
                    if not rest:
                        i += 1
                    if ch in "oDc" and not target_ok(v, ps):
                        deny(why)
                    if ch == "w" and "%output{" in v.lower():
                        deny("`curl -w` with %output{} writes a file.")
                    break

WGET_LONG = {"output-document": "doc", "output-file": "log", "append-output": "log",
             "directory-prefix": "dir", "save-cookies": "log", "rejected-log": "log",
             "warc-file": "log", "execute": "exec"}
WGET_VALUE = set("OoaPetTwQliBUARDIX")

def check_wget(args, ps):
    why = "`wget` writes the download to a file."
    if any(unq(a) in ("-V", "--version", "-h", "--help") for a in args):
        return
    has_target, i = False, 0
    while i < len(args):
        a = unq(args[i]); i += 1
        if a == "--":
            break
        kind, v = None, ""
        if a.startswith("--"):
            nm, eq, val = a[2:].partition("=")
            full = match_long(nm, set(WGET_LONG), 3)
            if full:
                kind = WGET_LONG[full]
                v = val if eq else (args[i] if i < len(args) else "")
                if not eq:
                    i += 1
        elif a.startswith("-") and len(a) > 1:
            for j, ch in enumerate(a[1:]):
                if ch in WGET_VALUE:
                    rest = a[2 + j:]
                    v = rest or (args[i] if i < len(args) else "")
                    if not rest:
                        i += 1
                    kind = {"O": "doc", "o": "log", "a": "log", "P": "dir", "e": "exec"}.get(ch)
                    break
        if kind == "exec":
            deny("wget -e can set an output file.")
        if kind in ("doc", "dir"):
            has_target = True
        if kind == "dir" and not shell_ok(v, ps):
            deny(why)
        if kind in ("doc", "log") and not target_ok(v, ps):
            deny(why)
    if not has_target:
        deny(why)

def check_sort(args, ps):
    why = "`sort -o` writes a file."
    i = 0
    while i < len(args):
        a = unq(args[i]); i += 1
        if a == "--":
            break
        if a.startswith("--"):
            nm, eq, val = a[2:].partition("=")
            if nm and "output".startswith(nm):
                v = val if eq else (args[i] if i < len(args) else "")
                if not eq:
                    i += 1
                if not shell_ok(v, ps):
                    deny(why)
            elif len(nm) >= 2 and "compress-program".startswith(nm):
                deny("`sort --compress-program` runs a program.")
        elif a.startswith("-") and len(a) > 1:
            for j, ch in enumerate(a[1:]):
                if ch in "oktST":
                    rest = a[2 + j:]
                    v = rest or (args[i] if i < len(args) else "")
                    if not rest:
                        i += 1
                    if ch == "o" and not shell_ok(v, ps):
                        deny(why)
                    break

SCRIPT_LONG_OK = {"return", "quiet", "append", "flush", "force", "echo", "version", "help"}

def check_script(args, ps):
    """script -c CMD FILE runs CMD and writes FILE. Judged: CMD, and FILE must be a safe
    target (/dev/null). Without -c it starts a shell. The log and timing options write files."""
    why = "`script` writes a typescript file."
    cmd, files, i, endopts = None, [], 0, False
    while i < len(args):
        raw = args[i]; a = unq(raw); i += 1
        if endopts or not a.startswith("-") or a == "-":
            files.append(raw); continue
        if a == "--":
            endopts = True; continue
        if a.startswith("--"):
            nm, eq, val = a[2:].partition("=")
            if nm and "command".startswith(nm):
                cmd = val if eq else (args[i] if i < len(args) else "")
                if not eq:
                    i += 1
            elif match_long(nm, SCRIPT_LONG_OK, 1) is None:
                deny(why)
            continue
        for j, ch in enumerate(a[1:]):
            if ch in "cEmo":
                v = a[2 + j:] or (args[i] if i < len(args) else "")
                if not a[2 + j:]:
                    i += 1
                if ch == "c":
                    cmd = v
                break
            if ch not in "qaefrVh":
                deny(why)
    if cmd is None or not files or not all(target_ok(f, ps) for f in files):
        deny(why)
    check_command(unq(cmd), ps=False)

def pkg_words(name, uargs):
    """The non-option words of a package manager command line, as (word, words after it),
    skipping the values of known value options. The scan stops at a known read-only
    subcommand, so an unknown option with a value (npm --maxsockets 5 install x) does not
    hide the real subcommand, and `npm view x add` is not read as `add`."""
    vo = PKG_VALUE.get(name, set())
    i, out = 0, []
    while i < len(uargs):
        a = uargs[i]
        if a.startswith("-") and a != "--":
            i += 2 if a in vo else 1
        elif a == "--" or a.startswith("+"):    # cargo +toolchain
            i += 1
        else:
            out.append((a.lower(), uargs[i + 1:]))
            if a.lower() in PKG_STOP:
                break
            i += 1
    return out

PKG_CFG_WRITE = {"set", "delete", "del", "rm", "remove", "unset", "edit", "fix"}
PKG_CACHE_WRITE = {"clean", "add", "verify", "purge", "remove", "rm", "delete", "prune"}

def pkg_check(name, uargs):
    words = pkg_words(name, uargs)
    for sub, rest in words:
        first = next((w for w, _ in pkg_words(name, rest)), "")
        if sub in ("config", "c") and first in PKG_CFG_WRITE:
            deny("`%s config %s` changes the package manager configuration." % (name, first))
        if sub == "cache" and first in PKG_CACHE_WRITE:
            deny("`%s cache %s` changes the package cache." % (name, first))
        if sub == "pack" and name in ("npm", "pnpm", "yarn", "bun") and "--dry-run" not in rest:
            deny("`%s pack` writes a tarball." % name)
        if name == "cargo" and (
                (sub == "fmt" and "--check" not in rest)
                or (sub == "clippy" and "--fix" in rest)
                or (sub == "package" and "--list" not in rest)):
            deny("`cargo %s` writes files." % sub)
        if name == "uv" and sub == "pip":                     # uv pip install x
            return pkg_check("pip", rest)
        if sub in PKG_SUB or sub in PKG_EXTRA.get(name, ()):
            if name == "npm" and sub == "version" and not pkg_words("npm", rest):
                return                                        # bare `npm version` prints versions
            if name == "npm" and sub == "pkg":
                inner = pkg_words("npm", rest)
                if inner and inner[0][0] == "get":
                    return                                    # npm pkg get reads package.json
            deny("`%s %s` changes installed packages or project files." % (name, sub))
        if sub == "audit" and "fix" in rest:
            deny("`%s audit fix` changes installed packages." % name)
    if name == "yarn" and not words and not any(
            a in ("-v", "--version", "-h", "--help") for a in uargs):
        deny("a bare `yarn` installs packages.")

def check_pkg(name, uargs):
    if re.match(r"^(python|pypy)[0-9.]*$|^py$", name):       # python -m pip install x, -mpip
        for i, a in enumerate(uargs):
            m = re.match(r"^-[A-Za-z]*m(.*)$", a)
            if m:
                mod = m.group(1) or (uargs[i + 1] if i + 1 < len(uargs) else "")
                if mod.lower() in ("pip", "pip3", "pipx", "uv"):
                    name, uargs = mod.lower(), uargs[i + (1 if m.group(1) else 2):]
                break
    if name in PKG:
        pkg_check(name, uargs)

def cname(tok):
    """A command word as a bare name: unquoted, directory and a leading backslash removed,
    lower case, without .exe, .cmd or .bat."""
    n = posixpath.basename(unq(tok).replace("\\", "/")).lower()
    for suffix in (".exe", ".cmd", ".bat"):
        if n.endswith(suffix):
            n = n[:-len(suffix)]
    return n

def check_segment(words, ps, wrapped=False):
    """wrapped is True when the words run under xargs, parallel or find -exec, which add
    operands of their own; the memory-dir allowance never applies there."""
    while words:
        w = unq(words[0]).lower()
        cn = cname(words[0])
        if GIT_VAR.match(unq(words[0])):
            deny(GIT_DENY)
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]) or w in KEYWORDS:
            words = words[1:]
        elif cn == "command" and len(words) > 1 and unq(words[1]) in ("-v", "-V"):
            return                          # command -v NAME only looks NAME up
        elif cn == "watch":                 # watch runs its words, joined, through a shell
            rest = words[1:]
            while rest and unq(rest[0]).startswith("-"):
                o = unq(rest[0]); rest = rest[1:]
                if o in ("-n", "--interval") and rest:
                    rest = rest[1:]
            check_command(" ".join(unq(a) for a in rest), ps)
            return
        elif cn in WRAPPERS:
            opts = WRAPPERS[cn]
            words = words[1:]
            if cn in APPENDING:
                wrapped = True
            while words and unq(words[0]).startswith("-"):
                raw = unq(words[0])
                words = words[1:]
                if cn == "env":             # -S "cmd", -S"cmd", -iS "cmd", --split-string=cmd
                    split = None
                    if raw.startswith("--"):
                        nm, eq, val = raw[2:].partition("=")
                        if nm and "split-string".startswith(nm):
                            split = val if eq else (words[0] if words else "")
                            if not eq and words:
                                words = words[1:]
                    else:
                        ms = re.match(r"^-[A-Za-z0-9]*S(.*)$", raw)
                        if ms and ms.group(1):
                            split = ms.group(1)
                        elif ms and words:
                            split, words = words[0], words[1:]
                    if split is not None:
                        # env splits the string into words and runs them with the rest
                        check_command("env " + unq(split) + " " + " ".join(words), ps)
                        return
                if raw.split("=")[0] in opts and "=" not in raw and words:
                    words = words[1:]       # the option value, as in xargs -I {}
            if cn in ("timeout", "chrt", "taskset") and words:
                words = words[1:]           # the duration, priority or mask
        else:
            break
    if not words:
        return
    name = cname(words[0])
    args = words[1:]
    uargs = [unq(a) for a in args]
    if name in ("export", "declare", "typeset", "readonly", "local", "setenv", "set") and any(
            GIT_VAR.match(a) for a in uargs):
        deny(GIT_DENY)
    if name in MEM_CMDS:
        if wrapped:
            deny("`%s` under xargs, parallel or find -exec gets operands that cannot be checked." % name)
        check_mem_cmd(name, args, ps)
    elif name in WRITE_CMDS:
        deny("`%s` writes or removes files." % name)
    if name in RUNNERS:
        deny("`%s` fetches and runs a registry package." % name)
    if name == "curl":
        check_curl(args, ps)
    if name == "wget":
        check_wget(args, ps)
    if name == "sort":
        check_sort(args, ps)
    if name in ("rg", "ripgrep") and any(
            a in ("--pre", "--hostname-bin") or a.startswith(("--pre=", "--hostname-bin="))
            for a in uargs):
        deny("`rg --pre` and `--hostname-bin` run a program.")
    if name == "script":
        check_script(args, ps)
    if ps and name in PS_WRITE:
        deny("`%s` writes or removes files." % words[0])
    if ps and any(a.lower() == "-outfile" for a in uargs):
        deny("`-OutFile` writes a file.")
    if name in ("sed", "perl") and any(re.match(r"^-[A-Za-z]*i", a) or
                                       a.startswith("--in-place") for a in uargs):
        deny("`%s -i` edits files in place." % name)
    check_pkg(name, uargs)
    if name == "git":
        check_git(args)
    if name == "find":
        for i, a in enumerate(uargs):
            if a == "-delete" or a.startswith("-fprint") or a == "-fls":
                deny("`find %s` writes or removes files." % a)
            if a in ("-exec", "-execdir", "-ok", "-okdir"):
                check_segment(args[i + 1:], ps, True)
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
    text, bodies = strip_comments(cmd.replace("\r", ""))
    text = QHOME_SUB.sub("$HOME", text)
    for body, body_ps in bodies:
        check_command(body, ps if body_ps is None else body_ps)
    for body in subst_bodies(text, ps):
        check_command(body, ps)
    if ps and PS_FILE_WRITE.search(text):
        deny("a PowerShell .NET file call writes or removes files.")
    if ps and PS_GIT_ENV.search(text):
        deny(GIT_DENY)
    toks = tokens(text)
    seg = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if is_sep(t):
            check_segment(seg, ps); seg = []; i += 1; continue
        if t and set(t) <= set("<>&|") and ">" in t:
            nxt = toks[i + 1] if i + 1 < len(toks) else ""
            if t in (">&", "&>") or t.endswith("&"):
                if t != "&>" and re.match(r"^(\d+|-)$", nxt):
                    i += 2; continue        # fd duplication such as 2>&1
            target = unq(nxt)
            if target.lower() in SAFE_TARGETS or shell_ok(nxt, ps):
                i += 2; continue
            deny("the shell redirect into %s writes a file." % (target or "a file"))
        if t and set(t) <= set("<>&|"):
            i += 1; continue                # input redirect or heredoc marker
        seg.append(t)
        i += 1
    check_segment(seg, ps)

command = tin.get("command") or ""
if isinstance(command, str) and command.strip():
    try:
        check_command(command, ps=(tool == "PowerShell"))
    except Exception:
        _fail_closed()
sys.exit(0)
PYEOF
)

# The payload is kept so that a failure of the checker itself can be turned into a deny
# for a guarded agent: Python that cannot start (no temp file and an argument list too long
# for -c) or dies must not become a silent allow.
INPUT=$(cat)
# Test seam: act as if no temp file could be made and Python could not start.
[ -n "${AGENT_WRITE_GUARD_TEST_NO_CHECKER:-}" ] && PYTHON=false
PYF=$(mktemp "${TMPDIR:-/tmp}/awg-XXXXXX" 2>/dev/null)
trap 'rm -f "$PYF"' EXIT           # set before the file is written, so no path leaks it
if [ -n "$PYF" ] && printf '%s' "$PY_SRC" > "$PYF" 2>/dev/null; then
  PYARGS=(-I "$(cygpath -m "$PYF" 2>/dev/null || printf '%s' "$PYF")")
else
  PYARGS=(-c "$PY_SRC")
fi
OUT=$(printf '%s' "$INPUT" | "$PYTHON" "${PYARGS[@]}" 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ]; then
  [ -n "$OUT" ] && printf '%s\n' "$OUT"
  exit 0
fi
for _a in $AGENT_WRITE_GUARD_LIST; do
  if printf '%s' "$INPUT" | grep -Eq "\"agent_type\"[[:space:]]*:[[:space:]]*\"$_a\""; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"agent-write-guard: the guard could not run for this read-only agent, so the call is blocked. Report the change in your final message so the caller can apply it."}}'
    exit 0
  fi
done
exit 0
