import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/game_storage.dart';
import '../theme.dart';
import 'menu_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  String _dots = '';
  Timer? _dotsTimer;
  bool _navigated = false;

  final List<_LoadStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() {
        _dots = _dots.length >= 3 ? '' : '$_dots.';
      });
    });
    _boot();
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    _steps.addAll([
      _LoadStep('Initializing engine', 220, _initEngine),
      _LoadStep('Loading storage', 260, _initStorage),
      _LoadStep('Warming assets', 550, _precacheAssets),
      _LoadStep('Preparing arena', 260, _prepareArena),
      _LoadStep('Ready', 220, _finalize),
    ]);
    final totalWeight = _steps.fold<int>(0, (a, b) => a + b.weight);
    int accumulated = 0;

    for (final step in _steps) {
      final startFraction = accumulated / totalWeight;
      final endFraction = (accumulated + step.weight) / totalWeight;
      await step.run(context);
      await _animateTo(startFraction, endFraction, step.weight * 2);
      accumulated += step.weight;
    }

    if (!mounted) return;
    _navigated = true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MenuScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _animateTo(double from, double to, int durationMs) async {
    const stepMs = 16;
    final steps = (durationMs / stepMs).ceil();
    for (var i = 1; i <= steps; i++) {
      if (!mounted || _navigated) return;
      final t = i / steps;
      setState(() => _progress = from + (to - from) * t);
      await Future<void>.delayed(const Duration(milliseconds: stepMs));
    }
  }

  Future<void> _initEngine(BuildContext ctx) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  Future<void> _initStorage(BuildContext ctx) async {
    await GameStorage.instance.init();
  }

  Future<void> _precacheAssets(BuildContext ctx) async {
    const assets = <String>[
      'assets/bg1_asset.webp',
      'assets/bg2_asset.webp',
      'assets/bg3_asset.webp',
      'assets/crystal_gem_asset.webp',
      'assets/Game_Name.webp',
      'assets/geometric_square_asset.webp',
      'assets/hexagonal_obstacle_asset.webp',
      'assets/Icon.png',
      'assets/neon_direction_asset.webp',
      'assets/shaped_obstacle_asset.webp',
      'assets/sphere_asset.webp',
      'assets/triangular_obstacle_asset.webp',
      'assets/vertical_neon_wall_asset.webp',
    ];
    for (final a in assets) {
      if (!ctx.mounted) return;
      await precacheImage(AssetImage(a), ctx);
    }
  }

  Future<void> _prepareArena(BuildContext ctx) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _finalize(BuildContext ctx) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              isPortrait
                  ? 'assets/Vertical_Loading_Screen.webp'
                  : 'assets/Horizontal_Loading_Screen.webp',
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            _buildProgress(isPortrait),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(bool isPortrait) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isPortrait ? 36 : 72,
          vertical: 28,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Loading$_dots',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: AppColors.neonCyan, blurRadius: 14),
                  Shadow(color: AppColors.neonPink, blurRadius: 24),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _NeonProgressBar(progress: _progress),
            const SizedBox(height: 10),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadStep {
  final String label;
  final int weight;
  final Future<void> Function(BuildContext) task;
  _LoadStep(this.label, this.weight, this.task);

  Future<void> run(BuildContext ctx) => task(ctx);
}

class _NeonProgressBar extends StatelessWidget {
  final double progress;
  const _NeonProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (ctx, cons) {
        final width = cons.maxWidth;
        return Container(
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.neonCyan, width: 1.4),
            boxShadow: [
              BoxShadow(color: AppColors.neonCyan.withOpacity(0.5), blurRadius: 18),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: width * clamped,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.neonCyan,
                        AppColors.neonPurple,
                        AppColors.neonPink,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.neonPink, blurRadius: 22),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ScanLinesPainter(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScanLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
