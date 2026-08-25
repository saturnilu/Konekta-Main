# Konekta 🔗

A mobile platform connecting brands with micro-influencers — from campaign discovery, application, video-performance tracking, in-app chat, subscriptions, and payouts, all in one app.

---

## Project Structure

```
konekta-main/
├── backend/          # Node.js + Express + TypeScript API
├── konekta/          # Flutter mobile app
├── database/         # SQL schema (+ migration scripts)
└── README.md
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (Dart) — `http` package + a custom `ApiClient`; state managed with `flutter_bloc` (Cubit) for most screens, with a thin `InheritedWidget` (`AppScope`) still handling dependency injection (session, API client, repositories) |
| Backend | Node.js + Express.js + TypeScript, layered as routes → controllers → services |
| Database | MySQL 8.x / MariaDB 10.x (developed/tested against MariaDB) |
| Auth | JWT (`jsonwebtoken`) + `bcryptjs` + Google OAuth 2.0 (`google-auth-library`) |
| Validation | Zod |
| File upload | `multer` (avatar/logo photos, stored on local disk — see note below) |
| PDF generation | `pdf` + `printing` (Flutter side, for downloadable invoices) |
| External | RapidAPI TikTok (`tiktok-api23`) + RapidAPI Instagram scraper (view/like/share/comment stats for submitted videos — see note below) |

> **Note on file storage:** uploaded avatars/logos are written to `backend/uploads/` on local disk. That's fine for local development, but most hosting platforms (Heroku, most containers, etc.) don't persist local disk across deploys/restarts — swap in real object storage (S3, Cloudinary, Supabase Storage) before deploying anywhere that isn't a single long-running VM.

> **Note on payments:** there is **no real payment gateway wired up yet**. Brand subscriptions, influencer subscriptions, and "pay influencer" all go through a clearly-labeled dummy checkout screen (an on-device generated QR code + a "simulate payment" button) purely so the rest of the product flow (invoices, notifications, plan gating) can be built and tested end-to-end. See [`PAYMENTS.md` section in ARCHITECTURE.md](./ARCHITECTURE.md) for exactly what to change when integrating Midtrans/Xendit/DOKU.

> **Note on Instagram Reels support:** video submission accepts both TikTok and Instagram Reel links (`backend/src/services/video_stats.service.ts` auto-detects the platform from the URL). TikTok stat fetching is verified end-to-end against a live RapidAPI subscription. Instagram's field-mapping (views/likes/comments/shares) is based on a real sample response but the exact endpoint path/param name (`REQUEST_PATH`/`REQUEST_PARAM_NAME` in `instagram.service.ts`) has **not** been confirmed against a specific RapidAPI product's docs yet — see the comment above `fetchInstagramStats()` before relying on it in production.

---

## Prerequisites

- Node.js >= 18.x
- Flutter SDK >= 3.10.x
- MySQL >= 8.x or MariaDB >= 10.5 (need `ADD COLUMN/KEY IF NOT EXISTS` support for the migration scripts)

---

## Backend Setup

```bash
cd backend
npm install
```

Create a `.env` file inside the `backend/` folder:

```env
PORT=4000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=konekta
JWT_SECRET=your_jwt_secret
TOKEN_EXPIRY_HOURS=24

# Google OAuth (optional — only needed for "Continue with Google")
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_REDIRECT_URI=http://localhost:4000/auth/google/callback

# RapidAPI for TikTok stats (optional — video submission still works
# without it, stats just stay at 0 until a key is configured)
RAPIDAPI_KEY=
RAPIDAPI_TIKTOK_HOST=tiktok-api23.p.rapidapi.com

# RapidAPI for Instagram Reel stats (optional — same key as above, just a
# different subscribed product/host; see the note on Instagram Reels above)
RAPIDAPI_INSTAGRAM_HOST=

NODE_ENV=development
```

Run the backend:

```bash
npm run dev      # development (auto-reload via ts-node-dev)
npm run build    # compile TypeScript
npm start        # production
```

Server runs at `http://localhost:4000`. Verify:

```bash
curl http://localhost:4000/health
```

---

## Database Setup

**Fresh install:**

