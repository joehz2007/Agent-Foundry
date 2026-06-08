# Vue review report structure

Use Markdown. Keep findings concrete and tied to files/components/routes.

## Sections

1. 审查对象
2. 技术结论
3. 阻塞/高风险问题
4. 中低风险问题
5. 测试与回归建议
6. 建议补丁/修复方向
7. 可供上层编排消费的 JSON 摘要

## 审查对象

| 项目 | 值 |
|---|---|
| 仓库/模块 |  |
| PR / diff / 文件范围 |  |
| 审查时间 |  |
| 任务/需求上下文 |  |

## 技术结论

| 维度 | 结论 | 说明 |
|---|---|---|
| 组件设计 | 通过/有条件/不通过/无法判断 |  |
| API/状态流 | 通过/有条件/不通过/无法判断 |  |
| 表单/校验 | 通过/有条件/不通过/无法判断 |  |
| 权限/安全 | 通过/有条件/不通过/无法判断 |  |
| UX/回归 | 通过/有条件/不通过/无法判断 |  |
| 测试 | 通过/有条件/不通过/无法判断 |  |
| 总体结论 | 通过/有条件通过/不通过/无法判断 |  |

## Findings table

| 严重级别 | 文件 | 行号/证据 | 问题 | 影响 | 建议 |
|---|---|---|---|---|---|

## JSON summary

When another orchestrator skill needs to consume the result, include or save a JSON-compatible summary with this shape:

```json
{
  "audit_type": "code-review-vue",
  "scope": [],
  "technical_conclusion": "有条件通过",
  "findings": [
    {
      "severity": "中",
      "file": "...",
      "line": "...",
      "issue": "...",
      "evidence": "...",
      "suggestion": "...",
      "related_task_ids": []
    }
  ],
  "test_evidence": [],
  "limitations": []
}
```
