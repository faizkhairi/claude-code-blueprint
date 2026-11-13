#!/bin/bash
# PreToolUse hook (Bash and PowerShell matchers): Blocks git push to protected remotes.
# Purpose: Prevents accidental pushes that could trigger CI/CD pipelines
#          or disrupt teammates mid-pull.
#
# It judges the push that would actually run, not the text of the command:
#   - the command is split into its parts (; && || | newlines, outside quotes) and unwrapped
#     through env, sudo, command, nohup, time, VAR=val, bash -c, eval, $(...) and backticks;
#   - `git` and `git.exe` are recognised with global options (-C dir, -c k=v, --git-dir=...);
#   - `cd dir` is tracked per part (the base directory is the payload cwd, else the hook's cwd);
#   - the target is `--repo X`, else the first argument after `push` (values of -o, --push-option,
#     --receive-pack and --exec are skipped), else the branch's pushRemote, remote.pushDefault,
#     the branch's remote, then origin;
#   - leading GIT_DIR and GIT_WORK_TREE assignments (also after env) are applied like --git-dir and
#     --work-tree; only the -c pairs whose key starts with remote., url., branch. or push. (any case) are
#     passed to the git calls that resolve the remote, so `-c remote.origin.pushurl=...`,
#     `-c url.<base>.insteadOf=...` and `-c remote.pushDefault=...` count. No other pair is passed:
#     `-c core.fsmonitor=<program>` would otherwise make this hook run the program before you decide;
#   - a remote name is resolved with `git remote get-url --push`; a literal URL is expanded with
#     `git ls-remote --get-url` (insteadOf) and both the literal and the expanded URL are checked;
#   - PowerShell text is read as PowerShell (a backslash is a path character, also at the end of a line and
#     inside "...", a backtick escapes the next character, `$x = git push` is an assignment, { } open and
#     close blocks); Bash text follows bash (an unquoted backslash is dropped, a backslash and a newline
#     continue the line, $'...' is decoded, `env -S 'git push'` is walked as a command string);
#   - a subcommand built at run time (`git $S origin`, `git pu$()sh`, `git {push,pull}`) and a shell alias given
#     on the command line (`-c 'alias.x=!git push'`) cannot be judged and count as a push, never guessed;
#   - the push is blocked when that URL contains a domain in BLOCKED_DOMAINS.
# A target that cannot be resolved (a variable, a missing directory, an unknown remote, an
# unparseable command that still mentions git push) is blocked with a message, never guessed.
# `echo "git push"` and a commit message that quotes `; git push` are not pushes.
# Threat model: these hooks stop accidental pushes to protected remotes and accidental secret commits; they
# are not a sandbox against deliberately obfuscated commands, so a parser cannot follow every shell expansion.
# Known limits: GIT_DIR and GIT_WORK_TREE set in an earlier statement (export, $env:NAME = ...) are not
# tracked, GIT_CONFIG_COUNT/KEY/VALUE, GIT_CONFIG_PARAMETERS and --config-env are not read, and
# url.<base>.pushInsteadOf applies to a remote name but not to a literal URL. The command text is what is
# read, so a push handed to another interpreter is not seen: `echo "git push" | bash`, `find -exec git push`,
# `su -c`, and the PowerShell `iex` and `Start-Process` forms. Also not followed: `pwsh -EncodedCommand`
# (base64 text) and abbreviated pwsh parameters (only -Command, -c and -cmd are read), the glued
# `cmd /c"..."` form, a directory change by popd or Pop-Location (cd, pushd and Set-Location are tracked), and
# a hook that Claude Code stops at its timeout does not block (the call then runs).
# Fail closed: an unexpected error after a push was detected blocks it, and so does a parser that exits
# abnormally on a command that mentions push, also behind quotes, backslashes or backticks (exit 1 would
# otherwise read as a non-blocking error).
# $CCB_GUARD_FAULT (any value) raises an error inside the judging loop: the seam the tests use.
# If git is not on PATH the hook cannot resolve a remote name: it warns and allows.
#
# Configuration: Add your protected domains to BLOCKED_DOMAINS below.
# Exit code 2 = deny (blocks the command)
# Exit code 0 = allow

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then
  echo "block-git-push: python not found: hook cannot parse input" >&2
  exit 0
