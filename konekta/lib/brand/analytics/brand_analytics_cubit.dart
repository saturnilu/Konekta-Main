import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/analytics_repository.dart';

class BrandAnalyticsState extends Equatable {
  static const tabDays = [7, 30, 365];

  final bool loading;
  final String? error;
  final int selectedTab;
  final Map<String, dynamic> data;

  const BrandAnalyticsState({
    this.loading = true,
    this.error,
    this.selectedTab = 0,
    this.data = const {},
  });

  int get days => tabDays[selectedTab];

  BrandAnalyticsState copyWith({
    bool? loading,
    String? error,
    int? selectedTab,
    Map<String, dynamic>? data,
  }) {
    return BrandAnalyticsState(
      loading: loading ?? this.loading,
      error: error,
      selectedTab: selectedTab ?? this.selectedTab,
      data: data ?? this.data,
    );
  }

  @override
  List<Object?> get props => [loading, error, selectedTab, data];
}

class BrandAnalyticsCubit extends Cubit<BrandAnalyticsState> {
  final AnalyticsRepository repo;
  BrandAnalyticsCubit(this.repo) : super(const BrandAnalyticsState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final data = await repo.brandAnalytics(days: state.days);
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