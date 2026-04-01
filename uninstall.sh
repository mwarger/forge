#!/usr/bin/env bash
set -euo pipefail

CLI_NAME="forge-pack"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[forge uninstall] %s\n' "$1"
}

remove_wrapper() {
  local candidates=()

  if [[ -n "${FORGE_BIN_DIR:-}" ]]; then
    candidates+=("$FORGE_BIN_DIR")
  fi

  candidates+=("/usr/local/bin" "/opt/homebrew/bin" "$HOME/.local/bin" "$HOME/bin")

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -d "$candidate" ]] || continue
    local name
    for name in "$CLI_NAME" "ralph-loop"; do
      local target="$candidate/$name"
      if [[ -f "$target" ]]; then
        rm -f "$target"
        log "removed wrapper $target"
      fi
    done
  done
}

main() {
  "$ROOT_DIR/scripts/cli.sh" uninstall-skills
  remove_wrapper
  log "done"
}

main "$@"
