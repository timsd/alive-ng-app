// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class AppwriteHealthService {
  static final AppwriteHealthService instance = AppwriteHealthService._();

  AppwriteHealthService._();

  late final Databases _databases = Databases(appwriteClient);
  final Logger _logger = Logger('AppwriteHealthService');

  Future<List<HealthTracking>> getUserHealthTracking(String userId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.healthTrackingCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('tracked_at'),
          Query.limit(200),
        ],
      );

      return response.documents.map((doc) {
        final data = doc.data;
        return HealthTracking(
          id: doc.$id,
          userId: _string(data['user_id']),
          category: _string(data['category'], fallback: 'general'),
          value: _double(data['value']),
          unit: _string(data['unit']),
          notes: data['notes'] as String?,
          trackedAt: _date(data['tracked_at'], fallback: doc.$createdAt),
          createdAt: _date(data['created_at'], fallback: doc.$createdAt),
        );
      }).toList();
    } catch (e) {
      _logger.error('Failed to fetch health tracking', e);
      throw DatabaseException('Failed to fetch health tracking',
          originalError: e);
    }
  }

  String _string(dynamic value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _date(dynamic value, {required String fallback}) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.parse(fallback);
    return DateTime.parse(fallback);
  }
}
