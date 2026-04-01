# Forge

Turn evidence into implementation-ready artifacts through autonomous iterative refinement.

## Lineage

Forge is the convergence of two prior systems. Each solved part of the problem. Forge combines them.

### Ralph TUI (the execution engine)

The first system. An autonomous agent orchestrator: pick a task, build a context-aware prompt, run an agent, detect completion, repeat. Ralph proved that AI agents work best when you give them fat descriptions, fresh context per task, and a dumb runner that just picks the next ready thing. The intelligence lives in the task descriptions, not the orchestrator.

Key insight: **strategy is encoded in task descriptions, not in the runner.**

### Trace (the specification engine)

The second system. An evidence-first spec pipeline: take raw inputs (code, docs, transcripts, screenshots), classify them as evidence, run them through a 12-phase pipeline with adversarial review, and produce a planning-ready spec with provenance tracking. Trace proved that you need formal readiness gates, blocker rules, and stress-testing before any spec ships. The spec doesn't become planning-ready until dynamic agent teams find nothing wrong with it.

Key insight: **readiness is a state machine with blocker rules, not a score threshold.**

### Forge (the synthesis)

Both systems converge on the same primitive: `hypothesis → act → evaluate → keep/discard → repeat`. Ralph applies it to implementation tasks. Trace applies it to spec quality. Forge makes that loop first-class.

Forge takes Trace's spec pipeline and adds autonomous improvement loops that self-replicate. After intake, you choose: work interactively (Trace's adaptive clarification), or hand it off to an autoresearch loop that runs overnight. Either path converges at the same readiness gate. The loop is the same pattern Ralph proved — fat bead descriptions, fresh agents, dumb runner — applied to iterative artifact refinement with blind scoring.

Key insight: **the spec pipeline and the execution engine are the same loop at different scales.**

## The core loop

Everything in Forge reduces to this:

```
hypothesis → act → evaluate → keep/discard → repeat
```

At the spec level: the doer improves the spec, the judge scores it blind, the arbiter keeps or reverts, the strategist decides what to try next. At the implementation level: Ralph picks a bead, an agent executes it, review agents evaluate, the cycle continues.

The autoresearch loop makes this concrete as a four-bead cycle:

```
doer-N → judge-N → arbiter-N → strategist-N → (stamps N+1)
```

Each bead is a fresh agent with no prior context. The bead description IS the context. No context rot. No accumulated confusion. Every iteration starts clean.

## Two paths to readiness

After spec intake, Forge presents a choice:

```
A) Evidence-first loop — interactive spec-loop with adaptive clarification.
   Best when you're available for questions.

B) Autoresearch loop — autonomous iterative improvement with blind scoring.
   Best for overnight runs or well-defined programs.
```

Both paths converge at the same READINESS_GATE. The spec doesn't care how it got there.

### Path A: Interactive (Trace's spec-loop)

You stay in the conversation. The pipeline asks clarifying questions mapped to critical decision buckets, processes evidence units, drafts spec sections, and loops until readiness gates pass. Then adversarial review, plan handoff, optional beads. This is Trace's full 12-phase pipeline, unchanged.

Best for: new features, sparse prompts, anything where the critical decisions haven't been made yet.

### Path B: Autoresearch loop

You walk away. The loop stamps a four-bead cycle into a `br` epic and returns an epic ID. You run `ralph-loop <epic-id>` externally. The loop iterates autonomously — doer improves, judge scores blind, arbiter keeps or reverts, strategist adapts focus — until a terminal condition is met. Then the retrospective bead updates `run-state.json` and the orchestrator resumes from READINESS_GATE.

Best for: overnight runs, well-defined programs with clear metrics, iterative refinement of existing artifacts.

## The four-bead cycle

### Doer

Fresh agent. Receives the program (stable directive), a ledger summary of what's been tried, a focus directive from the strategist, and a file scope. Makes one improvement. Commits. Done.

Does NOT receive: the metric definition, the target score, the judge's rubric.

### Judge

Fresh agent (soft) or shell command (hard). Receives the metric definition and the artifact path. Scores what it sees. Nothing else.

Does NOT receive: the doer's hypothesis, the ledger, the program, iteration history.

Two modes:
- **Hard judge** — runs a command (`npm test`, `eslint`, `pytest`). Unfakeable by construction.
- **Soft judge** — fresh agent with a rubric. Scores the artifact cold. Cannot be gamed because it has no idea what changed or why.

### Arbiter

Not an agent. A bash script. Pure arithmetic.

Reads judge output. Compares to previous score. Keeps if improved, reverts if not. Updates the ledger. Checks terminal conditions (goal reached, iteration cap, plateau). Writes a signal file for the strategist.

Cannot be gamed because there is no LLM in the scoring decision.

### Strategist

