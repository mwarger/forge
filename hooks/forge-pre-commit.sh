#!/usr/bin/env bash
# forge-pre-commit — git pre-commit hook installed by forge-pack init
#
# Reads .forge/config.json for validation commands and runs them.
# Exits non-zero if any required command fails.

set -euo pipefail

CONFIG=".forge/config.json"

if [[ ! -f "$CONFIG" ]]; then
  exit 0
fi

has_commands=$(jq -r '.validation.commands // [] | length' "$CONFIG" 2>/dev/null || echo "0")
if [[ "$has_commands" -eq 0 ]]; then
  exit 0
fi

failed=false

jq -c '.validation.commands[]' "$CONFIG" | while IFS= read -r entry; do
  name=$(echo "$entry" | jq -r '.name')
  command=$(echo "$entry" | jq -r '.command')
  required=$(echo "$entry" | jq -r '.required // true')

  printf '[forge-pre-commit] running %s: %s\n' "$name" "$command"

  if ! eval "$command"; then
    if [[ "$required" == "true" ]]; then
      printf '[forge-pre-commit] FAILED (required): %s\n' "$name" >&2
      exit 1
    else
      printf '[forge-pre-commit] FAILED (optional): %s — continuing\n' "$name" >&2
    fi
  else
    printf '[forge-pre-commit] passed: %s\n' "$name"
  fi
done
