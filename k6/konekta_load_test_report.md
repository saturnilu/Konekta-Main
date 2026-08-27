# Konekta API — Load Test Report

**Tool:** k6 v0.54.0
**Target:** Local backend, `http://localhost:4000` (Node 22, MariaDB 10.11)
**Test date:** 26 August 2026
**Script:** `mixed_traffic.js`

## Methodology

Rather than hammering a single endpoint, this test models a realistic mix of
traffic across three weighted scenarios running concurrently for 70 seconds
(20s ramp-up, 40s steady state, 10s ramp-down):

| Scenario | Share of traffic | Peak VUs | What it does |
|---|---|---|---|
| Browsing | ~70% | 30 | Anonymous: list offers, view an offer's detail, browse influencers. No auth. |
| Influencer login + apply | ~20% | 4 | Logs in as a seeded influencer, checks their profile, applies to a random open offer. |
| Brand dashboard | ~10% | 2 | Logs in as a seeded brand, checks the dashboard overview and their own offers. |

The weighting reflects how a marketplace like Konekta is actually used day to
day: most traffic is people browsing campaigns, a smaller slice is someone
actively logging in to act on something, and brands checking their dashboard
are the smallest group.

## Results

| Metric | Value |
|---|---|
| Total requests | 2,325 over 70s (~33 req/s) |
| Total iterations | 989 |
| Overall `http_req_duration` (all requests) | avg 2.8ms, p90 4.0ms, p95 5.5ms, max 37.9ms |
| Browsing-only latency | avg 3.0ms, p90 4.1ms, p95 5.7ms |
| Auth-only latency (successful logins) | avg 1.9ms, p90 3.2ms, p95 4.7ms |
| Checks passed | 100% (2,056/2,056) |
| `http_req_failed` (overall) | 12–14% |
| `auth_failures` (login attempts that didn't get a token) | ~93% |

## The headline finding: the backend is fast, the auth rate limiter is the real ceiling

Every response the backend actually computed was fast. Browsing p95 sat around
5–7ms, and even successful logins that made it through resolved in single-digit
milliseconds. There's no evidence of a database or application-level
performance problem at this traffic level.

The failures are concentrated entirely in login. Out of roughly 300 login
attempts across the influencer and brand scenarios combined, only about 20
succeeded — the rest came back `429 Too many requests`. That number lines up
exactly with the `/auth/*` rate limiter's configured budget: 20 requests per
15 minutes, shared across every route under `/auth`, keyed by IP. With even a
modest 6 concurrent virtual users repeatedly logging in over 70 seconds, that
budget is exhausted almost immediately, and every login after that fails —
not because the server is struggling, but because the limiter is doing
exactly what it's configured to do.

This is worth flagging as a capacity/product finding rather than a bug:

- **As an abuse-prevention control, it works correctly.** A brute-force
  attempt against one account is throttled hard, which is the intended
  behaviour (also verified functionally in the QA regression suite).
- **As a load-bearing limit for legitimate traffic, it's very tight.** Any
  situation with several real users authenticating from the same IP in a
  short window — a shared office network, a campus, a mobile carrier's NAT,
  or simply a marketing push that drives a burst of logins — will produce
  the same wall of 429s this test did, indistinguishable from an attack.
- **The current implementation is a single in-memory `Map`** (see
  `authRateLimit` in `app.ts`), which also means the limiter's state doesn't
  survive a server restart or scale across multiple backend instances if the
  app is ever run behind a load balancer. Every instance would enforce its
  own independent 20-request budget rather than sharing one.

## Recommendations

1. **Decide what the limiter is actually protecting against.** If the goal is
   specifically to slow down repeated failed login attempts on one account
   (credential stuffing), consider keying the limiter by `email` (or
   `email + IP`) instead of IP alone, and only counting failed attempts
   toward the budget — a user who logs in successfully once shouldn't spend
   down the same budget as someone guessing passwords.
2. **If IP-based throttling is intentional for other `/auth/*` routes**
   (registration spam, password-reset abuse), consider a higher budget or a
   separate, more generous limiter specifically for `/auth/login`, since
   login is the one auth endpoint every active user hits regularly, not just
   during an attack.
3. **Re-run this same load test after any limiter change**, comparing
   `auth_failures` before and after, to confirm the fix actually widens the
   ceiling for legitimate concurrent logins without reopening the door to
   brute-forcing.
4. **This finding does not block moving to a shared-state limiter (Redis
   etc.) as a separate concern** — that matters once the app runs on more
   than one instance, but the budget-sizing issue above would exist even on
   a single instance.

## What this test does not cover

- Sustained load beyond 70 seconds — this was a short representative run, not
  a soak test. A longer run (10–30 minutes) would be the next step to check
  for memory leaks or slow degradation under prolonged traffic.
- The video/payment endpoints (fixed after BUG-001) — not included in this
  pass, worth adding once a stable, non-destructive seed dataset for repeated
  submissions is available.
- Breakpoint testing to find the actual VU count at which the database or
  Node process itself becomes the bottleneck, since the rate limiter masked
  that entirely for any auth-touching path in this run.