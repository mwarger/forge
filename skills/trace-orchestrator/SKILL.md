---
name: trace-orchestrator
description: "Create a subject-named specification from any evidence source using a reducer-based Trace workflow. Use this when the user wants a planning-ready spec, a clean-room reverse spec, or an evidence-first feature spec with sub-agent fanout, provenance tracking, adaptive clarification, speculative variants, and a canonical readiness contract."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

Use this as the top-level skill for the pack.

The main session is the only reducer of canon.
Sub-agents may read canon and return typed patch proposals, but they may not
write `specs/<subject>.md` directly.

## When to use

Trigger when the user wants to:
- create a spec from code, docs, transcripts, screenshots, or a repo
- create a spec from a sparse feature description
- reconcile multiple evidence sources into one planning-ready subject doc
- keep implementation from inventing missing decisions

## Hard rules

1. Everything begins as evidence. A one-line feature request is evidence.
2. Nothing becomes canon without provenance.
3. The lead agent is the only reducer.
4. Use sub-agents by default for bounded read-heavy work.
5. Ask the user directly when user input is needed.
6. `trace-orchestrator` owns the canonical readiness verdict.
7. No run is planning-ready if blocker reasons remain open.
8. Scores matter only after blocker reasons are cleared.
9. A `sparse` `analogy_feature` or `parity_clone` run with
   `question_rounds_completed = 0` may never end in `PLANNING_READY`.
10. In that case, `handoff_status` must remain `WITHHELD` even if the draft is
    coherent.

## Canonical readiness contract

Every run must carry these canonical fields in `manifest.json` and
`run-state.json`:
- `policy_version`
- `request_archetype`
- `starting_evidence_density`
- `source_origin_keys`
- `planning_status`
- `handoff_status`
- `blocker_reasons`
- `critical_decision_coverage`
- `question_rounds_completed`
- `required_clarifications_remaining`
- `assumption_load`
- `assumption_risk_score`
- `unconfirmed_product_decisions`
- `acceptance_scenarios_present`
- `corroboration_score`
- `adversarial_rounds_completed`
- `adversarial_status`
- `adversarial_findings_total`
- `adversarial_findings_resolved_by_research`
- `adversarial_findings_resolved_by_user`
- `beads_generated`
- `beads_epic_id`
- `beads_review_rounds_completed`
- `beads_review_status`
- `beads_total`
- `beads_epilogue_count`
- `beads_followup_count`
- `beads_coverage_score`
- `beads_workspace_path`
- `loop_strategy`

`trace-orchestrator` is the only skill allowed to finalize:
- `planning_status`
- `handoff_status`
- `blocker_reasons`

Other skills emit structured inputs to that verdict.

## Planning state machine

Use these states:
- `planning_status`
  - `DISCOVERY`
  - `AWAITING_CLARIFICATION`
  - `SPECULATIVE_DRAFT`
  - `ADVERSARIAL_REVIEW`
  - `PLANNING_READY`
- `handoff_status`
  - `WITHHELD`
  - `ELIGIBLE`

Transitions:
- unresolved blocker reasons prevent `PLANNING_READY`
- unanswered required clarifications force `AWAITING_CLARIFICATION`
- bounded speculative variants while blockers remain force
  `SPECULATIVE_DRAFT`
- `handoff_status=ELIGIBLE` only when `planning_status=PLANNING_READY`
- do not emit a real implementation handoff while `handoff_status=WITHHELD`
- `sparse` `analogy_feature` or `parity_clone` plus zero question rounds must
  resolve to `AWAITING_CLARIFICATION` or `SPECULATIVE_DRAFT`, never
  `PLANNING_READY`
- `ADVERSARIAL_REVIEW` entry requires: `blocker_reasons` empty, all critical
  decision buckets closed, `completeness_score >= 80`,
  `evidence_confidence_score >= 80`, and synthesis-review verification passed
- `ADVERSARIAL_REVIEW` → `PLANNING_READY` only when adversarial rounds
  converge (zero material findings by agent consensus)
- `ADVERSARIAL_REVIEW` → `AWAITING_CLARIFICATION` if adversarial review
  surfaces ambiguity only the user can resolve, or if the round cap is hit
  (decomposition required)
- `ADVERSARIAL_REVIEW` → `SPECULATIVE_DRAFT` if adversarial review re-opens
  blocker reasons

## Canonical merge protocol

Every sub-agent result must include:
- `branch_id`
- `parent_revision`
- `touched_sections[]`
- `proposed_changes[]`
- `confidence_notes`

Apply results only if `parent_revision` matches canon.
If canon advanced, rebase, revalidate, or discard.

Merge order:
1. evidence / claim ingestion
2. contradiction update
3. ontology rescore
4. section patch application
5. readiness gate

## Run phases

