# Owner contribution report

`owner-contribution.md` evaluates task workload and execution quality by responsible owner for the current ZenTao execution review. It is an evidence-based contribution summary, not an HR performance appraisal. Avoid moral judgments and avoid ranking people without explaining scope, data limits, and confidence.

All owners in one run MUST be evaluated against the same measurement standard defined in `## 统一度量标准` below: the same dimensions, the same evidence sources, the same normalization basis, and the same banding rules. Never invent a per-owner metric. The output form is multi-dimension labels with cited evidence — do NOT compute a single composite contribution score, and do NOT rank people by a number.

## Inputs

Build this report from the merged outputs of the same run, so it covers ALL in-scope tasks, including reused conclusions:

- merged `rd-baseline.json` for factual task owner/type/status/rating/confidence/requirements/risks/PR refs;
- merged `review-baseline.json` for review scope, PR gate status, task type, review completeness, code-scope confidence;
- per-task code review reports and `_summary.md` for alignment/technical findings, blocking issues, reverse-mapping/orphan changes;
- for test tasks: bugs attributed to the task/owner via the ZenTao bug APIs (`zentao_list_bugs` / `zentao_get_bug`) for severity, status, validity, and reopen evidence; test-case counts when exposed by MCP, else marked `用例数未核验`; the linked story/dev task rd-audit baseline for 被测对象复杂度; and any automated-test code from git/PR evidence;
- latest ZenTao task raw fields for factual status, type, owner, deadline, and finished date only.

Self-reported effort fields (`estimate` / `consumed` / `left`) are NOT a measurement input and MUST NOT appear in this report. They are self-entered by the assignee, gameable, and not comparable across owners, so they cannot anchor the evaluation. Use them only as a silent internal cross-check: if self-reported consumed effort is grossly inconsistent with the objective code evidence, do not surface the hours — instead lower the affected workload confidence and note `工时与代码量不一致，存疑`. Workload is measured from objective code evidence and difficulty, never from person-hours.

## Attribution rules

- **Attribute development to the actual code author (git), not ZenTao `assignedTo` or the bare `owner` field.** `assignedTo` is the current handler and flips to the tester when a finished dev task moves to QA — so a done dev task often shows a tester as assignee, and the `owner` field may record a coordinator/QA rather than the coder. Confirm the developer from the feature/`task/<id>` branch's git authorship, cross-checked against the rd dev-owner. When git author and rd owner disagree, flag `归属待确认` instead of silently reassigning. A pure test owner who only received finished dev tasks for testing has no development workload — evaluate them on the test metric set only. See [[contribution-metrics]] §1.
- Evaluate the responsible owner recorded in the rd-audit baseline (`owner`) once authorship is confirmed. For `devel` tasks this is the development owner; for `test` tasks this is the testing owner. Unknown or empty owners go under `未指派/未知`.
- The report evaluates contribution within this execution plan. It does not infer individual capability beyond the reviewed evidence.
- Do not automatically blame task-description gaps on the assigned developer/tester. Use rd-audit responsibility evidence when available; otherwise mark the cause as `责任待定`.
- Attribute code-review findings, missing completed-task PR gaps, and task-scope implementation issues to the task owner only when the reviewed task/PR mapping supports it.
- Reused conclusions can be used for the current owner summary, but mark them as `复用 <date> 证据` in task details.

## 统一度量标准

The evaluation must be reproducible and comparable: same yardstick for everyone in the run. Apply these four rules without exception.

### 1. Two classes of input

- **Objective, verifiable evidence — the ONLY scoring basis.** Git diff stats after fetching latest remote state (`git diff --numstat`), PR count, repositories/modules touched, new APIs/DB migrations/config/tests, code-review outcomes (alignment, blocking findings, scope creep), and description-readiness ratings from rd-audit. Plus factual task metadata: type, status, deadline, finished date.
- **Self-reported / non-verifiable — excluded from scoring.** `estimate`/`consumed`/`left` and any self-claimed difficulty. Cross-check only (see Inputs); never displayed, never banded.

If an objective signal cannot be obtained (e.g. a repo was not checked out, diff stats unavailable), do not substitute a self-reported number — mark it `未核验` and lower that dimension's confidence.

