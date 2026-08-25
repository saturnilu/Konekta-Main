# Product Requirements Document (PRD)

## Konekta

**Platform:** Mobile App
**Frontend:** Flutter (Dart)
**Backend:** Express.js (TypeScript)
**Database:** MySQL / MariaDB

---

## 1. Product Summary

**Konekta** is a mobile application that connects **influencers** and **brands** on a single platform. The application serves two types of users:

- **Influencer side:** search for endorsement opportunities, manage social media profiles, receive collaboration offers, submit video deliverables with automatic performance tracking, get paid, and withdraw earnings.
- **Brand side:** find relevant influencers, view influencer performance data, run campaigns, monitor progress, pay creators, and manage a subscription plan.

The primary goal is to streamline matching, application, progress tracking, communication, and (in simulated form today) payment between influencers and brands.

---

## 2. Product Goals

1. Connect brands and influencers efficiently.
2. Provide a relevant search and filter system for both sides.
3. Help influencers monitor all their endorsements — and earnings — in one place.
4. Help brands find influencers that fit their campaign needs and track spend.
5. Improve collaboration transparency through clear status tracking and notifications.
6. Give both sides a believable, testable monetization flow (subscriptions, payouts) ahead of a real payment gateway integration.

---

## 3. Problems Being Solved

### For Influencers
- Difficulty finding brands that are a good fit.
- Endorsement workflows scattered across chat, email, and spreadsheets.
- Difficulty tracking the status of ongoing collaborations and how much they've actually earned.
- No visibility into *when* content performance (views/likes) meets a campaign's target.

### For Brands
- Difficulty finding the right influencer based on niche, audience, and budget.
- No structured way to compare influencer candidates.
- No visibility into true budget exposure across multiple campaigns with multiple creators each.
- No saved payment method — re-entering payment info every time is friction (and there was no way to remove a saved one, which this product intentionally supports from the start).

---

## 4. Target Users

### 4.1 Influencers
Micro/mid-tier influencers, content creators, KOLs.

### 4.2 Brands
SMEs, local brands, startups, marketing/talent agencies, enterprise brands running influencer campaigns.

---

## 5. Value Proposition

### For Influencers
- Faster access to endorsement opportunities.
- All collaborations recorded in one place, with real performance tracking against a target.
- Clear earnings balance and a self-service withdrawal request.
- A Pro tier that adds a verified badge, featured placement, and longer analytics history.

### For Brands
- Faster, more relevant influencer discovery.
- Structured, comparable influencer data.
- Budget visibility that accounts for how many creators a campaign can actually accept, not just its per-creator reward.
- A saved payment method so paying doesn't mean re-entering details every time.

---

## 6. Product Scope

### 6.1 Implemented (beyond the original MVP list)

The original MVP scope excluded payment/monetization entirely. That's since changed — the following are implemented, with the explicit caveat that **no real payment gateway is connected**:

- Brand subscription plans (Free / Starter / Pro / Enterprise) and influencer plans (Free / Pro Creator)
- A dummy QRIS-style checkout (on-device generated QR, no real transaction) for every "payment" — subscribing and paying an influencer both go through it
- Downloadable PDF invoices for subscription payments
- Subscription lock: a paid plan cannot be downgraded before its period ends; it lazily auto-expires back to Free on the next read after that
- Influencer earnings balance + self-service withdrawal requests (manually processed — see §6.3)
- Brand-saved payment methods (label + last 4 digits only, removable)
- Rich per-role analytics: view/engagement trends, budget vs. committed spend, application funnel, paginated transaction history
- Video submission accepts **TikTok or Instagram Reel** links — the platform is auto-detected from the URL, so an influencer never has to specify which one they're submitting (see §6.4 for a caveat on Instagram's data source)

### 6.2 Original MVP Scope (still the core loop)

- Registration and login (including Google Sign-In)
- Role selection: Influencer / Brand
- Complete profile based on role, including avatar/logo upload
- Search and filter for influencer / brand
- Influencer / brand profile detail
- Send collaboration offers (campaigns), apply, approve/reject
- Track endorsement / campaign status, including automatic progress calculation from submitted video stats
- In-app notifications (with an unread-count badge)
- 1:1 chat
- Per-role dashboard

### 6.3 Explicitly Out of Scope (for now)

- **A real payment gateway.** Midtrans/Xendit/DOKU integration is the clear next step — see `ARCHITECTURE.md` §7 for exactly what changes.
- **Real email delivery.** Password reset currently logs the token server-side (and echoes it in non-production API responses) rather than sending an email.
- **Automated withdrawal processing.** A withdrawal request needs a human to flip its status in the database; there's no admin UI or disbursement API call yet.
- AI recommendation engine
- Full KYC / identity verification
- Multi-team management for brands
- A web admin panel

