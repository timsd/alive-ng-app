import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  final Logger _logger = Logger('SupabaseService');

  /// Test SSL connection to Supabase
  Future<Map<String, dynamic>> testSSLConnection() async {
    try {
      _logger.info('Testing SSL connection to Supabase...');
      
      // Test basic connection with a simple query
      await client
          .from('users')
          .select('count')
          .limit(1);
      
      _logger.info('✅ SSL Connection successful');
      return {
        'success': true,
        'message': 'SSL connection established successfully',
        'timestamp': DateTime.now().toIso8601String(),
        'url': AppConstants.supabaseUrl,
      };
    } catch (e) {
      _logger.error('❌ SSL Connection failed: $e');
      return {
        'success': false,
        'message': 'SSL connection failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
        'url': AppConstants.supabaseUrl,
      };
    }
  }

  /// Verify SSL configuration and connection security
  Future<Map<String, dynamic>> verifySSLConfiguration() async {
    try {
      _logger.info('Verifying SSL configuration...');
      
      final Map<String, dynamic> result = {
        'ssl_enabled': AppConstants.supabaseUrl.startsWith('https://'),
        'url': AppConstants.supabaseUrl,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (!result['ssl_enabled']) {
        result['warning'] = 'Supabase URL is not using HTTPS - SSL not enabled';
        _logger.warning('⚠️ SSL not enabled - URL does not use HTTPS');
      } else {
        result['message'] = 'SSL is properly configured';
        _logger.info('✅ SSL is properly configured');
      }

      // Test actual connection
      final connectionTest = await testSSLConnection();
      result['connection_test'] = connectionTest;

      return result;
    } catch (e) {
      _logger.error('Error verifying SSL configuration: $e');
      return {
        'success': false,
        'error': 'Failed to verify SSL configuration: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Authentication Methods
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // User Profile Methods
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response =
          await client.from('profiles').select().eq('id', userId).single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<UserProfile> updateUserProfile(UserProfile user) async {
    try {
      final response = await client
          .from('profiles')
          .update(user.toJson())
          .eq('id', user.id)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile> createUserProfile(UserProfile user) async {
    try {
      final response =
          await client.from('profiles').insert(user.toJson()).select().single();

      return UserProfile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Prayer Requests Methods
  Future<List<PrayerRequest>> getPrayerRequests({String? category}) async {
    try {
      var queryBuilder = client
          .from('prayer_requests')
          .select('*, profiles(first_name, last_name)')
          .eq('is_public', true);

      if (category != null && category.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category', category);
      }

      final response = await queryBuilder.order('created_at', ascending: false);

      return (response as List)
          .map((item) => PrayerRequest.fromJson(item))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<PrayerRequest> createPrayerRequest(PrayerRequest request) async {
    try {
      final response = await client
          .from('prayer_requests')
          .insert(request.toJson())
          .select('*, profiles(first_name, last_name)')
          .single();

      return PrayerRequest.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> prayForRequest(String requestId, String userId) async {
    try {
      await client.from('prayer_interactions').insert({
        'prayer_request_id': requestId,
        'user_id': userId,
        'interaction_type': 'pray',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Health Activities Methods
  Future<List<HealthTracking>> getHealthActivities(
      String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await client
          .from('health_activities')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => HealthTracking.fromJson(item))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<HealthTracking> createHealthActivity(HealthTracking activity) async {
    try {
      final response = await client
          .from('health_activities')
          .insert(activity.toJson())
          .select()
          .single();

      return HealthTracking.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Missions Methods
  Future<List<Mission>> getMissions({String? category}) async {
    try {
      var queryBuilder = client.from('missions').select().eq('is_active', true);

      if (category != null && category.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category', category);
      }

      final response = await queryBuilder.order('created_at', ascending: false);

      return (response as List).map((item) => Mission.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinMission(String userId, String missionId) async {
    try {
      await client.from('user_missions').insert({
        'user_id': userId,
        'mission_id': missionId,
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Study Programs Methods
  Future<List<StudyProgram>> getStudyPrograms() async {
    try {
      final response = await client
          .from('study_programs')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => StudyProgram.fromJson(item))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> enrollInStudyProgram(String userId, String programId) async {
    try {
      await client.from('user_study_programs').insert({
        'user_id': userId,
        'study_program_id': programId,
        'progress': 0,
        'started_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Daily Verse Methods
  Future<DailyVerse?> getDailyVerse([DateTime? date]) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateString =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final response = await client
          .from('daily_verses')
          .select()
          .eq('date', dateString)
          .single();

      return DailyVerse.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Real-time subscriptions
  RealtimeChannel subscribeToPrayerRequests(
      Function(List<PrayerRequest>) onData) {
    return client
        .channel('prayer_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'prayer_requests',
          callback: (payload) async {
            final requests = await getPrayerRequests();
            onData(requests);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToMissions(Function(List<Mission>) onData) {
    return client
        .channel('missions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'missions',
          callback: (payload) async {
            final missions = await getMissions();
            onData(missions);
          },
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  // File Storage Methods
  Future<String> uploadFile(
    String bucket,
    String path,
    List<int> bytes, {
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: contentType,
              metadata: metadata,
            ),
          );

      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (e) {
      rethrow;
    }
  }

  String getPublicUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }

  // Health Activities Methods
  Future<List<Map<String, dynamic>>> getHealthActivitiesUpdatedSince(
      DateTime since) async {
    try {
      final response = await client
          .from('health_tracking')
          .select()
          .gte('updated_at', since.toIso8601String())
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.error('Error fetching health activities updated since $since: $e');
      return [];
    }
  }

  // Analytics Methods
  Future<void> trackEvent(
      String userId, String eventName, Map<String, dynamic>? properties) async {
    try {
      await client.from('user_events').insert({
        'user_id': userId,
        'event_name': eventName,
        'properties': properties,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail for analytics
    }
  }

  // FCM Token Methods
  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await client.from('push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': 'mobile',
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      _logger.info('FCM token updated for user $userId: $token');
    } catch (e) {
      _logger.error('Error updating FCM token', e);
    }
  }

  // Notification Settings Methods
  Future<void> updateNotificationSettings(
      String userId, Map<String, bool> settings) async {
    try {
      await client.from('notification_settings').upsert({
        'user_id': userId,
        ...settings,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      _logger.info('Notification settings updated for user $userId: $settings');
    } catch (e) {
      _logger.error('Error updating notification settings', e);
    }
  }

  // Content Management Methods
  static Future<Map<String, dynamic>?> getContentPageBySlug(String slug, {String? languageCode}) async {
    try {
      final targetLanguage = languageCode ?? 'en';
      
      // First try to get content in the requested language
      try {
        final response = await Supabase.instance.client
            .from('content_pages')
            .select()
            .eq('slug', slug)
            .eq('language', targetLanguage)
            .eq('is_published', true)
            .single();
        return response;
      } catch (e) {
        // If not found in target language, fallback to English
        if (targetLanguage != 'en') {
          final fallbackResponse = await Supabase.instance.client
              .from('content_pages')
              .select()
              .eq('slug', slug)
              .eq('language', 'en')
              .eq('is_published', true)
              .single();
          
          // Mark that this content needs translation
          fallbackResponse['needs_translation'] = true;
          fallbackResponse['target_language'] = targetLanguage;
          return fallbackResponse;
        }
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getDynamicContent({String? languageCode, String? category}) async {
    try {
      final targetLanguage = languageCode ?? 'en';
      
      var query = Supabase.instance.client
          .from('dynamic_content')
          .select()
          .eq('is_active', true);
      
      if (category != null) {
        query = query.eq('category', category);
      }
      
      // Try to get content in the requested language first
      final response = await query.eq('language', targetLanguage);
      
      if (response.isEmpty && targetLanguage != 'en') {
        // Fallback to English if no content in target language
        final fallbackQuery = Supabase.instance.client
            .from('dynamic_content')
            .select()
            .eq('is_active', true)
            .eq('language', 'en');
        
        if (category != null) {
          fallbackQuery.eq('category', category);
        }
        
        final fallbackResponse = await fallbackQuery;
        
        // Mark content as needing translation
        return fallbackResponse.map<Map<String, dynamic>>((item) {
          item['needs_translation'] = true;
          item['target_language'] = targetLanguage;
          return item;
        }).toList();
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}




