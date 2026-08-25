import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_scope.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models/influencer.dart';
import '../../data/repositories/discovery_repository.dart';
import '../../chat/chat_room_screen.dart';

class BrandViewProfileScreen extends StatefulWidget {
  final int influencerId;
  const BrandViewProfileScreen({super.key, required this.influencerId});

  @override
  State<BrandViewProfileScreen> createState() => _BrandViewProfileScreenState();
}

class _BrandViewProfileScreenState extends State<BrandViewProfileScreen> {
  bool _loading = true;
  String? _error;
  InfluencerProfile? _profile;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final scope = AppScope.of(context);
      final profile = await DiscoveryRepository(scope.api).influencer(widget.influencerId);
      if (!mounted) return;
      setState(() { _profile = profile; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _openMediaKit() async {
    final url = _profile?.mediaKitUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  void _contact() {
    final p = _profile;
    if (p == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          otherUserId: p.userId,
          otherUserName: p.username ?? 'Creator',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KonektaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'View Profile',
          style: TextStyle(color: KonektaColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _buildBody(_profile!),
    );
  }

  Widget _buildBody(InfluencerProfile p) {
    final followers = p.followersCount ?? 0;
    final engagement = p.engagementRate ?? 0;
    final niche = p.niche;
    final industry = p.industry;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(color: KonektaColors.primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                    color: const Color(0xFF9CC2F9),
                    image: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                        ? DecorationImage(image: NetworkImage(p.avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                      ? Center(
                          child: Text(
                            (p.username?.isNotEmpty == true ? p.username![0] : '?').toUpperCase(),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  p.location?.isNotEmpty == true ? p.location! : (p.username ?? 'Creator'),
                  style: const TextStyle(color: KonektaColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${p.username ?? 'creator'}',
                  style: const TextStyle(color: KonektaColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (niche != null && niche.isNotEmpty) _buildProfileBadge(label: niche),
                    if (industry != null && industry.isNotEmpty && industry != niche) _buildProfileBadge(label: industry),
                  ],
                ),
                if ((p.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    p.bio!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Audience & Reach',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KonektaColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.people_alt_outlined,
                        iconBg: const Color(0xFFE2F5F3),
                        iconColor: KonektaColors.success,
                        label: 'Followers',
                        value: Format.compact(followers),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.favorite_border,
                        iconBg: const Color(0xFFFEE2E2),
                        iconColor: const Color(0xFFFF7043),
                        label: 'Engagement',
                        value: '${engagement.toStringAsFixed(1)}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.emoji_events_outlined,
                        iconBg: const Color(0xFFDCFCE7),
                        iconColor: const Color(0xFF66BB6A),
                        label: 'Completed campaigns',
                        value: '${p.completedCampaigns ?? 0}',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.campaign_outlined,
                        iconBg: const Color(0xFFEBF2F9),
                        iconColor: KonektaColors.primary,
                        label: 'Active campaigns',
                        value: '${p.activeCampaigns ?? 0}',
                      ),
                    ),
                  ],
                ),
                if ((p.mediaKitUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openMediaKit,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('View media kit'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: KonektaColors.background,
          child: SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF76D1FF), Color(0xFF408CFF)]),
                boxShadow: [BoxShadow(color: KonektaColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton(
                onPressed: _contact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileBadge({required String label, Widget? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFD2E6FF).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 4)],
          Text(label, style: const TextStyle(color: KonektaColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.015), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: KonektaColors.textPrimary)),
        ],
      ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}