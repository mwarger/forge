---
name: spec-beads-review
description: "Stress-test beads for coverage, granularity, dependency correctness, and actionability using adversarial agent teams. Use this after spec-beads-generate when the beads workspace is populated."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

Use this after `spec-beads-generate` has emitted `beads-manifest.json` and
created all beads via `br`.

## Purpose

Find every remaining gap in the bead decomposition that could cause an
engineer to make a judgment call the beads should have made for them. The full
attack surface: missing spec claim coverage, wrong granularity, dependency
errors, vague acceptance criteria, missing TDD test sketches.

## Agent team allocation

Use agent teams (`TeamCreate`) as the primary organizing mechanism. The team
persists across all rounds for context continuity.

### Required agents

**Coverage agent** — checks every spec claim and acceptance criterion against
`beads-manifest.json`. Flags anything not traced to a bead, or traced to a
bead that does not actually address it. Primary input:
`unmapped_claims` and `unmapped_acceptance_criteria` arrays.

**Granularity agent** — evaluates each bead: too coarse (multiple unrelated
concerns, would need decomposition during implementation)? Too fine (trivially
small, noise)? Proposes splits or merges.

**Dependency agent** — uses `bv --robot-suggest` for cycle detection,
`bv --robot-graph` for structure analysis, `bv --robot-insights` for graph
health. Checks for missing edges (bead A clearly depends on bead B but no dep
exists) and false edges.

**Actionability agent** — plays literal implementer for each bead. Evaluates:
- could I implement this without asking questions?
- does it have clear acceptance criteria?
- can I write a failing test first? If the bead does not describe observable
  behavior or a verifiable outcome, it is not TDD-ready — flag it
- are test boundaries clear? Does the bead specify enough about inputs,
  outputs, and side effects to know what to assert against?
- beads that are inherently non-testable-first (pure refactors with no
  behavior change, infrastructure setup) get annotated as `test-first: n/a`
  with rationale

### TDD test sketches

The actionability agent produces pseudocode test sketches per bead, specifying
both the scenario and the test type. Choose the most appropriate type per bead
from: **unit**, **property**, **integration**, **contract**, **e2e**.

A pure data transformation gets property tests. A boundary interaction gets
contract or integration tests. A user-facing flow gets e2e. If the agent
cannot write meaningful test sketches for a bead, that is itself a finding —
the bead's acceptance criteria are too vague.

Test sketches are embedded in the bead description by default. Use
`br comments add` only when the description would exceed a reasonable length.

### Evidence sources

Agents must use `br` and `bv --robot-*` commands as evidence sources:
- `br list --label forge:<subject>` — list beads for this spec
- `br show <id>` — read bead details
- `br dep list <id>` — check dependencies
- `br dep tree <id>` — visualize dependency tree
- `br dep cycles` — detect cycles
- `bv --robot-suggest` — duplicates, dependency issues, label problems, cycles
- `bv --robot-graph` — dependency graph structure
- `bv --robot-insights` — graph analysis and health metrics
- `bv --robot-plan` — dependency-respecting execution order

## Round structure

Every round MUST spawn the full agent team — all four agents (coverage,
granularity, dependency, actionability). Do not spawn a subset, even if earlier
findings were narrow. Do not predict convergence — run the round and observe
the results. The point of subsequent rounds is to verify fixes did not
introduce new issues and to catch things the previous round missed.

Each round:
1. all agents evaluate the current bead set independently
2. agents use `br` queries and `bv --robot-*` commands as evidence
3. findings collected, deduplicated, and classified:
   - **critical** — missing spec claim coverage, dependency cycle, bead with
     multiple valid interpretations → escalate to user
   - **high** — granularity problem, missing dependency edge, vague acceptance
     criteria → escalate to user
   - **resolvable** — answer is unambiguous from spec, codebase, or bv
     analysis → auto-resolve, log decision, flag for user visibility
4. resolutions applied:
   - `br create` (new beads)
   - `br update` (fix descriptions)
   - `br dep add` / `br dep remove` (rewire)
   - `br delete` (merge or remove)
5. `beads-manifest.json` updated with any changes
6. next round begins on the updated bead set

## Convergence

- **minimum**: 2 rounds if round 1 produces findings. If round 1 produces
  zero material findings from all agents, 1 round is sufficient.
- **maximum**: 5 rounds (safety cap)
- **exit**: a round where ALL agents — all four — independently report zero
  material findings
- **bias**: toward running another round if any agent is uncertain. The cap is
  a safety valve, not a target.
- **"material" defined broadly**: anything that could cause an engineer to
  make a judgment call the beads should have made for them

## Cap behavior

Hitting the cap (5 rounds without convergence) is NOT an acceptable exit. It
triggers a decomposition signal:

