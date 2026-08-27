# Konekta API — Bug Report

**Tested by:** Saturn (QA/Backend)
**Test date:** 26 August 2026
**Environment:** Local. Node 22 with ts-node-dev, MariaDB 10.11, `NODE_ENV=development`.
**Build under test:** `backend` (Express + TypeScript), the commit provided in `Konekta-Main-main.zip`.
**Test basis:** `Konekta_QA_Test_Case_Matrix.xlsx`, 118 designed cases, of which 112 were executed across two passes (6 remain blocked, pending the BUG-001 fix).

---

## Summary

| Severity | Count | Status |
|---|---|---|
| Critical (P0) | 1 | Fixed |
| Medium (P2) | 3 | Fixed |
| Low (P3) | 2 | Fixed |
| **Total bugs found** | **6** | **6 of 6 fixed** |

No data-integrity or authorization breaches turned up during testing. Every IDOR, role-gate, and financial-boundary test attempted was blocked correctly at the database level, even before any fixes. The critical bug (BUG-001) turned out to have two layers: a missing route mount, and underneath it, a mount-path mismatch that would have caused every video endpoint to crash even after adding the mount naively. Both layers are now fixed and verified with an end-to-end submission-to-payment test. BUG-002 and BUG-003 shared the same root pattern (a mutating endpoint that scoped its query correctly but reported success without checking whether the query actually matched a row) and were fixed the same way. BUG-005 turned out to be a genuinely dead, unused endpoint once checked against the actual Flutter codebase, and was removed cleanly.

---

## BUG-001 — Video module completely unreachable, and a nested routing mismatch hiding underneath it

**Severity:** Critical (P0)
**Module:** Video submissions / payments
**Status:** Fixed during this engagement (see Resolution below)

**Description**
`src/routes/video.routes.ts` is imported in `src/app.ts` through `import videoRoutes from './routes/video.routes'`, but the matching mount line was missing from the route-mounting section, so every endpoint in this module returned `404 Endpoint not found` regardless of auth state or input validity.

Fixing the missing mount line alone was not enough. `video.routes.ts` declares its router with `Router({ mergeParams: true })`, and every handler in `video.controller.ts` reads `req.params.id` expecting it to be an offer ID. Neither the route file's own paths (`/`, `/:videoId/refresh`, `/brand/:influencerId`) nor a flat `/videos` mount ever defines an `:id` segment. `mergeParams: true` only has an effect when a router is nested inside a parent route that already has that param, which is a strong signal the module was designed to sit under `/offers/:id/videos`, not stand alone at `/videos`. Mounting it flat "fixed" the 404 but immediately surfaced a second failure: every handler crashed with `Unknown column 'NaN' in 'WHERE'`, because `req.params.id` was always `undefined` and `Number(undefined)` is `NaN`.

**Steps to reproduce (original state)**
1. Start the backend normally with `npm run dev`.
2. Authenticate as any user and obtain a valid JWT.
3. Call any video endpoint, for example `GET /videos` with a valid token.

**Expected result**
The endpoint responds according to its controller logic.

**Actual result (before any fix)**
```
HTTP 404
{"success": false, "message": "Endpoint not found"}
```

**Actual result (after only adding the mount line, before finding the deeper issue)**
```
HTTP 500
[unhandled] Error: Unknown column 'NaN' in 'WHERE'
sql: 'SELECT ... FROM submitted_videos WHERE offer_id = NaN AND influencer_user_id = 1 ...'
```

**Root cause**
Two layered issues:
1. `app.ts` never mounted `videoRoutes` at all.
2. The intended mount point was nested under an offer's ID (`/offers/:id/videos`), matching the `mergeParams: true` router option and every handler's reliance on `req.params.id`, not a flat top-level `/videos` path.

**Resolution applied**
```ts
// app.ts
app.use('/offers/:id/videos', videoRoutes);
```
With the correct nested mount, `req.params.id` resolves from the URL as intended, and no controller logic needed to change. The resulting endpoint shape is:
- `GET /offers/:id/videos` — list submissions and progress for that offer
- `POST /offers/:id/videos` — submit a video for that offer
- `POST /offers/:id/videos/:videoId/refresh` — refresh a submission's stats
- `GET /offers/:id/videos/brand/:influencerId` — brand's view of an influencer's submissions
- `POST /offers/:id/videos/brand/:influencerId/pay` — pay the influencer
- `POST /offers/:id/videos/brand/:influencerId/recalculate` — recalculate reward

