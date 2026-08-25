import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/dashboard_repository.dart';

class BrandDashboardState extends Equatable {
  final bool loading;
  final String? error;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rooms;

  const BrandDashboardState({
    this.loading = true,
    this.error,
    this.summary = const {},
    this.rooms = const [],
  });

  BrandDashboardState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? summary,
    List<Map<String, dynamic>>? rooms,
  }) {
    return BrandDashboardState(
      loading: loading ?? this.loading,
      error: error,
      summary: summary ?? this.summary,
      rooms: rooms ?? this.rooms,
    );
  }

  @override
  List<Object?> get props => [loading, error, summary, rooms];
}

class BrandDashboardCubit extends Cubit<BrandDashboardState> {
  final DashboardRepository repo;
  BrandDashboardCubit(this.repo) : super(const BrandDashboardState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final data = await repo.brandOverview();
      emit(state.copyWith(summary: data.summary, rooms: data.rooms, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }
}