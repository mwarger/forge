---
name: forge-init
description: "Bootstrap Forge in the current project. Detects project type, configures validation commands, installs pre-commit hook, and vendors ralph-loop. Use this when setting up a new project for Forge spec runs and bead execution."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
user-invocable: true
---

Set up Forge in the current project directory.

## What this does

1. Detects project type (Node, Python, Rust, Elixir, etc.)
2. Asks the user which validation commands to run (lint, typecheck, test)
3. Writes `.forge/config.json` with validation and auto-commit settings
4. Installs a pre-commit hook that runs validation commands
5. Vendors `ralph-loop` into `.forge/bin/` for local bead execution

## Procedure

### Step 1: Verify git repo

Run `git rev-parse --git-dir` to confirm this is a git repository. If not,
tell the user and stop.

### Step 2: Detect project type

Check for these files to determine the project type:

| File | Type | Suggested commands |
|------|------|-------------------|
| `package.json` | Node.js | `npm run lint`, `npx tsc --noEmit`, `npm test` |
| `pyproject.toml` or `setup.py` | Python | `ruff check .`, `mypy .`, `pytest` |
| `Cargo.toml` | Rust | `cargo clippy`, `cargo check`, `cargo test` |
| `mix.exs` | Elixir | `mix credo`, `mix dialyzer`, `mix test` |

For Node.js projects, also check `package.json` for existing `scripts.lint`,
`scripts.test`, `scripts.typecheck` entries and suggest those.

If multiple project types are detected (monorepo), detect all of them.

### Step 3: Ask the user

Use AskUserQuestion to present the detected commands and let the user
confirm, edit, or skip each one. Ask about:

1. Which validation commands to enable (lint, typecheck, test)
2. Which are required (block commits) vs optional (warn only)
3. Any custom commands to add
4. Which model to use for the commit agent (default: `claude-haiku-4-5-20251001`)

### Step 4: Write `.forge/config.json`

Create the `.forge/` directory and write the config:

```json
{
  "validation": {
    "commands": [
      { "name": "lint", "command": "npm run lint", "required": true },
      { "name": "typecheck", "command": "npx tsc --noEmit", "required": true },
      { "name": "test", "command": "npm test", "required": false }
    ]
  },
  "auto_commit": {
    "model": "claude-haiku-4-5-20251001",
    "skip_roles": ["arbiter-script", "judge"]
  }
}
```

### Step 5: Install pre-commit hook

Read the pre-commit hook template from `${CLAUDE_PLUGIN_ROOT}/hooks/forge-pre-commit.sh`
(or from the forge plugin's hooks directory).

If a pre-commit hook already exists at `.git/hooks/pre-commit`, ask the user
whether to overwrite it.

Write the hook to `.git/hooks/pre-commit` and make it executable with
`chmod +x`.

The pre-commit hook script:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONFIG=".forge/config.json"

if [[ ! -f "$CONFIG" ]]; then
  exit 0
fi

has_commands=$(jq -r '.validation.commands // [] | length' "$CONFIG" 2>/dev/null || echo "0")
if [[ "$has_commands" -eq 0 ]]; then
  exit 0
fi

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
```

### Step 6: Vendor ralph-loop

Copy `ralph-loop` from `${CLAUDE_PLUGIN_ROOT}/bin/ralph-loop` into
`.forge/bin/ralph-loop` and make it executable.

If the plugin root is not available, write a minimal instruction telling
the user to copy it manually.

### Step 7: Summary

Print a summary of what was set up:

```
Forge initialized:
  .forge/config.json     — validation commands and auto-commit config
  .git/hooks/pre-commit  — runs lint/typecheck before commits
  .forge/bin/ralph-loop  — local bead runner

Usage:
  .forge/bin/ralph-loop <epic-id>                  # run beads
  .forge/bin/ralph-loop <epic-id> --auto-commit    # commit after each bead
  .forge/bin/ralph-loop <epic-id> --worktree       # isolated worktree
```
