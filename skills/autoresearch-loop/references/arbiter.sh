#!/usr/bin/env bash
# arbiter.sh — Mechanical keep/revert decision
#
# This script is embedded in arbiter bead descriptions as a fenced bash block.
# The ralph-loop runner extracts and executes it. No LLM is involved.
#
# Template variables (filled at stamp time):
#   {{ITER}}                 — current iteration number
#   {{JUDGE_OUTPUT_PATH}}    — path to judge-output-N.json
#   {{LEDGER_PATH}}          — path to research-log.jsonl
#   {{CONFIG_PATH}}          — path to config.json
#   {{EPIC_ID}}              — br epic ID
#   {{SUBJECT_SLUG}}         — subject identifier

set -euo pipefail

ITER={{ITER}}
JUDGE_OUTPUT="{{JUDGE_OUTPUT_PATH}}"
LEDGER="{{LEDGER_PATH}}"
CONFIG="{{CONFIG_PATH}}"
EPIC_ID="{{EPIC_ID}}"
SUBJECT="{{SUBJECT_SLUG}}"

# --- Read judge output ---

if [[ ! -f "$JUDGE_OUTPUT" ]]; then
  echo "[arbiter] ERROR: judge output not found at $JUDGE_OUTPUT"
  exit 1
fi

SCORE=$(jq -r '.score' "$JUDGE_OUTPUT")
FINDINGS=$(jq -r '.findings | length' "$JUDGE_OUTPUT")

# --- Read previous score from ledger ---

if [[ -s "$LEDGER" ]]; then
  PREV_SCORE=$(tail -1 "$LEDGER" | jq -r '.score_after')
else
  PREV_SCORE=0
fi

DELTA=$((SCORE - PREV_SCORE))

# --- Read config ---

TARGET=$(jq -r '.target // 0' "$CONFIG")
MAX_ITER=$(jq -r '.caps.max_iterations // 20' "$CONFIG")
PLATEAU_THRESHOLD=$(jq -r '.caps.plateau_threshold // 3' "$CONFIG")
ADVERSARIAL_THRESHOLD=$(jq -r '.adversarial_threshold // 80' "$CONFIG")
CONFIRMATION_ROUNDS=$(jq -r '.confirmation_rounds // 2' "$CONFIG")

# --- Keep or revert ---

CURRENT_SHA=$(git rev-parse HEAD)

if [[ $DELTA -gt 0 ]]; then
  DECISION="keep"
  echo "[arbiter] iter $ITER: score $PREV_SCORE → $SCORE (+$DELTA). Keeping."
else
  DECISION="revert"
  # Revert the doer's commit
  git revert --no-commit HEAD 2>/dev/null && git commit -m "autoresearch: revert iter $ITER (score $SCORE, no improvement)" || true
  echo "[arbiter] iter $ITER: score $PREV_SCORE → $SCORE ($DELTA). Reverted."
fi

# --- Update ledger ---

ENTRY=$(jq -n \
  --argjson iter "$ITER" \
  --argjson score_before "$PREV_SCORE" \
  --argjson score_after "$SCORE" \
  --argjson delta "$DELTA" \
  --arg decision "$DECISION" \
  --arg sha "$CURRENT_SHA" \
  --argjson findings "$FINDINGS" \
  '{iter: $iter, score_before: $score_before, score_after: $score_after, delta: $delta, decision: $decision, sha: $sha, findings_count: $findings}')

echo "$ENTRY" >> "$LEDGER"

# --- Check terminal conditions ---

# 1. Goal reached (with confirmation rounds)
if [[ $TARGET -gt 0 && $SCORE -ge $TARGET ]]; then
  # Count consecutive rounds at or above target
  CONSECUTIVE=$(tail -"$CONFIRMATION_ROUNDS" "$LEDGER" | jq -r ".score_after" | awk -v t="$TARGET" 'BEGIN{c=0}{if($1>=t)c++;else c=0}END{print c}')
  if [[ $CONSECUTIVE -ge $CONFIRMATION_ROUNDS ]]; then
    echo "[arbiter] GOAL REACHED: score $SCORE >= target $TARGET for $CONSECUTIVE consecutive rounds"
    echo "{\"type\":\"terminal\",\"reason\":\"goal_reached\",\"iter\":$ITER,\"final_score\":$SCORE,\"decision\":\"$DECISION\"}" > .autoresearch/terminal-signal.json
    rm -f .autoresearch/arbiter-signal.json
    exit 0
  fi
fi

# 2. Iteration cap
if [[ $ITER -ge $MAX_ITER ]]; then
  echo "[arbiter] ITERATION CAP: reached $MAX_ITER iterations"
  echo "{\"type\":\"terminal\",\"reason\":\"iteration_cap\",\"iter\":$ITER,\"final_score\":$SCORE,\"decision\":\"$DECISION\"}" > .autoresearch/terminal-signal.json
  rm -f .autoresearch/arbiter-signal.json
  exit 0
fi

# 3. Plateau detection
if [[ $(wc -l < "$LEDGER") -ge $PLATEAU_THRESHOLD ]]; then
  PLATEAU=$(tail -"$PLATEAU_THRESHOLD" "$LEDGER" | jq -r '.delta' | awk 'BEGIN{p=1}{if($1>0)p=0}END{print p}')
  if [[ $PLATEAU -eq 1 ]]; then
    echo "[arbiter] PLATEAU: no improvement for $PLATEAU_THRESHOLD consecutive iterations"
    echo "{\"type\":\"terminal\",\"reason\":\"plateau\",\"iter\":$ITER,\"final_score\":$SCORE,\"decision\":\"$DECISION\"}" > .autoresearch/terminal-signal.json
    rm -f .autoresearch/arbiter-signal.json
    exit 0
  fi
fi

# --- Continue: signal strategist to stamp next cycle ---

echo "[arbiter] continuing to iteration $((ITER + 1))"
NEXT_ITER=$((ITER + 1))
echo "{\"type\":\"continue\",\"iter\":$ITER,\"next_iter\":$NEXT_ITER,\"current_score\":$SCORE,\"decision\":\"$DECISION\",\"delta\":$DELTA}" > .autoresearch/arbiter-signal.json
