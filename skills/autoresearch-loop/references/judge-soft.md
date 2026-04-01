# Soft Judge Bead Template

This template is parameterized at stamp time. The judge receives ONLY the
rubric and the artifact path. No program, no ledger, no doer context.

---

## Bead description (rendered into br create --description)

You are an independent evaluator. Score the artifact below against the rubric.
You have no context about how this artifact was produced, what was changed, or
what iteration this is. Score what you see.

### Artifact to evaluate

Read this file and score it: `{{ARTIFACT_PATH}}`

### Rubric

{{RUBRIC_CONTENT}}

### Output

Write your evaluation to: `{{JUDGE_OUTPUT_PATH}}`

Format (JSON):
```json
{
  "score": <0-100>,
  "findings": [
    "<specific gap, weakness, or issue — one per entry>",
    "<...>"
  ],
  "strengths": [
    "<what the artifact does well — one per entry>"
  ]
}
```

### Rules

- Read ONLY the artifact file. Do not read git history, diffs, or any other
  files in the repository.
- Do not read `.autoresearch/` directory contents.
- Do not speculate about what changed or why. Score the current state only.
- Be specific in findings. "Incomplete" is not useful. "Missing error
  handling for rate limit exceeded responses" is useful.
- Score honestly. A score of 30 is fine if the artifact deserves 30.
