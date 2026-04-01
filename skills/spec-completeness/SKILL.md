---
name: spec-completeness
description: "Score a subject spec against the ontology and canonical readiness contract. Use this when you need claim-level coverage scoring, corroboration checks, critical-decision coverage, risk-weighted assumptions, contradiction penalties, and blocker-aware 80/80 gates."
allowed-tools: Read, Write, Glob, Grep
---

Use this whenever canon changes materially.

Do not finalize readiness here.
Emit structured inputs for the `trace-orchestrator` verdict.

## Ontology

Track these dimensions:
- purpose and success criteria
- actors
- boundaries
- core flows
- entities
- state transitions
- interfaces
- constraints
- failure modes
- non-goals
- assumptions
- acceptance criteria

## Sub-signal requirements

The following sub-signals feed into existing dimensions as required coverage
inputs. A dimension cannot score above `partial` unless its mapped sub-signals
are addressed (per the archetype applicability matrix in `spec-loop`).

| Sub-signal | Feeds into dimensions |
|------------|----------------------|
| Security boundaries | `constraints`, `interfaces` |
| Edge cases | `failure modes`, `state transitions` |
| Scalability assumptions | `constraints`, `assumptions` |
| Operational concerns | `interfaces`, `constraints` |
| Ordering and concurrency | `state transitions`, `core flows` |

For archetypes where a sub-signal is marked `optional` in the spec-loop
matrix, that sub-signal does not block the parent dimension's coverage. It
only contributes if evidence is present.

## Domain terminology check

Read `UBIQUITOUS-LANGUAGE.md` at the project root (if it exists). Verify that
major canonical claims, entity names, and interface descriptions use terms from
the glossary. Flag inconsistencies as a sub-signal feeding into `entities` and
`interfaces` dimensions. Mismatched terminology does not block readiness on its
own but reduces confidence in those dimensions.

For each dimension track:
- `coverage`
- `confidence`
- `evidence_count`
- `independent_evidence_count`
- `weighted_support`
- `contradiction_count`
- `planning_blocker`

Also track:
- `critical_decision_coverage`
- `corroboration_score`
- `acceptance_scenarios_present`
- `assumption_load`
- `assumption_risk_score`
- `unconfirmed_product_decisions`

## Scores

Compute:
- `completeness_score`
- `evidence_confidence_score`
- `decision_risk_score`

Rules:
- blocker dimensions weigh more
- duplicate evidence should not inflate support
- multiple files from one origin do not count as strong corroboration by
  themselves
- unresolved assumptions cap the affected dimension
- contradictions reduce confidence and readiness
- a single direct prompt may strongly support `purpose`, but may not alone push
  `boundaries`, `interfaces`, `constraints`, `failure modes`, or
  `acceptance criteria` past partial unless the evidence is explicit
- no run may be planning-ready if a critical decision bucket is covered only by
  assumptions
- assumption risk matters more than raw assumption count
- on `sparse` `analogy_feature` or `parity_clone` runs with zero question
  rounds, `core_outcome`, `scope_boundary`, `implementation_constraints`, and
  `acceptance_signal` must remain `partial`, `open`, or `assumed`, not
  `covered`

Every assumption must be labeled:
- `criticality: low | medium | high`
- `reversibility: easy | moderate | expensive`

High-criticality or expensive-to-reverse assumptions increase
`assumption_risk_score` directly.

## Gates

Every scoring pass must emit:
- `why_not_ready[]`
- `blocker_dimensions[]`
- `minimum_next_actions[]`
- `critical_decision_coverage`
- `corroboration_score`
- `assumption_risk_score`
- `unconfirmed_product_decisions`

The orchestrator may only mark a run `PLANNING_READY` when:
- `completeness_score >= 80`
- `evidence_confidence_score >= 80`
- contradictions are resolved
- blocker reasons are empty
- critical decision buckets are closed
- acceptance scenarios are present or intentionally deferred
- assumption risk is below threshold

The orchestrator must not mark a run `PLANNING_READY` when:
- `request_archetype` is `analogy_feature` or `parity_clone`
- `starting_evidence_density` is `sparse`
- `question_rounds_completed = 0`

## Output

Update:
- `completeness-matrix.md`
- `manifest.json`
- `specs/<subject>.md` under `Completeness Status` and `Planning Readiness`
