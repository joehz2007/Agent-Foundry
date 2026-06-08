# Code review rubric

## Conclusions

| Conclusion | Meaning |
|---|---|
| 通过 | Task baseline is implemented, key risks are covered, no blocking scan/mapping issues. |
| 有条件通过 | Core behavior is implemented, but there are non-blocking gaps, missing tests, or limited evidence. |
| 不通过 | Required behavior, acceptance point, risk control, migration, or mapping is missing/wrong. |
| 无法判断 | Baseline, PR/diff, repository, or critical code evidence is insufficient. |

## Severity

| Severity | Meaning |
|---|---|
| 阻塞 | Cannot accept the task as implemented. |
| 高 | Likely production, data, security, or major task-alignment risk. |
| 中 | Real bug/risk with bounded impact. |
| 低 | Maintainability, clarity, or minor test improvement. |

## Hard gates

Conclusion upper bound is `不通过` if any applies:

1. Blocking anti-pattern hit in task scope.
2. `expected_changes` contains `应改未改` for an in-scope required change.
3. Reachability target is not wired/callable and is required for behavior.
4. Orphan business-code change exists outside any reviewed task/PR.
5. Security/payment/data-consistency task lacks required authorization, idempotency, transaction, or audit behavior.
6. Migration/dependency task has unverified or nonexistent target version and no build evidence.

Conclusion upper bound is `有条件通过` if:

- relevant tests were not run/provided;
- repository checkout is partial;
- attachments/comments in rd-audit baseline were unavailable;
- checklist coverage was intentionally limited by quick mode.

Do not write “looks fine” as a conclusion. Tie every conclusion to task requirements, code evidence, scan results, and hard-gate status.
