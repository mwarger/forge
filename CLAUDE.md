# Forge — Project Instructions

## Version bumping

Every commit that changes skills, orchestrator behavior, or plugin metadata
**must** bump the version in `.claude-plugin/plugin.json` before pushing.

Use semver:
- **patch** (0.1.0 → 0.1.1): bug fixes, wording clarifications, doc-only changes
- **minor** (0.1.0 → 0.2.0): new skills, behavioral changes, new fields in contracts
- **major** (0.1.0 → 1.0.0): breaking changes to skill interfaces or artifact schema

## Lineage

Forge is the third generation:
- **Super-Ralph** (`super-ralph`) — three-phase SDLC framework (reverse/decompose/forward), the methodology
- **Trace** (`trace`) — evidence-first spec pipeline, deeply refined the reverse phase
- **Forge** — the synthesis: Trace's spec pipeline + autonomous self-replicating loops

Keep the upstream projects clean — new synthesis work belongs here.
