import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/insight.dart';
import '../models/cosmetics.dart';
import '../services/game_storage.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'shop_screen.dart';
import 'tasks_screen.dart';
import 'settings_screen.dart';
import 'webview_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Insight.screen('menu');
  }

  Future<void> _openGame() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final storage = GameStorage.instance;
    final bgPath = Cosmetics.backgrounds[storage.selectedBgIndex.clamp(0, Cosmetics.backgrounds.length - 1)];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bgPath, fit: BoxFit.cover, gaplessPlayback: true),
          Container(color: Colors.black.withOpacity(0.35)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoHeight = (constraints.maxHeight * 0.22).clamp(120.0, 240.0);
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TopStatsBar(storage: storage),
                        const SizedBox(height: 18),
                        Center(
                          child: Image.asset(
                            'assets/Game_Name.webp',
                            height: logoHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RecordsCard(storage: storage),
                        const SizedBox(height: 18),
                        NeonButton(
                          label: 'Play',
                          icon: Icons.play_arrow_rounded,
                          color: AppColors.neonCyan,
                          onPressed: _openGame,
                          height: 64,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: NeonButton(
                                label: 'Shop',
                                icon: Icons.shopping_bag_rounded,
                                color: AppColors.neonPink,
                                onPressed: () => _open(const ShopScreen()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: NeonButton(
                                label: 'Tasks',
                                icon: Icons.checklist_rounded,
                                color: AppColors.neonPurple,
                                onPressed: () => _open(const TasksScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniButton(
                                icon: Icons.settings,
                                label: 'Settings',
                                onTap: () => _open(const SettingsScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniButton(
                                icon: Icons.shield_outlined,
                                label: 'Privacy',
                                onTap: () => _open(
                                  const WebPageScreen(
                                    title: 'Privacy Policy',
                                    url:
                                        'https://marbledescent.com/privacy-policy.html',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniButton(
                                icon: Icons.support_agent_rounded,
                                label: 'Support',
                                onTap: () => _open(
                                  const WebPageScreen(
                                    title: 'Support',
                                    url:
                                        'https://marbledescent.com/support.html',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStatsBar extends StatelessWidget {
  final GameStorage storage;
  const _TopStatsBar({required this.storage});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: NeonBorder(
            color: AppColors.neonCyan,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Image.asset('assets/crystal_gem_asset.webp', height: 28),
                const SizedBox(width: 8),
                Text('${storage.totalCrystals}', style: AppTextStyles.number),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: NeonBorder(
            color: AppColors.neonPurple,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 26),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${storage.bestScore}',
                    style: AppTextStyles.number,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordsCard extends StatelessWidget {
  final GameStorage storage;
  const _RecordsCard({required this.storage});

  @override
  Widget build(BuildContext context) {
    return NeonBorder(
      color: AppColors.neonPink,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        children: [
          _row(Icons.route_outlined, 'Best distance', '${storage.bestDistance} m'),
          const SizedBox(height: 6),
          _row(Icons.diamond_outlined, 'Total crystals mined', '${storage.lifetimeCrystals}'),
          const SizedBox(height: 6),
          _row(Icons.videogame_asset_outlined, 'Games played', '${storage.gamesPlayed}'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonCyan, size: 20, shadows: const [
          Shadow(color: AppColors.neonCyan, blurRadius: 8),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.bodyDim)),
        Text(value, style: AppTextStyles.body),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: NeonBorder(
          color: AppColors.neonPurple,
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 22, shadows: const [
                Shadow(color: AppColors.neonCyan, blurRadius: 10),
              ]),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