Fresh agent. Reads the full ledger and the arbiter's signal. Decides what the next doer should focus on. Adapts based on score trajectory:

- Below 50: evidence gathering — find what's missing entirely
- 50–75: gap filling — address specific judge findings
- Above 75: surgical refinement — precise improvements only
- Plateau: fundamentally different angle

The strategist's last action is stamping the next four-bead cycle via `br create`. This is the self-replicating mechanism.

## The blind judge contract

The doer and judge are context-firewalled:

|                    | Doer sees | Judge sees |
|--------------------|-----------|------------|
| Program            | yes       | no         |
| Ledger             | summary   | no         |
| Metric definition  | no        | yes        |
| Target score       | no        | no         |
| Judge rubric       | no        | yes        |
| Doer hypothesis    | yes       | no         |
| Artifact           | read/write | read-only |

This separation is load-bearing. The doer can't optimize for the rubric because it doesn't know the rubric. The judge can't be influenced by the doer's intent because it doesn't know the intent.

## The runner: ralph-loop

A bash script. Ships in `bin/`. Globally installable.

```
ralph-loop <epic-id> [--wall-clock <seconds>] [--agent <cmd>]
ralph-loop status <epic-id>
ralph-loop resume <epic-id>
```

The runner knows nothing about autoresearch, spec quality, or loop semantics. It just runs beads:

1. Query `br ready --parent <epic-id>` for next bead
2. Read role label to determine routing
3. For `role:arbiter-script`: extract and run bash from description
4. For `role:judge`: spawn agent with read-only tools
5. For all others: spawn agent with standard tools
6. Mark bead done
7. Repeat until no ready beads or wall-clock cap

The intelligence is in the bead descriptions, not the runner.

### Status

```bash
ralph-loop status EPIC_042
```

Shows: subject, epic, iteration count, score trajectory, kept/reverted ratio, current phase, and the last 5 iterations.

### Resume (human-in-the-loop)

The loop can't block on human input overnight. When human input is needed:

1. Strategist writes the question to `.autoresearch/needs-human.md`
2. Strategist stamps no next beads
3. Loop stops naturally (no ready beads)
4. Human reads the question, writes their answer
5. `ralph-loop resume <epic-id>` stamps a resume-strategist bead and restarts

No blocking. No polling. Clean stop, clean restart.

## The ledger

External JSONL file (`.autoresearch/research-log.jsonl`). The accumulator across iterations. Lives on disk, not inside any bead.

```jsonl
{"iter":1,"score_before":0,"score_after":34,"delta":34,"decision":"keep","sha":"a1b2c3","findings_count":8}
{"iter":2,"score_before":34,"score_after":58,"delta":24,"decision":"keep","sha":"d4e5f6","findings_count":5}
{"iter":3,"score_before":58,"score_after":55,"delta":-3,"decision":"revert","sha":"d4e5f6","findings_count":6}
```

The doer gets a summarized view. The judge gets nothing. The arbiter reads it for score comparison. The strategist reads the full history to decide direction.

## Signal schema

The arbiter communicates via JSON signal files.

**Terminal signal** (`.autoresearch/terminal-signal.json`):
```json
{"type":"terminal","reason":"goal_reached","iter":12,"final_score":85,"decision":"keep"}
```
Reasons: `goal_reached`, `iteration_cap`, `plateau`.

**Continue signal** (`.autoresearch/arbiter-signal.json`):
```json
{"type":"continue","iter":5,"next_iter":6,"current_score":67,"decision":"keep","delta":4}
```

When a terminal signal is written, the arbiter removes any stale continue signal.

## Workspace layout

```
.autoresearch/
├── config.json              # loop configuration (target, caps, metric, agents)
├── program.md               # stable directive — does not change across iterations
├── research-log.jsonl       # iteration ledger (the accumulator)
├── judge-template.md        # pre-rendered judge description (output path placeholder)
├── arbiter-template.sh      # pre-rendered arbiter script (iter/path placeholders)
├── judge-output-N.json      # per-iteration judge scores
├── arbiter-signal.json      # continue signal (removed on terminal)
├── terminal-signal.json     # terminal signal (written once)
├── needs-human.md           # question for human (when loop pauses)
├── retrospective.md         # post-loop learning artifact
└── rubric-suggestions.md    # judge improvement suggestions
```

## The spec pipeline

The full pipeline from Trace, integrated with autoresearch:

```
evidence → intake → [choice point] → readiness gate → adversarial review → plan handoff → beads
                         │                    ↑
                    ┌────┴────┐               │
                    │         │               │
              A: spec-loop   B: autoresearch  │
              (interactive)  (autonomous)     │
                    │         │               │
                    └────┬────┘               │
                         └────────────────────┘
```

### Pipeline phases

