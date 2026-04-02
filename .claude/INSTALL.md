# Forge for Claude Code

## Plugin install (recommended)

```
/plugin install forge
```

All 10 skills are available immediately (9 spec pipeline + autoresearch-loop).

## Manual install

If you prefer a local checkout:

```bash
cd /path/to/forge
./install.sh
```

That installs the skills into `~/.claude/skills/` (auto-detected), plus
`forge-pack` (helper CLI) and `ralph-loop` (bead runner) to your PATH.

Override the target with:

```bash
FORGE_SKILLS_DIR="$HOME/.claude/skills" ./install.sh
```

## Isolated local test install

If you want to test without touching your normal Claude Code setup:

```bash
cd /path/to/forge
./scripts/test-local.sh
FORGE_SKILLS_DIR="$(pwd)/.local-test/skills" claude
```

Then start Claude Code from that same shell.

## Verify

Run:

```bash
forge-pack doctor
forge-pack list-skills
```

Then start a new Claude Code session and try:

- "Create a subject-named spec for this feature request using Forge."
- "Stamp an autoresearch loop for overnight improvement."
- "Use the forge-orchestrator skill on this codebase."
