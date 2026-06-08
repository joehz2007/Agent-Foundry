# Spring Boot code review checklist

Use this checklist for Java/Kotlin Spring Boot backend code reviews. Focus on production risks and concrete code evidence.

## API / Controller

- Request DTO has validation annotations and controller uses `@Valid` / `@Validated`.
- Authentication and authorization are enforced server-side, not assumed from frontend.
- API response shape follows project conventions.
- Error messages do not leak stack traces, SQL, secrets, or sensitive personal data.
- Backward compatibility is considered for public endpoints, events, DTOs, and API contracts.

## Service / business logic

- Business rules live in service/domain layer, not controller or mapper XML.
- Transaction boundary is explicit and minimal.
- Idempotency exists for money movement, orders, callbacks, retries, imports, and external side effects.
- Retry logic is bounded and safe for non-idempotent operations.
- State transitions are validated and cannot skip required states.

## Persistence / SQL

- Queries include tenant/merchant/user scope where relevant.
- No obvious N+1 query or unbounded list/export query.
- Index impact is considered for new filters, joins, and sorting.
- Mapper/entity field mapping is complete and type-safe.
- Multi-table writes have correct transaction and rollback semantics.

## Security

- No broad `permitAll` or bypass of sensitive endpoints.
- No trust in request parameters for role, merchant, tenant, or user identity.
- No hardcoded secrets or credentials.
- Logs do not expose tokens, bank account data, personal IDs, or API keys.
- Crypto/TLS code does not disable certificate or hostname verification.

## Observability / operations

- Important state changes and external calls have useful logs without sensitive data.
- Metrics/actuator endpoints are safely exposed per environment.
- Failures preserve enough context for diagnosis.
- Feature flags/config defaults are safe.

## Tests

- Unit tests cover business rules and edge cases.
- Integration/API tests cover endpoint behavior, validation, authorization, and persistence.
- Regression tests cover bugfix root cause.
- Money/data-consistency tasks include idempotency, retry, and rollback tests.

## Hard gates

Mark as blocking or high severity when any applies:

- Missing authorization on sensitive operation.
- Missing idempotency/transaction safeguards for money movement or external side effects.
- SQL or repository access missing tenant/merchant/user isolation for sensitive data.
- Known exception is swallowed or converted to success.
- Required acceptance criterion has no implementation evidence.
