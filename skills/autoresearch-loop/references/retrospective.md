# Retrospective Bead Template

Stamped by the strategist when the arbiter signals termination. Runs once
at the end of the loop. Produces cross-run learning artifacts.

---

## Bead description (rendered into br create --description)

You are the retrospective agent for autoresearch loop `{{EPIC_ID}}`
(subject: {{SUBJECT}}).

The loop has terminated. Reason: read `.autoresearch/terminal-signal.json`.

### Your job

Analyze the full run and produce learning artifacts that help future loops
start smarter.

### Step 1: Read the run

- `.autoresearch/research-log.jsonl` — full iteration ledger
- `.autoresearch/config.json` — loop configuration
- `.autoresearch/terminal-signal.json` — why the loop stopped
- The final artifact at `{{ARTIFACT_PATH}}`

### Step 2: Analyze patterns

Answer these questions:

1. **What worked?** Which hypotheses improved the score? What patterns
   do they share? (e.g., "adding concrete examples consistently improved
   scores by 5-10 points")
2. **What failed?** Which hypotheses were reverted? What patterns do they
   share? (e.g., "expanding implementation details was consistently
   reverted — the judge penalizes over-specification")
3. **Plateaus**: Were there plateau periods? What broke through them?
   What didn't?
4. **Phase transitions**: Did the strategist's phase routing work well?
   Did evidence-gathering iterations actually score below 50? Did
   refinement iterations actually land above 75?
5. **Judge quality**: Did the judge's findings seem actionable? Were
   there scores that felt inconsistent? Suggest rubric improvements.
6. **Efficiency**: How many iterations were wasted (reverted)? What could
   the strategist have done differently?

### Step 3: Write artifacts

#### retrospective.md

Write to `.autoresearch/retrospective.md`:

```markdown
# Autoresearch Retrospective: {{SUBJECT}}

## Summary
- Iterations: <total>
- Kept: <count> | Reverted: <count>
- Score trajectory: <start> → <final>
- Terminal reason: <goal_reached | plateau | iteration_cap>

## What worked
<patterns that improved scores>

## What failed
<patterns that were reverted>

## Plateau analysis
<if applicable>

## Strategist effectiveness
<phase routing quality, directive quality>

## Recommendations for future runs
<specific, actionable suggestions>
```

#### rubric-suggestions.md

If you identified judge quality issues, write to
`.autoresearch/rubric-suggestions.md`:

```markdown
# Rubric Improvement Suggestions

## Current rubric gaps
<what the rubric missed or over-weighted>

## Suggested additions
<specific rubric criteria to add>

## Suggested removals or reweighting
<criteria that caused inconsistent scoring>
```

### Step 4: Update project artifacts

If `AGENTS.md` exists at the project root:
- Read it for existing conventions
- Add any new conventions discovered during this loop
- Do not remove existing content

If `UBIQUITOUS-LANGUAGE.md` exists at the project root:
- Add any new domain terms that emerged during the loop
- Do not remove existing content

### Step 5: Prepare Trace re-entry

If `specs/_artifacts/{{SUBJECT}}/run-state.json` exists, update it:
- Set `planning_status` to `READINESS_GATE`
- Set `loop_strategy` to `"autoresearch"`
- Set `question_rounds_completed` to iteration count from ledger
- Add `"autoresearch-loop"` to `source_origin_keys`
- Set `autoresearch_final_score` to final score from ledger
- Set `autoresearch_epic_id` to the epic ID
- Set `autoresearch_terminal_reason` from terminal-signal.json

This allows trace-orchestrator to detect the completed loop and resume
from READINESS_GATE.

### Rules

- Be specific and evidence-based. Cite iteration numbers.
- Do not editorialize about the quality of the final artifact.
- Focus on process insights, not content quality.
- These artifacts exist to help future loops — write for that audience.
