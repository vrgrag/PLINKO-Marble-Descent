import 'package:flutter/material.dart';

import '../services/game_storage.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = GameStorage.instance;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg1_asset.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.6)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Text('SETTINGS', style: AppTextStyles.heading),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NeonBorder(
                    color: AppColors.neonCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.vibration, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Haptic feedback', style: AppTextStyles.body),
                        ),
                        Switch.adaptive(
                          value: storage.soundEnabled,
                          activeColor: AppColors.neonCyan,
                          onChanged: (v) {
                            storage.soundEnabled = v;
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NeonBorder(
                    color: AppColors.neonPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Statistics', style: AppTextStyles.heading),
                        const SizedBox(height: 8),
                        _stat('Best score', '${storage.bestScore}'),
                        _stat('Best distance', '${storage.bestDistance} m'),
                        _stat('Games played', '${storage.gamesPlayed}'),
                        _stat('Total crystals earned', '${storage.lifetimeCrystals}'),
                        _stat('Longest survival',
                            '${(storage.bestSurvivalMs / 1000).toStringAsFixed(1)} s'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NeonBorder(
                    color: AppColors.neonPink,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        const Text('Reset all progress',
                            style: AppTextStyles.body),
                        const SizedBox(height: 8),
                        NeonButton(
                          label: 'Reset',
                          icon: Icons.delete_forever,
                          color: AppColors.neonPink,
                          onPressed: () async {
                            final ok = await _confirm(context);
                            if (ok) {
                              storage.totalCrystals = 0;
                              storage.lifetimeCrystals = 0;
                              storage.bestScore = 0;
                              storage.bestDistance = 0;
                              storage.bestSurvivalMs = 0;
                              storage.gamesPlayed = 0;
                              storage.unlockedBallSkinIds = ['ball_default'];
                              storage.unlockedWallSkinIds = ['wall_default'];
                              storage.selectedBallSkinId = 'ball_default';
                              storage.selectedWallSkinId = 'wall_default';
                              storage.selectedBgIndex = 0;
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyDim)),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deepBlue,
        title: const Text('Reset progress?', style: AppTextStyles.body),
        content: const Text(
          'This will erase all crystals, records and unlocked skins.',
          style: AppTextStyles.bodyDim,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET', style: TextStyle(color: AppColors.neonPink)),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}
