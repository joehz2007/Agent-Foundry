# Vue code review checklist

Use this checklist for Vue 2/3, TypeScript, Vite/Webpack, Element Plus/Element UI, and frontend business code.

## Component and state design

- Component responsibilities are clear; complex logic is extracted into composables/services when appropriate.
- Props/events are typed and documented through TypeScript or clear naming.
- Reactive state is not duplicated in ways that can become inconsistent.
- Watchers are necessary, scoped, and not causing loops or hidden side effects.
- Lifecycle hooks clean up timers, subscriptions, listeners, and pending requests.

## API integration

- Request/response fields match backend contract.
- Loading, empty, error, and retry states are handled.
- API errors are surfaced to users in project-standard style.
- Save/update flows refresh local state or invalidate cache correctly.
- Frontend does not rely on stale route/query/store values.

## Form and validation

- Required fields, ranges, formats, and conditional rules match business/backend constraints.
- Submit is protected against double-click/repeated requests when needed.
- Edit vs readonly modes are enforced consistently.
- Approval/review flows preserve state and audit fields.

## Permission and security

- Frontend permission checks are treated as UX only; sensitive actions require backend enforcement.
- Routes, buttons, and API calls honor role/tenant/merchant context.
- No secrets, tokens, or sensitive account data are logged or stored unnecessarily.
- Displayed sensitive data is masked when required.

## UX and accessibility

- Changes fit existing UI patterns and component library conventions.
- User feedback is clear for success/failure/validation.
- Tables, pagination, filters, and exports handle large data sensibly.
- Basic keyboard/accessibility behavior is not broken for dialogs/forms.

## Tests and regression

- Unit/component tests cover complex computed/watch/form logic.
- E2E or manual test plan covers critical user flows.
- Backend contract changes are tested or documented.
- Regression scope includes affected pages, readonly views, approval pages, and list/detail consistency.

## Hard gates

Mark as high/blocking when any applies:

- Sensitive action is only restricted in frontend but backend/API requirement implies server-side enforcement is needed.
- Required backend field is not sent or response field is misread.
- Save/approval flow can submit duplicate or stale data.
- Task acceptance criterion has no visible implementation evidence.
