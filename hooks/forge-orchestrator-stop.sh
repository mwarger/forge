#!/usr/bin/env bash
# forge-orchestrator-stop.sh — Stop hook for forge-orchestrator pipeline
#
# Reads run-state.json for any active spec run and blocks the stop if
# the orchestrator should auto-transition to the next phase.
#
# Contract:
#   stdin:  JSON with { stop_hook_active, cwd, ... }
#   stdout: { "decision": "block", "reason": "..." } to prevent stopping
#   exit 0 with no stdout to allow stopping

set -euo pipefail

INPUT=$(cat)

# Prevent infinite loops — if we already blocked once, let it stop
ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$ACTIVE" = "true" ]; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd')

# Find the most recently modified run-state.json
ARTIFACTS_DIR="$CWD/specs/_artifacts"
if [ ! -d "$ARTIFACTS_DIR" ]; then
  exit 0
fi

# Find run-state.json files, pick the most recently modified one
LATEST_STATE=$(find "$ARTIFACTS_DIR" -name "run-state.json" -type f -print0 2>/dev/null \
  | xargs -0 ls -t 2>/dev/null \
  | head -1)

if [ -z "$LATEST_STATE" ] || [ ! -f "$LATEST_STATE" ]; then
  exit 0
fi

PHASE=$(jq -r '.current_phase // ""' "$LATEST_STATE")
PLANNING_STATUS=$(jq -r '.planning_status // ""' "$LATEST_STATE")
# shellcheck disable=SC2034 # used in future phase checks
HANDOFF_STATUS=$(jq -r '.handoff_status // ""' "$LATEST_STATE")
ADVERSARIAL_STATUS=$(jq -r '.adversarial_status // ""' "$LATEST_STATE")
BLOCKER_COUNT=$(jq -r '.blocker_reasons | length // 0' "$LATEST_STATE")
COMPLETENESS=$(jq -r '.completeness_score // 0' "$LATEST_STATE" 2>/dev/null || echo "0")
CONFIDENCE=$(jq -r '.evidence_confidence_score // 0' "$LATEST_STATE" 2>/dev/null || echo "0")
BEADS_GENERATED=$(jq -r '.beads_generated // false' "$LATEST_STATE")
BEADS_REVIEW_STATUS=$(jq -r '.beads_review_status // ""' "$LATEST_STATE")
SUBJECT=$(jq -r '.subject // "unknown"' "$LATEST_STATE")

# Auto-transition rules (phases 8-12):
#
# READINESS_GATE passes → invoke spec-synthesis-review
# SYNTHESIS_REVIEW passes → invoke spec-adversarial-review
# ADVERSARIAL_REVIEW converges → invoke spec-plan-handoff
# PLAN_HANDOFF completes → prompt user for beads (ALLOWED PAUSE)
# BEADS_GENERATION completes → invoke spec-beads-review

block() {
  jq -n --arg reason "$1" '{"decision":"block","reason":$reason}'
  exit 0
}

case "$PHASE" in
  READINESS_GATE)
    # If gate passed (scores >= 80, no blockers), must continue to synthesis-review
    if [ "$BLOCKER_COUNT" -eq 0 ] && [ "$COMPLETENESS" -ge 80 ] && [ "$CONFIDENCE" -ge 80 ]; then
      block "[$SUBJECT] READINESS_GATE passed. Auto-transition: invoke spec-synthesis-review now. Do not summarize or pause."
    fi
    ;;

  SYNTHESIS_REVIEW)
    # If synthesis-review is complete, must continue to adversarial-review
    if [ "$PLANNING_STATUS" = "ADVERSARIAL_REVIEW" ] || [ "$PLANNING_STATUS" = "SPECULATIVE_DRAFT" ]; then
      block "[$SUBJECT] spec-synthesis-review complete. Auto-transition: set planning_status=ADVERSARIAL_REVIEW and invoke spec-adversarial-review now."
    fi
    ;;

  ADVERSARIAL_REVIEW)
    # If adversarial review converged, must continue to plan-handoff
    if [ "$ADVERSARIAL_STATUS" = "converged" ]; then
      block "[$SUBJECT] spec-adversarial-review converged. Auto-transition: set planning_status=PLANNING_READY, handoff_status=ELIGIBLE, and invoke spec-plan-handoff now. Do not summarize findings."
    fi
    ;;

  # PLAN_HANDOFF is an ALLOWED pause point (user chooses beads or not)
  # No block needed.

  BEADS_GENERATION)
    # If beads were generated, must continue to beads-review
    if [ "$BEADS_GENERATED" = "true" ] && [ "$BEADS_REVIEW_STATUS" != "converged" ]; then
      block "[$SUBJECT] BEADS_GENERATION complete. Auto-transition: invoke spec-beads-review now. Beads review is mandatory."
    fi
    ;;
esac

# No auto-transition needed — allow stop
exit 0
