import 'package:flutter/material.dart';

import '../models/cosmetics.dart';
import '../services/game_storage.dart';
import '../theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = GameStorage.instance;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg2_asset.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),
          SafeArea(
            child: Column(
              children: [
                _header(context, storage),
                TabBar(
                  controller: _tab,
                  indicatorColor: AppColors.neonCyan,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4),
                  tabs: const [
                    Tab(text: 'BALLS'),
                    Tab(text: 'WALLS'),
                    Tab(text: 'ARENAS'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _ballGrid(storage),
                      _wallGrid(storage),
                      _bgGrid(storage),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext ctx, GameStorage storage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Text('SHOP', style: AppTextStyles.heading),
          const Spacer(),
          NeonBorder(
            color: AppColors.neonCyan,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Image.asset('assets/crystal_gem_asset.webp', height: 22),
                const SizedBox(width: 6),
                Text('${storage.totalCrystals}', style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ballGrid(GameStorage storage) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: Cosmetics.ballSkins.length,
      itemBuilder: (ctx, i) {
        final s = Cosmetics.ballSkins[i];
        final unlocked = storage.isBallUnlocked(s.id);
        final selected = storage.selectedBallSkinId == s.id;
        return _CosmeticCard(
          title: s.name,
          selected: selected,
          unlocked: unlocked,
          price: s.price,
          accent: s.tint == Colors.transparent ? AppColors.neonCyan : s.tint,
          preview: ColorFiltered(
            colorFilter: ColorFilter.mode(
              s.tint.withOpacity(s.tintStrength),
              BlendMode.modulate,
            ),
            child: Image.asset('assets/sphere_asset.webp'),
          ),
          onTap: () async {
            if (!unlocked) {
              final ok = storage.trySpendCrystals(s.price);
              if (!ok) {
                _notEnough();
                return;
              }
              storage.unlockBall(s.id);
            }
            storage.selectedBallSkinId = s.id;
            setState(() {});
          },
        );
      },
    );
  }

  Widget _wallGrid(GameStorage storage) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: Cosmetics.wallSkins.length,
      itemBuilder: (ctx, i) {
        final s = Cosmetics.wallSkins[i];
        final unlocked = storage.isWallUnlocked(s.id);
        final selected = storage.selectedWallSkinId == s.id;
        return _CosmeticCard(
          title: s.name,
          selected: selected,
          unlocked: unlocked,
          price: s.price,
          accent: s.tint == Colors.transparent ? AppColors.neonCyan : s.tint,
          preview: ColorFiltered(
            colorFilter: ColorFilter.mode(
              s.tint.withOpacity(s.tintStrength),
              BlendMode.modulate,
            ),
            child: Image.asset('assets/vertical_neon_wall_asset.webp'),
          ),
          onTap: () async {
            if (!unlocked) {
              final ok = storage.trySpendCrystals(s.price);
              if (!ok) {
                _notEnough();
                return;
              }
              storage.unlockWall(s.id);
            }
            storage.selectedWallSkinId = s.id;
            setState(() {});
          },
        );
      },
    );
  }

  Widget _bgGrid(GameStorage storage) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemCount: Cosmetics.backgrounds.length,
      itemBuilder: (ctx, i) {
        final path = Cosmetics.backgrounds[i];
        final selected = storage.selectedBgIndex == i;
        return _CosmeticCard(
          title: 'Arena ${i + 1}',
          selected: selected,
          unlocked: true,
          price: 0,
          accent: AppColors.neonPurple,
          preview: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(path, fit: BoxFit.cover),
          ),
          onTap: () {
            storage.selectedBgIndex = i;
            setState(() {});
          },
        );
      },
    );
  }

  void _notEnough() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Not enough crystals'),
        backgroundColor: AppColors.deepBlue,
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  final String title;
  final bool unlocked;
  final bool selected;
  final int price;
  final Color accent;
  final Widget preview;
  final VoidCallback onTap;

  const _CosmeticCard({
    required this.title,
    required this.unlocked,
    required this.selected,
    required this.price,
    required this.accent,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: NeonBorder(
          color: selected ? Colors.amberAccent : accent,
          radius: 18,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: preview,
                    ),
                    if (!unlocked)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.lock, color: Colors.white, size: 32),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              if (selected)
                const Text('SELECTED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ))
              else if (!unlocked)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/crystal_gem_asset.webp', height: 16),
                    const SizedBox(width: 4),
                    Text('$price',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                )
              else
                const Text('TAP TO EQUIP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
