# ZenTao MCP capability contract

Before auditing, probe what the current ZenTao MCP can actually return. The current `zentaomcp` implementation exposes task/story comments and history through detail raw payloads, not through separate comment tools.

## Required probes

For the target execution, attempt to identify support for:

| Capability | Evidence to check | Baseline field |
|---|---|---|
| Task body | `get_task` / task raw payload contains description | `task_body_status` |
| Task comments/history | `zentao_get_task(taskId).data.raw.actions[]`; comments are usually in `actions[].comment` | `comment_status` |
| Story body | `get_story` / story raw payload contains description | `story_status` |
| Story comments/history | `zentao_get_story(storyId).data.raw.actions[]`; comments are usually in `actions[].comment` | `story_comment_status` |
| Task attachments | `list_task_attachments` and optional download | `attachment_status` |
| Story attachments | `list_story_attachments` and optional download | `attachment_status` |

## Status values

Use these exact values in baseline JSON:

- `read`: fully read and incorporated.
- `partial`: metadata or partial content available, but not all content verified.
- `unavailable`: MCP/tooling cannot access this source.
- `none`: source was checked and does not exist.

## Reporting rule

If comments/history or attachments are unavailable, say so explicitly in:

1. Main audit conclusion.
2. Per-task gaps or source notes.
3. Baseline JSON `open_questions` or source status fields.

Never write "all comments read" or "attachments reviewed" unless the tool output proves it.

## Action/comment extraction

Use this sequence for each task:

1. Call `zentao_get_task(taskId)`.
2. Read `data.raw.actions[]` from the result.
3. Treat every action as history evidence; treat non-empty `actions[].comment` as comment/remark evidence.
4. Extract PR links from all `actions[].comment`, not only the latest comment.
5. If a linked story exists, call `zentao_get_story(storyId)` and repeat the same extraction from `data.raw.actions[]`.

Recognize PR references in comments:

- GitHub: `/pull/<id>`
- GitLab: `/merge_requests/<id>`
- CodeUp: `/change/<id>`
- shorthand: `repo#123`

Only set `comment_status = unavailable` if `data.raw.actions` is absent or inaccessible, not merely because no standalone `list_comments` tool exists.
