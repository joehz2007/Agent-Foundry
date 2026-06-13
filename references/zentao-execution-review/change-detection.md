# Change detection rules

This document defines how `zentao-execution-review` computes fingerprints, classifies per-task changes, decides what to
re-run, and reports the changes. The goal: every conclusion in the final report is based on the latest description and
the latest code, and every difference from the previous review is stated explicitly.

## Fingerprint computation

Compute fingerprints from the freshly fetched ZenTao data of this run, before any audit or review starts.

- **Task metadata** (任务元数据): `status`, `type`, `title`, and `owner` from the latest fetch. Status matters even when
  nothing else changed, because the code-review PR gate is status-aware.
- **Description hash** (`desc_hash`, `story_desc_hash`): sha256 over the exact raw description string (HTML included),
  with only leading/trailing whitespace trimmed. Record as `sha256:` + first 16 hex chars. Do not normalize HTML —
  a false-positive re-review is acceptable; a missed change is not.
- **Attachments**: the sorted list of `{id, title, size}` for task and story attachments. For text-like attachments
  that are parsed (per rd-audit attachment rules), additionally hash the parsed text into `attachment_text_hashes`.
- **Comments/history**: `action_count` and `last_action_id` from `raw.actions[]` of both task and story, plus an
  **actions hash** (`task_actions_hash` / `story_actions_hash`): sha256 over the concatenation of every action's
  `id|date|actor|action|comment`, sorted by action ID ascending (for actions without an ID, sort by date, then actor,
  then action) — never by response array order, so unstable MCP ordering cannot cause false positives. Count and
  last-ID catch additions/deletions; the hash also catches in-place edits of existing comments.
- **PR set**: deduplicated, sorted `pr_refs` collected from task body, task action comments, story body, story action
  comments, and parsed attachment text (same sources as rd-audit).
- **PR heads and targets**: first refresh remote state — `git fetch` the relevant remotes or query the PR platform —
  so nothing is fingerprinted from a stale local clone. Then, for each PR ref, resolve the current head commit SHA
  (merged PRs: the merge/last commit) and the target (base) branch. Use the available repo tooling (`gh`,
  `git ls-remote`, repo platform API). Record what could not be resolved.

A practical way to hash inside the agent shell:

```bash
printf '%s' "$RAW_DESC" | shasum -a 256 | cut -c1-16
```

## Per-source change tests

Compare against the task's entry in `review-state.json`:

| Source | Changed when |
|---|---|
| 任务元数据 | `status`, `type`, `title`, or `owner` differs |
| 任务正文 | `desc_hash` differs |
| 需求正文 | `story_desc_hash` differs, or story link added/removed |
| 附件 | attachment list differs (added/removed/renamed/size change), or any `attachment_text_hashes` entry differs |
| 评论/历史 | `task_action_count`/`task_last_action_id`/`task_actions_hash` differ, or story counterparts differ |
| PR 集合 | `pr_refs` differ (added/removed/replaced) |
| PR 代码 | any `pr_heads` SHA differs, or any `pr_targets` branch differs (a retargeted PR has a new effective diff) |

Unknown handling: if a source cannot be read this run but had a previous fingerprint, or has no previous fingerprint
because it was unreadable last time, its change status is `unknown`, not `unchanged`.

## Task change classification

Each task gets exactly one `change_type`:

| `change_type` | Condition |
|---|---|
| `首次审查` | no state file, or task absent from state `tasks` while present in execution |
| `描述变更` | any of 任务元数据/正文/需求/附件/评论 changed; PR 集合与 PR 代码均未变 |
| `代码变更` | PR 集合或 PR 代码变化; description-side sources (含任务元数据) all unchanged |
| `描述+代码变更` | both of the above |
| `无变化` | every source unchanged and none `unknown` |
| `变化未知` | no source confirmed changed, but at least one source is `unknown` |
| `已移除` | present in state `tasks` but no longer in the execution |

