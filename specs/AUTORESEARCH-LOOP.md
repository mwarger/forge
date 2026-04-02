# Autoresearch Loop — Design Spec

## Origin

Convergence of three systems:

- **Karpathy autoresearch** — single file, single metric, blind evaluation,
  keep/discard loop. Agent modifies `train.py`, evaluation runs in untouchable
  `prepare.py`. ~12 experiments/hour, ~100 overnight.
- **Super-Ralph** — three-phase SDLC engine (reverse/decompose/forward) where
  strategy is encoded as bead packs with fat descriptions, executed by a dumb
  runner (ralph-tui) that picks ready beads and spawns fresh agents.
- **Trace** — evidence-first spec pipeline with provenance tracking, readiness
  contracts, adversarial review, and a canonical merge protocol.

All three are the same pattern at different scales:
`hypothesis → act → evaluate → keep/discard → repeat`.

## Core Primitive: The Loop

The **ralph-loop** is the atom. Everything else is configuration.

A loop is defined by:
- **program** — what the doer works on (natural language directive)
- **metric** — how the judge evaluates (hard command or soft agent rubric)
- **target** — what score means "done" (optional numeric goal)
- **caps** — max iterations, wall-clock limit, plateau threshold
- **scope** — files/dirs the doer can modify

The loop runs as a bash script outside the agent. It picks ready beads from a
`br` epic, routes them to agents based on role labels, marks them done, and
repeats until no ready beads remain. The complexity is in the beads, not the
runner.

## Four-Bead Cycle

Each iteration of the loop is four beads with dependency wiring:

```
doer-N → judge-N → arbiter-N → strategist-N → (stamps next cycle)
```

### Doer

Fresh agent. Receives:
- The program (stable directive from grill-me intake)
- Ledger summary (what's been tried, what worked, what didn't)
- Scope (which files to modify)

Does NOT receive: the metric definition, the target score, the judge's rubric.

Makes one improvement. Commits changes. Marks bead done.

### Judge

Fresh agent (soft) or command (hard). Receives:
- Metric definition (rubric or command)
- Path to artifact being evaluated
- Nothing else

Two modes:

**Hard judge** — runs a command. `npm test`, `eslint`, `pytest`. The agent
literally cannot fake a test passing without writing correct code. Unfakeable
by design.

**Soft judge** — fresh agent with minimal, curated context. Scores an artifact
cold. Does not know what iteration this is, what was tried, or what the doer
intended. Scores against a rubric and outputs structured results.

Writes `judge-output-N.json`: `{ score, findings[] }`.

### Arbiter

**Not an agent.** A bash script. Pure arithmetic.

Reads judge output. Compares to previous score. Keep if improved, revert if
not. Updates the ledger. Checks terminal conditions. If continuing, stamps a
strategist bead. If terminal, stamps a retrospective bead or nothing.

Cannot be gamed because there is no LLM in the loop for scoring decisions.

Terminal conditions (any of):
1. Goal reached — score >= target
2. Plateau — N consecutive iterations with no improvement
3. Wall-clock cap — time limit exceeded (enforced by runner, not arbiter)
4. Iteration cap — max beads spawned
5. No ready beads — loop ends naturally

### Strategist

Fresh agent. Reads the ledger and current state. Decides what the next doer
should focus on. Adapts focus based on score trajectory:

- Score < 50: "gather evidence, find what's missing entirely"
- Score 50-75: "fill specific gaps the judge identified"
- Score > 75: "surgical refinements, address judge findings precisely"
- Plateau detected: "try a fundamentally different angle"
- Near target after plateau: swap judge to adversarial mode

Stamps the next four-bead cycle (doer/judge/arbiter/strategist) with tailored
descriptions. This is the self-replicating mechanism — the strategist's last
action is `br create` for the next cycle's beads.

## Context Loading

Each bead starts with fresh context. The bead description IS the context.
No external context bus. No shared memory. No context rot.

The strategist produces correctly-contextualized descriptions for the next
cycle. Each bead type gets exactly the information it needs:

- **Doer**: program + ledger summary + scope + strategist's focus directive
- **Judge**: metric definition + artifact path + output path. Nothing else.
- **Arbiter**: judge output path + ledger path + config path + terminal
  conditions. A bash script, not a prompt.
- **Strategist**: ledger path + current state + templates for stamping next
  cycle + epic ID

The arbiter carries the templates for stamping the strategist. The strategist
carries the templates for stamping the next doer and judge. Information flows
forward through bead descriptions, not through accumulated context.

## The Ledger

External JSONL file (`.autoresearch/research-log.jsonl`). The accumulator
across iterations. Not inside any bead — lives on disk, read by beads that
need it.

```jsonl
{"iter":1,"phase":"evidence_gathering","hypothesis":"initial draft","score_before":0,"score_after":34,"delta":34,"decision":"keep","sha":"a1b2c3"}
{"iter":2,"phase":"evidence_gathering","hypothesis":"add failure modes","score_before":34,"score_after":58,"delta":24,"decision":"keep","sha":"d4e5f6"}
{"iter":3,"phase":"gap_filling","hypothesis":"expand error handling","score_before":58,"score_after":55,"delta":-3,"decision":"revert","sha":"d4e5f6"}
```

The doer gets a summarized view injected into its description. The judge gets
nothing from the ledger. The arbiter reads it for score comparison. The
strategist reads the full history to decide direction.

