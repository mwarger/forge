#!/usr/bin/env bash
set -euo pipefail

CLI_NAME="forge-pack"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${FORGE_PACK_HOME:-$HOME/.forge-pack}"
REPO_URL="${FORGE_REPO_URL:-}"

log() {
  printf '[forge install] %s\n' "$1"
}

fail() {
  printf '[forge install] ERROR: %s\n' "$1" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

pick_bin_dir() {
  local candidates=()

  if [[ -n "${FORGE_BIN_DIR:-}" ]]; then
    candidates+=("$FORGE_BIN_DIR")
  fi

  candidates+=("/usr/local/bin" "/opt/homebrew/bin" "$HOME/.local/bin" "$HOME/bin")

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue

    if [[ ! -d "$candidate" ]]; then
      mkdir -p "$candidate" 2>/dev/null || continue
    fi

    if [[ -w "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  fail "could not find a writable bin directory"
}

ensure_source() {
  if [[ -f "$ROOT_DIR/scripts/cli.sh" && -d "$ROOT_DIR/skills" ]]; then
    printf '%s\n' "$ROOT_DIR"
    return 0
  fi

  has_cmd git || fail "git is required for remote install"
  [[ -n "$REPO_URL" ]] || fail "set FORGE_REPO_URL for remote install"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "updating existing install at $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
  elif [[ -e "$INSTALL_DIR" ]]; then
    fail "$INSTALL_DIR exists but is not a git checkout"
  else
    log "cloning repo into $INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi

  printf '%s\n' "$INSTALL_DIR"
}

install_wrapper() {
  local source_dir="$1"
  local bin_dir="$2"
  local target="$bin_dir/$CLI_NAME"

  log "installing wrapper at $target"
  cat > "$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$source_dir/scripts/cli.sh" "\$@"
EOF
  chmod +x "$target"
}

install_ralph_loop() {
  local source_dir="$1"
  local bin_dir="$2"
  local target="$bin_dir/ralph-loop"
  log "installing ralph-loop at $target"
  cat > "$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$source_dir/bin/ralph-loop" "\$@"
EOF
  chmod +x "$target"
}

main() {
  has_cmd bash || fail "bash is required"
  has_cmd python3 || fail "python3 is required"

  local source_dir
  source_dir="$(ensure_source)"

  local bin_dir
  bin_dir="$(pick_bin_dir)"

  install_wrapper "$source_dir" "$bin_dir"
  install_ralph_loop "$source_dir" "$bin_dir"

  log "installing skills"
  "$source_dir/scripts/cli.sh" install-skills

  log "done"
  log "try:"
  log "  $CLI_NAME doctor"
  log "  $CLI_NAME test-local"
}

main "$@"
