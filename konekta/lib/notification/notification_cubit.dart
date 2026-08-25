import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/notification.dart';
import '../data/repositories/notification_repository.dart';

class NotificationState extends Equatable {
  final int unreadCount;
  final List<AppNotification> items;
  final bool loading;
  final String? error;

  const NotificationState({
    this.unreadCount = 0,
    this.items = const [],
    this.loading = false,
    this.error,
  });

  NotificationState copyWith({
    int? unreadCount,
    List<AppNotification>? items,
    bool? loading,
    String? error,
  }) {
    return NotificationState(
      unreadCount: unreadCount ?? this.unreadCount,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [unreadCount, items, loading, error];
}

class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository repo;
  NotificationCubit(this.repo) : super(const NotificationState());

  Future<void> refreshUnreadCount() async {
    try {
      final count = await repo.unreadCount();
      emit(state.copyWith(unreadCount: count));
    } catch (_) {
    }
  }

  Future<void> loadList() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await repo.list();
      final unread = items.where((n) => !n.isRead).length;
      emit(state.copyWith(items: items, unreadCount: unread, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<void> markRead(int id) async {
    final updated = state.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    final unread = updated.where((n) => !n.isRead).length;
    emit(state.copyWith(items: updated, unreadCount: unread));
    try {
      await repo.markRead(id);
    } catch (_) {
    }
  }

  Future<void> markAllRead() async {
    final updated = state.items.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(items: updated, unreadCount: 0));
    try {
      await repo.markAllRead();
    } catch (_) {
    }
  }
}