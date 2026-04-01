# Hard Judge Bead Template

For metrics computed by running a command (test suites, linters, benchmarks).
The bead runs the command and writes structured output. No LLM evaluation.

---

## Bead description (rendered into br create --description)

Run the following command and write the result as structured JSON.

### Command

```bash
{{METRIC_COMMAND}}
```

### Output

Write the result to: `{{JUDGE_OUTPUT_PATH}}`

Format (JSON):
```json
{
  "score": <numeric result from command>,
  "findings": [
    "<any failing tests, lint errors, or benchmark regressions — one per entry>"
  ],
  "raw_output": "<first 2000 chars of command stdout+stderr>"
}
```

### Instructions

1. Run the command above.
2. Parse the output to extract the numeric score.
3. Collect any failures, errors, or regressions as findings.
4. Write the JSON output file.
5. Do not modify any source files. Do not fix anything. Only observe and report.

### Score extraction

{{SCORE_EXTRACTION_HINT}}

Examples:
- Test pass rate: `(passed / total) * 100`
- Lint errors: `max(0, 100 - error_count)`
- Benchmark: use the raw metric value
