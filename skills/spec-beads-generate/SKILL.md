---
name: spec-beads-generate
description: "Decompose an implementation plan into br beads with dependency wiring, epic grouping, and provenance labels. Use this after spec-plan-handoff when the user accepts the beads generation prompt."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

Use this only after `spec-plan-handoff` has emitted `implementation-plan.md`
and the user has accepted the beads generation prompt.

## Purpose

Decompose `implementation-plan.md` into a set of beads with full provenance
back to the spec. This skill is the advocate — it makes the best decomposition
it can and hands it to the adversarial team (`spec-beads-review`).

## Preconditions

- `planning_status = PLANNING_READY`
- `handoff_status = ELIGIBLE`
- `adversarial_status = converged`
- `implementation-plan.md` exists in `specs/_artifacts/<subject>/`
- user accepted the beads generation prompt

## Behavior

1. locate the git repository root via `git rev-parse --show-toplevel`
2. if `.beads` exists at the git root, use it — do not re-init
3. if `.beads` does not exist, run `br init` at the git root
4. create an epic for the spec subject:
   `br create --type epic --title "<subject>" --labels "forge:<subject-slug>"`
5. read each workstream from `implementation-plan.md` and create beads:
   - one bead per discrete work unit within a workstream
   - `br create --title "..." --type task --parent <epic-id> --labels "forge:<subject-slug>" --description "..."`
   - description includes: what to do, acceptance criteria, which spec claims
     this bead covers
6. wire dependencies from the implementation plan's dependency graph:
   `br dep add <bead-id> <depends-on-id>`
7. create epilogue beads — see "Epilogue beads" section below. Each epilogue
   bead depends on all implementation beads created in steps 5–6. The Agent
   Guidance Review bead additionally depends on the Learnings Retrospective
   bead.
8. emit `beads-manifest.json` to `specs/_artifacts/<subject>/`

## Provenance contract

Every spec claim and acceptance criterion must appear in at least one
**implementation** bead's description. The manifest tracks this mapping
explicitly so the review phase can verify coverage.

Epilogue beads are exempt from the provenance contract — they do not map to
spec claims or acceptance criteria. They exist for post-implementation
quality and learning, not spec coverage.

## `beads-manifest.json` schema

```json
{
  "subject": "<subject-slug>",
  "epic_id": "<br epic ID>",
  "workspace_path": "<git root>/.beads",
  "beads": [
    {
      "bead_id": "<br issue ID>",
      "title": "<bead title>",
      "workstream": "<workstream name from implementation plan>",
      "spec_claims": ["<claim IDs from claim-ledger.jsonl>"],
      "acceptance_criteria": ["<AC IDs from spec>"],
      "dependencies": ["<bead IDs this depends on>"],
      "test_first": "yes | no | n/a",
      "walking_skeleton": "true | false",
      "test_sketches": [
        {
          "type": "unit | property | integration | contract | e2e",
          "description": "<pseudocode test scenario>"
        }
      ]
    }
  ],
  "unmapped_claims": ["<claim IDs not yet traced to any bead>"],
  "unmapped_acceptance_criteria": ["<AC IDs not yet traced to any bead>"],
  "epilogue_beads": [
    {
      "bead_id": "<br issue ID>",
      "title": "Epilogue: <name>",
      "kind": "epilogue",
      "spec_claims": [],
      "acceptance_criteria": [],
      "dependencies": ["<all implementation bead IDs>"],
      "test_first": "n/a",
      "test_sketches": []
    }
  ],
  "followup_beads": [
    {
      "bead_id": "<br issue ID>",
      "title": "<fix description>",
      "kind": "epilogue-followup",
      "created_by": "<epilogue bead ID that created this>",
      "source_finding": "<finding description>",
      "dependencies": ["<bead whose code needs fixing>"],
      "test_first": "yes | no | n/a",
      "test_sketches": []
    }
  ]
}
```

`unmapped_claims` and `unmapped_acceptance_criteria` start populated after
generation and must be empty after `spec-beads-review` converges. The coverage
agent uses these arrays as its primary attack surface.

## Outputs

