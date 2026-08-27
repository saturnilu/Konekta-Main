# Konekta Architecture Document

## 1. Overview

Konekta is a two-sided mobile platform connecting **influencers** and **brands** for endorsement campaigns.

| Layer | Technology |
|---|---|
| **Mobile** | Flutter (Dart) |
| **Backend** | Express.js (TypeScript) |
| **Database** | MySQL 8.x / MariaDB 10.x |

This document describes the architecture **as actually implemented in the codebase**, not an aspirational design. If you're comparing this against an earlier draft that mentioned BLoC/Cubit, a `features/` folder with `data/domain/presentation` layers, or design patterns like Builder/Adapter/Facade/Observer/State: those described a parallel scaffold (`backend/src/modules/*` and `backend/src/core/*`, plus a planned Flutter structure) that was never wired into the running app. `app.ts` only ever imported from the flat `middlewares/`, `utils/`, `controllers/`, `services/`, and `routes/` folders below, so `modules/` and `core/` sat alongside the real app as unreferenced dead code. They've now been deleted outright so the folder tree matches what's actually imported and executed, rather than just relying on a doc to say so.

---

## 2. Architecture Decision: Monolith vs. Micro-service

**Chosen: Modular Monolith.**

| Factor | Why monolith wins here |
|---|---|
| **Module coupling** | Auth, notifications, and chat are referenced from nearly every other module, so splitting them out would mean a lot of cross-service calls for little benefit at this scale. |
| **Team size / velocity** | A single deploy, single database, and `console.log`-level debugging keeps iteration fast. |
| **Data consistency** | Every write goes through the same MySQL instance with foreign keys, so no distributed transactions are needed. |
| **Still modular** | Each feature is its own `controller.ts` / `service.ts` / `routes.ts` triplet, so a genuinely hot module (e.g. chat, if it needs WebSockets at scale) can be extracted later without a full rewrite. |

---

## 3. Backend Architecture

### 3.1 Actual Folder Structure

```
backend/src/
├── server.ts               # process entry point
├── app.ts                  # Express app: middleware + route mounting
├── config/
│   ├── db.ts                # mysql2 connection pool
│   ├── env.ts                # process.env parsing
│   └── googleOAuth.ts         # Google OAuth2Client setup
├── middlewares/
│   ├── auth.ts               # requireAuth / optionalAuth (JWT verify)
│   └── error.ts              # centralized error → JSON response
├── utils/
│   ├── apiError.ts            # ApiError(status, message)
│   ├── response.ts            # ok()/created() JSON envelope helpers
│   └── username.ts            # collision-safe username generator
├── controllers/                # HTTP layer: parse request, call service, shape response
├── services/                   # business logic + SQL queries
└── routes/                     # Router() per feature, mounted in app.ts
```

There is no `modules/` or `core/` folder in the live app. An earlier iteration of the project had that scaffold (`campaignBuilder.ts` / `eventBus.ts` / `socialMediaFacade.ts` under `modules/`, plus a second copy of the auth middleware, error handler, and `ApiError` class under `core/`), but `app.ts` and every file it actually pulls in only ever imported from the flat structure above, so both folders were pure dead code and have been deleted. Everything the app actually does lives in the flat `controllers/services/routes` triplets above.

**Why this is called out explicitly:** the `core/` copy wasn't just inert, it was a trap. It re-implemented `requireAuth`, `errorHandler`, and `ApiError` closely enough to look interchangeable with the real versions in `middlewares/`/`utils/`, down to matching export names. Code written against `core/`'s versions (imports, or tests asserting on `instanceof ApiError`) would type-check and even run, but would silently be checking against a class or function the live app never touches, since the two `ApiError` classes aren't the same identity at runtime. This is exactly the kind of thing worth a fresh grep for (`grep -rn "from '.*core/"` from `backend/src`) after any large refactor, before assuming a stray import is harmless.

### 3.2 Request Flow

