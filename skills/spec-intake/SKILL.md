---
name: spec-intake
description: "Normalize all starting evidence into a subject spec run. Use this when beginning a Trace spec from code, docs, transcripts, screenshots, URLs, or a sparse user request. Creates the subject slug, frontmatter, evidence ledgers, request archetype, evidence-density classification, and canonical readiness skeleton."
allowed-tools: Read, Write, Glob, Grep, Bash, Agent
---

Use this skill first.

## Goal

Turn raw inputs into a normalized evidence run with:
- a subject slug
- a canonical spec path
- a root specs index path
- a request archetype
- an evidence-density classification
- a critical-decision coverage skeleton
- seeded frontmatter
- initial evidence records
- intake summary

## Steps

1. Derive the subject slug from the thing being studied or developed.
2. Ensure `specs/README.md` exists.
3. If `specs/README.md` is missing, create it with:
   - a short title
   - a one-line description of the specs tree
   - an optional notes section
   - a managed block delimited by:
     - `<!-- trace:spec-index:start -->`
     - `<!-- trace:spec-index:end -->`
4. If `specs/README.md` exists but the managed block is missing, add the
   managed block without deleting human prose outside it.
5. Create `specs/<subject>.md`.
6. Create `specs/_artifacts/<subject>/`.
7. Classify every input as:
   - `repo`
   - `doc`
   - `transcript`
   - `ui`
   - `user_statement`
   - `answer`
   - `observation`
8. For each input, create an `evidence_unit` record with:
   - `id`
   - `source_type`
   - `source_ref`
   - `directness`
   - `authority`
   - `freshness`
   - `independence_group`
   - `extraction_method`
9. Record `source_origin_keys` from evidence provenance, not raw file count.
10. Classify `request_archetype`:
   - `feature`
   - `analogy_feature`
   - `parity_clone`
   - `integration`
   - `bugfix`
   - `migration`
   - `refactor`
   - `reverse_spec`
11. Classify `starting_evidence_density`:
   - `sparse`
   - `mixed`
   - `dense`
12. Seed `critical_decision_coverage` with these buckets:
   - `core_outcome`
   - `scope_boundary`
   - `implementation_constraints`
   - `dependencies_and_integrations`
   - `acceptance_signal`
13. Seed the spec with:
   - `Overview`
   - `Intake Summary`
   - `Evidence Model`
14. Seed sidecars:
   - `manifest.json`
   - `run-state.json`
   - `branch-registry.json`
   - `input-log.md`
   - `evidence-ledger.jsonl`
   - `claim-ledger.jsonl`
15. If `UBIQUITOUS-LANGUAGE.md` does not exist at the project root, create it
    with an initial set of domain terms extracted from the evidence sources.
    If it already exists, read it and use existing terms for consistency.
    Append any new domain terms, entity names, or concepts discovered during
    intake.
16. Read `AGENTS.md` at the project root (if it exists). Note project
    conventions, patterns, and anti-patterns it encodes — these are prior
    implementation learnings that should inform the new spec rather than be
    rediscovered. Record relevant conventions as `observation` evidence units
    with `source_type: prior_learnings`.

## Output rules

- `Intake Summary` stays short.
- Detailed intake history stays in sidecars.
- A one-line feature request is still enough to start a run.
- If the source is large, spawn sub-agents to catalog source areas before the
  main loop starts.
- The root `specs/README.md` is navigational.
- The subject spec is the implementation handoff artifact.
- `sparse` analogy or feature runs should default to clarification if the
  critical decision buckets are not explicit in evidence.