fi

INPUT=$(cat)

# Configure: add your protected remote domains below (space separated)
# Example: "internal.example.com" or "gitea.mycompany.com"
BLOCKED_DOMAINS="internal.example.com"

# The parser below is the same text in block-git-push.sh, pre-commit-secret-scan.sh and
# post-commit-review.sh. Hooks stay standalone (no shared file), and hooks/test-hooks.sh
# diffs the copies, so edit all three together.
IFS= read -r -d '' PY_SRC <<'PYEOF' || true
# BEGIN SHARED CMDPARSE (one copy in each of block-git-push.sh, pre-commit-secret-scan.sh and post-commit-review.sh; hooks/test-hooks.sh diffs the copies)
import os, re, shutil, subprocess

_KW = ('{', '}', '!', 'if', 'then', 'elif', 'else', 'elseif', 'do', 'while', 'until', 'fi', 'done', 'try', 'catch', 'finally')
_SH = ('bash', 'sh', 'zsh', 'dash', 'ksh', 'ash')
_CD = ('cd', 'pushd', 'chdir', 'set-location', 'sl', 'push-location')
_WRAP = ('env', 'sudo', 'doas', 'command', 'builtin', 'nohup', 'time', 'exec', 'setsid', 'nice', 'ionice', 'stdbuf', 'timeout')
_ASSIGN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\+?=')
_PSASSIGN = re.compile(r'^\$[A-Za-z_][A-Za-z0-9_:.]*\+?=')
_PSVAR = re.compile(r'^\$[A-Za-z_][A-Za-z0-9_:.]*$')
_GITENV = ('GIT_DIR', 'GIT_WORK_TREE')
_ESC = {'n': '\n', 't': '\t', 'r': '\r', 'a': '\a', 'b': '\b', 'e': '\x1b', 'E': '\x1b', 'f': '\f', 'v': '\v',
        '\\': '\\', "'": "'", '"': '"', '?': '?'}
_REDIR = re.compile(r'^(?:\d*|&)(?:>>?|<{1,3})&?(.*)$')
_CFGOK = ('remote.', 'url.', 'branch.', 'push.')
_GITSUB = ('add', 'am', 'apply', 'archive', 'bisect', 'blame', 'branch', 'bundle', 'cat-file', 'checkout', 'cherry-pick',
           'clean', 'clone', 'commit', 'config', 'describe', 'diff', 'diff-tree', 'fetch', 'format-patch', 'gc', 'grep',
           'help', 'init', 'log', 'ls-files', 'ls-remote', 'ls-tree', 'merge', 'mv', 'notes', 'pull', 'push', 'rebase',
           'reflog', 'remote', 'reset', 'restore', 'rev-list', 'rev-parse', 'revert', 'rm', 'show', 'stage', 'stash',
           'status', 'submodule', 'switch', 'symbolic-ref', 'tag', 'version', 'worktree')

def _dyn(w):
    return '$' in w or '`' in w

def _flat(x):
    # The text without backslashes, quotes and backticks: pu\sh, 'pu'sh and PowerShell pu`sh read as push once unescaped.
    return re.sub(r'[\\\'"`]', '', x)

def mentions(cmd, word):
    # A tolerant pre-filter for the raw command text: true when word could be in the command, also behind
    # an escape, a $'...' string or a dynamic part ($var, $(...), `...`, {a,b}) next to git.
    return word in cmd or word in _flat(cmd) or "$'" in cmd or ('git' in cmd and any(c in cmd for c in '$`({'))

