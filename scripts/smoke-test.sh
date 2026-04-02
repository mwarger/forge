#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '[forge-smoke] %s\n' "$1"
}

require_file() {
  [[ -f "$1" ]] || {
    printf '[forge-smoke] ERROR: missing file %s\n' "$1" >&2
    exit 1
  }
}

log "checking required files"
require_file "$ROOT_DIR/README.md"
require_file "$ROOT_DIR/.claude-plugin/plugin.json"
require_file "$ROOT_DIR/bin/ralph-loop"

for skill in \
  forge-orchestrator \
  spec-intake \
  spec-loop \
  spec-completeness \
  spec-synthesis-review \
  spec-adversarial-review \
  spec-plan-handoff \
  spec-beads-generate \
  spec-beads-review \
  autoresearch-loop
do
  require_file "$ROOT_DIR/skills/$skill/SKILL.md"
done

log "checking hooks"
require_file "$ROOT_DIR/hooks/hooks.json"
require_file "$ROOT_DIR/hooks/forge-orchestrator-stop.sh"

log "checking autoresearch-loop references"
require_file "$ROOT_DIR/skills/autoresearch-loop/references/arbiter.sh"
require_file "$ROOT_DIR/skills/autoresearch-loop/references/doer.md"
require_file "$ROOT_DIR/skills/autoresearch-loop/references/strategist.md"
require_file "$ROOT_DIR/skills/autoresearch-loop/references/retrospective.md"
require_file "$ROOT_DIR/skills/autoresearch-loop/references/judge-soft.md"
require_file "$ROOT_DIR/skills/autoresearch-loop/references/judge-hard.md"

log "smoke test ok"
