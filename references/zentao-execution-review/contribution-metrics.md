# Contribution metrics (numeric indices)

This spec turns the qualitative owner-contribution evaluation into reproducible, iteration-over-iteration **numeric indices**, so contribution trend can be tracked and used as a KPI *foundation*. It builds on `owner-contribution.md` (same evidence, same unified standard, same KPI guardrails) and adds: indexed metrics, reference baselines, a defensible composite, and persistence for trend.

Numeric scoring is OPT-IN and is produced as `contribution-metrics.{md,json}` alongside `owner-contribution.md`. The dual indices (WLI/QI) are the primary output; the composite is a secondary, clearly-flagged convenience.

## 1. Attribution: use the code author, NOT ZenTao assignedTo

This is the single most important data rule and a common source of error.

- **Development work is attributed to the actual code author (git), never to ZenTao `assignedTo` or the task `owner` field alone.** ZenTao `assignedTo` is the *current handler*: when a dev task is finished and moved to QA, `assignedTo` flips to the tester, so a finished dev task will show a tester as its current assignee. The task `owner` field can likewise record a coordinator/QA rather than the coder.
- Determine the author from git: the feature/`task/<id>` branch's non-merge commit authors and the merge author, cross-checked against the rd dev-owner. Map by branch name (`task/276`, `feature/<x>_<sprint>`) to the task.
- When the git author disagrees with the rd `owner` (e.g. branch `task/274` authored by someone other than the recorded owner), DO NOT silently reassign — flag it `归属待确认 (git作者=X / rd-owner=Y)` and let a human resolve. Author-in-range can also be contaminated by cross-branch merges, so treat a lone discrepancy as a question, not a verdict.
- A pure test owner who only received finished dev tasks for testing has **no development WLI**; evaluate them only on the test metric set. Do not create a dev row for them.

## 2. Reference objects → everything becomes an index (baseline = 100)

Raw values are not comparable across people or iterations. Convert each metric to `I = raw / baseline × 100`. Maintain both axes:

- **团队迭代基准**: median of the SAME-ROLE in-scope tasks/owners this iteration. Primary for cross-person comparison and the published index.
- **个人滚动基准**: the owner's own mean over the last K iterations. Primary for trend ("how did this person change"). On the first iteration there is no history — seed it and leave the trend column empty.
- Show both. Index 120 = 20% above the median contributor; ΔI vs the personal baseline = the trend signal.

Small-sample caveat: with fewer than ~4-5 owners in a role, the median is volatile — adding/removing one owner shifts everyone's index. Say so, and prefer trend over a single snapshot.

## 3. Dev indices

- Effective code volume `ECV = additions + 0.5 × deletions`, computed from **real git first-parent diff** (`M^1..M`, the net change a PR merged into the mainline). Discount generated/vendored/formatting/rename/churn; a config-cleanup task that is deletion-heavy and low-complexity is down-weighted.
- Difficulty coefficient `0.8–1.5` per task from the fixed checklist (concurrency/transaction/funds/permission/cross-repo …).
- `WLI_dev_raw = Σ_task (ECV_task × difficulty_task)`, then index to the dev-team median.
- `QI_dev_raw (0–100) = 100 × review_pass_rate − blocking_penalty − completion_integrity_penalty` (pass=1 / conditional=0.5 / fail·unknown=0). Defect-injection density may be added when defect data carries resolution + assignee + date (see §6). Index QI to the dev-team median too.

## 4. Test indices

- `WLI_test_raw = (用例量 or 严重度加权有效缺陷发现) × 被测对象复杂度 × 测试难度`. Object complexity comes from the linked dev task's rd baseline. Case count is often `未核验` (no MCP case API) → fall back to bug + complexity evidence at lower confidence.
- `QI_test_raw = DDP(有效缺陷率) − 误报率 − 逃逸惩罚 + 覆盖完整性`. The needed fields ARE available from ZenTao: `zentao_list_bugs` returns them in `data.raw.bugs` (the thin `items` projection omits them, but `raw.bugs` — and `zentao_get_bug` — include `resolution`, `execution`, `openedDate`, `activatedCount`, `duplicateBug`, `resolvedBy/Date`). Scope to the iteration by `execution == <id>` (fall back to an `openedDate` window for bugs with `execution==0`). Then: DDP = valid(`fixed`/`tostory`/`postponed`) / resolved; 误报率 = (`bydesign`/`duplicate`/`notrepro`/`willnotfix`/`external` or `duplicateBug>0`) / total; regression = `activatedCount>0` count. Only mark `证据不足` when the bugs genuinely have no resolution yet (still active) or none link to the iteration. Note small-sample (often <10 bugs/tester/iteration) → lower confidence.
- Index to the test-team median. Never reward raw case/bug count; weight by severity and validity. Beware scoping: project-wide bug totals span many iterations and must NOT be used as one iteration's defect-finding.

## 5. Composite — multiplicative, NOT additive

The composite must NOT be a weighted sum `w1·WLI + w2·QI`. An additive mean lets a high quality *rate* substitute for a low work *amount*: someone who did 2% of the workload but did it cleanly would score near someone who carried a huge load. Workload is an extensive quantity; quality is an intensive rate — you cannot average them.

Contribution = **amount of work delivered, scaled by how good it was**:

```
QF = clamp(QI_index / 100, 0.5, 1.3)      # quality factor: median quality = 1.0
C  = WLI_index × QF
```

- A tiny-but-clean task stays small (low WLI × ~1.0 ≈ small). A large-but-blocked deliverable is discounted (high WLI × 0.5) but not zeroed, because the code is delivered and fixable.
- `clamp` floor/ceiling are tunable. If blocking-quality issues should be punished harder, lower the floor or use the geometric mean `C = sqrt(WLI_index × QI_index)`, which penalizes imbalance on either axis more strongly.
- The composite is a sortable convenience only. Always publish WLI and QI separately; never reduce a person to C alone.

## 6. Confidence gating & persistence

- Every index carries a data-completeness confidence. `provisional / 未核验 / 证据不足` indices MUST NOT enter formal KPI; they are reference only.
- Persist per-iteration results to `contribution-metrics.json` and append to a cumulative `metrics-history.json` keyed by owner × iteration, so WLI/QI/C trends can be charted. Stamp dates from inputs (the runtime has no clock).

## 7. KPI guardrails (DORA / SPACE / DX Core 4)

1. Team/system level for formal KPI; **individual indices are for trend and 1:1 coaching only — never a leaderboard, never tied directly to compensation** (Goodhart's law: a metric that becomes an individual target stops measuring reality).
2. Quality and workload never collapse into one substitutable number — the multiplicative composite enforces this.
3. Multiple metrics, human-in-the-loop interpretation. Low-confidence numbers excluded.
4. Trend over snapshots: a single iteration's index reflects task allocation as much as effort — require ≥3 iterations before reading trend.