### 6.4 Known Caveat: Instagram Reels Field Mapping

TikTok stat fetching (views/likes/shares) is verified end-to-end against a live RapidAPI subscription. Instagram's field mapping (views/likes/comments/shares) is based on a real sample response captured during development, but the exact RapidAPI endpoint path and parameter name for looking up **one specific Reel by URL** haven't been confirmed against a chosen product's docs yet — see the comment above `fetchInstagramStats()` in `backend/src/services/instagram.service.ts`. Submitting an Instagram Reel link works today (the platform is correctly detected and stored), but the stats returned may read as 0 or throw a clear "not configured yet" error until `RAPIDAPI_INSTAGRAM_HOST` is set to a verified product.

---

## 7. User Roles

### 7.1 Influencer
- Create personal and social media profiles; upload an avatar
- Display niche, rate card, audience, and media kit
- Apply to campaigns, submit video deliverables
- Track endorsement status and progress toward a campaign's view/like targets
- Chat with brands
- View earnings balance and request withdrawals
- Subscribe to Pro for a verified badge, featured placement, and full analytics history

### 7.2 Brand
- Create brand/company profile; upload a logo
- Search for influencers based on campaign needs
- Create campaigns (budget, target views/likes, max creators, deadline)
- Review and approve/reject applicants
- Monitor campaign progress and pay creators
- Save a payment method for faster checkout
- Subscribe to a paid plan for higher campaign limits

### 7.3 Admin (not yet built)
- User/content moderation, account verification, report handling, withdrawal processing — all currently require direct database access instead of a UI.

---

## 8. User Journey

### 8.1 Influencer Journey
1. Register (or sign in with Google) → select influencer role.
2. Complete profile: niche, social accounts, rate.
3. Browse campaigns, apply.
4. Get approved, submit a TikTok or Instagram Reel link.
5. Progress auto-updates from real view/like counts against the campaign's target.
6. Chat with the brand as needed.
7. Get marked as paid → balance increases.
8. Request a withdrawal to a saved bank account.

### 8.2 Brand Journey
1. Register (or sign in with Google) → select brand role.
2. Complete brand profile and create a campaign.
3. Review applicants, approve the ones that fit.
4. Monitor each approved creator's progress toward the campaign target.
5. Pay a creator once satisfied (via the dummy checkout — sees the creator's saved bank details if they've added one).
6. Track spend and campaign counts on the analytics dashboard.
7. Optionally subscribe to a higher plan for more concurrent campaigns.

---

## 9. Key Features

### 9.1 Authentication
Register, login, logout, Google Sign-In, forgot/reset password, change password (while logged in).

### 9.2 Profile Management
Influencer: name, avatar, bio, niche, social platforms, followers, engagement rate, rate card, location, media kit, payout bank details.
Brand: name, logo, description, industry, location, website, plan.

### 9.3 Discovery / Search
Brand → influencer search by niche/location/platform/followers/engagement (Pro-tier influencers surface first). Influencer → brand search by industry/location.