```
Client (Flutter)
    │
    ▼
Express Router (routes/*.ts)
    │
    ▼
Middleware, requireAuth (JWT verify) and/or Zod schema validation
    │
    ▼
Controller, parse req, call service, wrap result via ok()/created()
    │
    ▼
Service, SQL queries via the shared mysql2 pool, business rules
    │
    ▼
MySQL/MariaDB
    │
    ▼
JSON response → errorHandler middleware if anything threw
```

### 3.3 Backend Modules (as actually mounted in `app.ts`)

| Module | Controller | Service | Responsibilities |
|---|---|---|---|
| Auth | `auth.controller.ts`, `googleAuth.controller.ts` | `auth.service.ts` | Register/login/logout, password reset & change, Google Sign-In, collision-safe username generation |
| Profile | `profile.controller.ts`, `avatar.controller.ts` | `profile.service.ts` | Profile CRUD, avatar upload (`multer`, local disk), social account upsert |
| Discovery | `discovery.controller.ts` | `discovery.service.ts` | Search/filter influencers & brands, Pro-tier featured ordering |
| Offers | `offer.controller.ts`, `video.controller.ts` | `offer.service.ts`, `video_stats.service.ts` (platform dispatcher), `tiktok.service.ts`, `instagram.service.ts` | Campaign CRUD, applications, video submission + TikTok/Instagram stat fetch, payment marking |
| Chat | `chat.controller.ts` | `chat.service.ts` | Conversations (deduped both-directions), messages, new-message notifications |
| Notifications | `notification.controller.ts` | `notification.service.ts` | Feed, unread count, mark read/all-read |
| Dashboard/Analytics | `dashboard.controller.ts`, `analytics.controller.ts` | `dashboard.service.ts` | Home summaries, trend charts, transaction history |
| Subscriptions | `subscription.controller.ts` | `subscription.service.ts` | Role-aware plans, lazy expiry, invoice numbers |
| Withdrawals | `withdrawal.controller.ts` | `withdrawal.service.ts` | Influencer payout requests against real earned balance |
| Payment Methods | `payment_method.controller.ts` | `payment_method.service.ts` | Brand's saved payment methods (display-only, no real card data) |

### 3.4 Technology Stack

| Purpose | Library |
|---|---|
| Framework | Express.js |
| Language | TypeScript |
| Database driver | `mysql2/promise` |
| Validation | Zod |
| Auth | `jsonwebtoken`, `bcryptjs`, `google-auth-library` |
| File upload | `multer` |
| Dev server | `ts-node-dev` |

---

## 4. Frontend Architecture (Flutter)

### 4.1 Actual Folder Structure

```
konekta/lib/
├── main.dart                  # entry point, builds AppScope + MultiBlocProvider + MaterialApp
├── main_screen.dart           # bottom-nav shell (IndexedStack keeps tabs alive)
│
├── core/
│   ├── api_client.dart         # thin http wrapper: get/post/put/delete/uploadFile
│   ├── app_scope.dart          # InheritedWidget, dependency injection only (see §4.2)
│   ├── session.dart            # token/role/name persistence (SharedPreferences)
│   ├── session_cubit.dart      # reactive wrapper around Session, see §4.3
│   ├── theme.dart              # KonektaColors + KonektaTheme (single source of truth for colors)
│   ├── format.dart             # number/date formatting helpers
│   └── widgets.dart            # small shared widgets (e.g. GradientButton)
│
├── data/
│   ├── models/                 # plain Dart classes with fromJson()
│   └── repositories/            # one class per backend module, wraps ApiClient calls
│
├── auth/                       # onboarding, login, register, forgot/reset password
├── Opening/                    # splash screen (animated hub-connect intro)
├── influencer/                 # dashboard, explore, analytics, profile, earnings, subscription
│                               #   each with its own Cubit alongside the screen it serves
├── brand/                      # dashboard, explore, analytics, profile, subscription, settings
│                               #   same per-feature Cubit pattern as influencer/
├── campaign/                   # shared campaign detail/room/performance screens
├── chat/                       # conversation list + chat room + ChatCubit (used by both roles)
├── subscription/               # SubscriptionCubit + dummy checkout + success dialog, shared by
│                               #   both roles' subscription screens (backend has one role-
│                               #   dispatching service too, see §3.3/design-patterns.md)
├── notification/               # notifications feed, bell icon widget, NotificationCubit
└── settings/                   # shared Security / Help Center screens
```

