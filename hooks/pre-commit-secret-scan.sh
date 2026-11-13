#!/bin/bash
# Hook: PreToolUse (Bash and PowerShell matchers). Secret Scan Before Commit
# Scans what a `git commit` would record with gitleaks, before the commit runs.
# Blocks the commit (exit 2) if gitleaks detects a secret. This is a security
# gate, the same documented exception to "exit 0 always" that block-git-push.sh uses.
# Allows the commit (exit 0) when: gitleaks is clean, gitleaks isn't installed
# (fail-open), the command isn't a commit, or the input is malformed.
#
# It judges the commit that would actually run, not the text of the command:
#   - the command is split into its parts (; && || | newlines, outside quotes) and unwrapped
#     through env, sudo, command, nohup, time, VAR=val, bash -c, eval, $(...) and backticks;
#   - `git commit` is recognised with global options (`git -C dir commit`, `git -c k=v commit`,
#     `git  commit`), and `cd dir` is tracked per part (base directory: the payload cwd, else the
#     hook's cwd), so the repo that is scanned is the repo that is committed;
#   - it scans the index, plus the tracked working-tree changes when the commit has -a/--all or a
#     pathspec, plus the files an earlier `git add` in the same command would stage (a throwaway
#     index and object directory, so your repo is not touched);
#   - `--amend` and `--no-verify` are not skipped. --no-verify skips git's own hooks, not this
#     Claude-side gate;
#   - a clean gitleaks result is re-run up to 2 more times while the diff is non-empty, because
#     gitleaks 8.30.1 has been seen to report no leaks intermittently.
#
# A commit whose directory cannot be resolved (`cd "$DIR"`, `cd ~user`, `cd -`) is blocked with a message, not
# scanned in the payload directory. A subcommand built at run time (`git $S -m x`) and a shell alias given on the
# command line (`-c 'alias.c=!git commit -am x'`) are scanned as a commit. No command-supplied -c pair is passed
# to this hook's own git calls: `-c core.fsmonitor=<program>` would otherwise make the hook run the program
# before you decide. PowerShell text is read as PowerShell (a backtick escapes the next character).
#
# Threat model: these hooks stop accidental pushes to protected remotes and accidental secret commits; they
# are not a sandbox against deliberately obfuscated commands, so a parser cannot follow every shell expansion.
# Known limits: the command text is what is read, so a commit handed to another interpreter is not seen
# (`echo "git commit" | bash`, `find -exec git commit`, `su -c`, PowerShell `iex` and `Start-Process`), and a
# secret written to a new file earlier in the same command line is not scanned: the file does not exist yet
# when the hook runs. Also not followed: `pwsh -EncodedCommand` (base64 text) and abbreviated pwsh parameters
# (only -Command, -c and -cmd are read), the glued `cmd /c"..."` form, a directory change by popd or
# Pop-Location (cd, pushd and Set-Location are tracked), and a hook that Claude Code stops at its timeout does
# not block (the commit then runs unscanned).
#
# Fail closed: when a commit was detected but its scan cannot be prepared or run (the throwaway scan
# directory cannot be created, git does not answer, the parser dies, gitleaks exits with an error), the
# commit is blocked (exit 2) with a message. Only a missing gitleaks allows, with a note.
# $CCB_SCAN_TMPDIR names the directory for the throwaway scan files (default: the system temp dir); the
# tests point it at a path that cannot be created.
#
# Without Python the hook cannot parse the command: it warns on stderr and allows (fail-open, documented), like
# block-git-push.sh.
# Requires gitleaks on PATH to actually scan. Without it the hook is a no-op + warns:
#   winget install gitleaks   (Windows)   |   brew install gitleaks   (macOS)
# $GITLEAKS_BIN (default gitleaks) names the binary: it is the seam the tests use.

# python3 can be the Windows Store stub (under WindowsApps, exits 49): skip it unless it runs.
PYTHON=""
for _p in python3 python py; do
  _c=$(command -v "$_p" 2>/dev/null) || continue
  case "$_c" in *[Ww]indows[Aa]pps*) "$_c" -c '' >/dev/null 2>&1 || continue ;; esac
  PYTHON=$_c; break
done
if [ -z "$PYTHON" ]; then
  echo "pre-commit-secret-scan: python not found: hook cannot scan, allowing the commit unscanned" >&2
  exit 0
fi

INPUT=$(cat)

# The parser below is the same text in block-git-push.sh, pre-commit-secret-scan.sh and
# post-commit-review.sh. Hooks stay standalone (no shared file), and hooks/test-hooks.sh
# diffs the copies, so edit all three together.
#
# The Python part finds the commits and prepares what each one would record. It prints one
# line per commit: repo top, then (when an overlay is needed) a throwaway index, object
# directory, alternates path and temp dir, with "-" for "none".
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
import json, sys, tempfile

try:
    data = json.load(sys.stdin)
    cmd = data['tool_input']['command']
    cwd = data.get('cwd')
except Exception:
    sys.exit(0)
