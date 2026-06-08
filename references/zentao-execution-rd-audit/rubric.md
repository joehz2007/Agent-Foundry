# RD audit rubric

## Dimensions

Rate each task on five dimensions:

| Dimension | Question |
|---|---|
| Requirement clarity | Is the intended change/problem clear? |
| Acceptance criteria | Is completion objectively checkable? |
| Implementation path | Are modules, APIs, tables, flows, or technical approach clear enough? |
| Impact and regression scope | Are affected users, systems, data, permissions, and regression points clear? |
| Collaboration readiness | Can development, testing, and code review use this as a shared baseline? |

## Rating scale

| Rating | Meaning |
|---|---|
| A | Directly usable for development, testing, and code review. |
| B | Usable for development, but testing/review still need a few key clarifications. |
| C | Useful for understanding the issue only; not enough as a reliable engineering baseline. |
| N/A | Not a standard engineering task, such as manual data handling or pure coordination. |

Avoid micro-grades unless the user explicitly wants them. If legacy reports used `A-`, `B+`, or `C-`, preserve them only for comparison; new reports should prefer `A/B/C/N/A`.

## Source weighting

Audit against the combined evidence set:

1. Task body.
2. All accessible comments/history.
3. Linked story/body.
4. Accessible attachments.

If a source is unavailable, mark it as unavailable rather than pretending it was reviewed.

## Readiness mapping

| Output field | Yes when... |
|---|---|
| 可开发 | A developer can implement without major extra clarification. |
| 可Review | A reviewer can verify implementation against concrete expectations and boundaries. |
| 可写测试 | A tester can write structured positive, negative, boundary, and regression cases. |

## Progress judgment

Treat as real progress only when new facts change the engineering baseline, such as:

- rating improves;
- acceptance criteria are added;
- implementation or impact scope becomes concrete;
- a gap is closed with evidence;
- a newly read attachment/comment adds task facts that affect conclusions.

Do not count clearer wording, owner-only updates, or reformatting as real progress.
