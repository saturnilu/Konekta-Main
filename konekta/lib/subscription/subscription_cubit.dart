import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/subscription.dart';
import '../data/repositories/subscription_repository.dart';

class SubscriptionState extends Equatable {
  final bool loading;
  final String? error;
  final List<SubscriptionPlan> plans;
  final Subscription? current;

  const SubscriptionState({
    this.loading = false,
    this.error,
    this.plans = const [],
    this.current,
  });

  SubscriptionState copyWith({
    bool? loading,
    String? error,
    List<SubscriptionPlan>? plans,
    Subscription? current,
  }) {
    return SubscriptionState(
      loading: loading ?? this.loading,
      error: error,
      plans: plans ?? this.plans,
      current: current ?? this.current,
    );
  }

  @override
  List<Object?> get props => [loading, error, plans, current];
}

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionRepository repo;
  SubscriptionCubit(this.repo) : super(const SubscriptionState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final results = await Future.wait([repo.listPlans(), repo.current()]);
      emit(state.copyWith(
        plans: results[0] as List<SubscriptionPlan>,
        current: results[1] as Subscription?,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  Future<Subscription> subscribe(int planId) async {
    final updated = await repo.subscribe(planId);
    emit(state.copyWith(current: updated));
    return updated;
  }

  Future<void> cancelPlan() async {
    final updated = await repo.cancel();
    emit(state.copyWith(current: updated));
  }
}