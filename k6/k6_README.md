# Konekta API — Load Testing (k6)

## Files

| File | Purpose |
|---|---|
| `mixed_traffic.js` | The k6 script: three weighted scenarios (browsing, influencer login+apply, brand dashboard) running concurrently. |
| `Konekta_Load_Test_Report.md` | Results and findings from the latest run, including the auth rate-limiter bottleneck. |

## Running it

1. Install k6: see https://grafana.com/docs/k6/latest/set-up/install-k6/
2. Start the backend locally (same setup as the QA regression suite).
3. From this folder:

```bash
k6 run mixed_traffic.js
```

Optionally point it at a different host:

```bash
BASE_URL=https://your-staging-url.com k6 run mixed_traffic.js
```

## Why the auth-related thresholds fail on every run

This is expected, not a broken script. Read `Konekta_Load_Test_Report.md` for
the full explanation: the `/auth/*` rate limiter (20 requests / 15 minutes per
IP) gets exhausted almost immediately once more than a handful of virtual
users try to log in concurrently, so most login attempts during the test
correctly receive `429`. The `auth_failures` and `http_req_failed` thresholds
are intentionally left in the script (rather than relaxed to always pass) so
this bottleneck stays visible on every run until the rate-limiter's budget is
revisited — the same philosophy as the Postman regression suite's bug-tracking
assertions.

## Adjusting the scenario

The VU counts and stage durations are deliberately modest so the test can run
in about a minute for quick iteration. To simulate heavier traffic, increase
`target` in each scenario's `stages` in `mixed_traffic.js` — but expect the
auth-related failure rate to climb even faster as concurrency increases,
since the rate limiter's budget doesn't scale with load.