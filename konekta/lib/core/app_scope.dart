import 'package:flutter/material.dart';
import 'api_client.dart';
import 'session.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/profile_repository.dart';

class AppScope extends InheritedWidget {
  final Session session;
  final ApiClient api;
  final bool loading;
  final String? error;
  final AuthRepository authRepo;
  final ProfileRepository profileRepo;
  final ChatRepository chatRepo;
  final NotificationRepository notificationRepo;

  const AppScope({
    super.key,
    required this.session,
    required this.api,
    this.loading = false,
    this.error,
    required this.authRepo,
    required this.profileRepo,
    required this.chatRepo,
    required this.notificationRepo,
    required super.child,
  });

  String get role => session.role ?? 'influencer';

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  Future<T> run<T>(Future<T> Function() task) async {
    return task();
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      session != oldWidget.session || api != oldWidget.api || loading != oldWidget.loading || error != oldWidget.error;
}