Note: a PR ref newly appearing in a comment changes both 评论 and PR 集合; classify as `描述+代码变更`.

Metadata-only changes are folded into `描述变更` to keep the enum small, but they carry a hard rule: a status
transition must re-run the status-aware PR gate of `zentao-execution-code-review`, and a previous skip conclusion must
NEVER be reused across it. The canonical trap: a task was `doing` without PR last time (skipped as
`进行中，暂无PR属正常`) and is now `done` still without PR — the correct conclusion this run is `已完成但缺少可审PR`,
not the reused skip. Likewise a `type` change (e.g. `devel` ↔ `test`) re-decides code-review inclusion.

## Re-run decision matrix

| `change_type` | Description audit (rd-audit) | Code review (code-review) |
|---|---|---|
| `首次审查` | run | run if PR evidence per status-aware rules |
| `描述变更` | run | **run** — a changed description means the baseline (requirements/acceptance criteria) may have changed, so re-review the code against the new baseline even if no commit changed |
| `代码变更` | reuse previous rating and baseline entry | run |
| `描述+代码变更` | run | run |
| `无变化` | reuse | reuse |
| `变化未知` | run (conservative) | run if PR evidence exists (conservative) |
| `已移除` | report only; drop from state | none |

Additional rules:

- "Run code review" is always still gated by the status-aware PR rules of `zentao-execution-code-review`: tasks
  without reliable PR evidence are skipped (`进行中，暂无PR属正常`) or flagged (`已完成但缺少可审PR`), never reviewed
  against arbitrary diffs.
- Reuse means: copy the task's entry verbatim from the previous run's `rd-baseline.json` / `review-baseline.json`,
  loaded from the state file's `last_report_dir`, and mark it in the report as `复用 <reviewed_at> 结论`. Those files
  are the only legal reuse source — never re-derive a reused conclusion from memory or from the summary fields kept in
  `review-state.json`. If a previous baseline file is missing or unreadable, reuse is forbidden for the entries it
  would have provided: downgrade those tasks to re-audit/re-review and note the missing file in the report.
- If the user explicitly asks for a full re-review (全量重审), treat every task as `描述+代码变更` and ignore reuse.
- QA/test/verification tasks follow rd-audit for the description side and are excluded from code review as usual.

## Change reporting requirements

For every task whose `change_type` is not `无变化`, the change report (`changes.md` and the per-task section) must state
**what** changed, not merely that something changed:

- 正文/需求正文: summarize the semantic difference (added/removed/modified requirements, acceptance criteria, scope),
  comparing the new text against the previous review's merged baseline facts. Quote key added sentences. Do not paste
  full HTML diffs.
- 附件: list added/removed/renamed attachments by title; for re-parsed text attachments, summarize content changes.
- 评论: list every new action since `last_action_id` with action ID, date, author, and the comment content (quoted or
  tightly summarized). New comments are often where PR links and revised acceptance criteria appear — extract those
  explicitly.
- 评论被编辑: when the actions hash changed but count/last-ID did not (or the hash change is not explained by new
  actions alone), identify which action(s) were modified and report old vs new content. The previous raw text is
  usually not retrievable from ZenTao, so reconstruct the "old" side from the previous run's merged baseline facts
  (requirements/acceptance criteria/comment-derived evidence) and state explicitly when only the new text is available.
- 任务元数据: report old → new values (e.g. `status: doing → done`), and state the gate consequence when relevant
  (e.g. 由跳过转为缺口).
- PR: list added/removed PR refs; for changed heads, list new commits (`old_sha..new_sha`) with messages when the repo
  is accessible, otherwise state the SHA movement. For a target/base branch change, report `old_target → new_target`
  and note that the effective diff may have changed even though the head SHA did not.
- `变化未知`: state which source could not be verified and why the task was conservatively re-reviewed.

First review of a task has no change section; mark it `首次审查，无对比基准`.
