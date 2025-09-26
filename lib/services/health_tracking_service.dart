import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/toast_utils.dart';
import '../utils/logger.dart';
import '../models/health_models.dart';

class HealthTrackingService {
  static final _supabase = Supabase.instance.client;
  static final _logger = Logger('HealthTrackingService');

  static Future<List<Map<String, dynamic>>> fetchHealthData() async {
    try {
      final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

      final response = await _supabase
          .from('health_tracking')
          .select('*')
          .eq('user_id', user.id)
          .order('date', ascending: false)
          .limit(30); // Last 30 days

      return (response as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();
    } catch (error) {
      _logger.error('Error fetching health data', error);
      ToastUtils.showError('Failed to load health data');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getTodayData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('health_tracking')
          .select('*')
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      return response;
    } catch (error) {
      _logger.error('Error fetching today\'s health data', error);
      return null;
    }
  }

  static Future<bool> updateHealthData(Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        ToastUtils.showError('Please log in to track your health');
        return false;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      await _supabase.from('health_tracking').upsert({
        'user_id': user.id,
        'date': today,
        ...data,
      });

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

    return (scores.reduce((sum, score) => sum + score) / scores.length).round();
  }
}