Emit as structured input to the orchestrator:
- `beads-manifest.json`
- structured beads fields for `manifest.json`:
  - `beads_generated = true`
  - `beads_epic_id`
  - `beads_total`
  - `beads_epilogue_count`
  - `beads_followup_count`
  - `beads_workspace_path`

## Implementation methodology

Bead descriptions should encode methodology guidance so the implementing agent
follows disciplined engineering practices.

### Red-green-refactor (TDD)

**Rationale** (Kent Beck, *Test-Driven Development: By Example*, 2002; Robert C. Martin):
TDD is about managing fear and building confidence, not just catching bugs. Beck: "Tests are the Programmer's Stone, transmuting fear into boredom." The three steps must be distinct because "our limited minds are not capable of pursuing two simultaneous goals" (Martin) — correct behavior and correct structure at the same time. Red = focus on WHAT (behavior specification). Green = focus on making it WORK (minimum code). Refactor = focus on STRUCTURE (with green tests as safety net). Beck warns that TDD provides design *feedback*, not design itself: "Your design will only be as good as your design decisions." The most commonly neglected step is refactor (Fowler): "without refactoring you just end up with a messy aggregation of code fragments."

Every bead with `test_first: yes` must follow the TDD cycle:
1. **Red** — write a failing test that captures the bead's acceptance criteria
2. **Green** — write the minimum code to make the test pass
3. **Refactor** — improve the code for clarity, remove duplication, apply
   deep module principles — while keeping the test green

Bead descriptions should make the red-green-refactor steps explicit. The
acceptance criteria should be phrased as observable, testable outcomes.

### Walking skeleton / tracer bullet

**Rationale** (Alistair Cockburn, *Crystal Clear*, 2004; Hunt & Thomas, *The Pragmatic Programmer*, 1999):
The **tracer bullet** metaphor (Hunt & Thomas) comes from military tracer rounds — phosphorus rounds that leave a visible trail, letting soldiers adjust aim in real-time under actual conditions. The software equivalent: produce something early that users can see, rather than specifying everything upfront and hoping it hits the target. Key insight: software has a "Heisenberg effect, where delivering the software changes the user's perception of the requirements." Requirements are inherently a moving target. Tracer code is production-quality — it is kept and built upon, unlike prototypes which are thrown away. The **walking skeleton** (Cockburn) is "a tiny implementation of the system that performs a small end-to-end function." Teams typically defer integration and deployment until late in a project — exactly when it is most expensive to discover problems. The walking skeleton frontloads this risk, flushing out boundary-level issues (external systems, infrastructure, deployment) at the beginning when they are cheapest to fix. "The bigger the system, the more important it is to use this strategy."

The first beads in the dependency chain should build a thin end-to-end path
through the system before filling in depth. Get something working across all
layers first, then iterate on each layer. The implementation plan's workstream
ordering should reflect this.

When the implementation plan has a clear walking skeleton path, annotate the
first-pass beads with `walking_skeleton: true` in the manifest so the
execution engine prioritizes them.

### Deep modules

**Rationale** (John Ousterhout, *A Philosophy of Software Design*, 2018):
The cost of a module is its interface (what you must learn to use it). The benefit is its functionality (what it hides). Deep modules maximize benefit relative to cost. Ousterhout's visual: modules should be like icebergs — small visible tips (interfaces) with large submerged bases (implementations). "It's more important for a module to have a simple interface than a simple implementation." His canonical example: Unix file I/O — five functions (`open`, `read`, `write`, `lseek`, `close`) hiding tens of thousands of lines dealing with disk formats, permissions, caching, and concurrency. The interface has remained stable for decades while the implementation has been rewritten multiple times. The "classitis" warning: over-decomposing into many small, shallow classes increases system complexity because each boundary adds interface cost. If the functionality behind an interface is trivial, the system pays more in interface complexity than it gains in hidden implementation.