def _ansi(s, j):
    # s[j] is a backslash inside $'...'. Returns (text, next index).
    e = s[j + 1]
    if e in _ESC:
        return _ESC[e], j + 2
    m = re.match(r'x[0-9A-Fa-f]{1,2}|[0-7]{1,3}|u[0-9A-Fa-f]{1,4}|U[0-9A-Fa-f]{1,8}', s[j + 1:j + 10])
    if m:
        g = m.group(0)
        try:
            v = int(g[1:], 16) if g[0] in 'xuU' else int(g, 8) & 255
            return chr(v), j + 1 + len(g)
        except (ValueError, OverflowError):
            pass
    if e == 'c' and j + 2 < len(s):
        return chr(ord(s[j + 2]) & 31), j + 3
    return '\\' + e, j + 2

def _base(x):
    b = x.replace('\\', '/').rsplit('/', 1)[-1].lower()
    return b[:-4] if b.endswith('.exe') else b

def _scan(s, i=0, sub=False, ps=False):
    # Split shell text into items: ('c', [words]), ('(',) and (')',) scope marks, and
    # ('h', body) for a heredoc body. Quotes are removed from words. ps is PowerShell text: a backslash
    # is then a path character and { } open and close blocks. Returns (items, end, ok).
    n = len(s); items = []; words = []; cur = []; hd = []
    q = skip = False; ok = True; depth = 0; bl = 0

    def word():
        nonlocal q, skip
        if cur or q:
            w = ''.join(cur)
            m = None if q else _REDIR.match(w)
            if skip:
                skip = False
            elif m:
                skip = m.group(1) == ''
            else:
                words.append(w)
        del cur[:]
        q = False

    def cmd():
        nonlocal words
        word()
        while words and words[-1] == '}':
            words.pop()
        if words and words[-1].endswith('}') and words[-1].count('}') > words[-1].count('{'):
            words[-1] = words[-1][:-1]
        if words:
            items.append(('c', words))
            words = []

    def dollar(i):
        nonlocal ok
        its, j, sok = _scan(s, i + 2, True, ps)
        items.append(('(',)); items.extend(its); items.append((')',))
        cur.append(s[i:j]); ok = ok and sok
        return j

    def tick(i):
        nonlocal ok
        j = i + 1
        while j < n and s[j] != '`':
            j += 2 if s[j] == '\\' else 1
        if j >= n:
            ok = False; cur.append('`')
            return i + 1
        its, _, sok = _scan(s[i + 1:j], 0, False, ps)
        items.append(('(',)); items.extend(its); items.append((')',))
        cur.append(s[i:j + 1]); ok = ok and sok
        return j + 1

    while i < n:
        c = s[i]
        if c == '\\':
            nx = s[i + 1:i + 2]
            if nx == '\n' and not ps:
                i += 2
            elif nx == '\r' and s[i + 2:i + 3] == '\n' and not ps:
                i += 3
            elif nx and (not ps or nx in ' \t"\'$;&|()<>\\'):
                cur.append(nx); i += 2
            else:
                cur.append(c); i += 1
        elif c == "'":
            j = s.find("'", i + 1)
            q = True
            if j < 0:
                ok = False; cur.append(s[i + 1:]); i = n
            else:
                cur.append(s[i + 1:j]); i = j + 1
        elif c == '$' and s[i + 1:i + 2] == "'" and not ps:
            j = i + 2; buf = []; q = True
            while j < n and s[j] != "'":
                if s[j] == '\\' and j + 1 < n:
                    v, j = _ansi(s, j)
                    buf.append(v)
                else:
                    buf.append(s[j]); j += 1
            cur.append(''.join(buf))
            if j >= n:
                ok = False
            i = min(j + 1, n)
        elif c == '$' and s[i + 1:i + 2] == '"' and not ps:
            i += 1
        elif c == '"':
            q = True; i += 1
            while True:
                if i >= n:
                    ok = False
                    break
                d = s[i]
                if d == '"':
                    i += 1
                    break
                if d == '\\' and not ps and s[i + 1:i + 2] in ('"', '\\', '$', '`'):
                    cur.append(s[i + 1]); i += 2
                elif d == '`' and ps:
                    cur.append(s[i + 1:i + 2]); i += 2
                elif d == '$' and s[i + 1:i + 2] == '(':
                    i = dollar(i)
                elif d == '`':
                    i = tick(i)
                else:
                    cur.append(d); i += 1
        elif c == '$' and s[i + 1:i + 2] == '(':
            i = dollar(i)
        elif c in '<>' and s[i + 1:i + 2] == '(':
            i = dollar(i)
        elif ps and c == '`':
            # PowerShell: a backtick escapes the next character (or continues the line), it is not a substitution.
            e = 3 if s[i + 1:i + 3] == '\r\n' else 2
            if s[i + 1:i + 2] not in ('\n', '\r'):
                cur.append(s[i + 1:i + 2])
            i += e
        elif c == '`':
            i = tick(i)
        elif c == '<' and s.startswith('<<', i) and not s.startswith('<<<', i):
            j = i + 2
            strip = s[j:j + 1] == '-'
            if strip:
                j += 1
            while j < n and s[j] in ' \t':
                j += 1
            k = j
            while k < n and s[k] not in ' \t\r\n;&|<>()':
                k += 1
            word()
            hd.append((re.sub(r'[\'"\\]', '', s[j:k]), strip))
            i = k
        elif c == '\n':
            cmd(); i += 1
            for delim, strip in hd:
                body = []
                while i < n:
                    e = s.find('\n', i)
                    line = s[i:e if e >= 0 else n]
                    i = e + 1 if e >= 0 else n
                    if (line.lstrip('\t') if strip else line).rstrip('\r') == delim:
                        break
                    body.append(line)
                items.append(('h', '\n'.join(body)))
            hd = []
        elif c in ';|':
            cmd(); i += 1
        elif c == '&':
            if s[i + 1:i + 2] == '>' or (cur and cur[-1] in '<>' and not q):
                cur.append(c)
            else:
                cmd()
            i += 1
        elif c == '(':
            cmd(); items.append(('(',)); depth += 1; i += 1
        elif ps and c == '{':
            if cur or (words and _base(words[0]) == 'git' and words[-1].startswith('-')):
                cur.append(c); bl += 1
            else:
                cmd()
            i += 1
        elif ps and c == '}':
            if bl > 0:
                cur.append(c); bl -= 1
            else:
                cmd()
            i += 1
        elif c == ')':
            cmd(); i += 1
            if sub and depth == 0:
                return items, i, ok
            items.append((')',)); depth = max(0, depth - 1)
        elif c == '#' and not cur and not q:
            j = s.find('\n', i)
            i = n if j < 0 else j
        elif c in ' \t\r':
            word(); i += 1
        else:
            cur.append(c); i += 1
    cmd()
    if sub:
        ok = False
    return items, n, ok