```bash
mysql -u root -p -e "CREATE DATABASE konekta CHARACTER SET utf8mb4;"
mysql -u root -p konekta < database/schema.sql
```

**Updating an existing database** (adds new tables/columns without touching existing data — safe to re-run):

```bash
mysql -u root -p konekta < database/migration_2026_08.sql
mysql -u root -p konekta < database/migration_2026_08_v2.sql
```

---

## Flutter Setup

```bash
cd konekta
flutter pub get
```

The API base URL is read from a compile-time define (`lib/core/api_client.dart`), defaulting to `http://localhost:4000`. Override it per-environment instead of editing the source:

```bash
# Android Emulator (10.0.2.2 maps to the host machine's localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000

# Physical device on the same network (use your machine's LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000

# iOS Simulator / Flutter Web
flutter run --dart-define=API_BASE_URL=http://localhost:4000
```

---

## State Management (Flutter)

Most screens use `flutter_bloc` (Cubit) rather than plain `setState`. Two flavors are used, matching whether a screen's data needs to be shared:

| Scope | Registered where | Examples |
|---|---|---|
| **App-wide** (shared by multiple screens) | `main.dart`'s `MultiBlocProvider` | `SessionCubit`, `NotificationCubit`, `SubscriptionCubit`, `InfluencerDashboardCubit`, `BrandDashboardCubit`, `InfluencerAnalyticsCubit`, `BrandAnalyticsCubit` |
| **Screen-scoped** (only one screen ever needs it at a time) | A local `BlocProvider` inside that screen's own widget | `ChatCubit` (one chat room), `WithdrawalCubit` (the Withdraw Earnings screen) |

`AppScope` (an `InheritedWidget`) still exists purely for dependency injection — it hands out the `Session`, `ApiClient`, and a handful of repositories that Cubits and screens construct themselves from. See `ARCHITECTURE.md` §4 for the full picture, and `design-patterns.md` for why each Cubit landed in its specific folder.

---

## Feature Overview

| Area | What's implemented |
|---|---|
| **Auth** | Register, login, logout, Google Sign-In, forgot/reset password (email delivery is stubbed — see `auth.service.ts`), change password |
| **Profile** | Influencer & brand profile CRUD, avatar/logo upload, linked social media accounts (add/remove) |
| **Discovery** | Search/filter influencers and brands; Pro-subscribed influencers get featured placement |
| **Campaigns** | Brand creates offers, influencers apply, brand approves/rejects, video submission with TikTok **or Instagram Reel** stat tracking (platform auto-detected from the URL), progress calculation, "pay" flow with a dummy checkout |
| **Chat** | 1:1 conversations tied to a campaign or started directly from a profile |
| **Notifications** | In-app notification feed + unread-count badge on the bell icon; triggered by new applications, approvals, payments, subscriptions, withdrawals, and new messages |
| **Subscriptions** | Separate plans for brands (Free/Starter/Pro/Enterprise) and influencers (Free/Pro), lazy auto-expiry, dummy QRIS checkout + downloadable invoice |
| **Withdrawals** | Influencers request a payout against their real earned balance; brand never has visibility into "how" it's paid out beyond the saved bank details |
| **Payment Methods** | Brands can save a payment method (label + last 4 digits only — never a full card number) and pick it at checkout instead of re-entering it |
| **Analytics** | Per-role dashboards: views/engagement trends, budget/spend breakdown, application funnel |

---

## API Endpoints

Base URL: `http://localhost:4000`. All protected routes expect `Authorization: Bearer <token>`.

### Auth
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | | Register (influencer or brand) |
| POST | `/auth/login` | | Login |
| POST | `/auth/logout` | ✅ | Logout |
| POST | `/auth/forgot-password` | | Request a reset token |
| POST | `/auth/reset-password` | | Reset password with a token |
| POST | `/auth/change-password` | ✅ | Change password (knows current password) |
| GET | `/auth/google` | | Start Google OAuth (web) |
| POST | `/auth/google/idtoken` | | Google Sign-In (mobile, native flow) |

