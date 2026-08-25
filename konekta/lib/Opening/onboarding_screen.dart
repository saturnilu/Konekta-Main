import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _idx = 0;
  double _pageValue = 0;

  final _pages = const [
    _PageData(
      icon: Icons.diversity_3_rounded,
      iconColor: Color(0xFF5B9DFF),
      gradient: KonektaGradients.pillBlue,
      title: 'Discover premium brands',
      desc: 'Find brands actively looking for creators like you. Build authentic partnerships in minutes.',
    ),
    _PageData(
      icon: Icons.task_alt_rounded,
      iconColor: Color(0xFF3FCB85),
      gradient: KonektaGradients.success,
      title: 'Track every deliverable',
      desc: 'Track every deliverable, deadline, and milestone in one clean dashboard. Stay in control end-to-end.',
    ),
    _PageData(
      icon: Icons.account_balance_wallet_rounded,
      iconColor: Color(0xFFFF9142),
      gradient: KonektaGradients.orange,
      title: 'Fast, transparent payouts',
      desc: 'Fast payouts, transparent metrics, and tools that help you scale. Your influence, professionally managed.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pc.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _pc.page;
    if (p == null) return;
    setState(() => _pageValue = p);
  }

  @override
  void dispose() {
    _pc.removeListener(_onScroll);
    _pc.dispose();
    super.dispose();
  }

  Color _blendedColor() {
    final clamped = _pageValue.clamp(0, _pages.length - 1).toDouble();
    final lower = clamped.floor();
    final upper = (lower + 1).clamp(0, _pages.length - 1);
    final t = clamped - lower;
    return Color.lerp(_pages[lower].iconColor, _pages[upper].iconColor, t) ?? _pages[lower].iconColor;
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _idx == _pages.length - 1;
    final blended = _blendedColor();
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: blended.withValues(alpha: 0.14)),
            ),
          ),
          Positioned(
            top: 120,
            left: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, color: blended.withValues(alpha: 0.10)),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: blended.withValues(alpha: 0.08)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Text('Skip', style: TextStyle(color: KonektaColors.textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _idx = i),
                      itemBuilder: (_, i) => _OnboardingPageContent(data: _pages[i]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = _idx == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        width: active ? 26 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active ? blended : const Color(0xFFCFD8E5),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: active
                              ? [BoxShadow(color: blended.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: isLast ? 'Get Started' : 'Next',
                    icon: isLast ? Icons.arrow_forward_rounded : null,
                    onPressed: () {
                      if (isLast) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
                      } else {
                        _pc.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text.rich(
                      TextSpan(text: 'New here? ', style: TextStyle(color: KonektaColors.textSecondary),
                          children: [TextSpan(text: 'Create Account', style: TextStyle(color: KonektaColors.primary, fontWeight: FontWeight.w700))]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageContent extends StatefulWidget {
  final _PageData data;
  const _OnboardingPageContent({required this.data});

  @override
  State<_OnboardingPageContent> createState() => _OnboardingPageContentState();
}

class _OnboardingPageContentState extends State<_OnboardingPageContent> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _iconScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  late final AnimationController _breathe;
  late final Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
    _iconScale = CurvedAnimation(parent: _entrance, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut));
    _textFade = CurvedAnimation(parent: _entrance, curve: const Interval(0.35, 1.0, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entrance, curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic)));
    _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _glowPulse = CurvedAnimation(parent: _breathe, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pd = widget.data;
    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _breathe]),
      builder: (context, _) {
        final glow = 0.35 + (_glowPulse.value * 0.35);
        final ringScale = 1.0 + (_glowPulse.value * 0.06);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: _iconScale.value.clamp(0.0, double.infinity),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: ringScale,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pd.iconColor.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(color: const Color(0xFFF1F6FF), shape: BoxShape.circle),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: pd.gradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: pd.iconColor.withValues(alpha: glow), blurRadius: 28, spreadRadius: 2, offset: const Offset(0, 8)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(pd.icon, color: Colors.white, size: 48),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Opacity(
              opacity: _textFade.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, _textSlide.value.dy * 40),
                child: Column(
                  children: [
                    Text(
                      pd.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: KonektaColors.textPrimary, height: 1.2),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        pd.desc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14.5, height: 1.5, color: KonektaColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PageData {
  final IconData icon;
  final Color iconColor;
  final LinearGradient gradient;
  final String title;
  final String desc;
  const _PageData({required this.icon, required this.iconColor, required this.gradient, required this.title, required this.desc});
}