Favor modules with simple interfaces and deep functionality. Hide complexity
behind clean abstractions rather than spreading it across many shallow modules
with wide interfaces. When a bead creates a new module, its acceptance criteria
should specify:
- the public interface boundary (what callers see)
- what complexity it encapsulates (what callers don't see)
- why the abstraction boundary is where it is

### Ubiquitous language

**Rationale** (Eric Evans, *Domain-Driven Design*, 2003):
The problem: "On a project without a common language, developers have to translate for domain experts. Translation muddles model concepts, which leads to destructive refactoring of code." Translation is not just inconvenient — it actively corrupts the model. The solution: one language everywhere — in code (class names, method names), in conversation, and in documentation. The language is rooted in the domain model and co-evolves with it. Evans' feedback loop: "Domain experts should object to terms or structures that are awkward or inadequate to convey domain understanding; developers should watch for ambiguity or inconsistency that will trip up design." When a term feels wrong, that signals a problem in the model.

Bead titles and descriptions must use terms from the project's
`UBIQUITOUS-LANGUAGE.md` glossary (at the project root). If the glossary does
not yet exist, the intake phase creates it. Consistent domain terminology
across all beads prevents ambiguity during implementation.

## Quality gates and cross-cutting concerns

Do not create standalone beads for cross-cutting concerns like quality gates,
CI configuration, env var documentation, or linting setup. These are not
discrete work units — they apply across the entire epic.

Instead:
- embed quality gate criteria in the epic description
- distribute cross-cutting acceptance criteria across the beads they apply to
  (e.g., "all public functions have typespecs" goes on every bead that creates
  public functions)
- if a spec claim is purely cross-cutting (e.g., "all endpoints require auth"),
  map it to every bead whose work it constrains rather than creating a
  catch-all bead

The review phase's granularity agent will flag any bead that is just a
collection of unrelated cross-cutting checks.

## Epilogue beads

Every epic gets three epilogue beads created after all implementation beads.
These are meta-beads for post-implementation quality and continuous improvement.
They do not map to spec claims.

Create each with:
`br create --title "Epilogue: <name>" --type task --parent <epic-id> --labels "forge:<subject-slug>,epilogue" --description "..."`

Wire each epilogue bead as depending on ALL implementation beads:
`br dep add <epilogue-id> <impl-bead-id>` for every implementation bead.

### Epilogue: Learnings Retrospective

Scan `.ralph-tui/progress.md` (the cross-iteration learning log agents append
to after each bead), git history for the epic's commits, and the original spec.
Synthesize scattered per-bead learnings into a structured retrospective:

- what worked well and should be repeated
- what caused friction or wasted effort
- patterns discovered during implementation
- recommendations for future work in this area

After synthesizing learnings, create follow-up beads in the same epic for any
process improvements that require code or config changes. Use the follow-up
bead creation contract below.

Acceptance criteria: learnings document exists with categorized findings; every
bead's progress.md entry has been reviewed; findings are actionable, not just
observations; follow-up beads created for all actionable items.

Dependencies: all implementation beads.

### Epilogue: Agent Guidance Review

Audit existing agent rules for conflicts and gaps, then actively create or
update project-specific guidance. Depends on the Learnings Retrospective bead
(consumes its output to inform guidance updates).

Inputs to audit:
- project AGENTS.md
- `.ralph-tui/progress.md` Codebase Patterns section
- any project-scoped skills in `.claude/skills/`
- SKILL.md files referenced during implementation

Actions:
- update AGENTS.md with new project conventions discovered during implementation
- create or update project-scoped skills in `.claude/skills/` that auto-load
  for future agent runs
- update `.ralph-tui/progress.md` Codebase Patterns section with reusable
  patterns
- flag and resolve any conflicting rules across AGENTS.md, SKILL.md files,
  and progress.md
- audit and update `UBIQUITOUS-LANGUAGE.md` at the project root with any new
  domain terms discovered during implementation; ensure AGENTS.md references
  the glossary so agents use consistent terminology across all work

After auditing and updating guidance, create follow-up beads in the same epic
for any guidance changes that require code changes. Use the follow-up bead
creation contract below.

Acceptance criteria: all rule sources audited for conflicts; at least one
guidance artifact updated with implementation learnings; no contradictory
rules remain across guidance sources; UBIQUITOUS-LANGUAGE.md updated with new
terms; follow-up beads created for all actionable items.

Dependencies: all implementation beads + Epilogue: Learnings Retrospective.

### Epilogue: Full Code Review

Spawn a full agent team (via `TeamCreate`) to comprehensively review all code
changed during the epic. Agent roles:

- **Bug hunter** — logic errors, edge cases, race conditions, security issues
- **Coverage verifier** — cross-reference code changes against bead acceptance
  criteria to find missed implementations
- **Simplifier** — unnecessary complexity, dead code, redundant abstractions,
  simplification opportunities
- **Convention checker** — verify code follows project conventions from
  AGENTS.md, linting rules, and existing patterns

Uses a convergence model: multiple rounds until all agents report zero material
findings, max 3 rounds. Findings categorized by severity (critical, high,
resolvable). Critical findings block epic closure.

After each convergence round, create follow-up beads in the same epic for
every material finding. Use the follow-up bead creation contract below.
Each finding becomes a bead with:
- title describing the fix
- description with finding details and remediation steps
- dependency on the bead whose code introduced the issue

Acceptance criteria: every file changed during the epic has been reviewed; all
findings categorized by severity; critical findings have remediation steps;
follow-up beads created for all material findings.

Dependencies: all implementation beads.

### Follow-up bead creation contract

Every follow-up bead created by an epilogue MUST be parented to the epic and
use this exact command template:

```
br create --title "<fix description>" --type task --parent <epic-id> --labels "forge:<subject-slug>,epilogue-followup" --description "<finding details and remediation steps>"
```

Hard requirements:
- `--parent <epic-id>` is mandatory — omitting it creates an orphan invisible
  to `br ready` in the epic context
- `--labels` must include both `forge:<subject-slug>` and `epilogue-followup`
- each follow-up bead must declare a dependency on the bead whose code it
  addresses: `br dep add <followup-id> <source-bead-id>`
- update `beads-manifest.json` `followup_beads` array with the new bead

## Epilogue cycle

After all follow-up beads from an epilogue round are implemented, a new
epilogue cycle begins:

1. Create a new Full Code Review epilogue bead covering **only the code
   changed by follow-up beads** from the previous cycle
2. If that review produces material findings, create follow-up beads (using
   the contract above) and implement them
3. Repeat until a Full Code Review round produces **zero material findings**
4. **Max 3 epilogue cycles** (safety cap) — if cycle 3 still produces
   findings, escalate to the user

Cycle scoping rules:
- The **Learnings Retrospective** and **Agent Guidance Review** run only on
  the first cycle — subsequent cycles are Full Code Review only
- Each subsequent Full Code Review is scoped to code changed since the
  previous cycle, not the entire epic
- Follow-up beads in subsequent cycles still use the same creation contract
  (parented, labeled, dependency-wired)

## Bead sizing

A bead must be completable in a single focused agent session. Use these
heuristics to decide when to split:

- If a bead title contains "and" or commas listing distinct concerns, it needs
  splitting. "Config, GraphQL HTTP client, Clerk auth" is three beads, not one.
- Each bead should have a single responsibility — one module, one integration
  point, or one data structure.
- Workstreams with 3+ distinct deliverables should produce 3+ beads minimum.
- When in doubt, prefer smaller beads — the review phase can merge but cannot
  split.

## Hard rules

1. This skill does not evaluate quality. That is the review phase's job.
2. Every spec claim must map to at least one bead. If a claim cannot be
   decomposed into a discrete work unit, flag it and include it anyway — the
   review phase will address granularity.
3. Use `br` CLI commands for all bead operations. Do not write to the `.beads`
   directory directly.
4. Do not re-init an existing `.beads` workspace.
5. Epic and label provenance are required for every bead.
6. Do not create standalone beads for cross-cutting concerns — see
   "Quality gates and cross-cutting concerns" above.
7. When generation is complete, report results in a single status line and
   return control to the orchestrator. Do NOT ask the user whether to proceed —
   the orchestrator's auto-transition rule governs the next step. Do NOT offer
   a "stopping point" — beads review is mandatory and follows automatically.