Treat the workflow as a persisted state machine:
1. `INTAKE`
2. `EVIDENCE_FANOUT`
3. `REDUCE_AND_MERGE`
4. `GAP_ANALYSIS`
5. `USER_INPUT`
6. `DRAFT`
7. `VERIFY`
8. `READINESS_GATE`
9. `ADVERSARIAL_REVIEW`
10. `PLAN_HANDOFF`
11. `BEADS_GENERATION` (optional — user prompted after PLAN_HANDOFF)
12. `BEADS_REVIEW` (optional — runs if BEADS_GENERATION completed)

Each phase needs entry criteria, exit criteria, and a checkpoint artifact in
`specs/_artifacts/<subject>/run-state.json`.

### Auto-transition rule

Phases 8 through 12 are **automatic**: when a phase's exit criteria are met,
immediately invoke the next sub-skill without pausing for user input. Do not
stop to summarize intermediate results between phases. Specifically:

- `READINESS_GATE` passes (`completeness_score >= 80`,
  `evidence_confidence_score >= 80`, `blocker_reasons` empty) →
  immediately invoke `spec-synthesis-review`
- `spec-synthesis-review` verification passes →
  immediately set `planning_status = ADVERSARIAL_REVIEW` and invoke
  `spec-adversarial-review`
- `spec-adversarial-review` converges →
  immediately set `planning_status = PLANNING_READY`,
  `handoff_status = ELIGIBLE` and invoke `spec-plan-handoff`.
  Do not present options, summarize findings, or ask the user what to do
  next — the transition to plan handoff is not optional.
- `PLAN_HANDOFF` completes → prompt user for beads (this is the only
  user-facing pause in the late pipeline)
- `BEADS_GENERATION` completes → immediately invoke `spec-beads-review`

The only reasons to pause mid-pipeline are: (a) a gate fails and the run
loops back, or (b) user input is required (beads prompt after plan handoff).
Report phase transitions in a single status line, not a multi-line summary.

`ADVERSARIAL_REVIEW` phase contract:
- entry: synthesis-review passed, scoring gates met (`completeness_score >= 80`,
  `evidence_confidence_score >= 80`, `blocker_reasons` empty)
- exit: convergence (zero material findings by agent consensus) or
  decomposition required (cap hit).
  On convergence, do not pause or summarize — the auto-transition rule
  governs. Immediately proceed to `spec-plan-handoff`.
- checkpoint: `adversarial-review-log.md`

`BEADS_GENERATION` phase contract:
- entry: `PLAN_HANDOFF` complete, user accepts beads prompt
- prompt: present labeled options to the user:
  - **A) Generate beads** — decompose the plan into a beads workspace with
    dependency wiring, epic grouping, and provenance labels
  - **B) Done** — end the run here; the spec and plan are the final deliverables
- exit: `beads-manifest.json` emitted, all beads created via `br`
- checkpoint: `beads-manifest.json`
- if user chooses B, run ends at `PLAN_HANDOFF`

`BEADS_REVIEW` phase contract:
- entry: `BEADS_GENERATION` complete — proceed immediately, do not prompt the
  user. Beads review is mandatory whenever beads are generated.
- exit: convergence (zero material findings from all agents) or
  decomposition required (cap hit)
- checkpoint: `beads-review-log.md`

`EPILOGUE_CYCLE` concept (applies during implementation, after beads review):
- After beads review converges and all implementation + epilogue beads are
  complete, if any epilogue bead created follow-up beads, those follow-ups
  must be implemented and then reviewed by a new Full Code Review
- The cycle repeats until a Full Code Review produces zero material findings,
  max 3 cycles
- Learnings Retrospective and Agent Guidance Review run only on the first
  cycle — subsequent cycles are Full Code Review only
- Each cycle's Full Code Review is scoped to code changed by that cycle's
  follow-up beads, not the entire epic
- Follow-up beads in every cycle MUST use `--parent <epic-id>` — orphan
  follow-ups are a hard error

## Required sub-skill order

1. `spec-intake`

After `spec-intake` completes, present the user with a choice:

- **A) Evidence-first loop** — interactive spec-loop with adaptive
  clarification. Best when available for questions.
- **B) Autoresearch loop** — autonomous iterative improvement with
  blind scoring. Best for overnight runs or well-defined programs.
  Returns an epic ID; user runs `ralph-loop <epic-id>` externally.

If user chooses B:
1. Invoke `autoresearch-loop` skill
2. Set `loop_strategy = "autoresearch"` in run-state.json
3. Return epic ID to user — the run pauses here
4. User resumes Trace after loop converges (see post-loop re-entry)

If user chooses A (default):

2. `spec-loop`
3. `spec-completeness`
4. `spec-synthesis-review`
5. `spec-adversarial-review`
6. `spec-plan-handoff`
7. `spec-beads-generate` (optional — only if user accepts beads prompt)
8. `spec-beads-review` (mandatory if beads were generated — proceed immediately,
   do not prompt the user)

Loop back to `spec-loop` or `spec-completeness` whenever verification fails or
blockers remain. If `spec-adversarial-review` escalates back, pass the
`adversarial-escalation.json` artifact as input to the targeted `spec-loop`
round so it addresses the specific findings rather than running a generic pass.

