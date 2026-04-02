#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_NAME="forge-pack"

detect_skills_dir() {
  if [[ -n "${FORGE_SKILLS_DIR:-}" ]]; then
    printf '%s\n' "$FORGE_SKILLS_DIR"
  elif [[ -d "$HOME/.claude" ]]; then
    printf '%s\n' "$HOME/.claude/skills"
  elif [[ -d "$HOME/.codex" ]]; then
    printf '%s\n' "$HOME/.codex/skills"
  else
    printf '%s\n' "$HOME/.claude/skills"
  fi
}
MANIFEST_NAME=".forge-pack-install.json"
SKILL_NAMES=(
  forge-orchestrator
  forge-init
  spec-intake
  spec-loop
  spec-completeness
  spec-synthesis-review
  spec-adversarial-review
  spec-plan-handoff
  spec-beads-generate
  spec-beads-review
  autoresearch-loop
)

log() {
  printf '[%s] %s\n' "$CLI_NAME" "$1"
}

fail() {
  printf '[%s] ERROR: %s\n' "$CLI_NAME" "$1" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

skills_dir() {
  detect_skills_dir
}

install_mode() {
  printf '%s\n' "${FORGE_INSTALL_MODE:-link}"
}

manifest_path() {
  printf '%s/%s\n' "$(skills_dir)" "$MANIFEST_NAME"
}

ensure_prereqs() {
  has_cmd python3 || fail "python3 is required"
}

write_manifest() {
  local target_dir="$1"
  local mode="$2"
  TARGET_DIR="$target_dir" ROOT="$ROOT_DIR" MODE="$mode" python3 - <<'PY'
import json, os
skills = [
  "forge-orchestrator",
  "forge-init",
  "spec-intake",
  "spec-loop",
  "spec-completeness",
  "spec-synthesis-review",
  "spec-adversarial-review",
  "spec-plan-handoff",
  "spec-beads-generate",
  "spec-beads-review",
  "autoresearch-loop",
]
path = os.path.join(os.environ["TARGET_DIR"], ".forge-pack-install.json")
data = {
  "root_dir": os.environ["ROOT"],
  "install_mode": os.environ["MODE"],
  "skills": skills,
}
with open(path, "w", encoding="utf-8") as f:
  json.dump(data, f, indent=2)
  f.write("\n")
PY
}

install_skills() {
  ensure_prereqs

  local target_dir
  target_dir="$(skills_dir)"
  local mode
  mode="$(install_mode)"

  mkdir -p "$target_dir"

  local skill
  for skill in "${SKILL_NAMES[@]}"; do
    local src="$ROOT_DIR/skills/$skill"
    local dest="$target_dir/$skill"

    [[ -d "$src" ]] || fail "missing skill dir: $src"
    rm -rf "$dest"

    case "$mode" in
      link)
        ln -s "$src" "$dest"
        ;;
      copy)
        cp -R "$src" "$dest"
        ;;
      *)
        fail "unsupported install mode: $mode"
        ;;
    esac
  done

  write_manifest "$target_dir" "$mode"
  log "installed skills into $target_dir using mode=$mode"
}

uninstall_skills() {
  ensure_prereqs

  local target_dir
  target_dir="$(skills_dir)"
  local manifest
  manifest="$(manifest_path)"

  if [[ -f "$manifest" ]]; then
    local skill
    for skill in "${SKILL_NAMES[@]}"; do
      rm -rf "$target_dir/$skill"
    done
    rm -f "$manifest"
    log "removed managed skills from $target_dir"
  else
    log "no managed install manifest found at $manifest"
  fi
}

doctor() {
  ensure_prereqs
  log "root: $ROOT_DIR"
  log "skills dir: $(skills_dir)"
  log "install mode: $(install_mode)"

  local skill
  for skill in "${SKILL_NAMES[@]}"; do
    [[ -f "$ROOT_DIR/skills/$skill/SKILL.md" ]] || fail "missing $skill/SKILL.md"
  done

  [[ -f "$ROOT_DIR/scripts/smoke-test.sh" ]] || fail "missing smoke-test.sh"
  log "doctor ok"
}

