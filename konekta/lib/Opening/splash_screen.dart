import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/onboarding_screen.dart';
import '../core/app_scope.dart';
import '../core/api_client.dart';
import '../core/session_cubit.dart';
import '../main_screen.dart';
import 'dart:async';
import 'dart:math' as math;

class KonektaSplashScreen extends StatefulWidget {
  const KonektaSplashScreen({super.key});

  @override
  State<KonektaSplashScreen> createState() => _KonektaSplashScreenState();
}

class _KonektaSplashScreenState extends State<KonektaSplashScreen> with SingleTickerProviderStateMixin {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _decideNextScreen();
    }
  }

  Future<void> _decideNextScreen() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 3600));
    final scope = AppScope.of(context);
    final session = scope.session;

    Widget next = const OnboardingScreen();
    if (session.isLoggedIn) {
      try {
        await scope.api.get('/profile/me');
        next = const MainScreen();
      } on ApiException {
        await session.clear();
      } catch (_) {
        next = const MainScreen();
      }
    }

    await minDelay;
    if (!mounted) return;
    context.read<SessionCubit>().refresh();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF3AA1FF),
              Color(0xFF0D5CD6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _HubAnimation(),
            const SizedBox(height: 24),
            const Text(
              'Konekta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Where brands & creators connect.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubAnimation extends StatefulWidget {
  const _HubAnimation();

  @override
  State<_HubAnimation> createState() => _HubAnimationState();
}

class _HubAnimationState extends State<_HubAnimation> with SingleTickerProviderStateMixin {
  static const int _satelliteCount = 5;
  static const double _boxSize = 200;
  static const double _centerSize = 64;
  static const double _satelliteSize = 22;
  static const double _radius = 78;

  late final AnimationController _controller;
  late final Animation<double> _centerAnim;
  late final List<Animation<double>> _satelliteAnims;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();

    _centerAnim = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.22, curve: Curves.elasticOut));

    _satelliteAnims = List.generate(_satelliteCount, (i) {
      final start = 0.22 + i * 0.11;
      final end = (start + 0.20).clamp(0.0, 1.0);
      return CurvedAnimation(parent: _controller, curve: Interval(start, end, curve: Curves.elasticOut));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _satelliteOffset(int i) {
    final angle = (2 * math.pi * i / _satelliteCount) - math.pi / 2;
    return Offset(_radius * math.cos(angle), _radius * math.sin(angle));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _boxSize,
      height: _boxSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _HubLinesPainter(
              center: const Offset(_boxSize / 2, _boxSize / 2),
              satelliteOffsets: List.generate(_satelliteCount, _satelliteOffset),
              satelliteProgress: _satelliteAnims.map((a) => a.value.clamp(0.0, 1.0)).toList(),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < _satelliteCount; i++) _buildSatellite(i),
                Transform.scale(
                  scale: _centerAnim.value.clamp(0.0, double.infinity),
                  child: Container(
                    width: _centerSize,
                    height: _centerSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.white.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.hub_rounded, color: Color(0xFF0D5CD6), size: 32),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSatellite(int i) {
    final offset = _satelliteOffset(i);
    final scale = _satelliteAnims[i].value.clamp(0.0, double.infinity);
    return Positioned(
      left: _boxSize / 2 + offset.dx - _satelliteSize / 2,
      top: _boxSize / 2 + offset.dy - _satelliteSize / 2,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: _satelliteSize,
          height: _satelliteSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.white.withOpacity(0.5 * scale), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubLinesPainter extends CustomPainter {
  final Offset center;
  final List<Offset> satelliteOffsets;
  final List<double> satelliteProgress;

  _HubLinesPainter({
    required this.center,
    required this.satelliteOffsets,
    required this.satelliteProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < satelliteOffsets.length; i++) {
      final t = satelliteProgress[i];
      if (t <= 0) continue;
      final target = center + satelliteOffsets[i];
      final current = Offset.lerp(center, target, t)!;
      paint.color = Colors.white.withOpacity(0.5 * t);
      canvas.drawLine(center, current, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HubLinesPainter oldDelegate) => true;
}