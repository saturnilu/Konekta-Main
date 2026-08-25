# Design Patterns — Konekta

This document explains the patterns actually applied across the codebase — which file uses each one, why, and how.

> **A note on an earlier version of this document:** a previous draft described a Builder pattern (`campaignBuilder.ts`), a State pattern (`campaignState.ts`), an Adapter/Facade pair for social media APIs (`socialMediaAdapters.ts` / `socialMediaFacade.ts`), and an Observer-based event bus (`eventBus.ts`). Those files existed in `backend/src/modules/*`, but `app.ts` never imported that folder — none of it ever ran. It's since been deleted. There *is* now a real Adapter in the codebase — see Backend Pattern 8 below — it just isn't the one from that earlier draft. Everything below describes patterns in code that's actually on the request path.

---

## Backend Patterns

### 1. Layered Architecture (Route → Controller → Service)

**Where:** every feature, e.g. `routes/offer.routes.ts` → `controllers/offer.controller.ts` → `services/offer.service.ts`

**Why:** keeps HTTP concerns (parsing the request, status codes, response shape) separate from business logic (SQL queries, validation rules, cross-table writes). A controller method is almost always this shape:

```typescript
async setApplicationStatus(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.user) throw new ApiError(401, 'Unauthorized');
    const result = await offerService.setApplicationStatus(/* ...parsed args */);
    return ok(res, result, 'Status updated');
  } catch (e) { next(e); }
}
```

Services never touch `req`/`res` — they take plain arguments and return plain objects, which makes them independently testable and reusable (e.g. `subscriptionService.getBalance()` is called both from the HTTP controller and internally from `requestWithdrawal()`).

### 2. Centralized Error Handling

**Where:** `middlewares/error.ts`, `utils/apiError.ts`

**Why:** every controller's `catch (e) { next(e); }` funnels into one Express error-handling middleware. A service throws `new ApiError(404, 'Offer not found')` and the middleware turns that into a consistent `{ success: false, message }` JSON response with the right status code — no controller repeats that formatting logic.

### 3. Singleton Connection Pool

**Where:** `config/db.ts`

```typescript
export const pool: Pool = mysql.createPool({ /* ... */ });
```

**Why:** one shared `mysql2` pool is created at module load and imported everywhere (`import { pool } from '../config/db'`). Every service reuses the same connection pool instead of opening a new connection per request.

### 4. Role-Based Strategy Dispatch

**Where:** `services/subscription.service.ts`

**Why:** brands and influencers have different plans, different tables (`brand_subscriptions` vs. a `plan` column on `influencer_profiles`), and different rules — but the controller shouldn't need an `if (role === ...)` at every call site. The service exposes one role-agnostic entry point that dispatches internally:

```typescript
async subscribe(userId: number, role: PlanRole, planId?: number, planCode?: string) {
  return role === 'influencer'
    ? this.subscribeInfluencer(userId, planId, planCode)
    : this.subscribeBrand(userId, planId, planCode);
}
```

The same shape is used for `getCurrent()` and `cancel()`. Adding a third role (if the app ever needed one) means adding one more branch here, not hunting down every call site.

### 5. Lazy Evaluation (Expire-on-Read)

**Where:** `services/subscription.service.ts` — `_expireInfluencerIfNeeded()` / `_expireBrandIfNeeded()`

**Why:** subscriptions need to "expire" after their period ends and fall back to the free plan, but there's no background job scheduler in this app. Instead, every read of the subscription status checks the expiry timestamp first and flips the plan back to `free` (and revokes the `is_verified` badge) if it's already passed, before returning:

```typescript
async getCurrentInfluencer(influencerUserId: number) {
  await this._expireInfluencerIfNeeded(influencerUserId);
  // ...then read and return the (now-correct) current plan
}
```

This is also called before allowing a *new* subscribe/cancel action, so a stale "still active" row can never block a legitimate plan change. The tradeoff, noted directly in the code, is that a plan that expired 5 minutes ago will show as expired the next time *anyone* reads it — there's no proactive notification the moment it lapses without a real scheduled job.

### 6. Idempotent Writes via `INSERT ... ON DUPLICATE KEY UPDATE`

**Where:** `services/profile.service.ts` (`addSocialMedia`), `services/tiktok.service.ts` (`upsertDailyStats`), `services/withdrawal.service.ts`

