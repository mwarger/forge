# Spec Quality Rubric

Use this rubric for soft-judge evaluation of specification documents.

Score each dimension 0-20. Total score is the sum (0-100).

## 1. Completeness (0-20)

Does the spec cover all aspects of the subject?

- 0-5: Major sections missing. Feels like a sketch, not a spec.
- 6-10: Core functionality covered but significant gaps in edge cases,
  error handling, or operational concerns.
- 11-15: Most areas covered. A few gaps remain but the shape is clear.
- 16-20: Comprehensive. Hard to find missing areas. Edge cases, failure
  modes, and operational concerns are all addressed.

## 2. Specificity (0-20)

Are requirements concrete enough to implement without guessing?

- 0-5: Vague language throughout. "Should handle errors appropriately."
- 6-10: Mix of specific and vague. Core behavior is clear but many
  secondary behaviors are left ambiguous.
- 11-15: Most behaviors are specific. A few areas could be more precise.
- 16-20: An implementer could build this without asking questions.
  Acceptance criteria are testable.

## 3. Consistency (0-20)

Are there contradictions, conflicting requirements, or terminology
inconsistencies?

- 0-5: Multiple contradictions. Terms used inconsistently.
- 6-10: A few contradictions or ambiguities. Some terms unclear.
- 11-15: Mostly consistent. Minor terminology drift.
- 16-20: No contradictions found. Terms used consistently throughout.

## 4. Provenance (0-20)

Are claims backed by evidence? Can you trace each requirement to a source?

- 0-5: No evidence citations. Requirements appear invented.
- 6-10: Some claims cite evidence. Many are unsupported assertions.
- 11-15: Most claims are grounded. A few assumptions are uncited.
- 16-20: Every significant claim cites its source. Assumptions are
  explicitly labeled as such.

## 5. Actionability (0-20)

Could an implementation team pick this up and start building?

- 0-5: Reads as a wishlist, not a spec. No acceptance criteria.
- 6-10: Some acceptance criteria. Missing dependency information,
  sequencing, or integration points.
- 11-15: Clear acceptance criteria for most features. Dependencies
  identified. A few gaps in sequencing.
- 16-20: Ready to decompose into work items. Acceptance criteria are
  testable. Dependencies and sequencing are clear.

## Scoring output

```json
{
  "score": <sum of all dimensions>,
  "dimensions": {
    "completeness": <0-20>,
    "specificity": <0-20>,
    "consistency": <0-20>,
    "provenance": <0-20>,
    "actionability": <0-20>
  },
  "findings": [
    "<specific gap or issue — one per entry>"
  ],
  "strengths": [
    "<what the spec does well — one per entry>"
  ]
}
```
