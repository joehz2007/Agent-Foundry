# Execution review state schema

`review-state.json` is the fingerprint memory of the orchestrated execution review. It records, per task, what the
description and code evidence looked like at the end of the last review, so the next run can detect changes precisely
and reuse conclusions for unchanged tasks. It is owned exclusively by `zentao-execution-review`; rd-audit and
code-review must never read or write it.

## Location

```
reports/zentao-execution-review/<execution_slug>/review-state.json
```

`<execution_slug>` follows the same slug rules as rd-audit report filenames (execution name slugified; fall back to
`execution-<execution_id>` when the name is missing or ambiguous). One state file per execution; dated run directories
live next to it.

## Top-level shape

```json
{
  "schema_version": "1.2",
  "execution": {
    "id": 36,
    "name": "v20260617",
    "project_id": 15,
    "project_name": "B2B项目"
  },
  "last_review_date": "2026-06-12",
  "last_report_dir": "reports/zentao-execution-review/v20260617/20260612",
  "tasks": {}
}
```

`tasks` is an object keyed by task ID (string). Each entry:

| Field | Type | Notes |
|---|---|---|
| `title` | string | Task title at last review — fingerprint source, not just display metadata |
| `status` | string | ZenTao task status at last review — fingerprint source; status drives the status-aware PR gate |
| `type` | string | Task type (`devel`, `test`, …) at last review — fingerprint source |
| `owner` | string/null | Current owner at last review — fingerprint source (optional but recommended) |
| `desc_hash` | string | `sha256:<first16hex>` of the task description fingerprint (see change-detection.md) |
| `story_id` | number/string/null | Linked story ID, `null` if none |
| `story_desc_hash` | string/null | Same hash rule over the story description; `null` if no story or unreadable |
| `task_attachments` | array | `{id, title, size}` for every task attachment (metadata only) |
| `story_attachments` | array | Same shape for story attachments |
| `task_action_count` | number | Length of `task.raw.actions[]` at last review |
| `task_last_action_id` | number/null | Highest action ID seen; `null` if actions unavailable |
| `task_actions_hash` | string/null | `sha256:<first16hex>` over the full task actions sequence (see change-detection.md); catches edited/deleted comments |
| `story_action_count` | number/null | Same for story actions |
| `story_last_action_id` | number/null | Same for story actions |
| `story_actions_hash` | string/null | Same hash rule over story actions |
| `attachment_text_hashes` | object | Map of attachment ID → `sha256:<first16hex>` of parsed text content, for text-like attachments actually read |
| `pr_refs` | array | Deduplicated, sorted PR links / `repo#id` references at last review |
| `pr_heads` | object | Map of PR ref → head commit SHA (or merge commit SHA for merged PRs) when resolvable; resolve only after fetching the latest remote state |
| `pr_targets` | object | Map of PR ref → target (base) branch name when resolvable; a retargeted PR changes its effective diff even with an unchanged head |
| `pr_fingerprint_status` | string | `verified` (all heads resolved), `partial`, `unverified` (none resolved), `none` (no PRs) |
| `rd_rating` | string | `A/B/C/N/A` from the merged rd baseline |
| `rd_baseline_confidence` | string | `high/medium/low` |
| `review_scope_status` | string | Value from review-baseline schema (`included`, `excluded_*`) |
| `review_conclusion` | string/null | Short final code-review conclusion for included tasks; `null` if never reviewed |
| `reviewed_at` | string | Date this task entry was last refreshed (audit or review actually ran) |
| `reused_since` | string/null | Date of the run whose conclusion is being reused; `null` when freshly reviewed |
| `fingerprint_notes` | array | Anomalies, e.g. `actions unavailable this run`, `PR head unresolvable` |

## Schema versions and migration

- `1.0`: initial schema, without `task_actions_hash`, `story_actions_hash`, `pr_targets`.
- `1.1`: adds those three fields.
- `1.2`: current schema, promotes `title`/`status` to fingerprint sources and adds `type`/`owner` (任务元数据).

When reading an older state file (or any entry missing newer fields), do NOT treat the missing fingerprints as
unchanged and do not silently backfill them: for each task, the sources covered by the missing fields (评论/历史 for
the actions hashes, PR 代码 for `pr_targets`, 任务元数据 for `type`/`owner`) are `unknown` for this run, which per
change-detection.md conservatively re-runs the affected layer. After the run, write the entry back in full `1.2` shape
and set `schema_version = "1.2"`. `title`/`status` exist in every version, so 任务元数据 comparison can always use them
even when `type`/`owner` are missing.

## Update rules

1. Write the state file only after the run's reports were generated successfully. Never update fingerprints first —
   a crashed run must not mark tasks as already reviewed.
2. Update every task entry that was processed this run, including reused ones (`reused_since` keeps the original date,
   `reviewed_at` keeps the date the conclusion was actually produced).
3. Tasks that disappeared from the execution are removed from `tasks` after being reported once under `已移除任务`.
4. Single-task runs update only that task's entry; all other entries stay untouched.
5. If a fingerprint source was unavailable this run (for example `raw.actions` could not be read), keep the previous
   value, add a `fingerprint_notes` entry, and treat the source as `changed = unknown` per change-detection.md rather
   than silently overwriting with an empty fingerprint.
6. If the state file is missing or unparseable, treat the run as a first review: every task is `首次审查`, and a fresh
   state file is written at the end. Never partially merge into a corrupt file; back it up as
   `review-state.json.bak-<yyyymmdd>` first.
