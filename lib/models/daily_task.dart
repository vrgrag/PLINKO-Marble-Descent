import 'dart:math';

enum DailyTaskType {
  collectCrystals,
  travelDistance,
  crystalsInOneGame,
  playGames,
  beatRecord,
}

class DailyTask {
  final String id;
  final DailyTaskType type;
  final int target;
  final int reward;
  int progress;
  bool claimed;

  DailyTask({
    required this.id,
    required this.type,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  String get title {
    switch (type) {
      case DailyTaskType.collectCrystals:
        return 'Collect $target crystals';
      case DailyTaskType.travelDistance:
        return 'Travel $target m in total';
      case DailyTaskType.crystalsInOneGame:
        return 'Get $target crystals in one run';
      case DailyTaskType.playGames:
        return 'Play $target games';
      case DailyTaskType.beatRecord:
        return 'Set a new distance record';
    }
  }

  bool get completed => progress >= target;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'target': target,
        'reward': reward,
        'progress': progress,
        'claimed': claimed,
      };

  factory DailyTask.fromJson(Map<String, dynamic> json) => DailyTask(
        id: json['id'] as String,
        type: DailyTaskType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DailyTaskType.collectCrystals,
        ),
        target: json['target'] as int,
        reward: json['reward'] as int,
        progress: json['progress'] as int? ?? 0,
        claimed: json['claimed'] as bool? ?? false,
      );

  static List<DailyTask> generateSet() {
    final rnd = Random();
    return [
      DailyTask(
        id: 'crystals_${rnd.nextInt(1 << 30)}',
        type: DailyTaskType.collectCrystals,
        target: 100,
        reward: 40,
      ),
      DailyTask(
        id: 'distance_${rnd.nextInt(1 << 30)}',
        type: DailyTaskType.travelDistance,
        target: 5000,
        reward: 60,
      ),
      DailyTask(
        id: 'crystals_run_${rnd.nextInt(1 << 30)}',
        type: DailyTaskType.crystalsInOneGame,
        target: 25,
        reward: 30,
      ),
      DailyTask(
        id: 'games_${rnd.nextInt(1 << 30)}',
        type: DailyTaskType.playGames,
        target: 5,
        reward: 25,
      ),
      DailyTask(
        id: 'record_${rnd.nextInt(1 << 30)}',
        type: DailyTaskType.beatRecord,
        target: 1,
        reward: 80,
      ),
    ];
  }
}
