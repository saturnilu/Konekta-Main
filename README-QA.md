# Konekta API — QA

Postman + Newman + GitHub Actions for automated regression testing of the Konekta backend, plus k6 for load testing.

## Files

| File | Purpose |
|---|---|
| `postman/Konekta_QA_Regression_Suite.postman_collection.json` | 101 requests across 16 folders, one per API module, plus a folder for rate-limit testing (excluded from the main run). |
| `postman/Konekta_Local.postman_environment.json` | Environment for running against a local backend on `http://localhost:4000`. |
| `.github/workflows/api-regression.yml` | CI workflow: spins up MariaDB, starts the backend, runs the suite with Newman on every push and pull request. |
| `bug_report.md` | Full QA engagement report: 7 bugs found, all 7 fixed, plus everything tested and found correct. |
| `k6/mixed_traffic.js` + `k6/konekta_load_test_report.md` | Load testing setup and results. See `k6/k6_README.md` for details. |
| `backend/src/**/*.spec.ts` | Jest unit tests: regression tests tied to the bugs above, auth middleware, and financial boundary validation. |

## Running locally

1. Start MariaDB and load the schema and seed data.
2. Start the backend: `npm run dev` from the `backend` folder.
3. Import both JSON files into Postman, or run headless with Newman:

```bash
newman run Konekta_QA_Regression_Suite.postman_collection.json \
  -e Konekta_Local.postman_environment.json \
  --folder "01 - Auth" \
  --folder "02 - Google OAuth" \
  --folder "03 - Profile" \
  --folder "04 - Discovery" \
  --folder "05 - Offers" \
  --folder "06 - Video (BUG-001 fixed, nested under /offers/:id/videos)" \
  --folder "07 - Chat" \
  --folder "08 - Notifications" \
  --folder "09 - Dashboard" \
  --folder "10 - Analytics" \
  --folder "11 - Subscriptions" \
  --folder "12 - Social" \
  --folder "13 - Withdrawals" \
  --folder "14 - Payment Methods" \
  --folder "15 - System"
```

Run the folders together, in this order, in one Newman invocation. The Auth folder logs in as four seeded test accounts and stores their tokens as environment variables; later folders read those variables to authenticate. Running folders separately means later folders start with empty tokens and everything fails with 401, which is a test-runner ordering issue and not a bug in the API.

## Bug history

This suite was originally written against assertions for the *fixed* behaviour of six bugs discovered during the QA engagement, before those bugs were fixed, so that once each fix shipped the corresponding assertion would turn green automatically with no need to go back and rewrite the test. That's the point of a regression suite: it should already contain the check for a bug before the bug is fixed, not just after. (A seventh bug, BUG-007, surfaced later and isn't observable over HTTP, so it has no corresponding Postman assertion — see the unit tests section below.)

All seven bugs are now fixed (see `bug_report.md` for full root-cause analysis, repro steps, and verification for each):

- **BUG-001** (Critical, Video folder): video endpoints were unreachable, then crashed even once mounted, due to a missing route mount plus a nested `mergeParams` mismatch. Fixed by mounting `videoRoutes` at `/offers/:id/videos`.
- **BUG-002** (Medium, Notifications folder): marking another user's notification as read returned `200` instead of `404`. Fixed by checking the affected-rows count before responding.
- **BUG-003** (Medium, Social folder): deleting another user's social account returned `200` instead of `404`. Same root cause and fix pattern as BUG-002.
- **BUG-004** (Medium, System folder): a malformed JSON body returned `500` instead of `400`. Fixed by adding a `SyntaxError` branch in the global error handler.
- **BUG-005** (Low): `/subscriptions/mine` was a dead, unused duplicate of `/subscriptions/me`. Removed.
- **BUG-006** (Low): public offer endpoints leaked an internal `room_code` field via `SELECT o.*`. Fixed with an explicit column list.
- **BUG-007** (Low): a second, unwired copy of the auth middleware, error handler, and `ApiError` class sat under `src/core/`, closely enough named to look interchangeable with the real ones. Found while adding the Jest suite below, when a test imported from the wrong copy and silently checked code the live server never runs. `src/core/` and the equally-unreferenced `src/modules/` were deleted.

With all fixes applied, the suite should now pass in full. Re-running it after any future change to these modules is the fastest way to confirm nothing regressed.

This folder is excluded from the main run and from CI on purpose. The `/auth/*` rate limiter is a shared in-memory counter per IP, capped at 20 requests per 15 minutes across the whole `/auth` prefix. Every other folder that logs in or calls `/auth/*` consumes part of that budget. Running the rate-limit probe (which needs ~25 requests to itself) in the same pass as everything else causes unrelated tests to fail with 429, not because they're broken but because the shared budget ran out. Run this folder on its own, ideally against a freshly restarted backend, when specifically verifying the limiter.

## CI behaviour

The GitHub Actions workflow (`api-regression.yml`) runs the same 15 folders on every push and pull request, using a MariaDB service container and a fresh schema/seed load each time. With all six of the API-level bugs fixed, the workflow documents a green build against the current, real state of the API rather than a snapshot with known open issues.

## Unit tests

`backend/src/**/*.spec.ts` (Jest + ts-jest) cover the logic underneath the black-box findings above, mocking the database and JWT layer so each test runs in milliseconds with no server or MariaDB instance required:

- **Regression tests for BUG-002, BUG-003, and BUG-004**, asserting the exact fixed behaviour directly against the controller/middleware functions (e.g. `markOneRead` throws a 404 `ApiError` when 0 rows are affected, `errorHandler` returns 400 for a body-parser `SyntaxError`).
- **`requireAuth`/`requireRole`** (`middlewares/auth.spec.ts`): missing header, malformed header, wrong-secret forged token, expired token, and correct role-gating.
- **`withdrawalService.requestWithdrawal`** (`services/withdrawal.service.spec.ts`): financial boundary validation — zero/negative amount, below-minimum amount, amount exceeding balance, and the exact-boundary cases.
- **`generateUniqueUsername`** (`utils/username.spec.ts`): sanitization and suffix-collision handling.

Writing this suite is also what surfaced BUG-007 (see `bug_report.md`): a test written against `errorHandler`/`ApiError` initially resolved to a second, unwired copy of both under `src/core/`, which type-checked and ran but silently checked code the live app never executes. `src/core/` and the equally-dead `src/modules/` have since been deleted. Worth remembering going forward: if a test for previously-verified behaviour starts failing right after it's written (not after a real code change), check which file the import actually resolved to before assuming the fix regressed.

Run from `backend/`:

```bash
npm test              # run once
npm run test:watch    # watch mode
npm run test:coverage # with a coverage report
```

## Load testing

`k6/mixed_traffic.js` runs three weighted, concurrent scenarios (anonymous browsing, influencer login + apply, brand dashboard) to check the backend under realistic mixed traffic rather than hammering one endpoint. The latest run found the backend itself fast (single-digit millisecond p95 on every computed response), with the real ceiling being the `/auth/*` rate limiter's budget (20 requests/15 minutes per IP), which throttles legitimate concurrent logins the same way it would throttle an attack. Full results, methodology, and recommendations are in `k6/konekta_load_test_report.md`; setup instructions are in `k6/k6_README.md`.