- emit `beads_review_status = decomposition_required` as structured input to
  the orchestrator
- emit `beads-decomposition-proposal.md` explaining what is tangled and why

Decomposition can mean one of two things:

1. **the implementation plan's workstreams are too tangled** — the beads
   cannot be cleanly separated because the plan itself has unclear boundaries.
   Escalate back to the user with a proposal to revise the implementation
   plan.
2. **the spec has gaps the beads review exposed** — the act of decomposing
   into concrete work units revealed ambiguity that the spec adversarial
   review missed. Emit `beads-escalation.json` listing finding IDs, affected
   spec sections, and reopened blockers. The orchestrator passes this to
   `spec-loop` for a targeted re-entry round.

The user decides next steps based on the decomposition proposal.

## Finding structure

Each finding must include:
- `finding_id` — stable identifier
- `round` — which review round
- `agent_role` — coverage, granularity, dependency, or actionability
- `severity` — critical, high, or resolvable
- `bead_id` — which bead (or null for cross-cutting findings)
- `description` — what the problem is
- `evidence` — what the agent observed (bv output, br query result, spec
  text, or codebase evidence)
- `resolution` — how it was resolved (user answer, auto-resolve, or pending)
- `resolution_source` — user, bv_analysis, codebase, or auto

## Outputs

Emit as structured input to the orchestrator (do not write these directly):
- `beads-review-log.md` — all findings across all rounds with resolutions and
  provenance
- `beads-review-round-N.json` — structured findings per round
- updated `beads-manifest.json`
- structured beads review fields for `manifest.json`:
  - `beads_review_rounds_completed`
  - `beads_review_status` (`converged` | `decomposition_required`)
  - `beads_coverage_score`

On decomposition:
- `beads-decomposition-proposal.md`
- `beads-escalation.json` (on back-transition to spec-loop)

## Epilogue bead exemptions

Epilogue beads (labeled `epilogue`) are meta-beads for post-implementation
quality and learning. They require different treatment from each agent:

- **Coverage agent**: skip epilogue beads entirely. They have no spec claims
  or acceptance criteria to verify — `spec_claims` and `acceptance_criteria`
  are intentionally empty.
- **Granularity agent**: skip epilogue beads. Their scope is fixed by
  definition and not subject to split/merge proposals.
- **Dependency agent**: verify each epilogue bead depends on ALL implementation
  beads. Flag any implementation bead missing from an epilogue bead's
  dependency list. The Agent Guidance Review bead must also depend on the
  Learnings Retrospective bead. Disregard `bv` warnings about high fan-in
  on epilogue beads — this is expected and intentional.
- **Actionability agent**: evaluate epilogue beads for clarity of description
  and acceptance criteria, but mark `test_first: n/a` with rationale
  "epilogue meta-task". Do not require TDD test sketches — these are
  review/analysis tasks, not code-producing tasks.

Epilogue beads are listed in the `epilogue_beads` array of
`beads-manifest.json`, not in the `beads` array. The `unmapped_claims` and
`unmapped_acceptance_criteria` arrays do not apply to them.

### Follow-up beads created by epilogues

Epilogue beads may create `epilogue-followup` labeled beads in the same epic
to address their findings. Follow-up beads ARE subject to the normal review
rules — they are implementation beads, not epilogue beads.

**Hard rule**: every follow-up bead MUST use `--parent <epic-id>` when
created. A follow-up bead without a parent is an orphan invisible to
`br ready` in the epic context. The dependency agent's checklist must include:
verify every `epilogue-followup` bead is a child of the same epic (check via
`br show <followup-id>` — parent field must equal the epic ID).

The dependency agent should also verify follow-up beads are wired correctly
(each depends on the bead whose code it addresses). Follow-up beads appear in
the `followup_beads` array of `beads-manifest.json`.

## Hard rules

1. This skill does not write canon. It emits proposals. The orchestrator
   reduces.
2. Use `br` and `bv` CLI commands as evidence sources. Do not read `.beads`
   database files directly.
3. Zero material findings means zero. "Probably fine" is not zero.
4. The cap is a decomposition signal, not an acceptable exit.
5. `beads_review_status` has exactly two values: `converged` or
   `decomposition_required`. No middle ground. The field is absent until the
   review phase exits.
6. Agent teams are the required organizing mechanism. Do not use ad-hoc agent
   spawning.
7. Every bead must have a `test_first` annotation and test sketches (unless
   `test-first: n/a` with rationale). Missing test sketches is a finding.
8. Never predict convergence. Never skip a round because you believe it will
   converge. Spawn all agents, collect their findings, and only then determine
   whether findings are zero. "I'm confident round N will converge" is not a
   substitute for running round N.
