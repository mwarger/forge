#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '[trace-smoke] %s\n' "$1"
}

require_file() {
  [[ -f "$1" ]] || {
    printf '[trace-smoke] ERROR: missing file %s\n' "$1" >&2
    exit 1
  }
}

log "checking required files"
require_file "$ROOT_DIR/README.md"
require_file "$ROOT_DIR/.claude/INSTALL.md"
require_file "$ROOT_DIR/.codex/INSTALL.md"
require_file "$ROOT_DIR/.claude-plugin/plugin.json"
require_file "$ROOT_DIR/specs/README.md"
require_file "$ROOT_DIR/specs/analytics-module.md"
require_file "$ROOT_DIR/specs/feature-flags-system.md"
require_file "$ROOT_DIR/specs/auth-session-system.md"

for skill in \
  trace-orchestrator \
  spec-intake \
  spec-loop \
  spec-completeness \
  spec-synthesis-review \
  spec-adversarial-review \
  spec-plan-handoff \
  spec-beads-generate \
  spec-beads-review
do
  require_file "$ROOT_DIR/skills/$skill/SKILL.md"
done

log "checking root specs index markers"
grep -q '<!-- trace:spec-index:start -->' "$ROOT_DIR/specs/README.md" || {
  printf '[trace-smoke] ERROR: missing start marker in specs/README.md\n' >&2
  exit 1
}
grep -q '<!-- trace:spec-index:end -->' "$ROOT_DIR/specs/README.md" || {
  printf '[trace-smoke] ERROR: missing end marker in specs/README.md\n' >&2
  exit 1
}

log "validating json/jsonl artifacts"
ROOT="$ROOT_DIR" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT"])
for path in root.joinpath("specs", "_artifacts").rglob("*.json"):
    data = json.loads(path.read_text())
    if path.name == "manifest.json":
        for key in (
            "policy_version",
            "request_archetype",
            "planning_status",
            "handoff_status",
            "blocker_reasons",
            "critical_decision_coverage",
        ):
            if key not in data:
                raise SystemExit(f"missing {key} in {path}")
    if path.name == "run-state.json":
        for key in (
            "policy_version",
            "planning_status",
            "handoff_status",
            "blocker_reasons",
        ):
            if key not in data:
                raise SystemExit(f"missing {key} in {path}")

for path in root.joinpath("specs", "_artifacts").rglob("*.jsonl"):
    for line in path.read_text().splitlines():
        if line.strip():
            json.loads(line)
PY

log "smoke test ok"