def _join(base, d):
    # Resolve directory d against base; None when it cannot be known from the text.
    if d is None or _dyn(d):
        return None
    d = d.replace('\\', '/')
    if d.startswith('~'):
        if d[1:2] not in ('', '/'):
            return None  # ~user is not resolved
        d = os.path.expanduser(d).replace('\\', '/')
        if d.startswith('~'):
            return None
    if d.startswith('/') or re.match(r'^[A-Za-z]:/', d):
        return d
    if base is None:
        return None
    return base if d in ('', '.') else base.rstrip('/') + '/' + d

def _unwrap(w):
    # Drop shell keywords, VAR=val prefixes, PowerShell $x = assignments and wrapper commands (env, sudo,
    # command, nohup, time, nice, timeout, ...). Returns (words, chdir, env): chdir is an env -C directory,
    # env the GIT_DIR / GIT_WORK_TREE assignments seen in front of the command.
    w = list(w); chd = None; env = {}
    for _ in range(20):
        while w:
            if _ASSIGN.match(w[0]):
                k, v = w[0].split('=', 1)
                if k in _GITENV:
                    env[k] = v
                w = w[1:]
            elif w[0] in _KW:
                w = w[1:]
            elif _PSASSIGN.match(w[0]):
                w = [w[0].split('=', 1)[1]] + w[1:]
                if w[0] == '':
                    w = w[1:]
            elif len(w) > 1 and _PSVAR.match(w[0]) and w[1] in ('=', '+='):
                w = w[2:]
            else:
                break
        if not w or _base(w[0]) not in _WRAP:
            break
        c = _base(w[0]); w = w[1:]
        if c == 'env':
            while w and (w[0].startswith('-') or _ASSIGN.match(w[0])):
                k = w.pop(0)
                if _ASSIGN.match(k):
                    kk, v = k.split('=', 1)
                    if kk in _GITENV:
                        env[kk] = v
                    continue
                sv = None
                if k.startswith('--split-string='):
                    sv = k[15:]
                elif k.startswith('--chdir='):
                    chd = k[8:]
                elif k == '--split-string' or re.match(r'^-[A-Za-z0-9]*S$', k):
                    sv = w.pop(0) if w else ''
                elif k.startswith('-S') and not k.startswith('--'):
                    sv = k[2:]
                elif k.startswith('-C') and not k.startswith('--') and len(k) > 2:
                    chd = k[2:]
                elif k in ('-u', '-C', '--unset', '--chdir') and w:
                    v = w.pop(0)
                    if k in ('-C', '--chdir'):
                        chd = v
                if sv is not None:
                    w = [x for it in _scan(sv)[0] if it[0] == 'c' for x in it[1]] + w
        elif c in ('sudo', 'doas'):
            while w and w[0].startswith('-'):
                k = w.pop(0)
                if k in ('-u', '-g', '-h', '-p', '-r', '-t', '-C', '-U', '-D', '-R', '-T') and w:
                    w.pop(0)
        else:
            lookup = c == 'command' and any(k in ('-v', '-V') for k in w[:2])
            val = {'nice': ('-n',), 'ionice': ('-c', '-n', '-p'), 'timeout': ('-s', '-k', '--signal', '--kill-after')}.get(c, ())
            while w and w[0].startswith('-'):
                k = w.pop(0)
                if k in val and w:
                    w.pop(0)
            if c == 'timeout' and w:
                w.pop(0)
            if lookup:
                return [], chd, env
    return w, chd, env