**Why:** several actions are safe to repeat (re-adding the same social account, re-submitting today's video stats) and should update the existing row instead of erroring or creating a duplicate:

```sql
INSERT INTO social_media_accounts (influencer_user_id, platform, handle, followers_count, engagement_rate)
VALUES (?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  followers_count = VALUES(followers_count),
  engagement_rate = VALUES(engagement_rate)
```

A unique key on `(influencer_user_id, platform, handle)` makes "duplicate" well-defined; without it, double-tapping "Add" in the app used to silently create multiple rows for the same account.

### 7. Best-Effort Side Effects

**Where:** every notification-sending call site, e.g. `chat.service.ts`'s `sendMessage()`, `offer.service.ts`'s `apply()`

**Why:** a notification failing to send should never fail the primary action (sending the message, applying to a campaign). Side effects are wrapped so they can't take down the main flow:

```typescript
try {
  await notificationService.push(recipientId, { /* ... */ });
} catch {
  // best-effort — don't fail the send if this errors
}
```

### 8. Adapter (the real one)

**Where:** `services/video_stats.service.ts` dispatching to `tiktok.service.ts` / `instagram.service.ts`

**Why:** TikTok and Instagram each have a completely different API shape, auth style, and response format for "get stats for this video." Everything downstream (progress calculation, the daily-stats rollup, the client) needs one consistent shape regardless of which platform a video came from:

```typescript
export interface VideoStats {
  platform: 'tiktok' | 'instagram';
  views: number;
  likes: number;
  shares: number;
  comments: number;
  title: string;
  author: string;
}

export async function fetchVideoStats(url: string): Promise<VideoStats> {
  const platform = detectPlatform(url);
  if (platform === 'tiktok') {
    const stats = await fetchTikTokStats(url);
    return { ...stats, platform: 'tiktok' };
  }
  const stats = await fetchInstagramStats(url);
  return { ...stats, platform: 'instagram' };
}
```

Adding a third platform (YouTube Shorts, say) means writing one more provider file with a `fetchXStats()` matching this shape and adding one branch here — `video.controller.ts`, `refreshAllVideosForUser()`, and the Flutter client never need to change, since they only ever see the normalized `VideoStats` shape.

---

## Frontend (Flutter) Patterns

### 1. Repository Pattern

**Where:** `data/repositories/*.dart` — one class per backend module (`ProfileRepository`, `ChatRepository`, `SubscriptionRepository`, `WithdrawalRepository`, `PaymentMethodRepository`, etc.)

**Why:** widgets never call `ApiClient` directly for anything beyond the most trivial one-off requests — a repository owns the URL paths and JSON parsing for its feature:

```dart
class WithdrawalRepository {
  final ApiClient api;
  WithdrawalRepository(this.api);

  Future<WithdrawalBalance> balance() async {
    final data = await api.get('/withdrawals/balance');
    return WithdrawalBalance.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
```

This keeps every screen's business logic focused on *when* to call something, not *how* — and means the JSON shape only needs to be known in one place per feature.

### 2. `fromJson` Factory Constructor

**Where:** every class in `data/models/*.dart`

**Why:** consistent, defensive JSON parsing. MySQL returns numeric aggregates (`SUM()`, `DECIMAL` columns) as strings over the wire, so models never do a raw `as num` cast — they go through small local helpers that accept either shape:

```dart
factory WithdrawalBalance.fromJson(Map<String, dynamic> json) {
  num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
  return WithdrawalBalance(available: n(json['available']), /* ... */);
}
```

A direct `json['available'] as num` looks fine until the value happens to arrive as a string (which it does, from certain SQL aggregate queries) — that has caused real crashes during development (see `ARCHITECTURE.md` §5.2), which is why every model funnels through a permissive helper like the one above instead.

### 3. `InheritedWidget` as a Pure DI Container

**Where:** `core/app_scope.dart`

**Why:** `AppScope` used to be described as standing "in place of a state-management package" — that's no longer accurate (see Pattern 4 below). Its role narrowed to just dependency injection: it hands out the `Session` and repositories that Cubits and screens construct themselves from, and holds no reactive app state of its own. `SubscriptionRepository` was removed from it entirely once `SubscriptionCubit` existed — keeping it there too would've just been a second, redundant path to the same thing. See `ARCHITECTURE.md` §4.2 for the full picture, including the `initState()` timing rule that every data-loading screen has to follow.

### 4. BLoC (Cubit) for Reactive, Shared State

**Where:** `core/session_cubit.dart`, `notification/notification_cubit.dart`, `subscription/subscription_cubit.dart`, `influencer/dashboard/influencer_dashboard_cubit.dart`, `brand/dashboard/brand_dashboard_cubit.dart`, `influencer/analytics/influencer_analytics_cubit.dart`, `brand/analytics/brand_analytics_cubit.dart`, plus two screen-scoped ones (Pattern 5)

**Why:** before this, every screen that displayed a piece of shared data (subscription status, the unread-notification count, dashboard summaries) fetched and cached it independently — meaning six-plus separate places could each show a slightly different unread count, or a dashboard's counts would stay stale until manually reloaded. A `Cubit` centralizes both the state and the logic to mutate it, and every widget watching it rebuilds the moment it changes:

```dart
class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository repo;
  NotificationCubit(this.repo) : super(const NotificationState());

  Future<void> markRead(int id) async {
    final updated = state.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    emit(state.copyWith(items: updated, unreadCount: updated.where((n) => !n.isRead).length));
    try {
      await repo.markRead(id);
    } catch (_) {
      // best-effort — see Backend Pattern 7's reasoning, same idea here
    }
  }
}
```

Marking one notification read on the notifications screen instantly updates every bell icon on screen, since they all `context.watch<NotificationCubit>()` the same instance — no manual "reload after navigating back" needed for anything this covers.

Every state class extends `Equatable` (from the `equatable` package) so `Cubit` can tell when a new state is *structurally* identical to the last one and skip an unnecessary rebuild — without it, `Cubit`'s default equality is reference-based, which would rebuild on every `emit()` even when nothing observable actually changed.

### 5. Scoped vs. App-Wide Cubits

**Where:** app-wide — registered in `main.dart`'s `MultiBlocProvider`, all the Cubits listed in Pattern 4. Scoped — `chat/chat_cubit.dart`, `influencer/earnings/withdrawal_cubit.dart`

**Why:** not every Cubit needs to be reachable from everywhere. Chat and Withdrawal state is inherently tied to *one* open screen at a time — there's no "keep multiple simultaneously-open screens in sync" problem to solve, so making them global would just be unnecessary ceremony. Instead, the screen itself is a thin wrapper that builds a fresh Cubit scoped to just that screen:

```dart
class WithdrawEarningsScreen extends StatelessWidget {
  const WithdrawEarningsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return BlocProvider(
      create: (_) => WithdrawalCubit(WithdrawalRepository(scope.api))..load(),
      child: const _WithdrawEarningsView(),
    );
  }
}
```

This is safe from being re-created on every rebuild because the wrapper is a `StatelessWidget` reached via `Navigator.push` (built once per navigation), and `BlocProvider`'s `create` callback is cached by its own internal `State` rather than re-invoked just because an ancestor happens to rebuild.

**What deliberately stayed on plain `setState`:** a few genuinely screen-local, non-duplicated bits of state were left alone rather than wrapped in a Cubit for its own sake — e.g. `_AllCampaignsScreenState` (a private class inside `brand_dashboard_screen.dart`) keeps its own `_loading`/`_items` fields, since only that one screen ever needs them.

### 6. Guarded One-Time Initialization

**Where:** virtually every `StatefulWidget` that loads data on open

```dart
bool _initialized = false;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (!_initialized) {
    _initialized = true;
    _load();
  }
}
```

**Why:** `didChangeDependencies()` can fire more than once (e.g. when an ancestor `InheritedWidget` changes), but the initial data load should only happen once. The boolean guard makes that explicit rather than relying on `_load()` itself being idempotent.

### 7. Reload-on-Return (now partly superseded by Cubits)

**Where:** any navigation into a screen that can mutate data the *previous* screen displays, e.g. approving an applicant, submitting a video, subscribing to a plan

```dart
onTap: () async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const BrandPendingApprovalsScreen()),
  );
  if (mounted) _load(); // refresh the summary now that something may have changed
}
```

**Why:** before Cubits existed, the app had no shared/reactive state store at all — a screen's data was just whatever it fetched on its own `_load()` call, so without explicitly reloading after a child screen popped, a dashboard's counts (e.g. "3 pending approvals") would stay stale until the whole tab was torn down and rebuilt. `main_screen.dart` uses an `IndexedStack` for the bottom-nav tabs specifically so they *don't* rebuild on every tab switch, which is what made this pattern necessary in the first place.

This is now **only needed in two situations**: (1) screens backed by a *scoped* Cubit (Chat, Withdrawal — Pattern 5), since there's no global listener to react to changes automatically, and (2) the handful of plain-`setState` screens that were deliberately left alone (e.g. `_AllCampaignsScreenState`). Anywhere backed by an app-wide Cubit no longer needs this — approving an applicant now updates the dashboard's counts reactively the moment `BrandDashboardCubit.load()` is called from wherever the approval happened, without the dashboard screen needing to be the one to trigger it.

---

## Pattern Summary

| Pattern | Layer | File(s) |
|---|---|---|
| Layered architecture | Backend | every `routes/services/controllers` triplet |
| Centralized error handling | Backend | `middlewares/error.ts`, `utils/apiError.ts` |
| Singleton connection pool | Backend | `config/db.ts` |
| Role-based strategy dispatch | Backend | `services/subscription.service.ts` |
| Lazy evaluation (expire-on-read) | Backend | `services/subscription.service.ts` |
| Idempotent upsert writes | Backend | `profile.service.ts`, `tiktok.service.ts`, `withdrawal.service.ts` |
| Best-effort side effects | Backend | notification `push()` call sites |
| Adapter (multi-platform video stats) | Backend | `video_stats.service.ts` → `tiktok.service.ts` / `instagram.service.ts` |
| Repository pattern | Frontend | `data/repositories/*.dart` |
| Defensive `fromJson` parsing | Frontend | `data/models/*.dart` |
| `InheritedWidget` as pure DI | Frontend | `core/app_scope.dart` |
| BLoC (Cubit) for shared state | Frontend | 7 app-wide Cubits — see Pattern 4 |
| Scoped (per-screen) Cubits | Frontend | `ChatCubit`, `WithdrawalCubit` — see Pattern 5 |
| Guarded one-time init | Frontend | most `StatefulWidget`s that load data |
| Reload-on-return | Frontend | scoped-Cubit screens and the few remaining plain-`setState` screens only |