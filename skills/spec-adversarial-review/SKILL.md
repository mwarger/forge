---
name: spec-adversarial-review
description: "Stress-test a subject spec for ambiguity, gaps, contradictions, and untestable claims using dynamic agent teams. Use this when the spec has passed completeness and synthesis-review gates and needs adversarial validation before readiness promotion."
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

Use this after `spec-synthesis-review` passes and the orchestrator's scoring
gates are met. Do not use this before `blocker_reasons` is empty and
`completeness_score >= 80` and `evidence_confidence_score >= 80`.

## Purpose

Find every remaining gap that could force an engineer to make a judgment call
the spec should have made for them. The full adversarial attack surface:
ambiguity, missing failure modes, contradictions between sections, unstated
dependencies, scalability gaps, security blind spots, untestable claims.

## Agent team allocation

The orchestrator creates agent teams via `TeamCreate` before delegating to this
skill. The team persists across all rounds for context continuity.

### Section agents (depth)

One per substantive spec area. Allocate dynamically by reading the completeness
matrix. A simple spec gets 3-4 agents, a complex one 8-10.

Candidate roles (allocate only those with substantive spec content):
- core flows agent
- entity and state transitions agent
- interfaces and integrations agent
- constraints and failure modes agent
- security boundaries agent
- acceptance criteria agent
- data model agent
- migration and rollback agent

### Cross-cutting agents (coherence)

Always allocate these regardless of spec size:
- **literal implementer** — "If I read this spec with zero context and built
  exactly what it says, what would go wrong?"
- **QA adversary** — "What claims are untestable? What edge cases have no
  defined behavior?"
- **consistency checker** — "Where does section X contradict or assume
  something incompatible with section Y?"

## Round structure

Every round MUST spawn the full agent team — all section agents and all
cross-cutting agents. Do not spawn a subset, even if earlier findings were
narrow. The point of subsequent rounds is to verify fixes did not introduce new
issues elsewhere and to catch things the previous round missed.

Each round:
1. all agents read the current spec, `UBIQUITOUS-LANGUAGE.md`, and `AGENTS.md`
   (project root, if they exist) independently
2. section agents probe their area for: ambiguous language, missing failure
   modes, unstated assumptions, vague constraints, gaps an engineer would have
   to fill with judgment
3. cross-cutting agents probe for: inter-section contradictions, untestable
   claims, unstated dependencies, things that work on paper but break in
   practice
4. each agent researches the codebase before filing a finding — if the answer
   is in the code, it is a resolution, not a finding
5. findings are collected, deduplicated, and classified:
   - **critical** — multiple valid interpretations of a core behavior, missing
     failure mode that changes architecture → escalate to user
   - **high** — ambiguous constraint, unclear boundary, missing edge case with
     non-obvious answer → escalate to user
   - **resolvable** — answer is unambiguous from codebase or context →
     auto-resolve, log decision, flag for user visibility
6. user answers escalated findings
7. the orchestrator (as lead agent and sole reducer) applies all resolutions to
   the spec — this skill emits structured resolution proposals, it does not
   write canon directly
8. next round begins on the updated spec

## Convergence

- **minimum**: 2 rounds if round 1 produces findings. If round 1 produces zero
  material findings from all agents, 1 round is sufficient.
- **maximum**: 5 rounds (safety cap)
- **exit**: a round where ALL agents — section and cross-cutting — independently
  report zero material findings
- **bias**: toward running another round if any agent is uncertain. The cap is a
  safety valve, not a target.
- **"material" defined broadly**: anything that could cause an engineer to make
  a judgment call the spec should have made for them

## Cap behavior

Hitting the cap (5 rounds without convergence) is NOT an acceptable exit. It
triggers a decomposition signal:
- emit `adversarial_status = decomposition_required` as structured input to
  the orchestrator
- emit `decomposition-proposal.md` identifying natural seams, tangled concerns,
  and 2-3 suggested sub-specs with boundaries
- emit `sub-spec-brief-<name>.md` per suggested sub-spec containing:
  - extracted evidence relevant to that sub-spec
  - scope and boundaries (in and out)
  - constraints inherited from the parent spec
  - dependencies on other sub-specs (if any)
  - enough context for a fresh session to run `spec-intake` without losing
    information
- the decomposition proposal must identify dependency edges between sub-specs
- the user decides per sub-spec: run now (sequential), run in parallel via
  agent teams (for independent sub-specs), or save for later (self-contained
  brief for a new session)

## Back-transitions

When escalating back to earlier pipeline stages:
- emit `adversarial-escalation.json` listing: finding IDs, affected sections,
  blocker reason if reopened
- the orchestrator passes this to `spec-loop` so the re-entry round is targeted
  to the specific findings, not a generic pass

## Finding structure

Each finding must include:
- `finding_id` — stable identifier
- `round` — which adversarial round
- `agent_role` — which agent filed it
- `severity` — critical, high, or resolvable
- `spec_section` — which section of the subject spec
- `description` — what the problem is
- `evidence` — what the agent observed (spec text, codebase evidence, or both)
- `resolution` — how it was resolved (user answer, codebase research, or
  pending)
- `resolution_source` — user, codebase, or auto

## Outputs

Emit as structured input to the orchestrator (do not write these directly):
- `adversarial-review-log.md` — all findings across all rounds with resolutions
  and provenance
- `adversarial-round-N.json` — structured findings per round
- resolution proposals for `specs/<subject>.md`
- structured adversarial fields for `manifest.json`:
  - `adversarial_rounds_completed`
  - `adversarial_status` (`converged` | `decomposition_required`)
  - `adversarial_findings_total`
  - `adversarial_findings_resolved_by_research`
  - `adversarial_findings_resolved_by_user`

On decomposition:
- `decomposition-proposal.md`
- `sub-spec-brief-<name>.md` (one per suggested sub-spec)
- `adversarial-escalation.json` (on back-transition)

## Hard rules

1. This skill does not write canon. It emits proposals. The orchestrator
   reduces.
2. Research the codebase before filing any finding. If the answer is there, it
   is a resolution, not a finding.
3. Zero material findings means zero. "Probably fine" is not zero.
4. The cap is a decomposition signal, not an acceptable exit.
5. `adversarial_status` has exactly two values: `converged` or
   `decomposition_required`. No middle ground.
6. Agent teams are the required organizing mechanism. Do not use ad-hoc agent
   spawning.
7. Never predict convergence. Never skip a round because you believe it will
   converge. Spawn all agents, collect their findings, and only then determine
   whether findings are zero. "I'm confident round N will converge" is not a
   substitute for running round N.