def _git(w, cwd, st, fuzzy, env=None):
    # w[0] is git. Parse global options, then the subcommand and its arguments. env holds the
    # GIT_DIR / GIT_WORK_TREE assignments in front of the command (a global option overrides them).
    d = cwd; cfg = []; i = 1; n = len(w)
    gd = (env or {}).get('GIT_DIR'); wt = (env or {}).get('GIT_WORK_TREE')
    fuzzy = fuzzy or _dyn(gd or '') or _dyn(wt or '')
    while i < n:
        a = w[i]
        if a == '-C' and i + 1 < n:
            d = _join(d, w[i + 1]); i += 2
        elif a == '-c' and i + 1 < n:
            cfg.append(w[i + 1]); i += 2
        elif a.startswith('--git-dir='):
            gd = a[10:]; i += 1
        elif a == '--git-dir' and i + 1 < n:
            gd = w[i + 1]; i += 2
        elif a.startswith('--work-tree='):
            wt = a[12:]; i += 1
        elif a == '--work-tree' and i + 1 < n:
            wt = w[i + 1]; i += 2
        elif a in ('--namespace', '--super-prefix', '--config-env') and i + 1 < n:
            i += 2
        elif a.startswith('-'):
            i += 1
        else:
            break
    sub = w[i] if i < n else ''
    # A dynamic subcommand ($S, $(...), `...`, {a,b}) or an alias that runs a shell command (alias.x=!...) cannot be
    # judged: the call is fuzzy and kept for any subcommand asked for (dyn). A plain alias is resolved.
    dyn = '(' in sub or '{' in sub or _dyn(sub)
    al = dict((k[6:].split('=', 1)[0].lower(), k.split('=', 1)[1]) for k in cfg if k[:6].lower() == 'alias.' and '=' in k)
    bang = None
    for _ in range(5):
        val = al.get(sub.lower())
        if val is None:
            break
        if val.startswith('!'):
            bang = val[1:]; dyn = True
            break
        sub = (val.split() or [sub])[0]
    dyn = dyn or (bool(al) and sub not in _GITSUB)
    st['out'].append({'sub': sub, 'args': w[i + 1:], 'dir': d, 'gitdir': gd, 'worktree': wt, 'cfg': cfg, 'fuzzy': fuzzy or dyn, 'dyn': dyn})
    if bang:
        _walk(bang, d, st, 3, False)

