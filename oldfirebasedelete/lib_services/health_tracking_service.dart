// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/health_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import '../utils/toast_utils.dart';
import 'auth_service.dart';

class HealthTrackingService {
  static final Databases _databases = Databases(appwriteClient);
  static final _authService = AuthService.instance;
  static final _logger = Logger('HealthTrackingService');

  static Future<List<Map<String, dynamic>>> fetchHealthData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw AuthException('User not authenticated');
      }

      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.healthTrackingCollectionId,
        queries: [
          Query.equal('user_id', user.uid),
          Query.orderDesc('date'),
          Query.limit(30),
        ],
      );

      return response.documents.map((doc) {
        return {
          ...doc.data,
          'id': doc.$id,
        };
      }).toList();
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

      final today = _todayKey();
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.healthTrackingCollectionId,
        queries: [
          Query.equal('user_id', user.uid),
          Query.equal('date', today),
          Query.limit(1),
        ],
      );

      if (response.documents.isEmpty) return null;
      final doc = response.documents.first;
      return {
        ...doc.data,
        'id': doc.$id,
      };
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

      final today = _todayKey();
      final docId = _healthDocumentId(user.uid, today);
      final now = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'user_id': user.uid,
        'date': today,
        ...data,
        'updated_at': now,
      };

      try {
        await _databases.updateDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.healthTrackingCollectionId,
          documentId: docId,
          data: payload,
        );
      } on AppwriteException catch (error) {
        if (error.code != 404) rethrow;
        await _databases.createDocument(
          databaseId: AppwriteBackendConfig.databaseId,
          collectionId: AppwriteBackendConfig.healthTrackingCollectionId,
          documentId: docId,
          data: {
            ...payload,
            'created_at': now,
          },
        );
      }

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
      final currentIntake = _intValue(todayData?['water_intake']);
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
      final currentMinutes = _intValue(todayData?['exercise_minutes']);
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
      final currentMinutes = _intValue(todayData?['sunlight_minutes']);
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

  // Calculate today's wellness score based on health data.
  static int getTodayWellnessScore(HealthData? todayData) {
    if (todayData == null) return 0;

    final scores = [
      (todayData.waterIntake / 8).clamp(0, 1) * 100,
      (todayData.exerciseMinutes / 30).clamp(0, 1) * 100,
      (todayData.sunlightMinutes / 20).clamp(0, 1) * 100,
      (todayData.sleepHours / 8).clamp(0, 1) * 100,
      todayData.nutritionScore.toDouble(),
      todayData.temperanceScore.toDouble(),
      todayData.airQualityScore.toDouble(),
      todayData.restScore.toDouble(),
      todayData.trustInGodScore.toDouble(),
    ];

    return (scores.reduce((acc, score) => acc + score) / scores.length).round();
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static String _healthDocumentId(String userId, String date) {
    return '${userId}_${date.replaceAll('-', '_')}';
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
