import 'package:flutter/material.dart';

import '../theme.dart';

class GameOverScreen extends StatelessWidget {
  final int score;
  final int distance;
  final int crystals;
  final bool isBestScore;
  final bool isBestDistance;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.distance,
    required this.crystals,
    required this.isBestScore,
    required this.isBestDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.72),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: NeonBorder(
            color: AppColors.neonPink,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: AppColors.neonPink, blurRadius: 16),
                      Shadow(color: AppColors.neonCyan, blurRadius: 22),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _StatRow(
                  label: 'Score',
                  value: '$score',
                  icon: Icons.star_rounded,
                  color: Colors.amberAccent,
                  highlight: isBestScore,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'Distance',
                  value: '$distance m',
                  icon: Icons.route_rounded,
                  color: AppColors.neonCyan,
                  highlight: isBestDistance,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'Crystals',
                  value: '$crystals',
                  icon: Icons.diamond_outlined,
                  color: AppColors.neonPurple,
                ),
                if (isBestDistance || isBestScore) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'NEW RECORD!',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(color: Colors.amberAccent, blurRadius: 14),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                NeonButton(
                  label: 'Retry',
                  icon: Icons.replay_rounded,
                  color: AppColors.neonCyan,
                  onPressed: () => Navigator.of(context).pop('retry'),
                ),
                const SizedBox(height: 10),
                NeonButton(
                  label: 'Menu',
                  icon: Icons.home_rounded,
                  color: AppColors.neonPink,
                  onPressed: () => Navigator.of(context).pop('menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? Colors.amberAccent : color.withOpacity(0.7),
          width: 1.2,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.35), blurRadius: 14)]
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22, shadows: [
            Shadow(color: color, blurRadius: 10),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.number),
        ],
      ),
    );
  }
}
