import 'package:flutter/material.dart';

import '../models/daily_task.dart';
import '../services/game_storage.dart';
import '../theme.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = GameStorage.instance;
    final tasks = storage.dailyTasks;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg3_asset.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),
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
                      const Text('DAILY TASKS', style: AppTextStyles.heading),
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: AppColors.neonCyan),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tasks reset daily. Progress persists across runs.',
                          style: AppTextStyles.bodyDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemBuilder: (ctx, i) => _TaskCard(
                      task: tasks[i],
                      onClaim: () {
                        storage.claimDailyReward(tasks[i]);
                        setState(() {});
                      },
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: tasks.length,
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

class _TaskCard extends StatelessWidget {
  final DailyTask task;
  final VoidCallback onClaim;
  const _TaskCard({required this.task, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final progress = task.target == 0 ? 0.0 : (task.progress / task.target).clamp(0.0, 1.0);
    final done = task.completed;
    return NeonBorder(
      color: task.claimed
          ? Colors.white24
          : (done ? Colors.amberAccent : AppColors.neonPurple),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neonCyan.withOpacity(0.5)),
            ),
            child: Icon(_iconFor(task.type), color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: AppTextStyles.body),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      done ? Colors.amberAccent : AppColors.neonCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${task.progress} / ${task.target}',
                    style: AppTextStyles.bodyDim),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _rewardButton(),
        ],
      ),
    );
  }

  Widget _rewardButton() {
    if (task.claimed) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
          SizedBox(height: 4),
          Text('CLAIMED',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              )),
        ],
      );
    }
    if (task.completed) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onClaim,
          borderRadius: BorderRadius.circular(12),
          child: NeonBorder(
            color: Colors.amberAccent,
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/crystal_gem_asset.webp', height: 18),
                    const SizedBox(width: 4),
                    Text('${task.reward}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('CLAIM',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    )),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/crystal_gem_asset.webp', height: 18),
            const SizedBox(width: 4),
            Text('+${task.reward}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ],
    );
  }

  IconData _iconFor(DailyTaskType t) {
    switch (t) {
      case DailyTaskType.collectCrystals:
        return Icons.diamond_outlined;
      case DailyTaskType.travelDistance:
        return Icons.route_outlined;
      case DailyTaskType.crystalsInOneGame:
        return Icons.auto_awesome;
      case DailyTaskType.playGames:
        return Icons.videogame_asset_outlined;
      case DailyTaskType.beatRecord:
        return Icons.emoji_events_outlined;
    }
  }
}
