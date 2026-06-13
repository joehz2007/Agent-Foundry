# Execution review report structure

A full-execution run writes one dated directory plus the state file update:

```
reports/zentao-execution-review/<execution_slug>/
├── review-state.json                  # updated last, after reports succeed
└── <yyyymmdd>/
    ├── _summary.md                    # combined orchestration report
    ├── changes.md                     # detailed per-task change report
    ├── owner-contribution.md          # workload/quality/contribution report by responsible owner
    ├── rd-baseline.json               # merged fact baseline (rd-audit baseline schema)
    ├── review-baseline.json           # merged review baseline (code-review schema)
    └── task-<id>-<slug>.md            # one per task code-reviewed THIS run
```

Slug rules are identical to rd-audit report filenames. If two runs happen the same day, suffix the directory with
`-2`, `-3`, … and point `last_report_dir` at the latest.

Merged baselines use the unchanged schemas from `references/zentao-execution-rd-audit/baseline-schema.md` and
`references/zentao-execution-code-review/review-baseline-schema.md`. "Merged" means: re-audited/re-reviewed tasks get
fresh entries; reused tasks get their previous entries copied verbatim. Add nothing to those schemas; orchestration
metadata (change types, reuse markers) lives only in `_summary.md`, `changes.md`, and `review-state.json`.

## `_summary.md` sections

Use this order:

1. 审查概况 — | 项目 | 执行 | 审查日期 | 对比基准（上次审查日期/`首次审查`） | 任务总数 |
2. 数据来源与能力边界 — same table as rd-audit (add rows for PR head/target 解析 and 远端刷新（git fetch / PR 平台查询）
   是否成功, so the report shows whether code fingerprints reflect the latest remote state)
3. 变更与动作总览 — | 任务ID | 任务 | 状态 | 变更类型 | 描述审查动作 | 代码审查动作 | 结果 |
   - 变更类型: `首次审查 / 描述变更 / 代码变更 / 描述+代码变更 / 无变化 / 变化未知 / 已移除`
   - 描述审查动作: `重审 / 复用(yyyy-mm-dd) / 不适用`
   - 代码审查动作: `重审 / 复用(yyyy-mm-dd) / 跳过-无PR / 跳过-未到审查阶段 / 缺口-已完成无PR / 不适用`
4. 描述审查结果 — rd-audit 开发/测试任务审计表 format, over the merged baseline (mark reused rows with `*`)
5. 代码审查结果 — | 任务ID | 任务 | PR | 对齐结论 | 技术结论 | 阻塞项 | 报告文件 |
6. 排除与跳过 — every task not code-reviewed, with the status-aware reason
7. 仍需补充的关键信息 — top gaps merged from both layers
8. 一句话结论

## `changes.md` sections

1. 对比基准 — previous review date and report dir, or `首次审查，无对比`
2. 变更摘要 — counts per 变更类型
3. 任务级变更明细 — one subsection per task with `change_type != 无变化`, following the reporting requirements in
   `change-detection.md` (semantic body diff, new attachments, new comments quoted with action ID/date/author, PR/commit
   movement)
4. 已移除任务 — tasks dropped from the execution since last review

## `owner-contribution.md`

Generate this file for full-execution runs by default. Follow `references/owner-contribution.md`.

Purpose: evaluate workload, execution quality, and contribution by responsible owner for this execution plan. Use merged
rd/code-review evidence across all in-scope tasks, including reused conclusions marked by evidence date. Keep attribution
careful: this is an evidence-based contribution summary, not an HR performance appraisal.

## Per-task review files

`task-<id>-<slug>.md` follows `references/zentao-execution-code-review/report-structure.md` for its body, with one extra
leading section `本次变更` summarizing that task's entry from `changes.md`. Only tasks actually reviewed this run get a
file; reused tasks keep their file in the previous run directory — link to it from the 总览 table instead of copying.

## Single-task mode

Answer in the conversation by default: change report + description audit conclusion + code review conclusion (or the
skip reason). Update only that task's entry in `review-state.json`. Write files only when the user asks; then create the
dated directory with `_summary.md` scoped to that task plus its `task-<id>-<slug>.md`.

## Final reply

The final chat reply must contain:

- report directory, `_summary.md` path, and `owner-contribution.md` path (full runs)
- three separate count groups (a task can mix actions, e.g. 描述复用 + 代码重审, so never collapse them into one list):
  - 变更类型: 首次审查 / 描述变更 / 代码变更 / 描述+代码变更 / 无变化 / 变化未知 / 已移除
  - 描述审查动作: 重审 / 复用 / 不适用
  - 代码审查动作: 重审 / 复用 / 跳过 / 缺口 / 不适用
- the most important changes found this run (top 3)
- the most important review findings or gaps (top 3)
- the most important owner-contribution observations (top workload/quality highlights or risks)
- any evidence that could not be verified (actions, attachments, PR heads/targets, remote refresh/fetch, effort fields)
