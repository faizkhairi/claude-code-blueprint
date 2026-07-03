#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Claude Code Blueprint - Setup Script
# Installs hooks, agents, skills, rules, and settings to ~/.claude/
# https://github.com/faizkhairi/claude-code-blueprint
# ============================================================

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/backup"
DRY_RUN=false
AUTO_YES=false
PRESET=""
INSTALLED_HOOKS=0
INSTALLED_AGENTS=0
INSTALLED_SKILLS=0
INSTALLED_RULES=0
SKIPPED=0
CONFLICTS=0

# --- File lists per preset ---

MINIMAL_HOOKS=(protect-config.sh notify-file-changed.sh)

STANDARD_HOOKS=(block-git-push.sh cost-tracker.sh session-checkpoint.sh post-commit-review.sh)
STANDARD_AGENTS=(verify-plan.md code-reviewer.md)

# Core adds two review agents + a curated, broadly-useful skill/rule set on top of Standard.
CORE_AGENTS=(security-reviewer.md qa-tester.md)
CORE_SKILLS=(review-full review-diff test-check deploy-check db-check changelog)
CORE_RULES=(testing.md database-schema.md)

FULL_HOOKS=(session-start.sh precompact-state.sh status-line.sh verify-mcp-sync.sh
            instructions-loaded.sh pre-commit-secret-scan.sh)
FULL_AGENTS=(architecture-reviewer.md backend-specialist.md db-analyst.md
             devops-engineer.md docs-writer.md frontend-specialist.md project-architect.md
             qa-tester.md security-reviewer.md)
SKILL_DIRS=(changelog db-check deploy-check e2e-check elicit-requirements
            scaffold-project load-session register-project review-full review-diff
            save-diary save-session session-end sprint-plan status tech-radar test-check)
RULE_FILES=(api-endpoints.md database-schema.md memory-session.md
            session-lifecycle.md testing.md testing-general.md)

# ============================================================
# Utility Functions
# ============================================================

print_header() {
  echo ""
  echo "  Claude Code Blueprint Setup v${VERSION}"
  echo "  ======================================="
  echo ""
}

print_usage() {
  echo "Usage: ./setup.sh [OPTIONS]"
  echo ""
  echo "Install Claude Code Blueprint components to ~/.claude/"
  echo ""
  echo "Options:"
  echo "  --preset=PRESET   Skip menu. PRESET: minimal, standard, core, full"
  echo "  --dry-run          Preview what would be installed (no changes)"
  echo "  --yes              Auto-confirm all prompts"
  echo "  --help             Show this help message"
  echo ""
  echo "Presets:"
  echo "  minimal   4 files   CLAUDE.md + 2 hooks + settings.json (60 seconds)"
  echo "  standard  10 files  + 4 hooks, 2 agents, settings.json (5 minutes)"
  echo "  core      20 files  + 2 review agents, 6 skills, 2 rules (curated, broadly useful)"
  echo "  full      48 files  + all agents, skills, rules (30 minutes)"
  echo ""
  echo "Examples:"
  echo "  ./setup.sh                          Interactive preset selection"
  echo "  ./setup.sh --preset=standard        Install standard preset"
  echo "  ./setup.sh --preset=full --dry-run  Preview full installation"
  echo "  ./setup.sh --preset=minimal --yes   Minimal, no prompts"
}

log_info()  { echo "  [INFO]  $*"; }
log_ok()    { echo "  [OK]    $*"; }
log_skip()  { echo "  [SKIP]  $*"; }
log_warn()  { echo "  [WARN]  $*"; }
log_error() { echo "  [ERROR] $*" >&2; }
log_dry()   { echo "  [DRY]   $*"; }

confirm() {
  # Auto-confirm when --yes is set OR stdin is not a TTY (piped/redirected/CI).
  # A bare `read` against a non-TTY hits EOF and, under `set -e`, aborts the whole
  # install. Returning 0 here means "proceed with the default", correct for an
  # unattended run. Covers all callers (safe_copy, offer_claude_md, replace_placeholders).
  if [ "$AUTO_YES" = true ] || ! [ -t 0 ]; then return 0; fi
  local prompt="$1 [y/N] "
  read -r -p "  $prompt" response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Darwin*)  echo "macos" ;;
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "windows-wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*) echo "windows-gitbash" ;;
    CYGWIN*)      echo "windows-cygwin" ;;
    *)            echo "unknown" ;;
  esac
}