### 4.1a Why `subscription/` Is a Top-Level Folder

Subscription screens are genuinely different UI per role (`influencer/subscription/influencer_subscription_screen.dart` vs. `brand/subscription/subscription_screen.dart`), but the underlying state and logic are identical, with the same plan-loading, same checkout flow, same backend endpoint with role-dispatch (§3.3). Duplicating a whole Cubit per role would mean two copies of the same logic to keep in sync, so `SubscriptionCubit` lives in a neutral top-level folder (matching how `chat/` already worked before this) and both role-specific screens import it. The two screens even share widgets (`subscription/subscription_widgets.dart`, namely `CurrentPlanCard`, `PlanCard`, `SubscriptionErrorState`) that were previously copy-pasted verbatim into each screen's file.

### 4.1b State Management: BLoC (Cubit)

An earlier version of this document said flatly "no BLoC/Cubit anywhere in the app." That changed, and most screens were migrated to `flutter_bloc` (specifically `Cubit`, not full `Bloc` with events) over several passes. Two distinct scopes are used, and the distinction matters:

**App-wide Cubits** are registered once in `main.dart`'s `MultiBlocProvider`, reachable from anywhere via `context.read`/`context.watch`/`BlocBuilder`:

| Cubit | Location | Replaces |
|---|---|---|
| `SessionCubit` | `core/session_cubit.dart` | Screens reading `AppScope.of(context).session.name` directly (which never updated reactively, so editing your name wouldn't update a dashboard greeting until next login) |
| `NotificationCubit` | `notification/notification_cubit.dart` | Six-plus separate unread-count fetches (one per bell icon instance) that could disagree with each other |
| `SubscriptionCubit` | `subscription/subscription_cubit.dart` | Duplicated plan/current-status loading logic in both role's subscription screens |
| `InfluencerDashboardCubit` | `influencer/dashboard/influencer_dashboard_cubit.dart` | Manual `_load()` + local fields |
| `BrandDashboardCubit` | `brand/dashboard/brand_dashboard_cubit.dart` | The single screen with the most "reload after navigating to a screen that might have changed something" call sites in the app (5 of them) |
| `InfluencerAnalyticsCubit` / `BrandAnalyticsCubit` | `influencer/analytics/`, `brand/analytics/` | Near-identical manual tab-state + fetch logic duplicated across both role's analytics screens |

**Screen-scoped Cubits** are deliberately *not* in `main.dart`, created via a local `BlocProvider` inside the one screen that uses them, because there's no "shared across multiple simultaneously-open screens" state to centralize:

| Cubit | Location | Why scoped, not global |
|---|---|---|
| `ChatCubit` | `chat/chat_cubit.dart` | Only one chat room is ever open at a time, and state (which conversation, its messages) is inherently per-instance |
| `WithdrawalCubit` | `influencer/earnings/withdrawal_cubit.dart` | Only reachable from one place (influencer dashboard), and no other screen needs its balance/history state |

The scoped pattern: the screen itself is a thin `StatelessWidget` whose only job is to build a fresh Cubit and hand it to the real view:

```dart
class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({super.key, this.conversationId, this.otherUserId, this.otherUserName});
  // ...
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider(
      create: (_) => ChatCubit(chatRepo: scope.chatRepo, discoveryRepo: DiscoveryRepository(scope.api), role: scope.role)
        ..init(conversationId: conversationId, otherUserId: otherUserId, otherUserName: otherUserName),
      child: const _ChatRoomView(),
    );
  }
}
```

This is safe from the "re-created every rebuild" trap because the wrapper is a `StatelessWidget` reached via `Navigator.push`, so it's built once per navigation, and `BlocProvider`'s `create` callback is cached by its own internal `State`, not re-invoked just because an ancestor rebuilds.

**What didn't get a Cubit, on purpose:** a few genuinely screen-local, non-duplicated concerns were left on plain `setState` rather than forced into a Cubit for its own sake, like `_AllCampaignsScreenState` (a private class inside `brand_dashboard_screen.dart` showing the full campaign list) keeps its own local `_loading`/`_items` state, since only that one screen ever needs it and wrapping it in a Cubit would add ceremony without removing any duplication.

There is no `features/<name>/data|domain|presentation` Clean Architecture split in this app, and Cubits live directly alongside the screens they serve (or in a neutral top-level folder when shared by both roles), not in a separate `blocs/` folder grouped by file-type. See `design-patterns.md` for the reasoning.

### 4.2 Dependency Injection: `AppScope`

`AppScope` is an `InheritedWidget` created once in `main.dart` and wrapped around the whole app. Its role narrowed once Cubits took over state: it now exists purely to hand out the session and repositories that Cubits and screens construct themselves from, and it holds no app state of its own.

```dart
class AppScope extends InheritedWidget {
  final Session session;
  final ApiClient api;
  final AuthRepository authRepo;
  final ProfileRepository profileRepo;
  final ChatRepository chatRepo;
  final NotificationRepository notificationRepo;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }
}
```

`SubscriptionRepository` is deliberately **not** on this list, since once `SubscriptionCubit` existed, nothing needed to reach the repository directly anymore, so exposing it on `AppScope` too would just be a second, redundant way to get to the same thing. `DashboardRepository`, `CampaignRepository`, and `AnalyticsRepository` are constructed once in `main.dart` and passed straight into the relevant Cubits' constructors, and they never touch `AppScope` at all. Repositories still instantiated ad-hoc wherever needed (e.g. `PaymentMethodRepository`, `WithdrawalRepository`, `DiscoveryRepository`) are for the handful of things that haven't been pulled into a Cubit.

**Important lifecycle rule:** `AppScope.of(context)` requires the `InheritedWidget` to already be attached to the tree. Calling it synchronously inside `initState()`, even indirectly through an `async` method's pre-`await` code, throws `dependOnInheritedWidgetOfExactType<AppScope>() was called before ... initState() completed`. Every screen in this app that loads data on open follows this pattern instead:

```dart
class _MyScreenState extends State<MyScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load(); // safe here, since AppScope.of(context) works fine
    }
  }
}
```

This exact bug (calling `AppScope.of(context)` from `initState()`, sometimes nested two calls deep before any `await`) was found and fixed repeatedly across the app during development. If a screen appears to load forever or silently shows no data on first open but works after a manual refresh, check this pattern first.

### 4.3 Data Flow

Two shapes exist side by side, depending on whether a screen's data is Cubit-backed:

**Cubit-backed screens** (most of the app now):

```
User action (tap button)
    │
    ▼
context.read<XCubit>().someMethod()
    │
    ▼
Cubit calls a Repository method
    │
    ▼
Repository calls ApiClient.get/post/put/delete
    │
    ▼
HTTP request → Backend → JSON response → Model.fromJson()
    │
    ▼
Cubit calls emit(newState) → every BlocBuilder/context.watch<XCubit>()
listening rebuilds, including other screens watching the same Cubit
```

The key difference from the old flow: `emit()` fans out to *every* widget watching that Cubit, not just the one that triggered the action. This is what let the "reload after navigating back" pattern (§ design-patterns.md, "Reload-on-Return") be removed for anything backed by an app-wide Cubit, like approving an applicant on the Pending Approvals screen now updates the dashboard's counts the moment you navigate back, because both screens watch the same `BrandDashboardCubit`, without either screen having to know the other exists.

**Plain `setState` screens** (the few genuinely-local ones, e.g. `_AllCampaignsScreenState`):

```
User action (tap button)
    │
    ▼
StatefulWidget calls a Repository method directly
    │
    ▼
Repository calls ApiClient.get/post/put/delete
    │
    ▼
JSON response → Model.fromJson()
    │
    ▼
setState(() => _data = model) → only this widget rebuilds
```

### 4.4 Technology Stack

| Purpose | Package |
|---|---|
| HTTP client | `http` |
| State management | `flutter_bloc` (Cubit) + `equatable` (value-equality for state classes, so `Cubit` doesn't re-emit/rebuild for a state that's structurally identical) |
| Local storage | `shared_preferences` |
| Charts | `fl_chart` |
| Fonts | `google_fonts` |
| Images | `image_picker` |
| QR codes | `qr_flutter` (dummy checkout screens) |
| PDF | `pdf` + `printing` (downloadable invoices) |
| Links | `url_launcher` |
| Google Sign-In | `google_sign_in` |

---

## 5. Database Architecture

### 5.1 Schema Overview

```
users
├── influencer_profiles (1:1)   # includes plan, plan_expires_at, payout_bank/account
├── brand_profiles      (1:1)   # includes `plan`
├── social_media_accounts (1:N)
├── offers               (1:N, as brand_user_id)
├── campaign_applicants  (N:N between offers and influencer users)
├── submitted_videos     (1:N per applicant) # includes `platform` enum('tiktok','instagram') and `comments_count`, added alongside Instagram Reels support
├── video_daily_stats    (daily rollup per influencer)
├── conversations        (1:N per participant, deduped both directions)
├── messages             (1:N per conversation)
├── notifications        (1:N)
├── earnings             (1:N), actual paid-out records
├── withdrawals          (1:N), payout requests against earnings
├── brand_subscriptions  (1:N), brand plan history
├── brand_payment_methods (1:N), saved display-only payment methods
└── password_resets      (1:N), single-use tokens
```

### 5.2 Design Principles

| Principle | Implementation |
|---|---|
| Single DB | One `konekta` schema, all tables together |
| Foreign keys | InnoDB constraints (`ON DELETE CASCADE` from `users`) |
| Money fields | `DECIMAL(15,2)`, and note that `mysql2` returns these (and `SUM()` aggregates) as **strings**, not numbers, so every controller that sends one to the client wraps it in `Number(...)` first. Forgetting this wrapper was the root cause of at least two "type 'String' is not a subtype of type 'num'" crashes found during development, see §7. |
| Timestamps | `created_at` (and `updated_at` where rows are mutable) on every table |
| Charset | `utf8mb4_unicode_ci` |

### 5.3 Notable Non-Obvious Columns

| Column | Why it's there |
|---|---|
| `influencer_profiles.plan_expires_at` | Drives lazy auto-downgrade: any read of the subscription status checks this first and flips `plan` back to `free` if it's passed, rather than needing a cron job. |
| `offers.max_creators` | `0` means unlimited. `dashboard`/`analytics` "Total Budget" multiplies `budget * GREATEST(max_creators, 1)` to represent the campaign's maximum possible spend, not just the per-creator reward. |
| `campaign_applicants.status = 'completed'` | Means *paid*, not "campaign finished", and the parent `offers.status` deliberately does **not** auto-flip when one applicant is paid, since a campaign can have multiple creators at different stages simultaneously. |
| `brand_payment_methods.last4` | Exactly 4 digits, display-only. There is no full card number, expiry, or CVV anywhere in this schema, see §7 on payments. |
| `submitted_videos.platform` | `enum('tiktok','instagram')`, detected from the URL at submit time (never trusted from client input) and stored so `refreshAllVideosForUser()` knows which provider to re-query later without re-parsing the URL every time. |

---

## 6. Communication Patterns

### 6.1 REST over HTTP

All Flutter ↔ Backend communication is plain REST/JSON (no GraphQL, no WebSockets). Chat and notifications are pull-based (the client re-fetches on screen open / pull-to-refresh), not push/real-time.

### 6.2 Auth Flow

```
Client                          Backend                       Database
  │── POST /auth/register ─────>│                               │
  │                              │── INSERT users (+ profile) ─>│
  │<── { token, user } ──────────│                               │
  │                              │                               │
  │── GET /profile/me ──────────>│                               │
  │   (Authorization: Bearer)    │── verify JWT (requireAuth) ──│
  │                              │── SELECT user + profile ─────>│
  │<── profile JSON ──────────────│                               │
```

Tokens are stateless JWTs (`TOKEN_EXPIRY_HOURS`, default 24h), so there's no server-side session table, so "logout" is purely a client-side token deletion.

### 6.3 Notification Delivery

Notifications are created inline by the service that causes them (e.g. `offer.service.ts` pushes one when someone applies, `chat.service.ts` pushes one on a new message, and `subscription.service.ts` pushes one on a successful upgrade). There's no event bus, and each service calls `notificationService.push(userId, {...})` directly. The client polls `GET /notifications/unread-count` to badge the bell icon and re-fetches the full list when the notifications screen opens.

---

## 7. Payments, What's Real vs. Simulated

**Nothing in this app moves real money.** This section exists so a future integration doesn't have to reverse-engineer where the seams are.

| Flow | What happens today | What to change for a real gateway |
|---|---|---|
| Brand/influencer subscribing | `DummyQrisCheckoutScreen` generates a random-looking QR client-side and a "simulate payment" button calls `subscription.service.ts`'s `subscribe()` directly | Have the backend create a real transaction with the gateway and return its `qr_string`/`checkout_url`; confirm via the gateway's webhook, not a client button |
| Brand paying an influencer | `BrandPayCheckoutScreen` shows the influencer's saved payout bank details (if any) and a "confirm" button calls the `pay` endpoint directly | Same idea, a real disbursement API call, confirmed server-side before flipping `campaign_applicants.status` to `completed` |
| Influencer withdrawing earnings | Inserts a `withdrawals` row with `status='pending'`, and nothing else happens automatically | Wire a disbursement API (Midtrans/Xendit Disbursement, DOKU) to actually move money, then flip the row to `completed` on success |
| Brand's saved "payment methods" | `brand_payment_methods` stores a label + last 4 digits only | Store the gateway's tokenized payment-method reference instead of any raw card data, and never store a full card number/CVV/expiry regardless of gateway |

---

## 8. Migration Path: Monolith → Micro-service

If traffic ever justifies it:

| Candidate | Trigger to split |
|---|---|
| Chat | Needs real-time (WebSocket) delivery instead of polling |
| Notifications | Needs push notifications (FCM/APNs) at scale |
| Video stats fetching (TikTok/Instagram) | RapidAPI rate limits become a bottleneck, so it could become a queued background worker. Adding a third platform (e.g. YouTube Shorts) means adding one more provider file matching `VideoStats` in `video_stats.service.ts`, and no changes are needed to `refreshAllVideosForUser()`, the controller, or the client. |

Since each module is already a self-contained `controller + service + routes` triplet talking to shared tables, extracting one means: stand up a new Express app with that triplet, point it at the same (or a copied) database, and update the Flutter repository's base URL for that feature.

---

## 9. Deployment Architecture

The live demo splits across two platforms, chosen for what each is actually good at, with Railway handling anything that needs a persistent process/database and Vercel serving the static Flutter web build:

```
┌─────────────────────────────┐         ┌──────────────────────────────┐
│  Railway project             │         │  Vercel                        │
│                              │         │                                │
│  ┌────────────┐   internal   │         │  ┌──────────────────────────┐  │
│  │  Backend    │◄───network──┤         │  │ app_frame.html (index)    │  │
│  │  (Express)  │   3306      │         │  │   └─ <iframe> ──► app.html│  │
│  └─────┬──────┘              │         │  │        (real Flutter build)│ │
│        │                     │         │  └──────────────────────────┘  │
│  ┌─────▼──────┐              │         └──────────────────────────────┘
│  │  MySQL      │              │                       │
│  └────────────┘              │                       │ HTTPS (API_BASE_URL)
└──────────────┬───────────────┘                       │
               │  public domain (Settings → Networking)  │
               └─────────────────────────────────────────┘
```

### 9.1 Why Backend + Database Share a Railway Project

Putting both in the same project means they can talk over Railway's **private network** (`mysql.railway.internal:3306`) instead of the public internet. Two consequences worth knowing:

- **It's free.** Railway bills egress on *public* traffic, and private-network traffic between services in the same project doesn't hit that meter.
- **The internal hostname isn't reachable from your own machine.** Importing the schema from a local `mysql` client or Workbench needs the **public** proxy host/port (Settings → Networking → enable Public Networking on the MySQL service), and that's a one-time step for setup, separate from what the backend itself uses at runtime.

### 9.2 Startup Safety Check: `JWT_SECRET`

The backend's config refuses to start in production if `JWT_SECRET` is missing or looks like a placeholder, and this surfaces as `[FATAL] JWT_SECRET must be set to a secure random value in production!` in the deploy logs rather than silently running with a guessable secret. This is a deliberate fail-fast guard (see `design-patterns.md`'s "Fail-Fast Startup Guard" pattern), not a bug, and the fix is always to set a real random `JWT_SECRET` env var, never to work around the check.

