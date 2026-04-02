---
name: spec-synthesis-review
description: "Reduce typed sub-agent outputs into canon and verify the subject spec before readiness promotion. Use this when you need deterministic merges, provenance review, contradiction handling, verification loops, section drafting, or final review passes across the spec."
allowed-tools: Read, Write, Edit, Glob, Grep
---

Use this after a scoring pass or when draft sections need promotion into canon.

## Reducer rules

- The lead agent is the only reducer.
- Apply sub-agent results only when `parent_revision` matches canon.
- If the result is stale, rebase, revalidate, or discard.

Merge order:
1. evidence / claims
2. contradictions
3. ontology rescore
4. section patch
5. readiness gate

## Required review passes

1. completeness review
2. contradiction review
3. provenance review
4. implementability review
5. terminology review

## Verification loop

Before readiness promotion, run:
- completeness check against requested deliverables
- grounding check from canonical text to claim ids
- empty-result recovery for suspiciously thin evidence
- section/schema format check
- missing-context gate
- action-safety gate for mutation or publication steps
- stable-id check for questions, assumptions, decisions, and major claims
- evidence-ref check for every major canon claim
- terminology check against `UBIQUITOUS-LANGUAGE.md` at the project root
- blocker-state check against the orchestrator readiness contract

If any check fails, return to:
- evidence gathering
- targeted questions
- contradiction review
- or redrafting

## Root specs index update

After the subject spec reaches a stable draft, create or update the row for the
current subject inside the managed block in `specs/README.md`.

Managed block markers:
- `<!-- forge:spec-index:start -->`
- `<!-- forge:spec-index:end -->`

Preserve prose outside the managed block.

The row should include:
- `Spec`
- `Target`
- `Purpose`
- `Planning Status`
- `Handoff`
- `Keywords`
- `Artifacts`

Rules:
- `Target` should point at the implementation directory or code path when it
  can be inferred, otherwise use `—`
- `Purpose` should be one short implementation-oriented sentence
- update an existing row for the subject instead of appending duplicates
- the root index is navigational; the subject spec remains the canonical
  implementation artifact

## Output

Update:
- `specs/<subject>.md`
- `specs/README.md`
- `review-report.md`
- `claim-ledger.jsonl`
- `contradiction-log.md`
- `decision-log.md`
- `branch-registry.json`