# Portable sed -i (BSD vs GNU)
sed_inplace() {
  local os
  os="$(detect_os)"
  if [ "$os" = "macos" ]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Convert Git Bash paths (/c/Users/name) to Windows paths (C:/Users/name) for JSON
normalize_path_for_json() {
  local path="$1"
  local os
  os="$(detect_os)"
  if [[ "$os" == windows-* ]]; then
    # /c/Users/name -> C:/Users/name
    echo "$path" | sed 's|^/\([a-zA-Z]\)/|\U\1:/|'
  else
    echo "$path"
  fi
}

# Back up a file before overwriting
backup_file() {
  local file="$1"
  if [ ! -f "$file" ]; then return 0; fi
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local backup_path="${BACKUP_DIR}/$(basename "$file").${timestamp}"
  mkdir -p "$BACKUP_DIR"
  cp "$file" "$backup_path"
  log_info "Backed up to $backup_path"
}

# Safe copy with conflict detection
safe_copy() {
  local src="$1" dst="$2" category="$3"

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would copy: $(basename "$src") -> $dst"
    return 0
  fi

  if [ -f "$dst" ]; then
    if diff -q "$src" "$dst" >/dev/null 2>&1; then
      log_skip "Identical: $(basename "$dst")"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    echo ""
    log_warn "File exists and differs: $dst"
    diff --unified=3 "$dst" "$src" 2>/dev/null | head -15 || true
    echo "  ..."
    if ! confirm "Overwrite?"; then
      log_skip "Kept existing: $(basename "$dst")"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    backup_file "$dst"
    CONFLICTS=$((CONFLICTS + 1))
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log_ok "Installed: $(basename "$dst")"

  case "$category" in
    hook)  INSTALLED_HOOKS=$((INSTALLED_HOOKS + 1)) ;;
    agent) INSTALLED_AGENTS=$((INSTALLED_AGENTS + 1)) ;;
    skill) INSTALLED_SKILLS=$((INSTALLED_SKILLS + 1)) ;;
    rule)  INSTALLED_RULES=$((INSTALLED_RULES + 1)) ;;
  esac
}

# ============================================================
# Argument Parsing
# ============================================================

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --preset=*)  PRESET="${1#*=}" ;;
      --dry-run)   DRY_RUN=true ;;
      --yes)       AUTO_YES=true ;;
      --help)      print_usage; exit 0 ;;
      *)           log_error "Unknown option: $1"; print_usage; exit 1 ;;
    esac
    shift
  done

  if [ -n "$PRESET" ] && [[ ! "$PRESET" =~ ^(minimal|standard|core|full)$ ]]; then
    log_error "Invalid preset: $PRESET (must be minimal, standard, core, or full)"
    exit 1
  fi
}

# ============================================================
# Prerequisites
# ============================================================

check_prerequisites() {
  local missing=0

  for required in "CLAUDE.md" "hooks/protect-config.sh" "agents/verify-plan.md" "skills/review-full/SKILL.md" "examples/settings-template.json"; do
    if [ ! -f "${SCRIPT_DIR}/${required}" ]; then
      log_error "Missing: ${required}"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ]; then
    echo ""
    log_error "This script must be run from the claude-code-blueprint repository."
    log_error "Usage: cd claude-code-blueprint && ./setup.sh"
    exit 1
  fi

  # Warn if running from the blueprint repo directory itself
  if [ "$(pwd)" = "$SCRIPT_DIR" ]; then
    log_warn "You're in the blueprint repo directory."
    log_warn "CLAUDE.md will NOT be copied here (it should go in your project root)."
    echo ""
  fi
}

# ============================================================
# Preset Selection
# ============================================================

