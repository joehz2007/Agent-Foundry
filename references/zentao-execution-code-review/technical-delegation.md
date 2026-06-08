# Technical review delegation

`zentao-execution-code-review` is the orchestrator for ZenTao task alignment. It should not duplicate deep backend/frontend technical audit logic. Delegate technical implementation review to specialized code-review skills and consume their findings.

## Responsibilities

| Area | Owner |
|---|---|
| ZenTao task facts, baseline, PR extraction | `zentao-execution-rd-audit` |
| Task ↔ PR ↔ changed-file mapping | `zentao-execution-code-review` |
| Business/acceptance consistency | `zentao-execution-code-review` |
| Task-extraneous or orphan changes | `zentao-execution-code-review` |
| Spring Boot technical implementation | `code-review-spring-boot` |
| Vue frontend technical implementation | `code-review-vue` |

## Delegation rules

For each included PR or changed-file group:

1. Classify files by technology.
2. Delegate technical review:
   - Java/Kotlin, Spring Boot, MyBatis/JPA, YAML/backend config → `code-review-spring-boot`.
   - Vue, TypeScript, Vite/Webpack, Element Plus/UI files → `code-review-vue`.
3. If both backend and frontend are touched, run both technical reviews and keep findings separate.
4. Map each technical finding back to affected task IDs and acceptance criteria when possible.
5. Final ZenTao conclusion remains with `zentao-execution-code-review`.

## File classification hints

| File pattern | Delegate |
|---|---|
| `src/main/**/*.java`, `src/test/**/*.java`, `*.kt` | `code-review-spring-boot` |
| `*Mapper.xml`, `db/migration/*`, `application*.yml`, `bootstrap*.yml` | `code-review-spring-boot` |
| `*.vue`, `*.ts`, `*.tsx`, `src/api/**`, `src/router/**`, `src/store/**` | `code-review-vue` |
| `package.json`, `vite.config.*`, `webpack.config.*`, `tsconfig*.json` | `code-review-vue` unless backend build integration is the issue |

## Final report integration

In `_summary.md`, keep separate columns or sections for:

- 业务一致性问题：task requirement/acceptance mismatch, missing implementation, task-extraneous change.
- 技术实现问题：findings returned by `code-review-spring-boot` / `code-review-vue`.

Do not let a technical review finding automatically become a task-alignment failure unless it prevents acceptance or violates a hard gate. Conversely, a task can be technically clean but still fail task alignment if it misses the business requirement.