def _run(w, cwd, st, depth):
    # Interpret one simple command. Returns the working directory for the commands after it.
    w, chd, env = _unwrap(w)
    here = _join(cwd, chd) if chd else cwd
    if not w:
        return cwd
    c = _base(w[0]); a = w[1:]
    if c in _CD:
        t = None
        for k, x in enumerate(a):
            if x.lower() in ('-path', '-literalpath') and k + 1 < len(a):
                t = a[k + 1]
                break
        else:
            p = [x for x in a if x == '-' or not x.startswith('-')]
            t = p[0] if p else '~'
        return None if t == '-' else _join(here, t)
    if c in _SH:
        for k, x in enumerate(a):
            if x[:1] == '-' and x[:2] != '--' and 'c' in x[1:]:
                if k + 1 < len(a):
                    _walk(a[k + 1], here, st, depth + 1, False)
                return cwd
        st['shell'] = True
    elif c in ('pwsh', 'powershell'):
        for k, x in enumerate(a):
            if x.lower() in ('-command', '-c', '-cmd'):
                _walk(' '.join(a[k + 1:]), here, st, depth + 1, True)
                break
    elif c == 'cmd':
        for k, x in enumerate(a):
            if x.lower() in ('/c', '/k', '/r'):
                _walk(' '.join(a[k + 1:]), here, st, depth + 1, True)
                break
    elif c == 'eval':
        _walk(' '.join(a), here, st, depth + 1)
    elif c == 'xargs':
        for k, x in enumerate(a):
            if _base(x) == 'git':
                _git(a[k:], here, st, True, env)
                return cwd
        k = 0
        while k < len(a) and a[k].startswith('-'):
            k += 2 if a[k] in ('-I', '-L', '-n', '-P', '-s', '-d', '-E', '-a', '-J') else 1
        if k < len(a):
            _run(a[k:], here, st, depth + 1)
    elif c == 'git':
        _git(w, here, st, False, env)
    elif _dyn(w[0]):
        _git(['git'] + a, here, st, True, env)
    return cwd

def _walk(s, cwd, st, depth, ps=None):
    if depth > 6:
        st['unparsed'] = True
        return
    outer = st['ps']
    if ps is not None:
        st['ps'] = ps
    try:
        items, _, ok = _scan(s, 0, False, st['ps'])
        if not ok:
            st['unparsed'] = True
        stack = []; shell = False
        for it in items:
            if it[0] == '(':
                stack.append(cwd)
            elif it[0] == ')':
                cwd = stack.pop() if stack else cwd
            elif it[0] == 'h':
                if shell:
                    _walk(it[1], cwd, st, depth + 1, False)
            else:
                st['shell'] = False
                cwd = _run(it[1], cwd, st, depth)
                shell = st['shell']
    finally:
        st['ps'] = outer

def git_calls(cmd, base, sub, ps=False):
    # Every `git ... <sub>` the command would run, in order: dict(sub, args, dir, gitdir, worktree,
    # cfg, fuzzy, dyn, before). dir is None when it cannot be known; fuzzy marks a call that could only be
    # guessed (xargs, a variable as the command, unparseable text); dyn marks a dynamic subcommand or a shell
    # alias, kept whatever sub is asked for; before lists the earlier git calls.
    # ps is true for PowerShell text (a backslash is a path character there, not an escape).
    st = {'out': [], 'unparsed': False, 'shell': False, 'ps': ps}
    _walk(cmd, base, st, 0)
    for k, c in enumerate(st['out']):
        c['before'] = st['out'][:k]
    out = [c for c in st['out'] if c['sub'] == sub or c.get('dyn')]
    if st['unparsed'] and any(re.search(r'\bgit(\.exe)?\b[^\n]*\b' + sub + r'\b', x) for x in (cmd, _flat(cmd))):
        out.append({'sub': sub, 'args': [], 'dir': base, 'gitdir': None, 'worktree': None, 'cfg': [], 'fuzzy': True, 'before': st['out']})
    return out