select_preset() {
  if [ -n "$PRESET" ]; then return 0; fi

  echo "  Choose a preset:"
  echo ""
  echo "    1) Minimal   : CLAUDE.md + 2 hooks (config protection, edit verification)"
  echo "    2) Standard  : + 4 more hooks, 2 agents, settings.json"
  echo "    3) Core      : + 2 review agents, 6 universal skills, 2 path-scoped rules"
  echo "    4) Full      : + all 11 agents, 17 skills, 6 rules (everything)"
  echo ""
  echo "  Not sure? Start with Standard or Core. You can run this script again to add more later."
  echo ""
  # Read the menu choice. A failed read (EOF / no input on a non-TTY) exits cleanly
  # instead of hanging; piped input (e.g. `echo 3 | setup.sh`) still works because
  # read succeeds with the piped value.
  if ! read -r -p "  Select [1/2/3/4]: " choice; then
    log_error "No preset selected (no input / EOF). Pass --preset=minimal|standard|core|full (or --yes)."
    exit 1
  fi

  case "$choice" in
    1) PRESET="minimal" ;;
    2) PRESET="standard" ;;
    3) PRESET="core" ;;
    4) PRESET="full" ;;
    *) log_error "Invalid choice. Please enter 1, 2, 3, or 4."; exit 1 ;;
  esac
  echo ""
}

# ============================================================
# Installation
# ============================================================

create_directories() {
  local dirs=("${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/agents" "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/rules" "$BACKUP_DIR")

  for dir in "${dirs[@]}"; do
    if [ "$DRY_RUN" = true ]; then
      # Full if/then, since a bare `[ ! -d ] && cmd` returns 1 when the dir exists,
      # and as the loop body's last statement that aborts the whole script under `set -e`.
      if [ ! -d "$dir" ]; then
        log_dry "Would create: $dir"
      fi
    else
      if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_ok "Created: $dir"
      fi
    fi
  done
}

install_hooks() {
  local hooks=("${MINIMAL_HOOKS[@]}")

  if [[ "$PRESET" == "standard" || "$PRESET" == "core" || "$PRESET" == "full" ]]; then
    hooks+=("${STANDARD_HOOKS[@]}")
  fi
  if [ "$PRESET" = "full" ]; then
    hooks+=("${FULL_HOOKS[@]}")
  fi

  echo ""
  log_info "Installing hooks (${#hooks[@]} files)..."
  for hook in "${hooks[@]}"; do
    safe_copy "${SCRIPT_DIR}/hooks/${hook}" "${CLAUDE_DIR}/hooks/${hook}" "hook"
  done
}