## The Blind Judge Contract

The doer and judge are context-firewalled:

| | Doer sees | Judge sees |
|---|---|---|
| Program | yes | no |
| Ledger | summary | no |
| Metric definition | no | yes |
| Target score | no | no |
| Judge rubric | no | yes |
| Doer hypothesis | yes | no |
| Codebase/artifact | yes (read/write) | yes (read-only) |

For hard judges (test runners, linters), the doer knows tests exist but
cannot fake them passing. The metric is honest by construction.

For soft judges (spec quality, product fidelity), the doer does not know the
rubric. The judge does not know what changed. Neither can game the other.

## Agent Routing

Beads declare their agent preference via labels:

```
role:doer,agent:claude-opus,scope:specs/
role:judge,agent:claude-haiku,scope:specs/
role:arbiter-script,agent:bash
role:strategist,agent:claude-sonnet
```

The runner reads labels and routes accordingly. Cheap beads (judge scoring a
rubric) go to fast/cheap models. Complex beads (doer making architectural
decisions) go to capable models. Arbiter runs bash. No wasted tokens.

## The Runner: ralph-loop

A bash script. Ships in `bin/`. Globally installable. ~60 lines.

```
ralph-loop <epic-id> [--wall-clock <seconds>] [--agent <cmd>]
```

The runner:
1. Queries `br ready --parent <epic-id>` for next bead
2. Reads role label to determine routing
3. For `role:arbiter-script`: extracts and runs bash from description
4. For `role:judge`: spawns agent with read-only tool restrictions
5. For all others: spawns agent with standard tool access
6. Marks bead done
7. Repeats until no ready beads or wall-clock cap

The runner knows nothing about autoresearch, spec quality, or loop semantics.
It just runs beads. The intelligence is in the bead descriptions.

## Human in the Loop

The loop cannot block on human input overnight. When the judge or strategist
determines human input is needed:

1. Strategist writes the question to `.autoresearch/needs-human.md`
2. Strategist stamps NO next beads
3. The loop naturally stops (no ready beads)
4. Human comes back, reads the question, answers
5. Human (or a restart script) stamps the next cycle with the answer
6. Runner is restarted — loop resumes

The loop terminates cleanly and can be restarted. No blocking. No polling.

## Retrospective Bead

When the loop terminates (goal reached or cap hit), the arbiter stamps one
final bead — a retrospective:

- Reads: full ledger, final artifact, config
- Produces: `retrospective.md` (what worked, what failed, plateau analysis)
- Produces: `rubric-suggestions.md` (improvements to the judge rubric)
- Updates: `AGENTS.md` if applicable

Future loops on this project read the retrospective corpus to start smarter.
Autoresearch on autoresearch.

## Nested Loops

Loops compose. A macro orchestrator can chain sequential loops:

```
INSPECT loop  (metric: spec completeness)
  → spec done
BUILD loop    (metric: test pass rate)
  → code done
QA loop       (metric: E2E pass + visual diff)
  → product done
```

Each inner loop is a self-contained autoresearch cycle with its own epic,
ledger, and terminal conditions. The macro orchestrator stamps the next loop
when the previous converges. This is the Ralph-to-Ralph model.

## Integration with the spec pipeline

The spec pipeline maps to loop configurations:

| Pipeline Phase | Loop Equivalent |
|---|---|
| INTAKE | Interactive grill-me → produces program.md |
| EVIDENCE_FANOUT | Early doer iterations (score < 50) |
| GAP_ANALYSIS | Mid doer iterations (score 50-75) |
| DRAFT | Late doer iterations (score > 75) |
| READINESS_GATE | Arbiter terminal condition (score >= target) |
| ADVERSARIAL_REVIEW | Judge swap to adversarial rubric at high scores |
| PLAN_HANDOFF | Separate skill after loop converges |

The pipeline's valuable properties survive:
- **Provenance**: doer instructions require evidence citations; judge rubric
  scores provenance
- **Readiness contract**: arbiter maintains `run-state.json` mechanically
- **Canonical merge**: only doer writes to spec; file permissions enforced by
  runner

## Workspace Layout

```
.autoresearch/
├── config.json              # loop configuration (target, caps, metric)
├── program.md               # stable directive from intake
├── research-log.jsonl       # iteration ledger
├── judge-output-N.json      # per-iteration judge scores
├── needs-human.md           # questions requiring human input (if any)
├── retrospective.md         # post-loop learning (written by retro bead)
└── rubric-suggestions.md    # judge improvement suggestions
```

## Loop Configuration Schema

```json
{
  "subject": "rate-limiter",
  "epic_id": "EPIC_042",
  "metric": {
    "type": "soft",
    "rubric_path": "metrics/spec-quality.md",
    "artifact_path": "specs/rate-limiter.md"
  },
  "target": 80,
  "caps": {
    "max_iterations": 20,
    "wall_clock_seconds": 14400,
    "plateau_threshold": 3
  },
  "scope": {
    "doer_paths": ["specs/rate-limiter.md", "specs/_artifacts/rate-limiter/"],
    "judge_paths": ["specs/rate-limiter.md"]
  },
  "agents": {
    "doer": "claude-opus",
    "judge": "claude-haiku",
    "strategist": "claude-sonnet"
  },
  "adversarial_threshold": 80,
  "confirmation_rounds": 2
}
```