### 2. Effective change, not raw churn

Compute **effective code volume**, not raw lines: discount or exclude generated/vendored files, formatting-only diffs, mass renames, and unrelated large changes. Raw lines changed is never contribution by itself. Flag suspected churn as `scope risk` rather than rewarding it.

### 3. Normalize against this iteration's distribution

Continuous objective quantities (effective code volume, difficulty signals) are banded **relative to the distribution of this execution plan's own tasks**, not against fixed absolute thresholds. Use quantiles of the in-scope task set:

- `高`: at or above ~P75 of the iteration; `中`: ~P25–P75; `低`: below ~P25. State the basis (e.g. "本迭代开发任务有效改动量中位数 ~X，该责任人合计落在 P80").
- Banding makes claims like `规模高` mean "high relative to this iteration", so they are comparable across owners and robust to overall iteration size.
- With too few comparable tasks to form a stable distribution (rule of thumb < 4 development tasks in scope), say so and fall back to absolute descriptive evidence at lower confidence instead of forcing quantiles.

### 4. Difficulty is judged from a fixed checklist, with cited hits

Difficulty is inherently a judgment; make it reproducible by anchoring every rating to the objective signals it hit (see the difficulty checklists below). For each difficulty rating, list which signals were hit — never a bare adjective. Calibrate horizontally: tasks in the same band within one run must show comparable hit profiles.

## Workload evaluation

For each owner, compute (all from objective evidence; band per `## 统一度量标准` rule 3):

| Metric | How to compute |
|---|---|
| `任务数` | count of tasks assigned to the owner |
| `完成数/进行中/未开始/已关闭` | status buckets from latest ZenTao status |
| `开发/测试任务数` | split by task `type` |
| `可审PR任务数` | tasks with reliable PRs or included code review scope |
| `已完成但缺PR数` | completed code tasks with `excluded_completed_missing_pr` |
| `开发代码量(有效/归一)` | for development tasks, aggregate effective PR/diff evidence: PR count, repos touched, files changed, effective additions/deletions, major modules, then band to 高/中/低 relative to this iteration; if diff stats are unavailable, write `代码量未核验` and use only PR/module breadth as low-confidence evidence |
| `开发难度(归一)` | for development tasks, derive technical and business difficulty separately from the fixed checklist below, then band relative to this iteration; cite the hit signals |
| `复杂度代理` | 高/中/低 derived from risk_points count, acceptance criteria count, task_type, effective PR/file scope, and review_focus breadth, normalized to this iteration |

Development workload guidance:

- Code volume signals: number of PRs, number of repositories, files changed, additions/deletions, new APIs/DB migrations/config entries/tests, and breadth of modules. Prefer platform PR stats or `git diff --stat/--numstat` after fetching latest remote state. Do not reward churn: generated files, formatting-only changes, mass renames, or unrelated large PRs should be discounted or marked as scope risk.
- Technical difficulty: concurrency/deadlock, transaction boundaries, idempotency, security/permissions, audit logging, data migration, scheduled jobs, integration with external systems, backward compatibility, frontend route/permission state, and testability.
- Business difficulty: payment/funds movement, KYC/risk control, settlement/reconciliation, channel routing, merchant-facing workflows, regulatory/compliance impact, and high blast-radius core flows.
- High: large or cross-repo code volume plus high technical/business difficulty, or a small but critical algorithm/transaction/security change.
- Medium: normal feature/bugfix with several acceptance criteria, moderate PR scope, or one notable technical/business risk.
- Low: config/text/minor UI/low-risk isolated change.
- If code volume is unavailable for a repo (for example frontend repo not checked out), keep the workload confidence lower and say exactly what could not be measured.

### Test-task workload (different dimensions from development)