install_agents() {
  local agents=()

  if [[ "$PRESET" == "standard" || "$PRESET" == "core" || "$PRESET" == "full" ]]; then
    agents+=("${STANDARD_AGENTS[@]}")
  fi
  # Core-only: security-reviewer + qa-tester. Full gets these via FULL_AGENTS instead,
  # so this rung must NOT fire for full (it would install them twice).
  if [ "$PRESET" = "core" ]; then
    agents+=("${CORE_AGENTS[@]}")
  fi
  if [ "$PRESET" = "full" ]; then
    agents+=("${FULL_AGENTS[@]}")
  fi

  if [ ${#agents[@]} -eq 0 ]; then return 0; fi

  echo ""
  log_info "Installing agents (${#agents[@]} files)..."
  for agent in "${agents[@]}"; do
    safe_copy "${SCRIPT_DIR}/agents/${agent}" "${CLAUDE_DIR}/agents/${agent}" "agent"
  done
}

install_skills() {
  local skills=()
  if [ "$PRESET" = "core" ]; then
    skills=("${CORE_SKILLS[@]}")
  elif [ "$PRESET" = "full" ]; then
    skills=("${SKILL_DIRS[@]}")
  else
    return 0   # minimal/standard install no skills; explicit 0 so `set -e` doesn't abort
  fi

  echo ""
  log_info "Installing skills (${#skills[@]} skills)..."
  for skill in "${skills[@]}"; do
    safe_copy "${SCRIPT_DIR}/skills/${skill}/SKILL.md" "${CLAUDE_DIR}/skills/${skill}/SKILL.md" "skill"
  done
}

install_rules() {
  local rules=()
  if [ "$PRESET" = "core" ]; then
    rules=("${CORE_RULES[@]}")
  elif [ "$PRESET" = "full" ]; then
    rules=("${RULE_FILES[@]}")
  else
    return 0   # minimal/standard install no rules; explicit 0 so `set -e` doesn't abort
  fi

  echo ""
  log_info "Installing rules (${#rules[@]} files)..."
  for rule in "${rules[@]}"; do
    safe_copy "${SCRIPT_DIR}/rules/${rule}" "${CLAUDE_DIR}/rules/${rule}" "rule"
  done
}

install_settings() {
  # Every preset gets a settings.json so its installed hooks are actually wired
  # (minimal previously returned early, leaving its 2 hooks copied but never fired).
  # We ship ONE template and prune it down to the hooks this preset installed
  # (prune_settings_to_installed_hooks), so the wiring always matches reality.
  local src="${SCRIPT_DIR}/examples/settings-template.json"
  local dst="${CLAUDE_DIR}/settings.json"

  echo ""
  if [ "$DRY_RUN" = true ]; then
    if [ -f "$dst" ]; then
      log_dry "Would merge settings-template.json into existing settings.json (then prune to installed hooks)"
    else
      log_dry "Would copy settings-template.json -> settings.json (then prune to installed hooks)"
    fi
    return
  fi

  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    log_ok "Created: settings.json"
    prune_settings_to_installed_hooks "$dst"
    return
  fi

  # Existing settings.json: try merge, fallback to template copy
  log_info "Existing settings.json found. Attempting merge..."
  backup_file "$dst"

  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    local py
    py="$(command -v python3 2>/dev/null || command -v python)"
    "$py" - "$dst" "$src" << 'PYMERGE'
import json, os, sys

existing_path, template_path = sys.argv[1], sys.argv[2]

with open(existing_path) as f:
    existing = json.load(f)
with open(template_path) as f:
    template = json.load(f)

# Merge hooks. The Claude Code schema makes each event a LIST of matcher-blocks:
#   "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ {type, command|prompt} ] } ] }
# So we merge per matcher-block (keyed by its "matcher"), and within a matched block we
# append inner hooks not already present, keyed by (type, command|prompt) so command and
# prompt hooks both dedup correctly. This makes re-running the installer idempotent.
def hook_key(h):
    # Stable identity for an inner hook entry: its command, else its prompt, else its type.
    return (h.get("type", ""), h.get("command", h.get("prompt", "")))

if "hooks" in template:
    if "hooks" not in existing or not isinstance(existing.get("hooks"), dict):
        existing["hooks"] = {}
    for event, tmpl_blocks in template["hooks"].items():
        # Each event value is a list of matcher-blocks.
        if not isinstance(tmpl_blocks, list):
            continue
        if event not in existing["hooks"] or not isinstance(existing["hooks"][event], list):
            existing["hooks"][event] = []
        existing_blocks = existing["hooks"][event]
        # Index existing matcher-blocks by their matcher (default "" = no matcher).
        by_matcher = {b.get("matcher", ""): b for b in existing_blocks if isinstance(b, dict)}
        for tblock in tmpl_blocks:
            if not isinstance(tblock, dict):
                continue
            m = tblock.get("matcher", "")
            if m not in by_matcher:
                existing_blocks.append(tblock)
                by_matcher[m] = tblock
            else:
                eblock = by_matcher[m]
                seen = {hook_key(h) for h in eblock.get("hooks", []) if isinstance(h, dict)}
                for h in tblock.get("hooks", []):
                    if isinstance(h, dict) and hook_key(h) not in seen:
                        eblock.setdefault("hooks", []).append(h)
                        seen.add(hook_key(h))

# Merge env: add keys that don't exist
if "env" in template:
    if "env" not in existing:
        existing["env"] = {}
    for k, v in template["env"].items():
        if k not in existing["env"]:
            existing["env"][k] = v

# Add statusLine if the template defines one and the user has none (don't overwrite theirs).
# Placed before the prune pass so a preset that didn't install status-line.sh still drops it.
if "statusLine" in template and "statusLine" not in existing:
    existing["statusLine"] = template["statusLine"]

# Merge permissions.allow: append entries not present
if "permissions" in template and "allow" in template["permissions"]:
    if "permissions" not in existing:
        existing["permissions"] = {}
    if "allow" not in existing["permissions"]:
        existing["permissions"]["allow"] = []
    existing_perms = set(existing["permissions"]["allow"])
    for perm in template["permissions"]["allow"]:
        if perm not in existing_perms:
            existing["permissions"]["allow"].append(perm)

# Atomic write: temp file + os.replace, so a crash mid-write can't truncate the
# user's settings.json (install_settings also keeps a backup as a second safety net).
tmp_path = existing_path + ".tmp"
with open(tmp_path, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")
os.replace(tmp_path, existing_path)

print("  [OK]    Merged settings.json (hooks, env, permissions)")
PYMERGE
    prune_settings_to_installed_hooks "$dst"
  else
    log_warn "Python not found. Cannot auto-merge settings.json."
    cp "$src" "${dst}.blueprint-template"
    log_info "Saved template as: settings.json.blueprint-template"
    log_info "Manually merge hooks/permissions from the template into your existing settings.json."
  fi
}

# Remove command-hook entries that reference a blueprint hook script NOT installed
# under <claude>/hooks/ (e.g. FULL-only hooks wired by the shared template on a core
# install). Prunes now-empty matcher-blocks and now-empty events. Prompt-type hooks
# (no file) are always kept; user hooks pointing outside <claude>/hooks/ are untouched.
prune_settings_to_installed_hooks() {
  local settings="$1"
  command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || return 0
  local py
  py="$(command -v python3 2>/dev/null || command -v python)"
  "$py" - "$settings" "${CLAUDE_DIR}/hooks" << 'PYPRUNE'
import json, os, re, sys

settings_path, hooks_dir = sys.argv[1], sys.argv[2]
try:
    with open(settings_path) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)  # nothing safe to do; leave as-is

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    sys.exit(0)

# Match a hook script path that lives under <claude>/hooks/ and grab its basename.
HOOKS_REF = re.compile(r'/hooks/([^"\'\s]+\.sh)')

def keep(inner):
    # Keep anything without a command (prompt-type hooks have no file dependency).
    cmd = inner.get("command") if isinstance(inner, dict) else None
    if not cmd:
        return True
    m = HOOKS_REF.search(cmd)
    if not m:
        return True  # command points somewhere else (user's own hook), leave it
    return os.path.isfile(os.path.join(hooks_dir, m.group(1)))

removed = 0
for event in list(hooks.keys()):
    blocks = hooks[event]
    if not isinstance(blocks, list):
        continue
    new_blocks = []
    for block in blocks:
        if not isinstance(block, dict):
            new_blocks.append(block)
            continue
        inner = block.get("hooks", [])
        if isinstance(inner, list):
            kept = [h for h in inner if keep(h)]
            removed += len(inner) - len(kept)
            block["hooks"] = kept
            if not kept:
                continue  # drop matcher-block with no remaining hooks
        new_blocks.append(block)
    if new_blocks:
        hooks[event] = new_blocks
    else:
        del hooks[event]  # drop event with no remaining matcher-blocks

# statusLine is a separate top-level key, not under "hooks", but it also references a
# hook script (status-line.sh, FULL-only). Drop it if its script wasn't installed.
sl = data.get("statusLine")
if isinstance(sl, dict) and not keep(sl):
    del data["statusLine"]
    removed += 1

tmp_path = settings_path + ".tmp"
with open(tmp_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp_path, settings_path)  # atomic: never leave a half-written settings.json

if removed:
    print("  [OK]    Pruned %d hook(s) not installed by this preset" % removed)
PYPRUNE
}

offer_claude_md() {
  echo ""
  if [ "$(pwd)" = "$SCRIPT_DIR" ]; then
    log_info "Skipping CLAUDE.md (you're in the blueprint repo)."
    log_info "Copy it to your project root: cp ${SCRIPT_DIR}/CLAUDE.md /path/to/your/project/"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    log_dry "Would offer to copy CLAUDE.md to $(pwd)/"
    return
  fi

  if [ -f "$(pwd)/CLAUDE.md" ]; then
    log_skip "CLAUDE.md already exists in $(pwd)/"
  elif confirm "Copy CLAUDE.md to $(pwd)/ (your project root)?"; then
    cp "${SCRIPT_DIR}/CLAUDE.md" "$(pwd)/CLAUDE.md"
    log_ok "Copied CLAUDE.md to $(pwd)/"
  fi
}

# ============================================================
# Placeholder Replacement
# ============================================================

replace_placeholders() {
  if [ "$DRY_RUN" = true ]; then
    echo ""
    log_dry "Would prompt for placeholder variables and replace in installed files"
    return
  fi

  # Memory enablement (hybrid prompt, Y/n default Y)
  echo ""
  log_info "Memory persistence is an opt-in feature."
  log_info "When enabled, Claude remembers preferences, decisions, and session"
  log_info "context across sessions on this machine. Memory lives in ./memory/"
  log_info "Session, reminders, and diary are git-ignored (won't leak if you push"
  log_info "your fork); preferences/identity/decisions stay tracked by default."
  echo ""
  if [ "$AUTO_YES" = true ] || ! [ -t 0 ]; then
    memory_choice="Y"   # --yes / non-TTY: default memory on, don't block on read (EOF would abort under set -e)
  else
    read -r -p "  Enable persistent memory? [Y/n]: " memory_choice
  fi
  memory_choice="${memory_choice:-Y}"
  if [[ "$memory_choice" =~ ^[Yy] ]]; then
    log_ok "Memory enabled. session + reminders + diary are git-ignored; preferences/identity/decisions stay tracked unless you uncomment them in memory/.gitignore."
    rm -f "${CLAUDE_DIR}/.memory-disabled" 2>/dev/null || true
    # Seed personal session/reminders files from the tracked .example templates
    # (only if the real, git-ignored file does not already exist; never overwrite).
    for mem in session reminders; do
      mem_real="${SCRIPT_DIR}/memory/core/${mem}.md"
      mem_tmpl="${SCRIPT_DIR}/memory/core/${mem}.md.example"
      if [ ! -f "$mem_real" ] && [ -f "$mem_tmpl" ]; then
        if cp "$mem_tmpl" "$mem_real"; then
          log_info "Seeded memory/core/${mem}.md from template (this file is git-ignored)."
        else
          log_warn "Could not seed memory/core/${mem}.md (copy failed); create it manually if needed."
        fi
      fi
    done
  else
    log_info "Memory disabled. Skills load-session/save-session/save-diary/session-end will be no-ops."
    touch "${CLAUDE_DIR}/.memory-disabled" 2>/dev/null || true
  fi

  # Check if any installer-replaceable placeholders exist in installed files
  if ! grep -rqE '\{PROJECTS_ROOT\}|\{CLAUDE_CONFIG_PATH\}|\{USER_NAME\}|\{MEMORY_MD_PATH\}' "${CLAUDE_DIR}/" 2>/dev/null; then
    return
  fi

  echo ""
  log_info "Some installed files contain placeholder variables."
  echo ""

  if ! confirm "Replace placeholder variables now? (You can do this later manually)"; then
    log_info "Skipped. Replace later with: grep -r '{PROJECTS_ROOT}' ~/.claude/"
    return
  fi

  # Auto-detect what we can
  local claude_config_path user_name projects_root memory_md_path
  claude_config_path="$(normalize_path_for_json "$CLAUDE_DIR")"
  user_name="$(git config user.name 2>/dev/null || whoami)"
  # Global auto-memory index, derived from the config path (see skills/README.md).
  memory_md_path="${claude_config_path}/memory/MEMORY.md"

  echo ""
  if [ "$AUTO_YES" = true ] || ! [ -t 0 ]; then
    # --yes / non-TTY: accept the auto-detected name + default projects root, don't block on read.
    projects_root="$HOME/projects"
  else
    read -r -p "  Your name [$user_name]: " input
    user_name="${input:-$user_name}"

    read -r -p "  Projects root directory [~/projects]: " input
    projects_root="${input:-$HOME/projects}"
  fi
  projects_root="$(normalize_path_for_json "$projects_root")"

  echo ""

  # Replace in all files under ~/.claude/ (not the repo)
  local target_dirs=("${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/agents" "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/rules")
  for dir in "${target_dirs[@]}"; do
    [ ! -d "$dir" ] && continue
    find "$dir" -type f \( -name '*.md' -o -name '*.sh' \) 2>/dev/null | while read -r file; do
      sed_inplace "s|{CLAUDE_CONFIG_PATH}|${claude_config_path}|g" "$file" 2>/dev/null || true
      sed_inplace "s|{USER_NAME}|${user_name}|g" "$file" 2>/dev/null || true
      sed_inplace "s|{PROJECTS_ROOT}|${projects_root}|g" "$file" 2>/dev/null || true
      sed_inplace "s|{MEMORY_MD_PATH}|${memory_md_path}|g" "$file" 2>/dev/null || true
    done
  done

  # Fix settings.json paths
  if [ -f "${CLAUDE_DIR}/settings.json" ]; then
    sed_inplace "s|C:/Users/YourUser|${claude_config_path%/.claude}|g" "${CLAUDE_DIR}/settings.json" 2>/dev/null || true
    sed_inplace "s|/Users/youruser|${HOME}|g" "${CLAUDE_DIR}/settings.json" 2>/dev/null || true
  fi

  log_ok "Placeholder variables replaced"
}

# ============================================================
# Post-Install Verification
# ============================================================

verify_installation() {
  echo ""
  echo "  Verification"
  echo "  ------------"

  # Syntax check hooks
  local hook_errors=0
  for hook_file in "${CLAUDE_DIR}"/hooks/*.sh; do
    [ ! -f "$hook_file" ] && continue
    if ! bash -n "$hook_file" 2>/dev/null; then
      log_warn "Syntax error: $(basename "$hook_file")"
      hook_errors=$((hook_errors + 1))
    fi
  done
  if [ "$hook_errors" -eq 0 ]; then
    log_ok "All hooks pass syntax check"
  fi

  # Validate settings.json
  if [ -f "${CLAUDE_DIR}/settings.json" ]; then
    local py
    py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "")"
    if [ -n "$py" ]; then
      if "$py" -m json.tool "${CLAUDE_DIR}/settings.json" >/dev/null 2>&1; then
        log_ok "settings.json is valid JSON"
      else
        log_warn "settings.json has JSON syntax errors"
      fi
    fi
  fi

  # Check for unreplaced placeholders.
  # Guard the GREP itself with `|| true` INSIDE the pipeline: under `set -euo pipefail`
  # a no-match grep exits 1, which fails the whole pipeline and aborts the command
  # substitution (set -e). Neutralising grep's exit before the pipe means pipefail has
  # nothing to propagate, so a clean "0" is captured on the no-match (happy) path.
  local remaining
  # {BOILERPLATE_NAME} is intentionally left for the user to set in their own copy of the
  # scaffold-project skill (it names THEIR template repo, e.g. "nuxt-boilerplate"), so it is
  # not an installer responsibility, excluded from this check to avoid a permanent false WARN.
  remaining="$( { grep -rho '{PROJECTS_ROOT}\|{CLAUDE_CONFIG_PATH}\|{USER_NAME}\|{MEMORY_MD_PATH}' "${CLAUDE_DIR}/" 2>/dev/null || true; } | wc -l | tr -d '[:space:]')"
  remaining="${remaining:-0}"
  if [ "$remaining" -gt 0 ]; then
    log_warn "${remaining} unreplaced placeholder(s) remain. Run: grep -r '{' ~/.claude/ | grep -E '{[A-Z_]+}'"
  else
    log_ok "No unreplaced placeholders"
  fi
}

# ============================================================
# Summary
# ============================================================

print_summary() {
  local total=$((INSTALLED_HOOKS + INSTALLED_AGENTS + INSTALLED_SKILLS + INSTALLED_RULES))

  echo ""
  echo "  ======================================="
  echo "  Setup Complete"
  echo "  ======================================="
  echo ""
  echo "  Preset:   $PRESET"
  echo "  Hooks:    $INSTALLED_HOOKS installed"
  echo "  Agents:   $INSTALLED_AGENTS installed"
  echo "  Skills:   $INSTALLED_SKILLS installed"
  echo "  Rules:    $INSTALLED_RULES installed"
  echo "  Skipped:  $SKIPPED (identical or declined)"
  echo "  Conflicts: $CONFLICTS (resolved with backup)"
  echo "  Total:    $total files installed"
  echo ""
  echo "  Next steps:"
  echo "  1. Copy CLAUDE.md to your project root (if not done)"
  echo "  2. Start Claude Code in your project: cd your-project && claude"
  echo "  3. Review ~/.claude/settings.json and adjust permissions"
  echo "  4. Read docs/WHY.md to understand the reasoning behind each component"
  if [[ "$PRESET" == "core" || "$PRESET" == "full" ]]; then
    echo "  5. Read agents/README.md for model tiering and cost guidance"
  fi
  echo ""
}

# ============================================================
# Main
# ============================================================

main() {
  parse_args "$@"
  print_header

  if [ "$DRY_RUN" = true ]; then
    log_info "DRY RUN: no files will be modified"
    echo ""
  fi

  check_prerequisites
  select_preset

  log_info "Installing ${PRESET} preset to ${CLAUDE_DIR}/"
  echo ""

  create_directories
  offer_claude_md
  install_hooks
  install_agents
  install_skills
  install_rules
  install_settings

  if [ "$DRY_RUN" = false ]; then
    replace_placeholders
    verify_installation
    print_summary
  else
    echo ""
    log_info "DRY RUN complete. Run without --dry-run to install."
  fi
}

main "$@"