def native(d):
    # A directory string a Windows Python can open (Git Bash style /c/x or /tmp/x become C:/x).
    if d and os.name == 'nt' and d.startswith('/') and not d.startswith('//'):
        try:
            r = subprocess.run(['cygpath', '-m', d], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True, timeout=10)
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.strip()
        except Exception:
            pass
        m = re.match(r'^/([A-Za-z])(/.*)?$', d)
        if m:
            return m.group(1) + ':' + (m.group(2) or '/')
    return d

def git_run(call, args, env=None, cfgok=False):
    # Run git for a call (its -C, --git-dir and --work-tree applied). Returns the CompletedProcess or None.
    # Command-supplied -c pairs are NOT passed (core.fsmonitor=<program> would make the hook run the program
    # before the user's permission decision); with cfgok only remote., url., branch. and push. keys are, case-insensitive.
    argv = ['git']
    for k in (call.get('cfg') or []) if cfgok else []:
        if k.split('=', 1)[0].lower().startswith(_CFGOK):
            argv += ['-c', k]
    if call.get('dir'):
        argv += ['-C', native(call['dir'])]
    if call.get('gitdir'):
        argv.append('--git-dir=' + native(call['gitdir']))
    if call.get('worktree'):
        argv.append('--work-tree=' + native(call['worktree']))
    try:
        return subprocess.run(argv + list(args), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              universal_newlines=True, encoding='utf-8', errors='replace', env=env, timeout=30)
    except Exception:
        return None
# END SHARED CMDPARSE
import json, sys

def deny(msg):
    sys.stderr.write(msg + '\n')
    sys.exit(2)

def push_target(args):
    # --repo X, else the first non-option word after push. -o/--push-option/--receive-pack/--exec
    # take a separate value, which is skipped.
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--':
            i += 1
            break
        if a in ('-o', '--push-option', '--receive-pack', '--exec'):
            i += 2
        elif a == '--repo' and i + 1 < len(args):
            return args[i + 1]
        elif a.startswith('--repo='):
            return a[7:]
        elif a.startswith('-'):
            i += 1
        else:
            return a
    return args[i] if i < len(args) else None

def cfg(call, key):
    r = git_run(call, ['config', '--get', key], None, True)
    return r.stdout.strip() if r is not None and r.returncode == 0 else ''

def default_remote(call):
    r = git_run(call, ['symbolic-ref', '--short', '-q', 'HEAD'], None, True)
    br = r.stdout.strip() if r is not None and r.returncode == 0 else ''
    for v in ((br and cfg(call, 'branch.%s.pushRemote' % br)), cfg(call, 'remote.pushDefault'),
              (br and cfg(call, 'branch.%s.remote' % br))):
        if v and v != '.':
            return v
    return 'origin'

try:
    data = json.load(sys.stdin)
    cmd = data['tool_input']['command']
    cwd = data.get('cwd')
except Exception:
    sys.exit(0)
if not isinstance(cmd, str):
    sys.exit(0)
try:
    named = mentions(cmd, 'push')
except Exception:
    named = True  # cannot tell: look at it
if not named:
    sys.exit(0)
ps = data.get('tool_name') == 'PowerShell'
base = (cwd if isinstance(cwd, str) and cwd else os.getcwd()).replace('\\', '/')
domains = os.environ.get('BLOCKED_DOMAINS', '').split()
have_git = shutil.which('git') is not None

try:
    calls = git_calls(cmd, base, 'push', ps)