If `spec-beads-review` triggers a back-transition, pass the
`beads-escalation.json` artifact as input to the targeted `spec-loop` round.
`spec-loop` treats `beads-escalation.json` identically to
`adversarial-escalation.json` — scope the round to the listed findings.

### Post-autoresearch re-entry

When `loop_strategy = "autoresearch"` and the user returns after convergence:

1. Read `.autoresearch/research-log.jsonl` for final score
2. Read `.autoresearch/retrospective.md` for process insights
3. Set `planning_status = READINESS_GATE` in run-state.json
4. Run READINESS_GATE entry criteria check
5. If gate passes, auto-transition pipeline takes over (unchanged)
6. If gate fails, offer: re-enter spec-loop interactively or re-stamp
   another autoresearch cycle

## Delegation policy

Default sub-agent roles:
- `evidence-explorer`
- `question-generator`
- `contradiction-reviewer`
- `completeness-reviewer`
- `provenance-reviewer`
- `spec-section-drafter`
- `implementability-reviewer`
- `artifact-curator`

Use the runtime's agent or subprocess mechanism for delegation (Agent tool in
Claude Code, sub-agents in Codex).

Delegate when work is:
- parallelizable
- read-heavy
- review-oriented
- locally scoped
- compressible to a short typed result

Keep work local when it changes canon, readiness, or user interaction policy.

For adversarial review, create agent teams via `TeamCreate`:
- section agents: one per substantive spec area, allocated by reading the
  completeness matrix
- cross-cutting agents: literal implementer, QA adversary, consistency checker
- team persists for all adversarial rounds

For beads review, create agent teams via `TeamCreate`:
- coverage agent: spec claim traceability
- granularity agent: bead sizing
- dependency agent: graph correctness (uses `bv --robot-*` commands)
- actionability agent: implementability + TDD test sketches
- team persists for all beads review rounds

## Tool policy

- Give each role the minimum viable tool allowlist.
- Read-only reviewers do not get write tools.
- Normalize untrusted external text into validated fields before it influences
  canon.
- Destructive or publication-adjacent actions require approval when the runtime
  supports it.

## Question policy

Ask the user when critical decision coverage is incomplete and passive evidence
is exhausted or lower value.

Every question must map to:
- one critical decision bucket or blocker dimension
- one ambiguity
- one reason it matters

Ask the user directly when available.
Batch the smallest independent unblocker set, default max `3`.
Offer a recommended default pack when a full answer can be approved quickly.

## Request archetypes

Classify every run into one of:
- `feature`
- `analogy_feature`
- `parity_clone`
- `integration`
- `bugfix`
- `migration`
- `refactor`
- `reverse_spec`

Analogy-driven prompts such as "like X" or "replicate X" default to
`analogy_feature` unless strong contrary evidence exists.

## Critical decision buckets

These buckets drive readiness:
- `core_outcome`
- `scope_boundary`
- `implementation_constraints`
- `dependencies_and_integrations`
- `acceptance_signal`

Evidence density is a routing hint, not the sole readiness gate.
A single explicit prompt may be enough if it closes these buckets without
relying on unconfirmed assumptions.
Analogy-driven sparse prompts do not get that exception by default.

## Artifacts

Root index:
- `specs/README.md`

Canonical spec:
- `specs/<subject>.md`

Project-level (not per-spec — persists across all Trace runs):
- `UBIQUITOUS-LANGUAGE.md` — domain glossary at the project root, created
  during intake if missing, updated throughout the pipeline and by epilogue
  beads
- `AGENTS.md` — project agent conventions at the project root, created or
  updated by epilogue beads; read during intake, loop, adversarial review, and
  plan handoff to carry forward learnings across runs
- `.claude/skills/` — project-scoped agent skills, created or updated by
  epilogue beads, referenced as-needed during implementation work

Sidecars:
- `manifest.json`
- `run-state.json`
- `branch-registry.json`
- `evidence-ledger.jsonl`
- `claim-ledger.jsonl`
- `input-log.md`
- `spec-ledger.md`
- `question-backlog.md`
- `completeness-matrix.md`
- `contradiction-log.md`
- `decision-log.md`
- `review-report.md`
- `implementation-plan.md`
- `adversarial-review-log.md`
- `adversarial-round-N.json`
- `adversarial-escalation.json`
- `decomposition-proposal.md`
- `sub-spec-brief-<name>.md`
- `beads-manifest.json`
- `beads-review-log.md`
- `beads-review-round-N.json`
- `beads-decomposition-proposal.md`
- `beads-escalation.json`

## Root specs index

Every successful Trace run must leave behind a root `specs/README.md`.

Rules:
- if `specs/README.md` is missing, create it before or alongside the subject spec
- if it exists, preserve human-written prose outside the managed block
- update only the managed block for subject rows
- do not duplicate rows for the same subject; update the existing row

Managed block markers:
- `<!-- trace:spec-index:start -->`
- `<!-- trace:spec-index:end -->`

The root index is for discovery and navigation.
The subject spec is the backing artifact to hand to an external implementation
loop or another agent.
