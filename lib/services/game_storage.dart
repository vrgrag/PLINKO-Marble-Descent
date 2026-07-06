import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cosmetics.dart';
import '../models/daily_task.dart';

class GameStorage {
  GameStorage._();
  static final GameStorage instance = GameStorage._();

  late SharedPreferences _prefs;
  bool _initialized = false;

  static const _kTotalCrystals = 'total_crystals';
  static const _kBestScore = 'best_score';
  static const _kBestDistance = 'best_distance';
  static const _kBestSurvivalMs = 'best_survival_ms';
  static const _kGamesPlayed = 'games_played';
  static const _kLifetimeCrystals = 'lifetime_crystals';
  static const _kSoundEnabled = 'sound_enabled';
  static const _kSelectedBall = 'selected_ball_skin';
  static const _kSelectedWall = 'selected_wall_skin';
  static const _kUnlockedBalls = 'unlocked_ball_skins';
  static const _kUnlockedWalls = 'unlocked_wall_skins';
  static const _kSelectedBg = 'selected_bg_index';
  static const _kDailyTasks = 'daily_tasks_v1';
  static const _kDailyDate = 'daily_tasks_date';

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    _ensureDailyTasks();
    _ensureUnlockedDefaults();
  }

  void _ensureUnlockedDefaults() {
    if (unlockedBallSkinIds.isEmpty) {
      unlockedBallSkinIds = [Cosmetics.ballSkins.first.id];
    }
    if (unlockedWallSkinIds.isEmpty) {
      unlockedWallSkinIds = [Cosmetics.wallSkins.first.id];
    }
  }

  int get totalCrystals => _prefs.getInt(_kTotalCrystals) ?? 0;
  set totalCrystals(int v) => _prefs.setInt(_kTotalCrystals, v);

  int get lifetimeCrystals => _prefs.getInt(_kLifetimeCrystals) ?? 0;
  set lifetimeCrystals(int v) => _prefs.setInt(_kLifetimeCrystals, v);

  int get bestScore => _prefs.getInt(_kBestScore) ?? 0;
  set bestScore(int v) => _prefs.setInt(_kBestScore, v);

  int get bestDistance => _prefs.getInt(_kBestDistance) ?? 0;
  set bestDistance(int v) => _prefs.setInt(_kBestDistance, v);

  int get bestSurvivalMs => _prefs.getInt(_kBestSurvivalMs) ?? 0;
  set bestSurvivalMs(int v) => _prefs.setInt(_kBestSurvivalMs, v);

  int get gamesPlayed => _prefs.getInt(_kGamesPlayed) ?? 0;
  set gamesPlayed(int v) => _prefs.setInt(_kGamesPlayed, v);

  bool get soundEnabled => _prefs.getBool(_kSoundEnabled) ?? true;
  set soundEnabled(bool v) => _prefs.setBool(_kSoundEnabled, v);

  String get selectedBallSkinId =>
      _prefs.getString(_kSelectedBall) ?? Cosmetics.ballSkins.first.id;
  set selectedBallSkinId(String v) => _prefs.setString(_kSelectedBall, v);

  String get selectedWallSkinId =>
      _prefs.getString(_kSelectedWall) ?? Cosmetics.wallSkins.first.id;
  set selectedWallSkinId(String v) => _prefs.setString(_kSelectedWall, v);

  int get selectedBgIndex => _prefs.getInt(_kSelectedBg) ?? 0;
  set selectedBgIndex(int v) => _prefs.setInt(_kSelectedBg, v);

  List<String> get unlockedBallSkinIds =>
      _prefs.getStringList(_kUnlockedBalls) ?? const <String>[];
  set unlockedBallSkinIds(List<String> v) =>
      _prefs.setStringList(_kUnlockedBalls, v);

  List<String> get unlockedWallSkinIds =>
      _prefs.getStringList(_kUnlockedWalls) ?? const <String>[];
  set unlockedWallSkinIds(List<String> v) =>
      _prefs.setStringList(_kUnlockedWalls, v);

  bool isBallUnlocked(String id) => unlockedBallSkinIds.contains(id);
  bool isWallUnlocked(String id) => unlockedWallSkinIds.contains(id);

  void unlockBall(String id) {
    if (isBallUnlocked(id)) return;
    unlockedBallSkinIds = [...unlockedBallSkinIds, id];
  }

  void unlockWall(String id) {
    if (isWallUnlocked(id)) return;
    unlockedWallSkinIds = [...unlockedWallSkinIds, id];
  }

  bool trySpendCrystals(int amount) {
    if (totalCrystals < amount) return false;
    totalCrystals = totalCrystals - amount;
    return true;
  }

  void addCrystals(int amount) {
    totalCrystals = totalCrystals + amount;
    lifetimeCrystals = lifetimeCrystals + amount;
  }

  List<DailyTask> get dailyTasks {
    _ensureDailyTasks();
    final raw = _prefs.getString(_kDailyTasks);
    if (raw == null || raw.isEmpty) return const <DailyTask>[];
    final list = (jsonDecode(raw) as List)
        .map((e) => DailyTask.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  set dailyTasks(List<DailyTask> tasks) {
    final raw = jsonEncode(tasks.map((e) => e.toJson()).toList());
    _prefs.setString(_kDailyTasks, raw);
  }

  void _ensureDailyTasks() {
    final today = _todayKey();
    final stored = _prefs.getString(_kDailyDate);
    if (stored == today && (_prefs.getString(_kDailyTasks)?.isNotEmpty ?? false)) {
      return;
    }
    final generated = DailyTask.generateSet();
    _prefs.setString(_kDailyDate, today);
    _prefs.setString(
      _kDailyTasks,
      jsonEncode(generated.map((e) => e.toJson()).toList()),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void updateDailyTasks(void Function(List<DailyTask> tasks) mutator) {
    final tasks = dailyTasks;
    mutator(tasks);
    dailyTasks = tasks;
  }

  void incrementDailyProgress({
    int crystalsCollected = 0,
    int distanceMeters = 0,
    int gamesPlayedDelta = 0,
    bool newDistanceRecord = false,
    int? oneGameCrystals,
  }) {
    updateDailyTasks((tasks) {
      for (final t in tasks) {
        switch (t.type) {
          case DailyTaskType.collectCrystals:
            t.progress = (t.progress + crystalsCollected).clamp(0, t.target);
            break;
          case DailyTaskType.travelDistance:
            t.progress = (t.progress + distanceMeters).clamp(0, t.target);
            break;
          case DailyTaskType.crystalsInOneGame:
            if (oneGameCrystals != null && oneGameCrystals > t.progress) {
              t.progress = oneGameCrystals.clamp(0, t.target);
            }
            break;
          case DailyTaskType.playGames:
            t.progress = (t.progress + gamesPlayedDelta).clamp(0, t.target);
            break;
          case DailyTaskType.beatRecord:
            if (newDistanceRecord) t.progress = t.target;
            break;
        }
      }
    });
  }

  void claimDailyReward(DailyTask task) {
    updateDailyTasks((tasks) {
      final match = tasks.firstWhere(
        (t) => t.id == task.id,
        orElse: () => task,
      );
      if (match.progress >= match.target && !match.claimed) {
        match.claimed = true;
        addCrystals(match.reward);
      }
    });
  }
}
