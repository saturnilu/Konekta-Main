import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/api_client.dart';
import 'core/session.dart';
import 'core/app_scope.dart';
import 'core/session_cubit.dart';
import 'notification/notification_cubit.dart';
import 'subscription/subscription_cubit.dart';
import 'influencer/dashboard/influencer_dashboard_cubit.dart';
import 'brand/dashboard/brand_dashboard_cubit.dart';
import 'influencer/analytics/influencer_analytics_cubit.dart';
import 'brand/analytics/brand_analytics_cubit.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/subscription_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/campaign_repository.dart';
import 'data/repositories/analytics_repository.dart';
import 'Opening/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final session = Session(prefs);
  final api = ApiClient(session);
  final authRepo = AuthRepository(api, session);
  final profileRepo = ProfileRepository(api);
  final chatRepo = ChatRepository(api);
  final notificationRepo = NotificationRepository(api);
  final subscriptionRepo = SubscriptionRepository(api);
  final dashboardRepo = DashboardRepository(api);
  final campaignRepo = CampaignRepository(api);
  final analyticsRepo = AnalyticsRepository(api);
  runApp(KonektaApp(
    session: session,
    api: api,
    authRepo: authRepo,
    profileRepo: profileRepo,
    chatRepo: chatRepo,
    notificationRepo: notificationRepo,
    subscriptionRepo: subscriptionRepo,
    dashboardRepo: dashboardRepo,
    campaignRepo: campaignRepo,
    analyticsRepo: analyticsRepo,
  ));
}

class KonektaApp extends StatelessWidget {
  final Session session;
  final ApiClient api;
  final AuthRepository authRepo;
  final ProfileRepository profileRepo;
  final ChatRepository chatRepo;
  final NotificationRepository notificationRepo;
  final SubscriptionRepository subscriptionRepo;
  final DashboardRepository dashboardRepo;
  final CampaignRepository campaignRepo;
  final AnalyticsRepository analyticsRepo;
  const KonektaApp({
    super.key,
    required this.session,
    required this.api,
    required this.authRepo,
    required this.profileRepo,
    required this.chatRepo,
    required this.notificationRepo,
    required this.subscriptionRepo,
    required this.dashboardRepo,
    required this.campaignRepo,
    required this.analyticsRepo,
  });

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: session,
      api: api,
      authRepo: authRepo,
      profileRepo: profileRepo,
      chatRepo: chatRepo,
      notificationRepo: notificationRepo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SessionCubit(session)),
          BlocProvider(create: (_) => SubscriptionCubit(subscriptionRepo)),
          BlocProvider(create: (_) => InfluencerDashboardCubit(dashboardRepo, campaignRepo)),
          BlocProvider(create: (_) => BrandDashboardCubit(dashboardRepo)),
          BlocProvider(create: (_) => InfluencerAnalyticsCubit(analyticsRepo)),
          BlocProvider(create: (_) => BrandAnalyticsCubit(analyticsRepo)),
          BlocProvider(create: (_) {
            final cubit = NotificationCubit(notificationRepo);
            cubit.refreshUnreadCount();
            return cubit;
          }),
        ],
        child: MaterialApp(
          title: 'Konekta',
          debugShowCheckedModeBanner: false,
          theme: KonektaTheme.light,
          home: const KonektaSplashScreen(),
        ),
      ),
    );
  }
}