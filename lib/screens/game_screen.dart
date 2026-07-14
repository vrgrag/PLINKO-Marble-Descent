import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../bridge/insight.dart';
import '../models/cosmetics.dart';
import '../services/game_storage.dart';
import '../theme.dart';
import 'game_over_screen.dart';

enum EntityType { crystal, obstacleHex, obstacleTri, obstacleSquare, obstacleShaped }

class _Entity {
  final EntityType type;
  double worldY;
  final double x;
  final double size;
  bool collected;

  _Entity({
    required this.type,
    required this.worldY,
    required this.x,
    required this.size,
    this.collected = false,
  });

  bool get isCrystal => type == EntityType.crystal;

  String get asset {
    switch (type) {
      case EntityType.crystal:
        return 'assets/crystal_gem_asset.webp';
      case EntityType.obstacleHex:
        return 'assets/hexagonal_obstacle_asset.webp';
      case EntityType.obstacleTri:
        return 'assets/triangular_obstacle_asset.webp';
      case EntityType.obstacleSquare:
        return 'assets/geometric_square_asset.webp';
      case EntityType.obstacleShaped:
        return 'assets/shaped_obstacle_asset.webp';
    }
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  static const double _wallThicknessRatio = 0.09;

  late Ticker _ticker;
  late AnimationController _pulseCtrl;
  Duration _lastTick = Duration.zero;

  double _hintOpacity = 1.0;
  double _timeSinceStart = 0;

  double _scrollDistance = 0;
  double _fallSpeed = 260;
  final double _baseFallSpeed = 260;
  final double _maxFallSpeed = 620;
  final double _accelerationPerSecond = 6.0;

  double _horizontalSpeedPxPerSec = 260;
  int _direction = 1;

  double _ballScreenYRatio = 0.42;
  double _ballX = 0;
  double _ballRadius = 26;

  double _screenWidth = 0;
  double _screenHeight = 0;
  double _corridorLeft = 0;
  double _corridorRight = 0;

  final List<_Entity> _entities = [];
  double _nextSpawnAt = 200;
  final Random _rnd = Random();

  int _score = 0;
  int _crystalsThisGame = 0;
  int _distanceMeters = 0;
  bool _gameOver = false;
  bool _paused = false;
  bool _started = false;

  DateTime? _startTime;

  int _comboStreak = 0;
  double _streakGlow = 0;
  double _shake = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Insight.screen('game');
    _ticker = createTicker(_onTick);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_started || _gameOver || _paused) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    _fallSpeed = min(_maxFallSpeed, _fallSpeed + _accelerationPerSecond * dt);
    _horizontalSpeedPxPerSec = 220 + (_fallSpeed - _baseFallSpeed) * 0.6;

    _scrollDistance += _fallSpeed * dt;

    _ballX += _direction * _horizontalSpeedPxPerSec * dt;
    final leftBound = _corridorLeft + _ballRadius;
    final rightBound = _corridorRight - _ballRadius;
    if (_ballX < leftBound) {
      _ballX = leftBound;
      _direction = 1;
    } else if (_ballX > rightBound) {
      _ballX = rightBound;
      _direction = -1;
    }

    _distanceMeters = (_scrollDistance / 30).floor();

    _score = _distanceMeters + _crystalsThisGame * 10;

    _maybeSpawn();
    _updateEntities(dt);
    _checkCollisions();

    _streakGlow = (_streakGlow - dt * 1.2).clamp(0.0, 1.0);
    _shake = (_shake - dt * 5).clamp(0.0, 1.0);

    _timeSinceStart += dt;
    if (_timeSinceStart < 3.5) {
      _hintOpacity = 1.0;
    } else if (_timeSinceStart < 5.0) {
      _hintOpacity = (5.0 - _timeSinceStart) / 1.5;
    } else {
      _hintOpacity = 0.0;
    }

