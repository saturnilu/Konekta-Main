# Konekta API — QA Regression Suite

Postman + Newman + GitHub Actions setup for automated regression testing of the Konekta backend.

## Files

| File | Purpose |
|---|---|
| `Konekta_QA_Regression_Suite.postman_collection.json` | 101 requests across 16 folders, one per API module, plus a folder for rate-limit testing (excluded from the main run). |
| `Konekta_Local.postman_environment.json` | Environment for running against a local backend on `http://localhost:4000`. |
| `.github/workflows/api-regression.yml` | CI workflow: spins up MariaDB, starts the backend, runs the suite with Newman on every push and pull request. |

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
  --folder "06 - Video (known bug BUG-001)" \
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

## Why the suite currently shows 8 failing assertions

This is expected, not a broken suite. Eight assertions are written to check for the *correct* behaviour on four known, already-logged bugs (see `Konekta_QA_Bug_Report.md`):

- **BUG-001** (5 assertions, Video folder): asserts the video endpoints return 200/201. They currently return 404 because the routes are never mounted.
- **BUG-002** (1 assertion, Notifications folder): asserts marking another user's notification as read returns 404. It currently returns 200.
- **BUG-003** (1 assertion, Social folder): asserts deleting another user's social account returns 404. It currently returns 200.
- **BUG-004** (1 assertion, System folder): asserts a malformed JSON body returns 400. It currently returns 500.

These tests are intentionally written against the *fixed* behaviour so that once a developer ships the fix, the corresponding assertion turns green automatically, with no need to go back and rewrite the test. This is the point of a regression suite: it should already contain the check for a bug before the bug is fixed, not just after.

## The Rate Limiting folder (folder 16)

This folder is excluded from the main run and from CI on purpose. The `/auth/*` rate limiter is a shared in-memory counter per IP, capped at 20 requests per 15 minutes across the whole `/auth` prefix. Every other folder that logs in or calls `/auth/*` consumes part of that budget. Running the rate-limit probe (which needs ~25 requests to itself) in the same pass as everything else causes unrelated tests to fail with 429, not because they're broken but because the shared budget ran out. Run this folder on its own, ideally against a freshly restarted backend, when specifically verifying the limiter.

## CI behaviour

The GitHub Actions workflow (`api-regression.yml`) runs the same 15 folders on every push and pull request, using a MariaDB service container and a fresh schema/seed load each time. It will currently report failures corresponding to the four open bugs above; this is intentional and documents the current, real state of the API rather than a green build that hides known issues. Once BUG-001 is fixed (a one-line change), five of the eight failing assertions should turn green immediately. BUG-002/003/004 each need a small code fix in their respective controller/middleware, documented with a suggested patch in the bug report.
