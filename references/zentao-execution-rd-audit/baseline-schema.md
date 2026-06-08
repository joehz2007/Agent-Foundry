# RD audit baseline JSON schema

The baseline is the fact layer consumed by code-review. It must contain confirmed task facts only, not review-time interpretation.

## Top-level shape

```json
{
  "schema_version": "1.0",
  "execution": {
    "id": 36,
    "name": "v20260617",
    "audit_date": "2026-06-05",
    "source": "zentao-mcp",
    "project_id": 15,
    "project_name": "B2B项目"
  },
  "capabilities": {
    "task_body_status": "read",
    "task_action_status": "read",
    "comment_status": "read",
    "story_status": "read",
    "story_action_status": "read",
    "story_comment_status": "read",
    "task_attachment_status": "partial",
    "story_attachment_status": "read"
  },
  "tasks": []
}
```

## Task fields

| Field | Type | Notes |
|---|---|---|
| `task_id` | number/string | ZenTao task ID |
| `title` | string | Task title |
| `type` | string | `devel`, `test`, or original type |
| `status` | string | ZenTao task status |
| `owner` | string | Current owner interpreted by task type |
| `product` | string | Product or product ID/name when available |
| `rating` | string | `A`, `B`, `C`, `N/A` |
| `baseline_confidence` | string | `high`, `medium`, `low` |
| `task_body_status` | string | `read`, `partial`, `unavailable`, `none` |
| `task_action_status` | string | whether `zentao_get_task(...).data.raw.actions[]` was available |
| `comment_status` | string | comment evidence from task `raw.actions[].comment`; same status values |
| `comment_refs` | array | action IDs/timestamps/sources actually read |
| `story_status` | string | same status values |
| `story_action_status` | string | whether `zentao_get_story(...).data.raw.actions[]` was available |
| `story_comment_status` | string | comment evidence from story `raw.actions[].comment`; same status values |
| `attachment_status` | string | `yes`, `no`, `unverified`, `partial` |
| `attachment_refs` | array | all deduplicated attachment IDs/names/links |
| `pr_status` | string | `yes`, `no`, `invalid` |
| `pr_refs` | array | all deduplicated PR links or `repo#id` references |
| `requirements` | array | confirmed requirement facts |
| `acceptance_criteria` | array | verifiable completion criteria |
| `implementation_hints` | array | modules, APIs, tables, paths, flows |
| `risk_points` | array | regression, data, security, performance, transaction risks |
| `review_focus` | array | future code-review checklist |
| `open_questions` | array | unresolved questions and unavailable evidence |
| `source_refs` | array | fact source pointers |

## Confidence rules

Set `baseline_confidence = low` when:

- task body is weak and task/story `raw.actions` are unavailable or contain no useful comments/history;
- relevant attachments exist but are not downloaded/read;
- PR exists but link is invalid or not task-scoped;
- requirements or acceptance criteria are inferred rather than explicit.

Never place code-review interpretations such as `task_type`, `expected_changes`, or `anti_pattern_targets` in this baseline. Those belong to review-baseline JSON.