list_skills() {
  local skill
  for skill in "${SKILL_NAMES[@]}"; do
    printf '%s\n' "$skill"
  done
}

where_cmd() {
  printf 'root=%s\n' "$ROOT_DIR"
  printf 'skills_dir=%s\n' "$(skills_dir)"
  printf 'manifest=%s\n' "$(manifest_path)"
}

smoke_test() {
  "$ROOT_DIR/scripts/smoke-test.sh"
}

test_local() {
  "$ROOT_DIR/scripts/test-local.sh"
}

init_cmd() {
  # Ensure we're in a git repo
  git rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repository"

  local config_dir=".forge"
  local config_file="$config_dir/config.json"
  local git_hooks_dir
  git_hooks_dir="$(git rev-parse --git-dir)/hooks"

  mkdir -p "$config_dir"

  log "detecting project type..."

  # Detect project type and suggest commands
  local commands=()

  if [[ -f "package.json" ]]; then
    log "found package.json (Node.js project)"

    # Check for lint script
    if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
      local lint_cmd
      lint_cmd=$(jq -r '.scripts.lint' package.json)
      log "  lint script found: $lint_cmd"
      printf '  Use "npm run lint" for linting? [Y/n] '
      read -r answer
      if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
        commands+=("{\"name\":\"lint\",\"command\":\"npm run lint\",\"required\":true}")
      fi
    fi

    # Check for TypeScript
    if [[ -f "tsconfig.json" ]]; then
      log "  tsconfig.json found"
      printf '  Use "npx tsc --noEmit" for type checking? [Y/n] '
      read -r answer
      if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
        commands+=("{\"name\":\"typecheck\",\"command\":\"npx tsc --noEmit\",\"required\":true}")
      fi
    fi

    # Check for test script
    if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
      log "  test script found"
      printf '  Use "npm test" for testing? (optional — won'\''t block commits) [Y/n] '
      read -r answer
      if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
        commands+=("{\"name\":\"test\",\"command\":\"npm test\",\"required\":false}")
      fi
    fi
  fi

  if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    log "found Python project"
    if command -v ruff >/dev/null 2>&1; then
      printf '  Use "ruff check ." for linting? [Y/n] '
      read -r answer
      if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
        commands+=("{\"name\":\"lint\",\"command\":\"ruff check .\",\"required\":true}")
      fi
    fi
    if command -v mypy >/dev/null 2>&1; then
      printf '  Use "mypy ." for type checking? [Y/n] '
      read -r answer
      if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
        commands+=("{\"name\":\"typecheck\",\"command\":\"mypy .\",\"required\":true}")
      fi
    fi
  fi

  if [[ -f "Cargo.toml" ]]; then
    log "found Cargo.toml (Rust project)"
    printf '  Use "cargo clippy" for linting? [Y/n] '
    read -r answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      commands+=("{\"name\":\"lint\",\"command\":\"cargo clippy\",\"required\":true}")
    fi
    printf '  Use "cargo check" for type checking? [Y/n] '
    read -r answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      commands+=("{\"name\":\"typecheck\",\"command\":\"cargo check\",\"required\":true}")
    fi
  fi

  if [[ -f "mix.exs" ]]; then
    log "found mix.exs (Elixir project)"
    printf '  Use "mix credo" for linting? [Y/n] '
    read -r answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      commands+=("{\"name\":\"lint\",\"command\":\"mix credo\",\"required\":true}")
    fi
    printf '  Use "mix dialyzer" for type checking? [Y/n] '
    read -r answer
    if [[ "${answer:-Y}" =~ ^[Yy]?$ ]]; then
      commands+=("{\"name\":\"typecheck\",\"command\":\"mix dialyzer\",\"required\":true}")
    fi
  fi

  # Allow custom commands
  while true; do
    printf '  Add a custom validation command? [y/N] '
    read -r answer
    if [[ ! "${answer:-N}" =~ ^[Yy]$ ]]; then
      break
    fi
    printf '    Name (e.g. "format"): '
    read -r cmd_name
    printf '    Command: '
    read -r cmd_command
    printf '    Required (blocks commit)? [Y/n] '
    read -r cmd_required
    local req="true"
    [[ "${cmd_required:-Y}" =~ ^[Nn]$ ]] && req="false"
    commands+=("{\"name\":\"$cmd_name\",\"command\":\"$cmd_command\",\"required\":$req}")
  done

  # Build JSON array of commands
  local commands_json="[]"
  if [[ ${#commands[@]} -gt 0 ]]; then
    commands_json=$(printf '%s\n' "${commands[@]}" | jq -s '.')
  fi

  # Ask about auto-commit model
  local commit_model="claude-haiku-4-5-20251001"
  printf '  Commit agent model [%s]: ' "$commit_model"
  read -r answer
  [[ -n "$answer" ]] && commit_model="$answer"

  # Write config
  jq -n \
    --argjson commands "$commands_json" \
    --arg model "$commit_model" \
    '{
      validation: { commands: $commands },
      auto_commit: {
        model: $model,
        skip_roles: ["arbiter-script", "judge"]
      }
    }' > "$config_file"

  log "wrote $config_file"

  # Install pre-commit hook
  if [[ -f "$git_hooks_dir/pre-commit" ]]; then
    log "existing pre-commit hook found at $git_hooks_dir/pre-commit"
    printf '  Overwrite? [y/N] '
    read -r answer
    if [[ ! "${answer:-N}" =~ ^[Yy]$ ]]; then
      log "skipped pre-commit hook install"
      log "init complete"
      return
    fi
  fi

  cp "$ROOT_DIR/hooks/forge-pre-commit.sh" "$git_hooks_dir/pre-commit"
  chmod +x "$git_hooks_dir/pre-commit"
  log "installed pre-commit hook at $git_hooks_dir/pre-commit"

  # Vendor ralph-loop into the project
  local bin_dir=".forge/bin"
  mkdir -p "$bin_dir"
  cp "$ROOT_DIR/bin/ralph-loop" "$bin_dir/ralph-loop"
  chmod +x "$bin_dir/ralph-loop"
  log "vendored ralph-loop to $bin_dir/ralph-loop"

  log "init complete"
  log ""
  log "usage:"
  log "  .forge/bin/ralph-loop <epic-id> --auto-commit    # commit after each bead"
  log "  .forge/bin/ralph-loop <epic-id> --worktree       # run in isolated worktree"
}

help_cmd() {
  cat <<EOF
Usage: $CLI_NAME <command>

Commands:
  help
  init               Set up .forge/config.json and pre-commit hook
  where
  list-skills
  install-skills
  uninstall-skills
  doctor
  smoke-test
  test-local

Env vars:
  FORGE_SKILLS_DIR     override auto-detected skills directory
  FORGE_INSTALL_MODE   link (default) or copy

Platform detection (when FORGE_SKILLS_DIR is not set):
  1. ~/.claude/ exists → ~/.claude/skills/
  2. ~/.codex/ exists  → ~/.codex/skills/
  3. fallback          → ~/.claude/skills/
EOF
}

main() {
  local cmd="${1:-help}"

  case "$cmd" in
    help) help_cmd ;;
    init) init_cmd ;;
    where) where_cmd ;;
    list-skills) list_skills ;;
    install-skills) install_skills ;;
    uninstall-skills) uninstall_skills ;;
    doctor) doctor ;;
    smoke-test) smoke_test ;;
    test-local) test_local ;;
    *)
      fail "unknown command: $cmd"
      ;;
  esac
}

main "$@"
