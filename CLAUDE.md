# Forge — Project Instructions

## Version bumping

Every commit that changes skills, orchestrator behavior, or plugin metadata
**must** bump the version in `.claude-plugin/plugin.json` before pushing.

Use semver:
- **patch** (0.1.0 → 0.1.1): bug fixes, wording clarifications, doc-only changes
- **minor** (0.1.0 → 0.2.0): new skills, behavioral changes, new fields in contracts
- **major** (0.1.0 → 1.0.0): breaking changes to skill interfaces or artifact schema

## Lineage

Forge synthesizes two prior projects:
- **Ralph TUI** (`ralph-tui`) — autonomous agent orchestrator (the execution engine)
- **Trace** (`trace`) — evidence-first spec pipeline (the specification engine)

Forge is the convergence: specs feed autonomous improvement loops that self-replicate.
Keep the upstream projects clean — new synthesis work belongs here.