if not isinstance(cmd, str):
    sys.exit(0)
try:
    named = mentions(cmd, 'commit')
except Exception:
    named = True  # cannot tell: look at it
if not named:
    sys.exit(0)
ps = data.get('tool_name') == 'PowerShell'
base = (cwd if isinstance(cwd, str) and cwd else os.getcwd()).replace('\\', '/')

def commit_flags(args):
    # (-a/--all given, pathspecs). Options that take a separate value are skipped.
    allf = False; paths = []; i = 0
    longv = ('--message', '--file', '--reuse-message', '--reedit-message', '--template', '--author',
             '--date', '--cleanup', '--fixup', '--squash', '--pathspec-from-file', '--trailer')
    while i < len(args):
        a = args[i]
        if a == '--':
            paths += args[i + 1:]
            break
        if a == '--all':
            allf = True
        elif a.startswith('--'):
            if a in longv:
                i += 1
        elif a.startswith('-') and len(a) > 1:
            for k, ch in enumerate(a[1:]):
                if ch == 'a':
                    allf = True
                if ch in 'uS':
                    break
                if ch in 'mFCct':
                    if k == len(a) - 2:
                        i += 1
                    break
        else:
            paths.append(a)
        i += 1
    return allf, paths

def out(r):
    return r.stdout.strip() if r is not None and r.returncode == 0 else ''

def abspath(call, p):
    if p and not os.path.isabs(p) and not re.match(r'^[A-Za-z]:', p):
        p = os.path.join(native(call['dir']) if call.get('dir') else os.getcwd(), p)
    return p

def same(a, b):
    return a.replace('\\', '/').lower() == b.replace('\\', '/').lower()

try:
    calls = git_calls(cmd, base, 'commit', ps)
except Exception:
    calls = [{'sub': 'commit', 'args': [], 'dir': base, 'gitdir': None, 'worktree': None, 'cfg': [], 'fuzzy': True, 'before': []}]

pending = None  # a throwaway directory that was created but not yet handed to the shell

def fail(msg):
    # A commit was found but its scan could not be prepared: remove what this job made, tell the
    # shell (a "!" line) and exit 3. The shell blocks the commit: an error must never allow it.
    if pending:
        shutil.rmtree(pending, ignore_errors=True)
    sys.stdout.buffer.write(('!\t' + ' '.join(str(msg).split()) + '\n').encode('utf-8', 'replace'))
    sys.stdout.flush()
    sys.exit(3)

def need(r, what):
    # A git call that timed out or could not run (git_run gave None) is an error, not "no repo".
    if r is None:
        raise RuntimeError('git did not answer: ' + what)
    return r

try:
    for call in calls:
        if not call.get('dir'):
            if not call.get('gitdir'):
                fail('cannot tell which repository this commit goes to: its directory comes from a variable, a ~user path or cd -')
            call['dir'] = base
        top = out(need(git_run(call, ['rev-parse', '--show-toplevel']), 'rev-parse --show-toplevel'))
        gd = out(need(git_run(call, ['rev-parse', '--git-dir']), 'rev-parse --git-dir'))
        if not top or not gd:
            continue
        allf, paths = commit_flags(call['args'])
        adds = []
        for b in call['before']:
            if b['sub'] not in ('add', 'stage') or any(x in ('-p', '--patch', '-i', '--interactive', '-e', '--edit', '-n', '--dry-run') for x in b['args']):
                continue
            if not b.get('dir'):
                b['dir'] = base
            if same(out(need(git_run(b, ['rev-parse', '--show-toplevel']), 'rev-parse --show-toplevel')), top):
                adds.append(b)
        idx = obj = alt = tmp = '-'
        if allf or paths or adds:
            ip = abspath(call, out(need(git_run(call, ['rev-parse', '--git-path', 'index']), 'rev-parse --git-path index')))
            op = abspath(call, out(need(git_run(call, ['rev-parse', '--git-path', 'objects']), 'rev-parse --git-path objects')))
            if not (ip and op):
                raise RuntimeError('cannot locate the index or the object directory')
            tmp = tempfile.mkdtemp(prefix='ccb-scan-', dir=os.environ.get('CCB_SCAN_TMPDIR') or None)
            pending = tmp
            idx = tmp + '/index'
            obj = tmp + '/obj'
            alt = op
            os.mkdir(obj)
            try:
                shutil.copyfile(ip, idx)
            except (IOError, OSError):
                pass
            env = dict(os.environ, GIT_INDEX_FILE=idx, GIT_OBJECT_DIRECTORY=obj, GIT_ALTERNATE_OBJECT_DIRECTORIES=alt)
            if allf:
                need(git_run(call, ['add', '-u'], env), 'add -u')
            elif paths:
                need(git_run(call, ['add', '-u', '--'] + paths, env), 'add -u with pathspecs')
            for b in adds:
                need(git_run(b, ['add'] + b['args'], env), 'add')
        sys.stdout.buffer.write(('\t'.join([top, idx, obj, alt, tmp]) + '\n').encode('utf-8'))
        sys.stdout.flush()
        pending = None
