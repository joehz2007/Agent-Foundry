# Code review report structure

Default output directory:

```text
reports/zentao-code-review/
└── zentao-execution-<execution_id>-<execution_name>-code-review-<yyyymmdd-hhmmss>/
    ├── _summary.md
    ├── task-<task_id>-<slug>.md
    └── review-baseline.json
```

Single-task mode:

```text
reports/zentao-code-review/
└── zentao-task-<task_id>-code-review-<yyyymmdd-hhmmss>/
    ├── _summary.md
    └── review-baseline.json
```

## `_summary.md` sections

1. 审查对象
2. 代码范围
3. 使用的任务基线
4. 比较条件与限制
5. 任务到代码映射
6. 任务结论总览
7. 委托技术审计结果汇总
8. 排除任务
9. 反向映射核对
10. 未映射改动（非代码改动）
11. 反模式扫描结果
12. 阻塞问题总览
13. 一句话结论

## Task report sections

1. 任务信息
2. 审查时间
3. 任务描述与验收要点
4. 任务类型与 review-baseline 派生
5. 代码范围与映射依据
6. 代码逻辑与任务一致性
7. 应当变化清单核对
8. 反模式扫描结果（本任务范围）
9. 语义可达性核对
10. 错误、缺漏、多余实现检查
11. 性能与代码质量问题
12. 技术架构、调用路径与算法合理性
13. 相对上次审查的变化
14. 结论与建议

## Required summary tables

### 使用的任务基线

| 基线类型 | 文件 | 执行 | 日期 | 可信度 | 备注 |

Rows required:

- rd-audit baseline（事实层，只读）
- review-baseline（解释层，本次派生或复用）

### 比较条件与限制

| 条件 | 状态 | 对结论的影响 |

List skipped tasks, missing PR, unavailable comments/attachments, incomplete repository checkout, unavailable tests, and external docs that could not be fetched.

### 任务到代码映射

| 任务ID | 任务标题 | 基线评级 | PR / 分支 / 提交 | 关联代码 | 映射证据 |

Task ID should link to the task report when a report exists.

### 任务结论总览

| 任务ID | 任务标题 | 结论 | 实现一致性 | 主要代码问题 | 架构/路径/算法结论 | 来源 |

### 委托技术审计结果汇总

| 技术栈 | 委托 skill | 范围 | 技术结论 | 高风险发现 | 影响任务 |

Use rows for `code-review-spring-boot` and/or `code-review-vue` when delegated reviews were run. If no technical delegation was needed, write `无`.

### 排除任务

| 任务ID | 任务 | 状态 | 排除原因 |

Development/code tasks excluded due to missing/unreliable PR must explicitly say `缺少PR` or `PR关联不清`.

### 反向映射核对

Always include three sub-tables:

#### 任务超范围改动

| 任务ID | 文件 | 改动摘要 | 与任务关联度 | 严重级 | 建议 |

#### 孤儿改动

| 文件 | 改动摘要 | 提交/PR | 严重级 | 建议 |

#### 无业务风险

| 文件 | 改动类型 | 处理建议 |

## Empty tables

Do not omit required sections. If empty, write a single `无` row.
