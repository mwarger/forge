---
name: spec-plan-handoff
description: "Render the implementation handoff for a subject spec. Use this when the canonical readiness verdict already exists and you need either a real implementation plan for eligible runs or a withheld handoff plus bounded options for blocked runs."
allowed-tools: Read, Write, Glob, Grep
---

Use this only after `trace-orchestrator` has finalized `planning_status` and
`handoff_status`.

## Preconditions

Do not emit a real implementation plan if:
- `planning_status != PLANNING_READY`
- or `handoff_status != ELIGIBLE`
- or `adversarial_status != converged`
- or the run is a `sparse` `analogy_feature` or `parity_clone` with
  `question_rounds_completed = 0`

## Inputs

Read from canon and sidecars:
- `specs/<subject>.md`
- `decision-log.md`
- `completeness-matrix.md`
- `review-report.md`
- `adversarial-review-log.md`
- `UBIQUITOUS-LANGUAGE.md` (project root, if it exists)
- `AGENTS.md` (project root, if it exists) — prior implementation conventions
  that should inform workstream ordering, risk assessment, and anti-patterns
  to avoid

Do not plan directly from raw intake chatter.

## Outputs

If `handoff_status=ELIGIBLE`, create or update `implementation-plan.md` with:
- workstreams
- dependencies
- acceptance criteria
- test scenarios
- top risks
- explicit excluded work

If the run is blocked, write a withheld handoff note instead.
Blocked handoff may include:
- next required questions
- bounded variants
- prerequisite evidence to gather

Blocked handoff must not include:
- implementation sequencing
- file/task breakdown
- actionable workstreams
