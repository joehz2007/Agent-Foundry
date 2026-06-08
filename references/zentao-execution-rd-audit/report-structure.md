# RD audit report structure

Full audit outputs four files by default:

1. Main audit report: `zentao-execution-plan-audit-<execution>-<yyyymmdd>.md`
2. Changelog: `zentao-execution-plan-audit-<execution>-<yyyymmdd>-changelog.md`
3. Five-line summary: `zentao-execution-plan-audit-<execution>-<yyyymmdd>-summary.md`
4. Baseline JSON: `zentao-execution-plan-audit-<execution>-<yyyymmdd>-baseline.json`

## Main report sections

Use this order:

1. 执行概况
2. 数据来源与能力边界
3. 任务状态汇总
4. 审计结论
5. 任务完备性审计表
6. 责任归属表
7. 可直接作为基线的任务
8. 仍需补充的关键信息
9. 一句话结论

## Required tables

### 执行概况

| 项目 | 项目ID | 执行 | 执行ID | 周期 | 状态 | 进度 |

### 数据来源与能力边界

| 数据源 | 状态 | 说明 |

Include task body, task `raw.actions` comments/history, story body, story `raw.actions` comments/history, task attachments, story attachments, PR extraction.

### 任务状态汇总

| 状态 | 数量 |

### 审计结论

| 问题 | 结论 |

Must cover development readiness, testing readiness, review readiness, attachments/comments status, PR availability, and overall judgment.

### 开发任务审计表

| 任务ID | 产品 | 任务 | 开发负责人 | 等级 | 是否有附件 | 是否有PR | 可开发 | 可Review | 可写测试 | 简评 |

### 测试任务审计表

| 任务ID | 产品 | 任务 | 测试负责人 | 等级 | 是否有附件 | 是否有PR | 可开发 | 可Review | 可写测试 | 简评 |

Rules:

- Split development and test tasks.
- Use `任务类型 + 当前负责人` for mixed/other task lists.
- Sort each audit table by rating `A > B > C > N/A`, then task ID ascending.
- Use fixed values: `是否有附件 = 是 / 否 / 有但未核验 / 有（N个）`; `是否有PR = 是 / 否 / 链接无效 / 评论未核验 / 是（N个）`.
- Only use `评论未核验` when task/story `raw.actions` cannot be read. If `raw.actions` is read and no PR appears in task/story bodies, action comments, or attachments, use `否`.
- Keep `简评` short and evidence-based.

### 责任归属表

| 任务ID | 产品负责人 | 开发负责人 | 测试负责人 | 当前缺口 | 应补责任方 |

### 可直接作为基线的任务

| 用途 | 任务ID |

Include `开发基线`, `代码Review基线`, `测试设计基线`.

### 仍需补充的关键信息

| 任务ID | 主要缺口 |

## Changelog sections

Use this order:

1. 对比文件
2. 本次变更摘要
3. 数据对比
4. 任务级变化
5. 本次评级变化
6. 历史关键修正（可选）
7. 进展判断
8. 一句话说明

`本次评级变化` only records actual rating changes versus the immediately previous audit. If none, write one row: `无 | 无 | 无 | 相对上一版未出现评级变化`.

## Summary file

Five lines only:

1. Execution and audit date.
2. Overall readiness judgment.
3. Counts by rating.
4. Most important gaps.
5. Next action.
