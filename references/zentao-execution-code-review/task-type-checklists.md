# Task type checklists

Use these checklists to derive `expected_changes`, `anti_pattern_targets`, and `reachability_targets`. Apply all matching types; tasks often combine multiple types.

## Modes

| Mode | Use when | Coverage |
|---|---|---|
| quick | user asks for quick scan or time is limited | PR mapping, changed files, blocking/high risks only |
| standard | default | expected changes, key anti-patterns, core tests |
| deep | user asks for deep/full review | full checklist, external docs/version checks, broader reverse mapping |

## Common checks for all included tasks

- Map every reviewed code change to a ZenTao task and PR.
- Identify task-extraneous changes inside each PR.
- Check tests or explain missing test evidence.
- Check logging, error handling, validation, and compatibility when relevant.

## Type: payment / money movement

Triggers: payment, refund, payout, wire, account balance, quota rollback, clearing, settlement, bank channel.

Expected checks:

- Idempotency key is stable and persisted.
- Transaction boundary covers all local state changes that must commit/rollback together.
- External-channel success/failure/timeout semantics are explicit.
- Amount uses precise type and correct unit/currency.
- Audit log or business record is written for money-affecting operations.
- Retry behavior does not double-pay or double-refund.

Anti-patterns:

| Pattern | Severity | Meaning |
|---|---|---|
| `double|float` around amount fields | 高 | imprecise money representation |
| `catch\s*\([^)]*Exception[^)]*\)\s*\{\s*\}` | 高 | swallowed payment exception |
| `@Transactional` missing on service method with multi-table writes | 高 | consistency risk |

Hard gate: missing idempotency or transaction handling for money movement is `不通过`.

## Type: deadlock / concurrency

Triggers: deadlock, lock wait, 并发, 重试, transaction rollback, duplicate update.

Expected checks:

- Lock acquisition order is consistent.
- Retry is bounded and only retries safe operations.
- Transaction scope is minimized.
- SQL/update order avoids cross-table lock inversion.
- Failure after partial success is recoverable.

Anti-patterns:

| Pattern | Severity | Meaning |
|---|---|---|
| `Thread\.sleep` inside transaction path | 高 | blocks locks/resources |
| broad retry around non-idempotent operation | 阻塞 | may duplicate side effects |

## Type: quota / limit / risk control

Triggers: quota, limit, 敏感人, 风控, 额度, threshold.

Expected checks:

- Scope dimension is explicit: merchant/user/channel/currency/date.
- Boundary values are tested.
- Concurrent updates are safe.
- Override/admin changes are audited.
- Queries include tenant/merchant isolation.

## Type: frontend form / permission

Triggers: 前端, 表单, 商户端, 业管, 销售单元, UI permission.

Expected checks:

- Form validation matches backend constraints.
- Permission/role visibility is not frontend-only.
- API errors are surfaced to the user.
- State refresh after save is correct.
- Existing flows are not regressed.

## Type: data export

Triggers: export, 导出, xlsx, csv, report.

Expected checks:

- Authorization and tenant/merchant filters are applied.
- Large exports are paged/streamed or bounded.
- Sensitive columns are masked or excluded.
- Timezone/number formatting is deterministic.
- Async export status and error handling are clear when used.

## Type: healthcheck / observability

Triggers: actuator, health, metrics, 指标, monitoring.

Expected checks:

- Endpoint exposure is safe per environment.
- Health detail does not leak secrets.
- Liveness/readiness semantics are correct.
- All intended components are registered.
- Monitoring names/tags are stable.

## Type: config cleanup

Triggers: 配置整理, yml, yaml, properties, config cleanup.

Expected checks:

- Removed keys are not referenced by code or deployment scripts.
- Environment files remain structurally aligned.
- Secrets are not introduced.
- Defaults remain compatible.
- Profile-specific values are intentionally different.

## Type: security / auth

Triggers: auth, token, permission, 越权, 鉴权, 敏感信息.

Expected checks:

- Controller and SQL/repository both enforce identity scope when needed.
- No broad anonymous route is introduced.
- Sensitive fields are not logged or returned.
- Token/session refresh paths are protected.

Anti-patterns:

| Pattern | Severity | Meaning |
|---|---|---|
| `permitAll\(\).*\*\*` | 高 | broad anonymous access |
| `return\s+.*(secret|token|apiKey)` | 阻塞 | credential leakage |
| `where\s+id\s*=` without tenant/merchant dimension in sensitive query | 高 | possible IDOR |

## Type: dependency / migration

Triggers: dependency, upgrade, 依赖, 升级, migration, Spring Boot, Java, Vue.

Expected checks:

- Version exists or build evidence proves it.
- Dependency tree converges.
- Removed APIs are gone.
- Configuration/property migrations are covered.
- Compatibility tests or smoke tests are present.

External evidence:

- Prefer fetch/context7 MCP for official docs and Maven metadata.
- If external tools are unavailable, mark external evidence unverified and cap conclusion at `有条件通过` unless code/build evidence is strong.

## Type: generic feature / bugfix

Use when no specific type fits.

Expected checks:

- Each requirement maps to code evidence.
- Each acceptance criterion maps to code or tests.
- Bugfix addresses root cause, not only symptoms.
- Same-pattern regression scan was considered.
- New behavior is compatible with existing callers.
