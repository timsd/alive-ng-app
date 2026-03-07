// Removed supabase_flutter import - using Firebase now
import '../utils/toast_utils.dart';
import '../utils/logger.dart';
import '../models/health_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_database_service.dart';
import 'auth_service.dart';
import '../utils/app_exception.dart';

class HealthTrackingService {
  static final _firebaseService = FirebaseDatabaseService.instance;
  static final _authService = AuthService.instance;
  static final _logger = Logger('HealthTrackingService');

  static Future<List<Map<String, dynamic>>> fetchHealthData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final snapshot = await _firebaseService.firestore
          .collection('health_tracking')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (error) {
      _logger.error('Error fetching health data', error);
      ToastUtils.showError('Failed to load health data');
      if (error is AppException) rethrow;
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getTodayData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;

      final today = DateTime.now().toIso8601String().split('T')[0];

      final snapshot = await _firebaseService.firestore
          .collection('health_tracking')
          .where('user_id', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } catch (error) {
      _logger.error('Error fetching today\'s health data', error);
      return null;
    }
  }

  static Future<bool> updateHealthData(Map<String, dynamic> data) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to track your health');
        return false;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      // Create a deterministic ID based on uid and date to ensure one doc per day
      final docId = '${user.uid}_$today';

      await _firebaseService.firestore
          .collection('health_tracking')
          .doc(docId)
          .set({
        'user_id': user.uid,
        'date': today,
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ToastUtils.showSuccess('Health data updated');
      return true;
    } catch (error) {
      _logger.error('Error updating health data', error);
      ToastUtils.showError('Could not save your health tracking');
      return false;
    }
  }

  static Future<bool> logWaterIntake(int glasses) async {
    try {
      final todayData = await getTodayData();
      final currentIntake = todayData?['water_intake'] ?? 0;
      return await updateHealthData({
        'water_intake': currentIntake + glasses,
      });
    } catch (error) {
      _logger.error('Error logging water intake', error);
      return false;
    }
  }

  static Future<bool> logExercise(int minutes) async {
    try {
      final todayData = await getTodayData();
      final currentMinutes = todayData?['exercise_minutes'] ?? 0;
      return await updateHealthData({
        'exercise_minutes': currentMinutes + minutes,
      });
    } catch (error) {
      _logger.error('Error logging exercise', error);
      return false;
    }
  }

  static Future<bool> logSunlight(int minutes) async {
    try {
      final todayData = await getTodayData();
      final currentMinutes = todayData?['sunlight_minutes'] ?? 0;
      return await updateHealthData({
        'sunlight_minutes': currentMinutes + minutes,
      });
    } catch (error) {
      _logger.error('Error logging sunlight', error);
      return false;
    }
  }

  static Future<bool> logSleep(double hours) async {
    try {
      return await updateHealthData({
        'sleep_hours': hours,
      });
    } catch (error) {
      _logger.error('Error logging sleep', error);
      return false;
    }
  }

  static Future<bool> updateScores({
    int? nutritionScore,
    int? temperanceScore,
    int? freshAirScore,
    int? trustScore,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nutritionScore != null) updates['nutrition_score'] = nutritionScore;
      if (temperanceScore != null) {
        updates['temperance_score'] = temperanceScore;
      }
      if (freshAirScore != null) updates['fresh_air_score'] = freshAirScore;
      if (trustScore != null) updates['trust_score'] = trustScore;

      return await updateHealthData(updates);
    } catch (error) {
      _logger.error('Error updating scores', error);
      return false;
    }
  }

  // Calculate today's wellness score based on health data
  static int getTodayWellnessScore(HealthData? todayData) {
    if (todayData == null) return 0;

    final scores = [
      (todayData.waterIntake / 8).clamp(0, 1) * 100, // 8 glasses target
      (todayData.exerciseMinutes / 30).clamp(0, 1) * 100, // 30 min target
      (todayData.sunlightMinutes / 20).clamp(0, 1) * 100, // 20 min target
      (todayData.sleepHours / 8).clamp(0, 1) * 100, // 8 hours target
      todayData.nutritionScore.toDouble(),
      todayData.temperanceScore.toDouble(),
      todayData.airQualityScore.toDouble(),
      todayData.restScore.toDouble(),
      todayData.trustInGodScore.toDouble(),
    ];

    return (scores.reduce((acc, score) => acc + score) / scores.length).round();
  }
}