except Exception as e:
    fail('%s: %s' % (type(e).__name__, e))
PYEOF

# The Python exit status is checked: 0 = every commit found was prepared (JOBS may be empty), 3 = a
# commit was found and its scan could not be prepared (a "!" line says why), anything else = the
# parser itself died. When the command could be a commit, an error blocks it; it never allows it.
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
JOBS=$(printf '%s' "$INPUT" | "$PYTHON" "${PYARGS[@]}" 2>/dev/null)
PYRC=$?
JOBS=${JOBS//$'\r'/}

# cleanup_jobs: remove the throwaway index and object directories.
cleanup_jobs() {
  local _t _i _o _a _d
  while IFS=$'\t' read -r _t _i _o _a _d; do
    [ "$_t" != "!" ] && [ -n "$_d" ] && [ "$_d" != "-" ] && rm -rf "$_d"
  done <<< "$JOBS"
}

if [ "$PYRC" -ne 0 ]; then
  if [ "$PYRC" -ne 3 ]; then
    # The text is checked with quotes, backslashes and backticks removed, so git comm""it and git comm\it count too.
    NORM=$(printf '%s' "$INPUT" | tr -d "\\\\\"'\`")
    case "$INPUT$NORM" in *commit*) ;; *) cleanup_jobs; exit 0 ;; esac
  fi
  _why=""
  while IFS=$'\t' read -r _t _m; do
    if [ "$_t" = "!" ]; then _why=$_m; break; fi
  done <<< "$JOBS"
  [ -z "$_why" ] && _why="the command parser exited with status $PYRC"
  echo "Blocked: a git commit was detected but its secret scan could not be prepared ($_why)." >&2
  echo "         The commit is not allowed unscanned. Fix the cause, or ask the user to commit it themselves." >&2
  cleanup_jobs
  exit 2
fi
[ -z "$JOBS" ] && exit 0

GL="${GITLEAKS_BIN:-gitleaks}"
# gitleaks must be on PATH; fail open (warn, allow) if absent
if ! command -v "$GL" >/dev/null 2>&1; then
  echo "Note: gitleaks not installed; pre-commit secret scan skipped." >&2
  echo "      Install to enable: 'winget install gitleaks' or 'brew install gitleaks'." >&2
  cleanup_jobs
  exit 0
fi

# scan_once <repo-top> [env assignments...]: run gitleaks on what git would commit. --staged: the
# index (the throwaway one when env is given); --redact: hide secret values (show pattern + file);
# --exit-code 1: non-zero on findings. Older gitleaks has no `git` command, so retry as `protect`.
scan_once() {
  local top="$1"; shift
  local out rc
  out=$(cd "$top" && env "$@" "$GL" git --staged --no-banner --redact --exit-code 1 2>&1 </dev/null); rc=$?
  if [ $rc -ne 0 ] && [ $rc -ne 1 ] && printf '%s' "$out" | grep -qi 'unknown command'; then
    out=$(cd "$top" && env "$@" "$GL" protect --staged --no-banner --redact --exit-code 1 2>&1 </dev/null); rc=$?
  fi
  GL_OUT="$out"
  return $rc
}

while IFS=$'\t' read -r TOP IDX OBJ ALT _; do
  ENVV=()
  if [ "$IDX" != "-" ]; then
    ENVV=(GIT_INDEX_FILE="$IDX" GIT_OBJECT_DIRECTORY="$OBJ" GIT_ALTERNATE_OBJECT_DIRECTORIES="$ALT")
  fi
  tries=0
  while [ $tries -lt 3 ]; do
    tries=$((tries + 1))
    scan_once "$TOP" "${ENVV[@]}"
    GL_RC=$?
    if [ $GL_RC -ne 0 ]; then
      if [ $GL_RC -eq 1 ]; then
        echo "Blocked: gitleaks detected potential secret(s) in the content this commit would record, in $TOP" >&2
      else
        echo "Blocked: gitleaks failed to run (exit $GL_RC) on the content this commit would record, in $TOP. The commit is not allowed unscanned." >&2
      fi
      echo "$GL_OUT" | head -30 >&2
      echo "" >&2
      echo "To resolve:" >&2
      echo "  1) Unstage the secret (git reset <file>) and remove it from the file" >&2
      echo "  2) Rotate the leaked credential (assume it is compromised)" >&2
      echo "  3) Commit again once the content is clean" >&2
      echo "  4) Allowlist a false positive in .gitleaks.toml, or ask the user to commit it themselves" >&2
      cleanup_jobs
      exit 2
    fi
    # Clean result: gitleaks has reported no leaks intermittently, so look again while there is a diff.
    (cd "$TOP" && env "${ENVV[@]}" git diff --cached --quiet >/dev/null 2>&1 </dev/null)
    [ $? -eq 1 ] || break
  done
done <<< "$JOBS"

cleanup_jobs
exit 0