### 9.3 CORS in Production

`app.ts` reads `ALLOWED_ORIGINS` (comma-separated) and falls back to `'*'` if it's unset, so a public demo needs zero CORS configuration by default. Set `ALLOWED_ORIGINS` explicitly only when the API should be restricted to specific known frontend domains.

### 9.4 The Flutter Web "Phone Frame"

`konekta/build_web.sh` (invoked by `konekta/vercel.json`'s `buildCommand`) does more than a plain `flutter build web`:

1. Installs the Flutter SDK on Vercel's build machine (not preinstalled there).
2. Runs the normal build, using `konekta/web/index.html`, the *unmodified* Flutter template, as the entrypoint.
3. Renames that output to `app.html`, then copies `konekta/web/app_frame.html` in as the new `index.html`.

The result: what actually ships as `index.html` is a small wrapper page with an `<iframe src="app.html">` sized and decorated like a phone, and the real Flutter app runs inside that iframe, untouched.

**Why an iframe instead of just constraining `<body>` with CSS:** Flutter Web sizes its rendering surface based on the *browser viewport* it's running in, not the CSS box of whatever element it's attached to. An earlier attempt at this (styling `<body>` directly to a fixed width/height) produced a stretched, misaligned result, because Flutter didn't pick up the constraint. An `<iframe>` gives Flutter a genuinely separate `window`/viewport to measure against, so it reliably renders at exactly the iframe's dimensions regardless of what CSS surrounds it.

**Why the notch/home-indicator live in the frame's bezel padding, not inside the screen area:** an earlier version reserved a solid black strip *inside* the phone screen for these decorations so they couldn't overlap app content. That was technically correct, but it visibly ate into the usable screen area with plain black bars. Moving them into the outer bezel (the padding around the rounded screen rect, outside the iframe's box entirely) gets the same "never overlaps app content" guarantee for free, since nothing can overlap the iframe's content if it isn't drawn inside the iframe's box, without sacrificing any visible screen space.

**Why it disables itself under 560px width:** the frame is a presentation choice for people reviewing the demo on a desktop monitor. Below 560px (an actual phone's browser), `app_frame.html`'s media query drops the decoration and sizing entirely, so the same link opened on a real phone just shows the app full-screen like any other mobile web page, and no one accidentally gets a phone-inside-a-phone.

### 9.5 Google Sign-In: Two Different Domains, Two Different Settings

This one has bitten real setups, so it's worth stating explicitly: `GOOGLE_REDIRECT_URI` (a *backend* env var) and the OAuth client's "Authorized JavaScript origins" (a *Google Cloud Console* setting) point at two different domains and live in two different places:

| Setting | Points at | Configured in |
|---|---|---|
| `GOOGLE_REDIRECT_URI` | The **backend's** domain, since it's the backend that exchanges the OAuth code for a token | Railway env vars |
| Authorized JavaScript origins | The **frontend's** domain, since it's what lets the sign-in flow start from the page the person is looking at | Google Cloud Console → Credentials |

Pointing `GOOGLE_REDIRECT_URI` at the Vercel domain (an easy mistake, since that's the domain people actually visit) breaks the flow, since nothing at that address knows how to complete an OAuth exchange.