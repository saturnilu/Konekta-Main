import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/campaign.dart';
import '../../data/models/influencer_summary.dart';
import '../../data/repositories/campaign_repository.dart';
import '../../data/repositories/dashboard_repository.dart';

class InfluencerDashboardState extends Equatable {
  final bool loading;
  final String? error;
  final InfluencerSummary? summary;
  final List<Campaign> activeCampaigns;

  const InfluencerDashboardState({
    this.loading = true,
    this.error,
    this.summary,
    this.activeCampaigns = const [],
  });

  InfluencerDashboardState copyWith({
    bool? loading,
    String? error,
    InfluencerSummary? summary,
    List<Campaign>? activeCampaigns,
  }) {
    return InfluencerDashboardState(
      loading: loading ?? this.loading,
      error: error,
      summary: summary ?? this.summary,
      activeCampaigns: activeCampaigns ?? this.activeCampaigns,
    );
  }

  @override
  List<Object?> get props => [loading, error, summary, activeCampaigns];
}

class InfluencerDashboardCubit extends Cubit<InfluencerDashboardState> {
  final DashboardRepository dashboardRepo;
  final CampaignRepository campaignRepo;
  InfluencerDashboardCubit(this.dashboardRepo, this.campaignRepo)
      : super(const InfluencerDashboardState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final summary = await dashboardRepo.influencerSummary();
      List<Campaign> campaigns = const [];
      try {
        final allMine = await campaignRepo.listMine();
        campaigns = allMine
            .where((c) =>
                c.applicationStatus == 'approved' ||
                c.applicationStatus == 'completed')
            .toList();
      } catch (_) {
        campaigns = summary.activeCampaignsList;
      }
      emit(state.copyWith(summary: summary, activeCampaigns: campaigns, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }
}