| Phase | Purpose |
|-------|---------|
| `INTAKE` | Normalize inputs, classify archetype, seed evidence ledger |
| `EVIDENCE_FANOUT` | Sub-agent exploration of evidence sources |
| `REDUCE_AND_MERGE` | Canonical merge — single reducer writes spec |
| `GAP_ANALYSIS` | Identify missing coverage across dimensions |
| `USER_INPUT` | Clarifying questions mapped to decision buckets |
| `DRAFT` | Write spec sections from evidence with provenance |
| `VERIFY` | Check draft against acceptance criteria |
| `READINESS_GATE` | 12-dimension scoring, enforce 80/80 gates |
| `ADVERSARIAL_REVIEW` | Dynamic agent teams stress-test until zero findings |
| `PLAN_HANDOFF` | Render implementation plan or withheld handoff |
| `BEADS_GENERATION` | Decompose plan into dependency-wired beads |
| `BEADS_REVIEW` | Stress-test beads for coverage and actionability |

### Readiness model

Planning states: `DISCOVERY` → `AWAITING_CLARIFICATION` → `SPECULATIVE_DRAFT` → `ADVERSARIAL_REVIEW` → `PLANNING_READY`

Handoff states: `WITHHELD` → `ELIGIBLE`

Rules:
- Scores do not override blocker reasons
- Sparse analogy prompts with zero question rounds can never reach `PLANNING_READY`
- Entry to `ADVERSARIAL_REVIEW` requires both blocker_reasons empty and scores >= 80
- `PLANNING_READY` only when all adversarial agents report zero material findings

### Post-autoresearch re-entry

When the autoresearch loop converges and the user returns:

1. The retrospective bead has already updated `run-state.json`
2. `planning_status = READINESS_GATE`, `loop_strategy = "autoresearch"`
3. The orchestrator runs the readiness gate check
4. If gate passes → auto-transition through adversarial review and beyond
5. If gate fails → offer interactive spec-loop or another autoresearch cycle

## Nested loops

Loops compose. A macro orchestrator can chain them:

```
SPEC loop    (metric: spec completeness rubric)    → spec done
BUILD loop   (metric: test pass rate)              → code done
QA loop      (metric: E2E + visual diff)           → product done
```

Each inner loop is a self-contained autoresearch cycle with its own epic, ledger, and terminal conditions. This is the Ralph-to-Ralph model.

## Skills

| Skill | Role |
|-------|------|
| `trace-orchestrator` | Top-level orchestrator — routes through sub-skills, manages state, sole reducer |
| `spec-intake` | Normalize inputs, classify archetype, seed evidence ledger |
| `spec-loop` | Process evidence, ask clarifying questions, emit speculative variants |
| `spec-completeness` | Score spec against 12-dimension ontology, enforce 80/80 gates |
| `spec-synthesis-review` | Merge sub-agent outputs into canon, 4 review passes |
| `spec-adversarial-review` | Stress-test with dynamic agent teams until zero findings |
| `spec-plan-handoff` | Render implementation plan or withheld handoff |
| `spec-beads-generate` | Decompose plan into beads with dependency wiring |
| `spec-beads-review` | Stress-test beads for coverage, granularity, dependencies |
| `autoresearch-loop` | Stamp self-replicating four-bead cycle for autonomous improvement |

## Install

```bash
./install.sh
```

Installs `forge-pack` (helper CLI) and `ralph-loop` (bead runner) to your PATH.

### Prerequisites

- `br` CLI installed and initialized (for bead management)
- `claude` or another agent CLI (for running beads)
- `bash`, `git`, `python3`, `jq`

### Uninstall

```bash
./uninstall.sh
```

## Development

```bash
# Smoke test — verify repo structure and artifacts
./scripts/smoke-test.sh

# Local isolated testing
./scripts/test-local.sh
```

## The evolution

Looking back across the three projects:

| | Ralph TUI | Trace | Forge |
|---|---|---|---|
| **Core question** | How do you run AI agents on task lists? | How do you build specs that don't hallucinate? | How do you autonomously refine artifacts to readiness? |
| **Architecture** | TUI + plugins + trackers | Skill pipeline + sub-agents + readiness gates | Spec pipeline + self-replicating bead loops |
| **Loop primitive** | Pick task → run agent → mark done | Process evidence → score → gate | Doer → judge → arbiter → strategist → repeat |
| **Human role** | Watches the TUI, intervenes on errors | Answers clarifying questions | Chooses path, then walks away (or stays) |
| **Intelligence lives in** | Task descriptions + prompt templates | Skill definitions + readiness rules | Bead descriptions + blind scoring contracts |
| **What it proved** | Dumb runners + fat descriptions work | Formal readiness gates prevent hallucinated specs | The same loop works at every scale |

The pattern that emerged: encode strategy in descriptions, keep the runner dumb, use fresh context per task, and let the system self-replicate. Ralph did this for implementation. Trace did this for specs. Forge does both, and connects them.