Test tasks are NOT measured by code volume. Their output is defect discovery plus coverage assurance, so evaluate a different, type-specific dimension set — still under `## 统一度量标准` (objective evidence only, banded relative to this iteration's test tasks, self-report excluded). For each test owner compute:

| Metric | How to compute |
|---|---|
| `测试任务数 / 状态分布` | count and status buckets of `test`-type tasks for the owner |
| `用例规模` | number of test cases designed/executed for the task when obtainable (case count, scenario count); if the case API is unavailable via MCP, write `用例数未核验` and fall back to bug + scenario evidence at lower confidence — never substitute a self-reported number |
| `被测对象复杂度` | derive from the LINKED story/dev task's rd-audit baseline: requirement scope, risk points, acceptance-criteria count, module criticality (payment/funds/security/concurrency), cross-module/integration surface. The complexity of what is being tested, not of the test code |
| `测试难度` | environment/data setup difficulty, integration with external systems, concurrency/regression breadth, automation vs manual, reproduction difficulty, and number of re-test rounds after fixes |
| `缺陷发现成效` | bugs filed attributed to the task, weighted by severity and validity: confirmed/fixed bugs count, severity distribution, reopened/regression bugs caught; discount invalid/duplicate/rejected bugs (误报) — they lower, not raise, effectiveness |
| `自动化贡献` | automated test code authored, from git/PR evidence (new test files, frameworks, CI checks); objective and measurable when a test repo is checked out, else `自动化未核验` |
| `覆盖完整性` | share of the linked dev task's acceptance criteria covered by test scenarios; flag uncovered critical criteria |

Test workload guidance:

- Do not reward raw case count or raw bug count: many trivial split cases or many low-severity/invalid bugs are not contribution. Weight by被测对象复杂度, severity, and validity, and discount 误报 (rejected/duplicate) bugs and case-splitting churn.
- 被测对象复杂度 and 测试难度 are distinct: a simple object can still be hard to test (environment, data, concurrency, external integration), and a complex object may be straightforward to exercise. Band both separately, each relative to this iteration's test tasks, with cited signals.
- Defect-finding effectiveness is the test analogue of implementation quality: a high-severity, valid, early-caught defect is strong evidence; a high 误报率 is a quality concern, not a workload bonus.
- Bugs are fetchable via the ZenTao bug APIs (`zentao_list_bugs` / `zentao_get_bug`); test-case lists may not be exposed by MCP — when so, say `用例数未核验` and rely on bugs + linked-task complexity + automation evidence, at lower confidence.
- For test owners, the dev-only columns (`开发代码量` / `开发难度`) are marked `不适用`; report the test dimensions above instead.

## Quality evaluation

Separate description quality from implementation quality:

### Description/readiness quality

Use rd-audit evidence:

- rating distribution: `A/B/C/N/A`;
- baseline confidence distribution;
- counts of tasks ready for development/code review/test design when available from reports;
- recurring gaps and responsibility attribution when evidence supports it.

### Implementation/code-review quality (development tasks)

Use code-review evidence:

- included/reviewed task count;
- alignment conclusion distribution (`通过` / `有条件通过` / `不通过` / `无法判断`, or the closest wording in reports);
- blocking finding count and severity;
- missing completed-task PR gaps;
- scope problems: task-extraneous/orphan changes;
- technical findings from Spring/Vue reviewers when available; if a specialized reviewer was unavailable, cap confidence and say so.

### Test/defect-finding quality (test tasks)

For test owners, quality is defect-finding effectiveness and coverage, not code review. Use bug + coverage evidence:

- valid bug yield: confirmed/fixed bugs vs total filed, weighted by severity;
- 误报率: rejected/duplicate/invalid bug share — high values are a quality concern;
- regression catch: reopened bugs and defects caught after a fix re-test;
- coverage gaps: linked acceptance criteria with no test scenario, especially critical/high-risk ones;
- escaped defects when known (bugs found later that this task's scope should have caught), at the confidence the evidence supports.

If neither bug data nor case data can be verified for a test task, mark it `证据不足` rather than inferring effectiveness.

## Grading

Output is multi-dimension labels with cited evidence. Each dimension (`开发代码量` / `开发难度` / `描述质量` / `实现质量`) carries its own 高/中/低 or pass-rate band from `## 统一度量标准`. The `综合评价` column is a holistic label derived from those dimension labels under the same rules for everyone — NOT a weighted numeric score, and never used to rank people by a number.

| Grade | Meaning |
|---|---|
| `贡献突出` | workload and difficulty band high for this iteration with mostly good quality, no unresolved high-risk blocker |
| `稳定交付` | mid-band workload and acceptable quality, issues are low/medium risk or already bounded |
| `需关注` | notable quality gaps, missing PR for completed work, repeated unclear tasks, or incomplete evidence |
| `证据不足` | too little verified objective evidence to judge fairly |

Do NOT compute a single composite contribution score by default. If the user opts into numeric scoring (see [[contribution-metrics]]), produce the dual indices (WLI/QI) as primary, and any composite MUST be **multiplicative** — `C = WLI_index × clamp(QI_index/100, 0.5, 1.3)` — never an additive weighted sum. An additive `w1·WLI + w2·QI` lets a high quality rate substitute for low work amount (a 2%-workload task done cleanly would score near a huge load), which is invalid: workload is an amount, quality is a rate. Contribution = work delivered, scaled by quality. The composite is a sortable convenience only and is never a leaderboard or compensation input.

## Output file

Write this file in the dated execution-review run directory:

```text
reports/zentao-execution-review/<execution_slug>/<yyyymmdd>/owner-contribution.md
```

## Required structure

Use this section order:

1. 评价说明与边界 — explain objective evidence sources, the unified-standard rules, non-HR nature, that self-reported effort is excluded by design, and any unavailable code evidence.
2. 数据来源与可信度 — table: `数据源 | 状态 | 对评价影响`.
3. 归一化基准 — state the iteration-level baselines used for banding (e.g. median/quantiles of effective code volume across in-scope development tasks, task count), so every owner's 高/中/低 is interpretable.
4. 责任人贡献总览 — table:
   `责任人 | 角色/任务类型 | 任务数 | 完成/进行中/未开始 | 可审PR | 已完成缺PR | 开发代码量(归一) | 开发难度(归一) | 描述质量 | 实现质量 | 综合评价 | 可信度`.
   For test owners the dev columns (`开发代码量`/`开发难度`/`实现质量`) read `不适用`; carry their test dimensions (`用例规模`/`被测对象复杂度`/`测试难度`/`缺陷发现成效`) in the per-owner detail. If a run has many test owners, add a parallel 测试责任人贡献总览 table with columns `责任人 | 测试任务数 | 用例规模 | 被测对象复杂度 | 测试难度 | 缺陷发现成效 | 自动化贡献 | 覆盖完整性 | 综合评价 | 可信度`.
5. 责任人明细 — one subsection per owner:
   - 工作量与复杂度（开发任务拆成代码量与难度两个角度；测试任务改用用例规模/被测对象复杂度/测试难度/缺陷发现成效/自动化贡献/覆盖完整性；均标明在本迭代分布中的归一位置）
   - 质量表现（开发任务用描述/实现质量；测试任务用缺陷发现质量：有效缺陷产出、误报率、回归发现、覆盖缺口）
   - 主要贡献证据
   - 主要风险/待改进
   - 任务清单 table: `任务ID | 类型 | 状态 | 等级 | PR/代码审查状态 | 主要结论 | 证据来源(本次/复用日期)`
6. 横向风险与协作问题 — only evidence-based cross-owner issues, such as many completed tasks missing PR or repeated unclear acceptance criteria.
7. 一句话结论 — summarize contribution distribution and the highest-priority follow-up.

## Important wording

Use careful wording:

- Good (dev): `基于本次执行计划证据，张三承担 5 个开发任务；其中 2 个开发任务代码量中高（跨 2 个仓/多模块），且涉及资金一致性和权限审计，难度高；已审 PR 的实现质量整体稳定，但 1 个完成任务缺少可审 PR，需要补齐。`
- Good (test): `李四承担 3 个测试任务，被测对象含支付对账核心流程（被测对象复杂度本迭代偏高）；测试难度高（需构造多渠道对账数据+并发场景）。共提缺陷 12 个，其中高/严重 4 个、有效率 11/12（误报率低），并捕获 1 个回归缺陷；自动化未核验（测试仓未检出）。综合：稳定交付。`
- Bad: `张三能力差` / `李四绩效最好` / `用例提得最多` / unsupported ranking.
