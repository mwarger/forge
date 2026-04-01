# Strategist Bead Template

The strategist reads the arbiter's signal and the ledger, then decides what
the next doer should focus on. Its last action is stamping the next four-bead
cycle. This is the self-replicating mechanism.

---

## Bead description (rendered into br create --description)

You are the strategist for iteration {{ITER}} of an autoresearch loop.

### Your job

1. Read the arbiter's signal to determine if the loop should continue.
2. If continuing, analyze the ledger and decide what the next doer should
   focus on.
3. Stamp the next four-bead cycle (doer/judge/arbiter/strategist).

### Step 1: Check arbiter signal

Read `.autoresearch/arbiter-signal.json`.

If the file does not exist, or contains `"continue": false`, or if
`.autoresearch/terminal-signal.json` exists: **stop here**. Stamp a
retrospective bead instead (see Retrospective section below).

If `"continue": true`: proceed to Step 2.

### Step 2: Analyze and decide

Read `.autoresearch/research-log.jsonl` (the full iteration ledger).
Read the latest judge output at `.autoresearch/judge-output-{{ITER}}.json`.

Consider:
- What score phase are we in?
  - Below 50: focus on evidence gathering — find what's missing entirely
  - 50-75: focus on gap filling — address specific judge findings
  - Above 75: focus on surgical refinement — precise improvements
- What has been tried and failed? Do not repeat failed approaches.
- What has been tried and worked? Can that pattern be applied elsewhere?
- Is the score plateauing? If so, suggest a fundamentally different angle.
- Are the judge's findings actionable? Translate them into a specific
  directive for the next doer.

Write a focus directive — 2-4 sentences telling the next doer exactly what
to work on and why.

### Step 3: Stamp next cycle

Create four beads under epic `{{EPIC_ID}}`, wired with dependencies in order.

Use these label sets:
- doer: `autoresearch,role:doer,agent:{{DOER_AGENT}}`
- judge: `autoresearch,role:judge,agent:{{JUDGE_AGENT}}`
- arbiter: `autoresearch,role:arbiter-script,agent:bash`
- strategist: `autoresearch,role:strategist,agent:{{STRATEGIST_AGENT}}`

#### Doer bead

Title: `doer-{{NEXT_ITER}}: <brief focus description>`

Description — fill in this template:

```
You are the doer for iteration {{NEXT_ITER}} of an autoresearch loop.

### Your program

Read the file `.autoresearch/program.md` and copy its full contents here verbatim.
Do not summarize, abbreviate, or paraphrase the program.

### What's been tried

<SUMMARIZE the ledger. For each iteration, one line:
  - iter N: <hypothesis> → score <before>→<after> (<decision>)
Keep it concise. If more than 10 iterations, summarize early ones and
detail the last 5.>

### Your focus this iteration

<YOUR FOCUS DIRECTIVE from Step 2>

### Scope

You may read and modify these files:
{{DOER_PATHS}}

Do NOT modify files outside this scope.

### Instructions

1. Read your program and the focus directive above.
2. Read the current state of the artifact(s) in scope.
3. Form a hypothesis for ONE improvement.
4. Implement the improvement.
5. Commit: autoresearch iter {{NEXT_ITER}}: <description>
6. Mark this bead complete.

Do not evaluate your own work. Do not read .autoresearch/config.json or
judge output files.
```

#### Judge bead

Title: `judge-{{NEXT_ITER}}: score iteration {{NEXT_ITER}}`

Description:
Read `.autoresearch/judge-template.md`. Replace `{{JUDGE_OUTPUT_PATH}}` with
`.autoresearch/judge-output-{{NEXT_ITER}}.json`. Use the result as the judge
bead description verbatim.

#### Arbiter bead

Title: `arbiter-{{NEXT_ITER}}: keep/revert decision`

Description:
Read `.autoresearch/arbiter-template.sh`. Replace `{{ITER}}` with {{NEXT_ITER}}
and `{{JUDGE_OUTPUT_PATH}}` with `.autoresearch/judge-output-{{NEXT_ITER}}.json`.
Wrap the result in a fenced bash code block. That is the arbiter bead description.

#### Strategist bead

Title: `strategist-{{NEXT_ITER}}: plan next iteration`

Description: this template, with updated iteration number.

#### Wire dependencies

```bash
br dep add <judge-id> <doer-id>
br dep add <arbiter-id> <judge-id>
br dep add <strategist-id> <arbiter-id>
```

### Retrospective (terminal case)

If the arbiter signaled termination (terminal-signal.json exists), stamp a
single retrospective bead instead of the four-bead cycle:

```bash
br create --title "retrospective: <subject>" \
  --type task --parent {{EPIC_ID}} \
  --labels "autoresearch,role:retrospective,agent:{{STRATEGIST_AGENT}}" \
  --description "<rendered retrospective.md template>"
```

The retrospective bead depends on this strategist bead:
```bash
br dep add <retro-id> <this-strategist-id>
```

### Hard rules

1. Do not skip stamping. If the arbiter says continue, you MUST stamp the
   next cycle. If it says stop, you MUST stamp the retrospective.
2. The judge description must be identical every iteration except the output
   path. Do not leak doer context into the judge.
3. The arbiter is always a bash script. Never replace it with an agent prompt.
4. All beads must be parented to the epic with `--parent {{EPIC_ID}}`.
5. Include the full program in every doer description. Do not abbreviate it.
   The doer has no prior context — the description is everything.