**Verification**
With the corrected mount, the full submission-to-payment loop was exercised end to end:
- `POST /offers/1/videos` with a valid TikTok URL and an approved application: `201 Video submitted`.
- `GET /offers/1/videos/brand/1` as the owning brand: `200`, returning the influencer's profile, submitted videos, progress, and reward.
- `POST /offers/1/videos/brand/1/pay`: `200 Payment recorded`, and a new row appeared in `earnings` for the correct amount (`150000.00`, matching the offer's `reward_per_creator`).

**Impact**
Before the fix, the entire campaign → content → payment loop was dead: influencers could not submit proof of work, and brands could not pay them or recalculate rewards. Whichever fix ships needs to be the nested-mount version, not just adding a flat `/videos` route, since the flat mount still crashes every request.

**Note for the frontend**
Since the corrected paths are nested under `/offers/:id/videos` rather than a flat `/videos`, any client code (the Flutter app) already calling a flat `/videos/...` path will need its base path updated to match.

---

## BUG-002 — Notification "mark as read" returns success even when the notification doesn't belong to the caller

**Severity:** Medium (P2)
**Module:** Notifications
**Status:** Fixed during this engagement

**Description**
`POST /notifications/:id/read` always responds `200 "Marked as read"`, even when the target notification ID belongs to a different user. The underlying database update is scoped correctly, so it updates 0 rows when the notification isn't the caller's, and no data actually changes. The HTTP response, though, gives no sign of that, so it misleadingly signals success either way.

**Steps to reproduce**
1. Log in as User A, for example `ava@konekta-mobile.test`, and note a notification ID from `GET /notifications` that belongs to User A, say id `1`.
2. Log in as an unrelated User B, for example `leo@konekta-mobile.test`.
3. As User B, call `POST /notifications/1/read`.
4. Compare the response against the actual database state.

**Expected result**
The API should return `403 Forbidden` or `404 Not Found`, since it shouldn't claim success for a resource the caller doesn't own. This would match the pattern used elsewhere, since `/offers/:id` and `/payment-methods/:id` already return `403`/`404` correctly in the same situation.

**Actual result**
```
HTTP 200
{"success": true, "message": "Marked as read", "data": {"updated": 0}}
```
A follow-up query confirms the notification's `is_read` flag stays unchanged:
```sql
SELECT id, user_id, is_read FROM notifications WHERE id=1;
-- 1 | 1 | 0   (still unread, still belongs to user 1, untouched)
```

**Root cause**
`notification.controller.ts::markOneRead` forwards the service result straight into a hardcoded success response, without checking whether `updated` (or an equivalent affected-rows count) is greater than zero:
```ts
const r = await notificationService.markOneRead(req.user.id, id);
return ok(res, r, 'Marked as read'); // always 200, regardless of r.updated
```

**Impact**
There's no data leak or corruption, since the WHERE-clause scoping in the service layer already prevents the actual update. Even so, this creates a misleading contract for API consumers, because the Flutter app could believe an action succeeded when it silently did nothing. On top of that, the `updated: 0` versus `updated: 1` field in the response body lets an authenticated caller tell "this ID exists and is mine" apart from "this ID belongs to someone else," which is a minor enumeration side-channel.

**Suggested fix**
In the controller, branch on the result and return `404` when nothing was updated:
```ts
const r = await notificationService.markOneRead(req.user.id, id);
if (!r.updated) throw new ApiError(404, 'Notification not found');
return ok(res, r, 'Marked as read');
```

---

## BUG-003 — Social account delete returns success even when the account doesn't belong to the caller

**Severity:** Medium (P2)
**Module:** Social accounts
**Status:** Fixed during this engagement

**Description**
`DELETE /social/mine/:id` always responds `200 {"deleted": true}`, even when the target social account ID belongs to a different user. The SQL query is scoped correctly (`WHERE id = ? AND influencer_user_id = ?`), so it deletes 0 rows when the account isn't the caller's, and the account is never actually removed. The controller, though, never checks how many rows the query affected, so it reports success regardless.

**Steps to reproduce**
1. Log in as User A, for example `ava@konekta-mobile.test`, and note a social account ID that belongs to User A from `GET /social/mine`.
2. Log in as an unrelated User B, for example `leo@konekta-mobile.test`.
3. As User B, call `DELETE /social/mine/<User A's social account id>`.
4. Compare the response against the actual database state.

**Expected result**
The API should return `403 Forbidden` or `404 Not Found`, matching the pattern already used correctly on `/payment-methods/:id`, since the caller doesn't own that resource.

**Actual result**
```
HTTP 200
{"success": true, "message": "OK", "data": {"id": 8, "deleted": true}}
```
A follow-up query shows the record is still present and still belongs to the original owner:
```sql
SELECT id, influencer_user_id, platform FROM social_media_accounts WHERE id=8;
-- 8 | 1 | twitter   (still exists, still belongs to user 1, untouched)
```

**Root cause**
`social.controller.ts::remove` runs the scoped `DELETE` query and then always returns `{ id, deleted: true }`, without checking the query result's affected-rows count:
```ts
await pool.query(
  `DELETE FROM social_media_accounts WHERE id = ? AND influencer_user_id = ?`,
  [id, req.user.id]
);
return ok(res, { id, deleted: true }); // always reports deleted:true
```

**Impact**
No data is lost, since the WHERE-clause scoping already prevents the actual deletion. This is the same category of issue as BUG-002, though: it misleads the caller into thinking an action succeeded when it silently did nothing, and it's the third place in this codebase (alongside notifications) where a mutating endpoint doesn't check its own affected-rows count before declaring success.

**Suggested fix**
Capture the query result and branch on `affectedRows`:
```ts
const [result] = await pool.query<DbResult>(
  `DELETE FROM social_media_accounts WHERE id = ? AND influencer_user_id = ?`,
  [id, req.user.id]
);
if (result.affectedRows === 0) throw new ApiError(404, 'Social account not found');
return ok(res, { id, deleted: true });
```

**Related note**
Since this is the same pattern as BUG-002, it may be worth a codebase-wide pass checking every `DELETE`/`UPDATE` handler that scopes by owner ID (`payment_method.controller.ts` already does this correctly and can serve as the reference pattern).

---

## BUG-004 — Malformed JSON request body returns 500 Internal Server Error instead of 400 Bad Request

**Severity:** Medium (P2)
**Module:** Global (`errorHandler` middleware), observed via `/auth/login` and likely present on every JSON-accepting endpoint
**Status:** Fixed during this engagement

**Description**
Sending a syntactically invalid JSON body, such as a request cut off mid-object, causes Express's body-parser to throw a `SyntaxError`. Neither the `ZodError` nor the `ApiError` branch in `errorHandler` catches this, so it falls through to the generic handler and gets reported as a `500`. Since this is really a client-side mistake, a bad request syntax, it should surface as a `4xx` rather than a `5xx`.

**Steps to reproduce**
```bash
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{bad json'
```

**Expected result**
`400 Bad Request`, with a message indicating malformed JSON.

**Actual result**
```
HTTP 500
{"success": false, "message": "Internal server error", "detail": "Expected property name or '}' in JSON at position 1 (line 1 column 2)"}
```
The `detail` field only appears because `NODE_ENV !== production`. In production it would just show a bare `500` with no explanation, though the status code would still be wrong either way.

**Root cause**
`errorHandler` in `src/middlewares/error.ts` only special-cases `ZodError` and `ApiError`, so a raw `SyntaxError` from `express.json()`'s body-parser falls into the generic `500` branch.

**Impact**
This is functionally low-risk, since the request still gets rejected and no data is at risk. It matters more operationally, because if this API is ever monitored with alerting on 5xx rates (a standard production practice), malformed client requests would trigger false alarms that look identical to real server failures.

**Suggested fix**
Add a specific branch before the generic fallback:
```ts
if (err instanceof SyntaxError && 'body' in err) {
  return res.status(400).json({ success: false, message: 'Malformed JSON body' });
}
```

---

## BUG-005 — `/subscriptions/me` and `/subscriptions/mine` were duplicate endpoints

**Severity:** Low (P3), a code-quality observation
**Module:** Subscriptions
**Status:** Fixed during this engagement

**Description**
`subscription.routes.ts` defined both `GET /subscriptions/me` and `GET /subscriptions/mine`, both under `requireAuth`. On inspection, `mine` in the controller simply called `me` directly (`return subscriptionController.me(req, res, next);`) — it was a pure alias with no distinct behavior of its own.

**Investigation**
A search across the Flutter app (`konekta/lib/`) confirmed only `/subscriptions/me` is ever called, in `subscription_repository.dart` and `brand_profile_screen.dart`. `/subscriptions/mine` had no callers anywhere in the codebase.

**Resolution applied**
Removed the unused route and its controller method:
```ts
// subscription.routes.ts — removed:
r.get('/mine', requireAuth, subscriptionController.mine);

// subscription.controller.ts — removed:
async mine(req, res, next) {
  return subscriptionController.me(req, res, next);
},
```
`/subscriptions/me` is unchanged and remains the single source of truth for this data.

**Verification**
`GET /subscriptions/me` still returns `200` with the expected subscription data. `GET /subscriptions/mine` now correctly returns `404 Endpoint not found`, confirming the dead route is gone and nothing else broke.

**Impact**
No functional impact, since nothing called the removed route. This closes out the only bug in the original report that was open pending a decision rather than a straightforward fix.

---

## What was tested and found correct

These results are documented here too, so the report isn't read as only bad news, and so any re-test after a future refactor has a clear baseline to compare against.

| Area | What was tried | Result |
|---|---|---|
| Auth guard | 7+ sensitive endpoints hit with no `Authorization` header | All correctly returned `401` |
| Auth, user enumeration | `forgot-password` for an existing email versus a non-existent one | Identical response message both times, so no enumeration leak |
| Auth, rate limiting | 25 rapid requests to `/auth/*` from one IP | Correctly throttled to `429` once the 20-request/15-minute budget ran out |
| Auth, forged token | A JWT signed with the wrong secret | Correctly rejected with `401` |
| Offers, IDOR | Brand B tries to edit or view applicants on Brand A's offer | Correctly blocked with `403 "Not your offer"`, and no data changed |
| Offers, role gates | An influencer tries to create an offer, and a brand tries to apply to one | Both correctly blocked with `403` and a clear message |
| Offers, duplicate application | An influencer applies twice to the same offer | The second attempt is correctly blocked with `409` |
| Offers, validation | A negative budget, and a title below the minimum length | Both correctly rejected with `400` and a Zod message |
| Payment methods, IDOR | Brand B tries to delete or set-default on Brand A's payment method | Correctly blocked with `404`, and the data stayed unchanged |
| Withdrawals, financial integrity | An amount exceeding balance, below minimum, zero, and negative | All correctly rejected with `400` and the right message per case |
| Withdrawals, happy path | A valid request within balance | The balance was correctly decremented afterward |
| Chat, IDOR | A non-member tries to read or send into another pair's conversation | Correctly blocked with `403 "Not a member of this conversation"` |
| Chat and Offers, XSS payload | `<script>...</script>` and `<img onerror=...>` in free-text fields | Stored as literal text, and never executed server-side |
| Dashboard and Analytics, role gates | An influencer hits a brand-only view, and a brand hits an influencer-only view | Both correctly blocked with `403` |
| Subscriptions | Subscribing to a non-existent plan, and cancelling with no active subscription | Correctly rejected with `400` and `404` respectively |
| Dev-only data exposure | The `dev_token` field on the `forgot-password` response | Correctly gated behind `NODE_ENV !== 'production'`, so it won't appear in production |
| Auth, registration validation | Duplicate email, invalid email format, password below minimum length, invalid role, name below minimum length | All correctly rejected with `400`/`409` and clear Zod messages |
| Auth, password change | Correct current password, and an incorrect current password | Correctly accepted and correctly rejected respectively |
| Auth, forged token | A JWT signed with the wrong secret, tried again with a fresh forgery on a different endpoint | Correctly rejected with `401` |
| Profile, mass-assignment attempt | Passing another user's `id` inside the request body on `PUT /profile/me` | Ignored, since the update always scopes to `req.user.id` regardless of what the body contains; the other user's data stayed untouched |
| Profile, avatar upload | Uploading without an auth token | Correctly blocked with `401` |
| Offers, boundary | Title at exactly 160 characters (max) and at 161 characters (over max) | Accepted and rejected respectively, exactly at the schema boundary |
| Offers, applicant status IDOR | Brand B tries to approve/reject an applicant on Brand A's offer | Correctly blocked with `403 "Not your offer"`, and the applicant's status stayed unchanged |
| Offers, applicant status validation | An invalid status enum value | Correctly rejected with `400` and a clear Zod message |
| Offer progress, boundary | An empty milestone string | Correctly rejected with `400` |
| Chat, idempotency | Calling `ensure` twice for the same brand/influencer pair | Both calls return the same conversation ID, with no duplicate row created |
| Notifications, bulk action | `mark all as read` | Correctly updated every one of the caller's own notifications, and none of another user's |
| Dashboard, transaction scoping | Brand A and Brand B each request `/dashboard/brand/transactions` | Each correctly sees only their own (empty) transaction list |
| Withdrawals, read endpoints | Balance and withdrawal history, checked after an earlier withdrawal request | Figures matched what the earlier withdrawal test had already produced |
| CORS | Preflight `OPTIONS` request from a disallowed origin | Server responded `204` without an `Access-Control-Allow-Origin` header for that origin (needs confirming this holds with `ALLOWED_ORIGINS` actually restricted in production, since local `.env` used `*` for this pass) |

---

## BUG-006 — Public offer endpoints leaked an internal `room_code` field via `SELECT o.*`

**Severity:** Low (P3)
**Module:** Offers (discovery/public read paths)
**Status:** Fixed during this engagement

**Description**
While investigating why unauthenticated requests could read offer data at all
(a deliberate design choice, confirmed by checking that the Flutter app itself
calls `GET /offers` with `auth: false` for its own Explore screen), the query
backing both `GET /offers` and `GET /offers/:id` used `SELECT o.*`, which
returns every column on the `offers` table with no field-level filtering.

One of those columns, `room_code`, isn't referenced anywhere in the Flutter
app (confirmed by a full grep across `konekta/lib/`) and isn't checked against
in any access-control logic in the backend either. It appears to be an
internal or forward-looking field with no current purpose, but it was still
being handed to any unauthenticated caller who asked, simply because nobody
had written an explicit field list for these two public-facing queries.

**Steps to reproduce (before the fix)**
```bash
curl http://localhost:4000/offers/1
```

**Actual result (before)**
The response included `"room_code": "..."` for every offer, visible to any
caller, logged in or not.

**Root cause**
`offerController.listPublic` (in `controllers/offer.controller.ts`) and
`offerService.getById` (in `services/offer.service.ts`), the two functions
backing the public offer-browsing endpoints, both used `SELECT o.*` instead
of an explicit column list, so every column on the table rides along
automatically, including ones with no legitimate reason to be public.

**Resolution applied**
Replaced `SELECT o.*` with an explicit column list in both functions,
covering every field the app actually displays (title, brief, budget, reward,
targets, deliverables, requirements, audience, deadline, max creators,
status, visibility, timestamps) and dropping `room_code`.

**Verification**
```bash
curl http://localhost:4000/offers/1 | grep room_code
# (no output, field is gone)
```
Confirmed the rest of the public offer data (title, budget, brand name, applicant counts, etc.) is unaffected and still renders correctly.

**Impact and scope note**
No evidence this field was actively exploited, and it carries no access-control
weight anywhere in the current codebase, so the practical risk was low. The
broader lesson generalizes past this one field: `SELECT o.*` was found in six
other places in the codebase (`campaignBuilder.ts`, `modules/offers/offer.service.ts`,
and the brand/influencer-facing parts of `services/offer.service.ts`). Those
weren't touched in this pass since they're all reached through
`requireAuth`-protected, ownership-scoped routes, where a user seeing every
column of their own offer isn't a leak. If any of those routes are ever
relaxed to be reachable by someone other than the resource's owner, the same
`SELECT *` pattern would need the same explicit-column treatment applied here.

**Related design note (not changed, per product decision)**
Separately, whether offer browsing and discovery should require login at all
was discussed during this engagement. The current behavior (public read
access to offer listings, offer detail, and influencer/brand discovery,
mirroring how many marketplaces let people browse before creating an account)
was confirmed as an intentional product decision, not something this bug
touches. This bug is narrowly about incidental field-level exposure within
data that's already meant to be public, not about whether that data should be
public in the first place.

---

## Appendix A — Recommended follow-up once BUG-001 is fixed

Once `videoRoutes` gets mounted, six previously-untestable endpoints become reachable, and they need a fresh pass since their controller logic has never run end-to-end:
- Video submission validation, covering URL format and the platform enum.
- IDOR on `/videos/:videoId/refresh` and `/videos/brand/:influencerId`, since these are owned by design but unverified in practice.
- Payment calculation correctness on `/videos/brand/:influencerId/pay` and `/recalculate`, since this is financial logic and should sit at P0 priority in the next pass, the same tier as the withdrawal tests above.