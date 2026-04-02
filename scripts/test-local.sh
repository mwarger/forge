#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="${FORGE_TEST_ROOT:-$ROOT_DIR/.local-test}"
TEST_SKILLS_DIR="$TEST_ROOT/skills"
MANIFEST_PATH="$TEST_ROOT/README.md"

log() {
  printf '[forge-test-local] %s\n' "$1"
}

mkdir -p "$TEST_SKILLS_DIR"

log "installing isolated skill set into $TEST_SKILLS_DIR"
FORGE_SKILLS_DIR="$TEST_SKILLS_DIR" \
FORGE_INSTALL_MODE="${FORGE_INSTALL_MODE:-link}" \
"$ROOT_DIR/scripts/cli.sh" install-skills

cat > "$MANIFEST_PATH" <<EOF
# Local Test Environment

This directory is an isolated test install for Forge.

## Claude Code

\`\`\`bash
cd "$ROOT_DIR"
FORGE_SKILLS_DIR="$TEST_SKILLS_DIR" claude
\`\`\`

## Codex

\`\`\`bash
cd "$ROOT_DIR"
FORGE_SKILLS_DIR="$TEST_SKILLS_DIR" codex
\`\`\`

Suggested prompts:

- Create a subject-named spec for this feature request using Forge.
- Use the forge-orchestrator skill to build a spec from evidence.
- Stamp an autoresearch loop for overnight improvement.
EOF

log "wrote $MANIFEST_PATH"
log "next:"
printf '  FORGE_SKILLS_DIR="%s" claude   # or codex\n' "$TEST_SKILLS_DIR"