except Exception:
    calls = [{'fuzzy': True, 'args': [], 'dir': base}] if any(re.search(r'\bgit\b.*\bpush\b', x, re.S) for x in (cmd, _flat(cmd))) else []

try:
    for call in calls:
        if os.environ.get('CCB_GUARD_FAULT'):
            raise RuntimeError('injected fault (test seam)')
        if call['fuzzy']:
            deny('Blocked: cannot tell where this git push goes (xargs, a variable as the command, or text that '
                 'does not parse). Push manually to control CI/CD timing.')
        target = push_target(call['args'])
        literal = target is not None and (re.search(r'://|:|@|^[./~\\]', target) is not None)
        if target is not None and _dyn(target):
            deny('Blocked: cannot tell where this git push goes: the target "%s" is built from a variable or a '
                 'substitution. Name the remote directly, or push manually.' % target)
        if literal:
            urls = [target]
            if have_git:
                r = git_run(call, ['ls-remote', '--get-url', target], None, True)
                if r is not None and r.returncode == 0 and r.stdout.strip():
                    urls += r.stdout.split()
        else:
            if not have_git:
                sys.stderr.write('block-git-push: git not found on PATH: cannot resolve the push target, allowing\n')
                continue
            if call['dir'] is None and not call['gitdir']:
                deny('Blocked: cannot tell where this git push goes: its working directory comes from a '
                     'variable or a substitution. Push manually to control CI/CD timing.')
            name = target or default_remote(call)
            r = git_run(call, ['remote', 'get-url', '--push', '--all', name], None, True)
            if r is not None and 'cannot change to' in r.stderr:
                deny('Blocked: cannot tell where this git push goes: the directory %s does not exist. Push '
                     'manually to control CI/CD timing.' % call['dir'])
            if r is None or r.returncode != 0 or not r.stdout.strip():
                deny('Blocked: cannot tell where this git push goes: no remote named "%s" in %s. Push manually '
                     'to control CI/CD timing.' % (name, call['dir'] or 'the current directory'))
            urls = r.stdout.split()
        for u in urls:
            for dom in domains:
                if dom.lower() in u.lower():
                    deny('Blocked: git push to %s is not allowed. Push manually to control CI/CD timing.' % dom)
except Exception as e:
    # A push was found but judging it failed: block, never allow on an error.
    deny('Blocked: a git push was detected but the guard could not judge it (%s: %s). Push manually to control CI/CD timing.' % (type(e).__name__, ' '.join(str(e).split())))
sys.exit(0)
PYEOF

# The parser source is too long for a safe command line (a Windows one tops out near 32 KB): it runs from
# a temp file, in isolated mode (no script directory or PYTHON* variables on the import path). When no temp
# file can be made it falls back to -c.
PYF=$(mktemp "${TMPDIR:-/tmp}/ccb-parse-XXXXXX" 2>/dev/null)
if [ -n "$PYF" ] && printf '%s' "$PY_SRC" > "$PYF" 2>/dev/null; then
  trap 'rm -f "$PYF"' EXIT
  PYARGS=(-I "$(cygpath -m "$PYF" 2>/dev/null || printf '%s' "$PYF")")
else
  PYARGS=(-c "$PY_SRC")
fi
printf '%s' "$INPUT" | BLOCKED_DOMAINS="$BLOCKED_DOMAINS" "$PYTHON" "${PYARGS[@]}"
rc=$?
# 0 = allow, 2 = the parser's own block. Any other status means the parser died: Claude Code reads
# that as a non-blocking error and would run the command, so when the command could be a push it
# is turned into a block here.
if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then
  # The text is checked with quotes, backslashes and backticks removed, so git pu""sh and git pu\sh count too.
  NORM=$(printf '%s' "$INPUT" | tr -d "\\\\\"'\`")
  case "$INPUT$NORM" in
    *push*)
      echo "Blocked: a git push may be in this command but the guard failed (parser exit $rc). Push manually to control CI/CD timing." >&2
      exit 2 ;;
  esac
  exit 0
fi
exit $rc