### 9.4 Campaign Management
Create → apply → approve/reject → submit video (TikTok or Instagram Reel, auto-detected from the URL) → auto-tracked progress → paid. Campaign status: `open` → `in_progress` → `completed` (a campaign can stay `in_progress` with multiple creators at different individual stages simultaneously — an individual applicant being paid doesn't force the whole campaign to `completed`).

### 9.5 Messaging
1:1 chat, tied to a campaign relationship or started directly from a profile. Push-style delivery isn't implemented — the client polls/refreshes.

### 9.6 Dashboards & Analytics
Influencer: earnings this month/pending, active/completed campaigns, view/engagement trend (7 days on Free, up to 365 on Pro), recent transaction list.
Brand: open/active/completed campaign counts, total budget (accounting for `max_creators`), committed spend (reward × currently-approved creators), reach/engagement trend, paginated payment history.

### 9.7 Notifications
New applicant, application approved/rejected, new message, subscription activated, withdrawal requested — each pushed inline by the service that causes it, surfaced via an unread-count badge on the bell icon.

### 9.8 Monetization (simulated)
Subscriptions (both roles), a dummy checkout with a downloadable invoice, influencer withdrawal requests, and brand-saved payment methods.

---

## 10. Functional Requirements

- Users register with email + password or Google; the system stores their role.
- Users can update their profile, including uploading a photo.
- Influencers can add/remove multiple social media accounts (upserted, not duplicated, on re-add).
- Brands create campaigns with a budget, per-creator reward, target metrics, and an optional creator cap.
- Influencers apply; brands approve/reject; all status changes persist and notify the other party.
- Campaign progress is computed from real submitted-video view/like counts against the campaign's stated targets — not from headcount.
- Users can chat once a conversation exists; messages persist and are retrievable.
- A brand cannot downgrade a paid subscription before it expires; it auto-reverts to Free on the next status check after expiry.
- An influencer cannot withdraw more than their real earned-minus-already-withdrawn balance.

---

## 11. Non-Functional Requirements

- **Performance:** search and dashboard queries should return quickly even as campaign/applicant counts grow.
- **Security:** passwords hashed with bcrypt; JWT-protected endpoints; payment methods store display info only, never raw card data.
- **Reliability:** campaign, application, and payment-record data must not be lost; notification failures must never block the action that triggered them.
- **Usability:** simple, mobile-first UI; a single consistent color palette (`KonektaColors` — see `design-patterns.md`).
- **Maintainability:** layered backend (routes/controllers/services), repository + Cubit-based Flutter state management — see `ARCHITECTURE.md`.

---

## 12. Data Entities (High Level)

See `ARCHITECTURE.md` §5 for the full, current schema — the highlights that changed since the original MVP entity list:

- `influencer_profiles` gained `plan`, `plan_expires_at`, `payout_bank`, `payout_account`.
- `brand_profiles` gained `plan`.
- New tables: `withdrawals`, `brand_payment_methods`, `brand_subscriptions`, `password_resets`, `submitted_videos`, `video_daily_stats`, `earnings`.

---

## 13. MVP Success Metrics

- New registrations, completed-profile rate.
- Searches per day, offers sent, offer response rate.
- Completed campaigns, 7/30-day retention.
- **New:** subscription conversion rate (Free → Pro), withdrawal request volume, average time from "paid" to "withdrawal requested."

---

## 14. Product Risks

1. Incomplete profile data → weaker search relevance.
2. Low chat activity → offers stall before becoming campaigns.
3. No identity verification yet → risk of fake accounts.
4. Cold start problem → hard to reach critical mass on both sides at once.
5. **The payment simulation must not be mistaken for a real one** — every checkout screen carries an explicit "demo mode" label for this reason, and it should stay that way until a real gateway is wired in.

---

## 15. Recommended Development Phases

### Phase 1 — MVP (done)
Auth, profile, search, offers, tracking, chat, dashboards.

### Phase 2 — Monetization scaffolding (done, simulated)
Subscriptions with lazy expiry, dummy checkout + invoices, withdrawal requests, saved payment methods, notification badge, richer analytics.

### Phase 3 — Multi-platform video + state management overhaul (done)
Instagram Reels support alongside TikTok (platform auto-detected from the URL, see §6.4 for the one open caveat); migrated most of the Flutter app from plain `setState` to `flutter_bloc` (Cubit) — see `ARCHITECTURE.md` §4.1b and `design-patterns.md` for the full breakdown of which screens got a shared Cubit, which got a screen-scoped one, and which were deliberately left alone.

### Phase 4 — Real integrations (next)
- Real payment gateway (Midtrans/Xendit/DOKU) replacing every dummy checkout screen.
- Real email delivery for password reset.
- Confirm the exact Instagram RapidAPI endpoint/field mapping against a subscribed product (§6.4).
- Push notifications (FCM/APNs) instead of pull-based polling.
- Admin tooling for withdrawal processing and account verification.
- Rating/review after campaign completion.

---

## 16. Definition of Done (Current State)

The product today satisfies:
- Users can register, log in (including via Google), and log out.
- Influencers and brands can create and edit profiles with photos.
- Brands can search for influencers and vice versa.
- Campaigns can be created, applied to, approved/rejected, and tracked to completion with real performance data from TikTok or Instagram Reels.
- Chat and notifications work end-to-end.
- Subscriptions, invoices, withdrawals, and saved payment methods work end-to-end **as a simulation** — no real money moves yet.
- All of the above is stored securely in MySQL/MariaDB behind a JWT-authenticated API.

---

## 17. Summary

Konekta connects influencers and brands around **discovery, campaign management, chat, and now a full (simulated) monetization loop** — subscriptions, payments, and payouts. The immediate next milestone is swapping the dummy checkout screens for a real payment gateway without needing to change any of the surrounding product flow, since every seam for that swap is already isolated and documented in `ARCHITECTURE.md` §7.