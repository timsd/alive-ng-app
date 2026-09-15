import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// Per-user progress for Kids Missions. Mission rows in Appwrite are shared
/// content, so per-child completion state and earned points are tracked
/// locally (keyed by user id) and mirrored onto the UI.
class KidsMissionProgressService {
  static final KidsMissionProgressService _instance =
      KidsMissionProgressService._internal();
  factory KidsMissionProgressService() => _instance;
  KidsMissionProgressService._internal();

  static final Logger _logger = Logger('KidsMissionProgress');

  static const String _completedKey = 'kids_missions_completed';
  static const String _pointsKey = 'kids_missions_points';
  static const String _scoresKey = 'kids_missions_scores';

  Set<String> _completedIds = {};
  int _totalPoints = 0;
  Map<String, int> _bestScores = {};
  bool _loaded = false;

  Set<String> get completedIds => _completedIds;
  int get totalPoints => _totalPoints;

  bool isCompleted(String missionId) => _completedIds.contains(missionId);

  int bestScore(String missionId) => _bestScores[missionId] ?? 0;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _completedIds = (prefs.getStringList(_completedKey) ?? []).toSet();
      _totalPoints = prefs.getInt(_pointsKey) ?? 0;
      final raw = prefs.getString(_scoresKey);
      if (raw != null && raw.isNotEmpty) {
        _bestScores = (json.decode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toInt()));
      }
      _loaded = true;
    } catch (e) {
      _logger.error('Failed to load mission progress: $e');
      _loaded = true;
    }
  }

  /// Marks a mission complete and awards its points. Returns true when this
  /// was the first completion (points awarded), false if already done.
  Future<bool> completeMission(String missionId, int points,
      {int? score}) async {
    await load();
    if (_completedIds.contains(missionId)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      _completedIds.add(missionId);
      _totalPoints += points;
      if (score != null && score > bestScore(missionId)) {
        _bestScores[missionId] = score;
      }
      await prefs.setStringList(_completedKey, _completedIds.toList());
      await prefs.setInt(_pointsKey, _totalPoints);
      await prefs.setString(_scoresKey, json.encode(_bestScores));
      return true;
    } catch (e) {
      _logger.error('Failed to persist mission progress: $e');
      return false;
    }
  }

  /// Records a recitation/quiz attempt without completing the mission
  /// (used when the child did not reach the pass threshold).
  Future<void> recordAttempt(String missionId, int score) async {
    await load();
    if (score <= bestScore(missionId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _bestScores[missionId] = score;
      await prefs.setString(_scoresKey, json.encode(_bestScores));
    } catch (_) {}
  }
}
