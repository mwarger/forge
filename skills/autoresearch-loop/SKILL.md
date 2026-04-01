---
name: autoresearch-loop
description: "Stamp a self-replicating four-bead autoresearch loop (doer/judge/arbiter/strategist) for autonomous iterative improvement of any artifact. Use after interactive intake when you have a program and want to run an autonomous improvement loop with blind scoring. Triggers on: autoresearch, research loop, autonomous loop, overnight loop, iterative improvement."
allowed-tools: Read, Write, Bash, Glob, Grep, Agent
---

Stamp and configure an autoresearch loop.

## What this skill does

Takes a **program** (what to work on) and a **metric** (how to score it), then
stamps an initial four-bead cycle into a `br` epic. The beads self-replicate:
the strategist's last action is creating the next cycle's beads. The loop runs
in `ralph-loop` (external bash runner) until a terminal condition is met.

This skill does NOT run the loop. It stamps the beads and returns the epic ID.
The user runs `ralph-loop <epic-id>` separately.

## Prerequisites

- `br` CLI installed and initialized (`.beads` workspace exists)
- A program — either from a prior grill-me / spec-intake session, or provided
  directly by the user
- A metric choice — hard (command) or soft (rubric)

## Steps

### 1. Gather inputs

Collect from the user or from prior pipeline artifacts:

- **Program**: what the doer should work on. If a Trace spec run exists, use
  the spec subject and evidence as the program. If the user provides a
  description, use that. If unclear, ask.
- **Metric type**: `hard` (test command, lint, benchmark) or `soft` (agent
  with rubric). If spec refinement, default to soft with `spec-quality.md`
  rubric.
- **Target score**: numeric goal (0-100 for soft, metric-specific for hard).
  Optional — if omitted, loop runs until cap.
- **Caps**: max iterations (default 20), wall-clock seconds (default 0 = no
  limit), plateau threshold (default 3).
- **Scope**: files/dirs the doer can modify. If spec refinement, default to
  `specs/<subject>.md` and `specs/_artifacts/<subject>/`.
- **Agent preferences**: which model for each role. Defaults:
  doer = claude-opus, judge = claude-haiku, strategist = claude-sonnet.

### 2. Create workspace

```bash
mkdir -p .autoresearch
```

Write `.autoresearch/config.json`:
```json
{
  "subject": "<subject>",
  "epic_id": "<will be set after epic creation>",
  "metric": {
    "type": "soft|hard",
    "rubric_path": "<path to rubric file, for soft>",
    "command": "<shell command, for hard>",
    "artifact_path": "<path to artifact being evaluated>"
  },
  "target": <number or null>,
  "caps": {
    "max_iterations": 20,
    "wall_clock_seconds": 0,
    "plateau_threshold": 3
  },
  "scope": {
    "doer_paths": ["<paths>"],
    "judge_paths": ["<paths>"]
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

Write `.autoresearch/program.md` — the stable directive. If from a Trace
intake, include:
- Goal statement
- Design decisions (resolved)
- Design decisions (deferred — loop should explore)
- Constraints
- Evidence sources

Initialize the ledger:
```bash
touch .autoresearch/research-log.jsonl
```

Write `.autoresearch/judge-template.md` — the fully-rendered judge description
with all variables filled EXCEPT `{{JUDGE_OUTPUT_PATH}}`, which stays as a
literal placeholder for the strategist to fill per-iteration.

Write `.autoresearch/arbiter-template.sh` — the fully-rendered arbiter script
(from `references/arbiter.sh`) with all variables filled EXCEPT `{{ITER}}` and
`{{JUDGE_OUTPUT_PATH}}`, which stay as literal placeholders for the strategist
to fill per-iteration.

These templates give the strategist concrete files to read when stamping
subsequent cycles, rather than having to re-derive the descriptions.

### 3. Create epic

```bash
br create --type epic --title "autoresearch: <subject>" \
  --labels "autoresearch,trace:<subject-slug>"
```

Update `config.json` with the epic ID.

### 4. Stamp initial four-bead cycle

Create four beads under the epic. Each bead's description is rendered from the
templates in `references/`. The templates are parameterized — fill in paths,
iteration number (1), and the program content.

#### Bead 1: doer-1

```bash
br create --title "doer-1: initial improvement" \
  --type task --parent <epic-id> \
  --labels "autoresearch,role:doer,agent:<doer-agent>" \
  --description "<rendered doer.md template>"
```

The doer description includes:
- The full program from `.autoresearch/program.md`
- "This is iteration 1. No prior attempts."
- The scope (which files to modify)
- Instructions to commit changes when done

#### Bead 2: judge-1

```bash
br create --title "judge-1: score iteration 1" \
  --type task --parent <epic-id> \
  --labels "autoresearch,role:judge,agent:<judge-agent>" \
  --description "<rendered judge-soft.md or judge-hard.md template>"
```

Depends on doer-1:
```bash
br dep add <judge-1-id> <doer-1-id>
```

The judge description includes:
- The metric definition (rubric or command)
- The artifact path to evaluate
- Output path: `.autoresearch/judge-output-1.json`
- Explicit instruction: "Do not read git history. Do not read any files
  outside the artifact path. Score what you see, nothing else."

#### Bead 3: arbiter-1

```bash
br create --title "arbiter-1: keep/revert decision" \
  --type task --parent <epic-id> \
  --labels "autoresearch,role:arbiter-script,agent:bash" \
  --description "<rendered arbiter.sh template>"
```

Depends on judge-1:
```bash
br dep add <arbiter-1-id> <judge-1-id>
```

The arbiter description contains a bash script in a fenced code block. The
runner extracts and executes it directly — no LLM involved.

#### Bead 4: strategist-1

```bash
br create --title "strategist-1: plan next iteration" \
  --type task --parent <epic-id> \
  --labels "autoresearch,role:strategist,agent:<strategist-agent>" \
  --description "<rendered strategist.md template>"
```

Depends on arbiter-1:
```bash
br dep add <strategist-1-id> <arbiter-1-id>
```

The strategist description includes:
- Path to ledger
- Path to config (for caps, target, templates)
- The epic ID
- Full templates for doer, judge, arbiter, and strategist beads
- Instructions to stamp the next four-bead cycle or stop if the arbiter
  wrote a terminal signal

### 5. Report

Output to the user:
- Epic ID
- Workspace path (`.autoresearch/`)
- Config summary (metric, target, caps)
- Instructions: `ralph-loop <epic-id> [--wall-clock <seconds>]`

Do NOT run the loop. Return control to the user.

## Hard rules

1. This skill stamps beads. It does not run them.
2. Every bead must be parented to the epic. No orphans.
3. The arbiter is always a bash script, never an LLM agent.
4. The judge never sees the doer's hypothesis, the ledger, or the program.
5. The doer never sees the metric definition, the target score, or the rubric.
6. Dependencies must be wired: doer → judge → arbiter → strategist.
7. Do not hardcode iteration counts. The strategist decides whether to
   continue based on the arbiter's output.
8. The program is written once during setup and does not change across
   iterations. The strategist's focus directive is what adapts.
9. All bead descriptions must be self-contained — a fresh agent with no
   prior context must be able to execute the bead from its description alone.
10. The retrospective bead is stamped by the strategist when it reads a
    terminal signal from the arbiter. The arbiter writes the signal file;
    the strategist acts on it.