### Profile
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/profile/me` | ✅ | Get current user's profile |
| PUT | `/profile/me` | ✅ | Update profile |
| POST | `/profile/avatar` | ✅ | Upload avatar/logo photo (multipart) |
| POST | `/profile/influencer/social-media` | ✅ | Add/upsert a linked social account |

### Discovery
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/influencers` | | Search influencers (Pro-boosted first) |
| GET | `/influencers/:id` | | Influencer detail |
| GET | `/brands` | | Search brands |
| GET | `/brands/:id` | | Brand detail |

### Offers / Campaigns
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/offers` | | List public campaigns |
| POST | `/offers` | ✅ | Create campaign (brand) |
| GET | `/offers/mine` | ✅ | List the current user's campaigns |
| GET | `/offers/applications/mine` | ✅ | Full application history (influencer) |
| POST | `/offers/:id/applicants` | ✅ | Apply to a campaign (influencer) |
| GET | `/offers/:id/applicants` | ✅ | List applicants (brand) |
| PATCH | `/offers/:id/applicants/:appId/status` | ✅ | Approve/reject/shortlist an applicant |
| POST | `/offers/:id/videos` | ✅ | Submit a TikTok or Instagram Reel link (influencer) — platform auto-detected from the URL |
| GET | `/offers/:id/videos/brand/:influencerId` | ✅ | Progress detail for one applicant (brand) |
| POST | `/offers/:id/videos/brand/:influencerId/pay` | ✅ | Mark an applicant as paid |
| POST | `/offers/:id/videos/brand/:influencerId/recalculate` | ✅ | Re-aggregate stats/progress |
| POST | `/offers/:id/videos/:videoId/refresh` | ✅ | Re-fetch stats for one video |

### Chat
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/conversations` | ✅ | List conversations (with unread-relative "other user" info) |
| POST | `/conversations` | ✅ | Start/reuse a conversation with another user |
| GET | `/conversations/:id/messages` | ✅ | Message history |
| POST | `/conversations/:id/messages` | ✅ | Send a message |

### Notifications
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/notifications` | ✅ | List notifications |
| GET | `/notifications/unread-count` | ✅ | Count for the bell badge |
| POST | `/notifications/:id/read` | ✅ | Mark one as read |
| POST | `/notifications/read-all` | ✅ | Mark all as read |

### Subscriptions
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/subscriptions/plans` | optional | List plans (role-aware if logged in) |
| GET | `/subscriptions/me` | ✅ | Current plan status |
| POST | `/subscriptions/subscribe` | ✅ | Subscribe (blocked if a paid plan is still active) |
| POST | `/subscriptions/cancel` | ✅ | Cancel (blocked until the current period ends) |

### Withdrawals (influencer)
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/withdrawals/balance` | ✅ | Available balance vs. total earned/withdrawn |
| GET | `/withdrawals/mine` | ✅ | Withdrawal request history |
| POST | `/withdrawals` | ✅ | Request a withdrawal |

### Payment Methods (brand)
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/payment-methods/mine` | ✅ | List saved payment methods |
| POST | `/payment-methods` | ✅ | Add one |
| DELETE | `/payment-methods/:id` | ✅ | Remove one |
| POST | `/payment-methods/:id/default` | ✅ | Set as default |

### Dashboard & Analytics
| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/dashboard/influencer` | ✅ | Influencer home summary |
| GET | `/dashboard/brand` | ✅ | Brand home summary |
| GET | `/dashboard/brand/transactions` | ✅ | Paginated payment history |
| GET | `/analytics/influencer` | ✅ | Influencer analytics (date range gated by plan) |
| GET | `/analytics/brand` | ✅ | Brand analytics |

---

## Known Limitations (by design, not bugs)

- **No real payment gateway.** Every "payment" in the app (subscriptions, paying an influencer) is a labeled simulation. See `ARCHITECTURE.md` for the exact spots to wire in a real provider.
- **No real email delivery.** Password reset tokens are logged server-side and, outside `NODE_ENV=production`, echoed back in the API response so the flow is testable without an inbox.
- **Withdrawal processing is manual.** A request just sits as `pending` until someone flips it to `completed`/`rejected` directly in the database — there's no admin UI for this yet.