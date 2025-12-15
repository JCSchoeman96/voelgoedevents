# ISSUE 0001 — Auth login rate limiting applies to wrong routes

## Type
bug / security

## Problem
The login rate limiter is currently triggered by POST requests to `/auth/log_in`
(which is a LiveView page route returning 404), while the real authentication
endpoint `/auth/user/password/sign_in` is not being rate-limited.

This allows:
- accidental exhaustion of the limiter via an invalid route
- unlimited brute-force attempts against the real sign-in endpoint

## Evidence
Regression test:
`test/voelgoedevents_web/rate_limit_login_regression_test.exs`

Observed behavior:
- `/auth/log_in` POST → eventually returns 429 (incorrect)
- `/auth/user/password/sign_in` POST → always returns 401, never 429 (incorrect)

## Desired Behavior (Definition of Done)
- POST `/auth/log_in` must NEVER trigger login rate limiting
- POST `/auth/user/password/sign_in` MUST eventually return 429
- Rate limiting must apply ONLY to real auth action endpoints
- All regression tests pass
- No changes to LiveView GET routes

## Constraints
- Do not weaken CSRF protection
- Do not guess routes — use actual Phoenix routing
- Keep rate limiter rules unchanged
- Prefer router or pipeline-level fix over ad-hoc conditionals

## Affected Areas
- lib/voelgoedevents_web/router.ex
- auth pipelines / scopes
- rate limiting plug wiring

## Notes
This issue must be fixed in a way that survives future AshAuthentication
route changes.
