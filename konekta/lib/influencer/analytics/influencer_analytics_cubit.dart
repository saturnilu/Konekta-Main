import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/analytics_repository.dart';

class InfluencerAnalyticsState extends Equatable {
  static const tabDays = [7, 30, 365];

  final bool loading;
  final String? error;
  final int selectedTab;
  final Map<String, dynamic> data;

  const InfluencerAnalyticsState({
    this.loading = true,
    this.error,
    this.selectedTab = 0,
    this.data = const {},
  });

  int get days => tabDays[selectedTab];

  InfluencerAnalyticsState copyWith({
    bool? loading,
    String? error,
    int? selectedTab,
    Map<String, dynamic>? data,
  }) {
    return InfluencerAnalyticsState(
      loading: loading ?? this.loading,
      error: error,
      selectedTab: selectedTab ?? this.selectedTab,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [loading, error, selectedTab, data];
}

class InfluencerAnalyticsCubit extends Cubit<InfluencerAnalyticsState> {
  final AnalyticsRepository repo;
  InfluencerAnalyticsCubit(this.repo) : super(const InfluencerAnalyticsState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final data = await repo.influencerAnalytics(days: state.days);
      emit(state.copyWith(data: data, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }

  void changeTab(int i) {
    if (i == state.selectedTab) return;
    emit(state.copyWith(selectedTab: i));
    load();
  }
}