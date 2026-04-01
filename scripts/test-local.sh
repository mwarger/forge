#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="${TRACE_TEST_ROOT:-$ROOT_DIR/.local-test}"
TEST_SKILLS_DIR="$TEST_ROOT/skills"
MANIFEST_PATH="$TEST_ROOT/README.md"

log() {
  printf '[trace-test-local] %s\n' "$1"
}

mkdir -p "$TEST_SKILLS_DIR"

log "installing isolated skill set into $TEST_SKILLS_DIR"
TRACE_SKILLS_DIR="$TEST_SKILLS_DIR" \
TRACE_INSTALL_MODE="${TRACE_INSTALL_MODE:-link}" \
"$ROOT_DIR/scripts/cli.sh" install-skills

cat > "$MANIFEST_PATH" <<EOF
# Local Test Environment

This directory is an isolated test install for Trace.

## Claude Code

\`\`\`bash
cd "$ROOT_DIR"
TRACE_SKILLS_DIR="$TEST_SKILLS_DIR" claude
\`\`\`

## Codex

\`\`\`bash
cd "$ROOT_DIR"
TRACE_SKILLS_DIR="$TEST_SKILLS_DIR" codex
\`\`\`

Suggested prompts:

- Create a subject-named spec for this feature request using Trace.
- Reverse engineer this repo into a Trace spec with sidecar artifacts.
- Use the trace-orchestrator skill on this codebase.
EOF

log "wrote $MANIFEST_PATH"
log "next:"
printf '  TRACE_SKILLS_DIR="%s" claude   # or codex\n' "$TEST_SKILLS_DIR"
