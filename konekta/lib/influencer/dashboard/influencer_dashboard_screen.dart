import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/session_cubit.dart';
import '../../core/format.dart';
import '../../data/models/campaign.dart';
import '../../notification/notification_bell_icon.dart';
import '../../campaign/campaign_room_screen.dart';
import '../earnings/withdraw_earnings_screen.dart';
import 'influencer_dashboard_cubit.dart';

class InfluencerDashboardScreen extends StatefulWidget {
  const InfluencerDashboardScreen({super.key});

  @override
  State<InfluencerDashboardScreen> createState() => _InfluencerDashboardScreenState();
}

class _InfluencerDashboardScreenState extends State<InfluencerDashboardScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      context.read<InfluencerDashboardCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<SessionCubit>().state.name ?? 'Creator';
    return BlocBuilder<InfluencerDashboardCubit, InfluencerDashboardState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFEDF4FC),
          body: state.loading
              ? const _LoadingState()
              : state.error != null
                  ? _ErrorState(
                      message: state.error!,
                      onRetry: () => context.read<InfluencerDashboardCubit>().load(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context.read<InfluencerDashboardCubit>().load(),
                      child: _buildContent(context, name, state),
                    ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, String name, InfluencerDashboardState state) {
    final summary = state.summary!;
    final activeCampaigns = state.activeCampaigns;
    final views = Format.compact(summary.totalViews);
    final engagement = Format.compact(summary.totalLikes);
    return Stack(
      children: [
        ClipPath(
          clipper: BackgroundClipper(),
          child: Container(
            height: 260,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2FA2EE), Color(0xFF3B7CE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 7, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.hub_outlined, color: Colors.white, size: 24),
                        SizedBox(width: 6),
                        Text(
                          'Konekta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const NotificationBellIcon(color: Colors.white, size: 24),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Greeting
                      Text(
                        'Hi, $name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ready to grow today?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "THIS MONTH'S EARNINGS",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                                  .format(summary.thisMonthEarnings),
                              style: const TextStyle(
                                color: Color(0xFF00C853),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'PENDING FROM BRANDS',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                                  .format(summary.pendingEarnings),
                              style: const TextStyle(
                                color: Color(0xFF26264A),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const WithdrawEarningsScreen()),
                                  );
                                  if (context.mounted) {
                                    context.read<InfluencerDashboardCubit>().load();
                                  }
                                },
                                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF1F6FE5)),
                                label: const Text('Withdraw', style: TextStyle(color: Color(0xFF1F6FE5), fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF1F6FE5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quick analytics
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              label: 'TOTAL VIEWS',
                              value: views,
                              icon: Icons.trending_up,
                              iconColor: const Color(0xFF00C853),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              label: 'ENGAGEMENT',
                              value: engagement,
                              icon: Icons.favorite_border,
                              iconColor: const Color(0xFFFA5252),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Active Campaigns',
                        style: TextStyle(
                          color: Color(0xFF0F2547),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (activeCampaigns.isEmpty)
                        _buildEmptyCampaigns()
                      else
                        ...activeCampaigns.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildCampaignCard(c),
                            )),
                    ],
                  ),
                ),
              ],
            ),
          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCampaigns() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.campaign_outlined, color: Colors.grey.shade400, size: 40),
          const SizedBox(height: 12),
          const Text(
            'No active campaigns yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF26264A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore open offers to start collaborating with brands.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF26264A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(Campaign c) {
    final progress = ((c.progress ?? 0) / 100.0).clamp(0.0, 1.0);
    final daysLeft = c.daysLeft;
    final daysText = daysLeft == null
        ? '— Days Left'
        : daysLeft > 0
            ? '$daysLeft Days Left'
            : daysLeft == 0
                ? 'Due today'
                : 'Deadline passed';
    final statusLabel = _humanizeStatus(c.status);
    final statusColor = _statusColor(c.status);
    final earnings = c.budget != null
        ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(c.budget)
        : '—';
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CampaignRoomScreen(campaign: c)),
        );
        if (context.mounted) {
          context.read<InfluencerDashboardCubit>().load();
        }
      },
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A534E),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.shop, color: Colors.white70, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.brandName ?? 'Brand',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            daysText,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  earnings,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB0CDDB),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 10,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF80E5FF), Color(0xFF408CFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (c.description != null && c.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                c.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _humanizeStatus(String s) {
    switch (s) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'open':
        return 'OPEN';
      case 'completed':
        return 'COMPLETED';
      case 'draft':
        return 'DRAFT';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return s.toUpperCase();
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress':
        return const Color(0xFF00C853);
      case 'open':
        return const Color(0xFF3B7CE5);
      case 'completed':
        return const Color(0xFF64748B);
      case 'cancelled':
        return const Color(0xFFE5484D);
      default:
        return const Color(0xFFF6A623);
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF2FA2EE)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFFB0B8C4)),
            const SizedBox(height: 12),
            const Text(
              'Could not load dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF26264A)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7E8CA0)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2FA2EE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BackgroundClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    final firstControlPoint = Offset(size.width / 4, size.height);
    final firstEndPoint = Offset(size.width / 2, size.height);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    final secondControlPoint = Offset(size.width - (size.width / 4), size.height);
    final secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}