    if (mounted) setState(() {});
  }

  void _maybeSpawn() {
    while (_scrollDistance + _screenHeight > _nextSpawnAt) {
      final spawnRow = _nextSpawnAt;
      _spawnRow(spawnRow);
      final density = (_fallSpeed - _baseFallSpeed) / (_maxFallSpeed - _baseFallSpeed);
      final minGap = 130 - density * 40;
      final maxGap = 210 - density * 60;
      _nextSpawnAt += minGap + _rnd.nextDouble() * (maxGap - minGap);
    }
  }

  void _spawnRow(double worldY) {
    final density = (_fallSpeed - _baseFallSpeed) / (_maxFallSpeed - _baseFallSpeed);
    final corridorWidth = _corridorRight - _corridorLeft;

    final obstacleChance = 0.45 + 0.3 * density;
    final roll = _rnd.nextDouble();

    if (roll < obstacleChance) {
      final count = _rnd.nextDouble() < 0.35 + density * 0.35 ? 2 : 1;
      final available = List.generate(3, (i) => i);
      available.shuffle(_rnd);
      final positions = available.take(count).toList();
      for (final slot in positions) {
        final size = 46.0 + _rnd.nextDouble() * 14;
        final x = _corridorLeft + corridorWidth * (0.22 + slot * 0.28);
        final type = _pickObstacleType();
        _entities.add(
          _Entity(type: type, worldY: worldY, x: x, size: size),
        );
      }
      final cCount = _rnd.nextDouble() < 0.6 ? 1 : 0;
      for (var i = 0; i < cCount; i++) {
        final x = _corridorLeft + corridorWidth * (0.15 + _rnd.nextDouble() * 0.7);
        _entities.add(
          _Entity(
            type: EntityType.crystal,
            worldY: worldY + 30 + _rnd.nextDouble() * 40,
            x: x,
            size: 34,
          ),
        );
      }
    } else {
      final count = 1 + _rnd.nextInt(3);
      for (var i = 0; i < count; i++) {
        final x = _corridorLeft + corridorWidth * (0.15 + _rnd.nextDouble() * 0.7);
        _entities.add(
          _Entity(
            type: EntityType.crystal,
            worldY: worldY + i * 22.0,
            x: x,
            size: 34,
          ),
        );
      }
    }
  }

  EntityType _pickObstacleType() {
    final options = [
      EntityType.obstacleHex,
      EntityType.obstacleTri,
      EntityType.obstacleSquare,
      EntityType.obstacleShaped,
    ];
    return options[_rnd.nextInt(options.length)];
  }

  void _updateEntities(double dt) {
    _entities.removeWhere((e) {
      final screenY = _entityScreenY(e);
      return screenY < -e.size - 40;
    });
  }

  double _entityScreenY(_Entity e) {
    final ballScreenY = _screenHeight * _ballScreenYRatio;
    return (e.worldY - _scrollDistance) + ballScreenY - _ballRadius;
  }

  void _checkCollisions() {
    final ballScreenY = _screenHeight * _ballScreenYRatio;
    for (final e in _entities) {
      if (e.collected) continue;
      final ex = e.x;
      final ey = _entityScreenY(e) + e.size * 0.5;
      final dx = ex - _ballX;
      final dy = ey - ballScreenY;
      final dist2 = dx * dx + dy * dy;
      final r = e.isCrystal ? e.size * 0.5 * 0.9 : e.size * 0.5 * 0.85;
      final touchDist = _ballRadius + r;
      if (dist2 < touchDist * touchDist) {
        if (e.isCrystal) {
          e.collected = true;
          _crystalsThisGame++;
          _comboStreak++;
          _streakGlow = 1.0;
          if (_comboStreak > 0 && _comboStreak % 5 == 0) {
            _score += 20;
          }
          HapticFeedback.selectionClick();
        } else {
          _endGame();
          return;
        }
      }
    }
    _entities.removeWhere((e) => e.collected);
  }

  void _handleTap() {
    if (!_started) {
      _startGame();
      return;
    }
    if (_gameOver || _paused) return;
    _direction = -_direction;
  }

  void _startGame() {
    _started = true;
    _lastTick = Duration.zero;
    _startTime = DateTime.now();
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _resetGame() {
    _scrollDistance = 0;
    _fallSpeed = _baseFallSpeed;
    _direction = 1;
    _ballX = (_corridorLeft + _corridorRight) / 2;
    _entities.clear();
    _nextSpawnAt = 200;
    _score = 0;
    _crystalsThisGame = 0;
    _distanceMeters = 0;
    _gameOver = false;
    _paused = false;
    _started = false;
    _comboStreak = 0;
    _streakGlow = 0;
    _shake = 0;
    _timeSinceStart = 0;
    _hintOpacity = 1.0;
  }

  Future<void> _endGame() async {
    if (_gameOver) return;
    _gameOver = true;
    _shake = 1.0;
    if (_ticker.isActive) {
      _ticker.stop();
    }
    HapticFeedback.heavyImpact();
    final storage = GameStorage.instance;

    final elapsed = _startTime == null
        ? 0
        : DateTime.now().difference(_startTime!).inMilliseconds;

    final oldBestDistance = storage.bestDistance;
    final newDistanceRecord = _distanceMeters > oldBestDistance;
    if (newDistanceRecord) storage.bestDistance = _distanceMeters;

    if (_score > storage.bestScore) storage.bestScore = _score;
    if (elapsed > storage.bestSurvivalMs) storage.bestSurvivalMs = elapsed;

    Insight.event('game_over');
    Insight.tag('level', '$_distanceMeters');
    if (newDistanceRecord) Insight.event('game_new_distance_record');
    storage.addCrystals(_crystalsThisGame);
    storage.gamesPlayed = storage.gamesPlayed + 1;
    storage.incrementDailyProgress(
      crystalsCollected: _crystalsThisGame,
      distanceMeters: _distanceMeters,
      gamesPlayedDelta: 1,
      newDistanceRecord: newDistanceRecord,
      oneGameCrystals: _crystalsThisGame,
    );

    if (mounted) setState(() {});

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => GameOverScreen(
          score: _score,
          distance: _distanceMeters,
          crystals: _crystalsThisGame,
          isBestScore: _score >= storage.bestScore,
          isBestDistance: newDistanceRecord,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    if (!mounted) return;
    if (result == 'retry') {
      _resetGame();
      setState(() {});
    } else {
      Navigator.of(context).pop();
    }
  }

  void _togglePause() {
    if (!_started || _gameOver) return;
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: LayoutBuilder(
        builder: (context, cons) {
          _screenWidth = cons.maxWidth;
          _screenHeight = cons.maxHeight;
          final wallW = _screenWidth * _wallThicknessRatio;
          _corridorLeft = wallW;
          _corridorRight = _screenWidth - wallW;
          if (_ballX == 0) _ballX = _screenWidth / 2;
          _ballRadius = (_corridorRight - _corridorLeft) * 0.09;

          final storage = GameStorage.instance;
          final ball = Cosmetics.ballById(storage.selectedBallSkinId);
          final wall = Cosmetics.wallById(storage.selectedWallSkinId);
          final bg = Cosmetics.backgrounds[
              storage.selectedBgIndex.clamp(0, Cosmetics.backgrounds.length - 1)];

          final shakeOffset = _shake > 0
              ? Offset(
                  (_rnd.nextDouble() - 0.5) * 8 * _shake,
                  (_rnd.nextDouble() - 0.5) * 8 * _shake,
                )
              : Offset.zero;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: Transform.translate(
              offset: shakeOffset,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackground(bg),
                  _buildWall(left: true, skin: wall, width: wallW),
                  _buildWall(left: false, skin: wall, width: wallW),
                  ..._entities.map((e) => _buildEntity(e)),
                  _buildBall(ball),
                  _buildHud(),
                  if (!_started) _buildTapToStart(),
                  if (_paused) _buildPausedOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackground(String bg) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bg, fit: BoxFit.cover, gaplessPlayback: true),
          _ScrollingLines(scroll: _scrollDistance),
          Container(color: Colors.black.withOpacity(0.28)),
        ],
      ),
    );
  }

  Widget _buildWall({required bool left, required WallSkin skin, required double width}) {
    const tileH = 200.0;
    final tileCount = ((_screenHeight + tileH * 2) / tileH).ceil();
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: width,
      child: ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, -(_scrollDistance % tileH)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < tileCount; i++)
                  SizedBox(
                    width: width,
                    height: tileH,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        skin.tint.withOpacity(skin.tintStrength),
                        BlendMode.modulate,
                      ),
                      child: Image.asset(
                        'assets/vertical_neon_wall_asset.webp',
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntity(_Entity e) {
    final screenY = _entityScreenY(e);
    return Positioned(
      left: e.x - e.size / 2,
      top: screenY,
      width: e.size,
      height: e.size,
      child: IgnorePointer(
        child: Image.asset(e.asset, fit: BoxFit.contain, gaplessPlayback: true),
      ),
    );
  }

  Widget _buildBall(BallSkin ball) {
    final size = _ballRadius * 2.4;
    final ballY = _screenHeight * _ballScreenYRatio;
    final arrowSize = _ballRadius * 1.5;
    final showHint = _started && !_gameOver && _hintOpacity > 0.01;

    return Stack(
      children: [
        Positioned(
          left: _ballX - size / 2,
          top: ballY - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (ball.tint == Colors.transparent
                                ? AppColors.neonCyan
                                : ball.tint)
                            .withOpacity(0.65 + _streakGlow * 0.35),
                        blurRadius: 26 + _streakGlow * 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    ball.tint.withOpacity(ball.tintStrength),
                    BlendMode.modulate,
                  ),
                  child: Image.asset(
                    'assets/sphere_asset.webp',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: _ballX + _direction * (size * 0.55) - arrowSize / 2,
          top: ballY - arrowSize / 2,
          width: arrowSize,
          height: arrowSize,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (ctx, _) {
                final t = _pulseCtrl.value;
                final scale = 0.9 + 0.25 * sin(t * 2 * pi);
                return Opacity(
                  opacity: showHint ? _hintOpacity : 0.55,
                  child: Transform.scale(
                    scale: scale,
                    child: Transform.flip(
                      flipX: _direction < 0,
                      child: Image.asset(
                        'assets/neon_direction_asset.webp',
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHud() {
    final storage = GameStorage.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                _HudChip(
                  color: AppColors.neonCyan,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 6),
                      Text('$_score', style: AppTextStyles.body),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _HudChip(
                  color: AppColors.neonPink,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/crystal_gem_asset.webp', height: 18),
                      const SizedBox(width: 6),
                      Text('$_crystalsThisGame', style: AppTextStyles.body),
                    ],
                  ),
                ),
                const Spacer(),
                _HudChip(
                  color: AppColors.neonPurple,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.social_distance, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('$_distanceMeters m', style: AppTextStyles.body),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _togglePause,
                    child: NeonBorder(
                      color: AppColors.neonCyan,
                      radius: 14,
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _paused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Best: ${storage.bestScore}',
                  style: AppTextStyles.bodyDim,
                ),
                const SizedBox(width: 12),
                Text(
                  'Best distance: ${storage.bestDistance}m',
                  style: AppTextStyles.bodyDim,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapToStart() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.62),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'HOW TO PLAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      shadows: [
                        Shadow(color: AppColors.neonCyan, blurRadius: 14),
                        Shadow(color: AppColors.neonPink, blurRadius: 22),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _TutorialCard(
                    pulseCtrl: _pulseCtrl,
                  ),
                  const SizedBox(height: 20),
                  const _RuleRow(
                    icon: Icons.touch_app_rounded,
                    color: AppColors.neonCyan,
                    title: 'TAP anywhere',
                    subtitle: 'Ball switches direction ← →',
                  ),
                  const SizedBox(height: 10),
                  _RuleRow(
                    iconWidget: Image.asset('assets/crystal_gem_asset.webp',
                        width: 28, height: 28),
                    color: AppColors.neonPink,
                    title: 'COLLECT crystals',
                    subtitle: 'Score points and unlock skins',
                  ),
                  const SizedBox(height: 10),
                  const _RuleRow(
                    icon: Icons.dangerous_outlined,
                    color: AppColors.neonPurple,
                    title: 'AVOID obstacles',
                    subtitle: 'One hit ends the run',
                  ),
                  const SizedBox(height: 26),
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (ctx, _) {
                      final t = _pulseCtrl.value;
                      final scale = 0.94 + 0.06 * sin(t * 2 * pi);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              AppColors.neonCyan,
                              AppColors.neonPink,
                            ]),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonCyan.withOpacity(0.6),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded,
                                  color: Colors.white, size: 26),
                              SizedBox(width: 10),
                              Text(
                                'TAP TO START',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                  shadows: [Shadow(color: AppColors.neonPink, blurRadius: 14)],
                ),
              ),
              const SizedBox(height: 18),
              NeonButton(
                label: 'Resume',
                icon: Icons.play_arrow,
                onPressed: _togglePause,
              ),
              const SizedBox(height: 12),
              NeonButton(
                label: 'Exit',
                icon: Icons.exit_to_app,
                color: AppColors.neonPink,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final Widget child;
  final Color color;
  const _HudChip({required this.child, required this.color});
  @override
  Widget build(BuildContext context) {
    return NeonBorder(
      color: color,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: child,
    );
  }
}

class _ScrollingLines extends StatelessWidget {
  final double scroll;
  const _ScrollingLines({required this.scroll});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinesPainter(scroll),
      size: Size.infinite,
    );
  }
}

class _LinesPainter extends CustomPainter {
  final double scroll;
  _LinesPainter(this.scroll);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.neonCyan.withOpacity(0.08)
      ..strokeWidth = 1;
    const spacing = 60.0;
    final offset = scroll % spacing;
    for (double y = -spacing + offset; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter oldDelegate) => oldDelegate.scroll != scroll;
}

class _TutorialCard extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _TutorialCard({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: NeonBorder(
        color: AppColors.neonCyan,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: LayoutBuilder(
          builder: (context, cons) {
            return AnimatedBuilder(
              animation: pulseCtrl,
              builder: (ctx, _) {
                final t = pulseCtrl.value;
                final ballX = cons.maxWidth *
                    (0.2 + 0.6 * (0.5 + 0.5 * sin(t * 2 * pi)));
                final dir = cos(t * 2 * pi) >= 0 ? 1 : -1;
                final tapPulse = 0.6 + 0.4 * sin(t * 2 * pi);
                return Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 10,
                      right: 12,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonCyan.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 30,
                      right: 12,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.neonPink.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonPink.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: ballX - 22,
                      top: cons.maxHeight * 0.3,
                      width: 44,
                      height: 44,
                      child: Image.asset(
                        'assets/sphere_asset.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: ballX + dir * 30 - 12,
                      top: cons.maxHeight * 0.35,
                      width: 24,
                      height: 24,
                      child: Transform.flip(
                        flipX: dir < 0,
                        child: Image.asset(
                          'assets/neon_direction_asset.webp',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 6,
                      child: Opacity(
                        opacity: tapPulse,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.neonCyan.withOpacity(tapPulse),
                                blurRadius: 18,
                                spreadRadius: 3 * tapPulse,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 12,
                      bottom: 4,
                      child: Text(
                        'Watch: TAP flips direction',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color color;
  final String title;
  final String subtitle;

  const _RuleRow({
    this.icon,
    this.iconWidget,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.7), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.35), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: iconWidget ??
                  Icon(icon, color: color, size: 26, shadows: [
                    Shadow(color: color, blurRadius: 10),
                  ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB4BCEE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
