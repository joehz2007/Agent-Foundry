# Review baseline schema

`review-baseline.json` is the code-review interpretation layer derived from rd-audit baseline. Do not write these fields back into rd-audit baseline.

## Top-level shape

```json
{
  "schema_version": "1.0",
  "execution": {
    "id": 36,
    "name": "v20260617",
    "rd_audit_baseline": "path/to/*-baseline.json",
    "rd_audit_date": "2026-06-05",
    "review_baseline_date": "2026-06-05",
    "review_baseline_version": "1"
  },
  "review_mode": "standard",
  "tasks": []
}
```

## Task fields

| Field | Meaning |
|---|---|
| `task_id`, `title`, `owner`, `status` | copied from rd-audit baseline |
| `review_scope_status` | `included`, `excluded_missing_pr`, `excluded_pr_unreliable`, `excluded_non_code` |
| `review_scope_note` | why included/excluded |
| `pr_refs` | copied from rd-audit `pr_refs`; required for included tasks |
| `task_type` | array such as `feature`, `bugfix`, `payment`, `deadlock`, `frontend`, `config`, `healthcheck` |
| `task_type_confidence` | `high`, `medium`, `low` |
| `task_type_reason` | evidence for type classification |
| `scope_modules` | modules/files inferred from PR diff and baseline hints |
| `expected_changes` | checklist of code changes that should exist |
| `anti_pattern_targets` | grep/static scan targets |
| `reachability_targets` | symbols/configuration paths that must be wired or callable |
| `reverse_mapping_inputs` | PR, branch, commit keywords used for reverse mapping |
| `review_completeness` | `A/B/C/N/A` for review-boundary clarity |
| `code_scope_confidence` | `high/medium/low` for available code evidence |
| `conclusion_thresholds` | hard gates that cap the final conclusion |
| `open_questions` | unresolved review-scope questions |
| `source_refs` | references to rd-audit baseline and checklist entries |

## PR handling

Use PR evidence in this order:

1. rd-audit baseline `pr_refs`.
2. PR links re-extracted from task body, task `raw.actions[].comment`, story body, story `raw.actions[].comment`, and attachment text if baseline is incomplete.
3. User-provided PR link/ID.

For full execution review, skip only tasks with missing/unreliable PR. For single-task review, missing/unreliable PR stops the review.

## Regeneration rules

Regenerate review-baseline when:

- rd-audit baseline path/date changed;
- user asks to refresh review-baseline;
- checklist references changed after the previous review-baseline;
- PR mapping changed.

Otherwise reuse the latest review-baseline to keep repeat reviews comparable.
