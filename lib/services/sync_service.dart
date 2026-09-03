import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'appwrite_profile_service.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import 'daily_verse_generation_service.dart';
import 'daily_verse_repository.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();

  SyncService._() {
    _initializeSync();
  }

  final TablesDB _tables = TablesDB(appwriteClient);
  final Realtime _realtime = Realtime(appwriteClient);
  final StorageService _storage = StorageService.instance;
  final AuthService _auth = AuthService.instance;
  final AppwriteProfileService _profileService = AppwriteProfileService();
  final DailyVerseGenerationService _verseGenerator =
      DailyVerseGenerationService.instance;
  final Logger _logger = Logger('SyncService');

  // Legacy backend sync removed; Appwrite is the single backend.

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  // Real-time subscriptions
  final Map<String, RealtimeSubscription> _realtimeChannels = {};
  final StreamController<RealtimeUpdate> _realtimeUpdatesController =
      StreamController<RealtimeUpdate>.broadcast();

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 15);

  // Initialize sync service
  void _initializeSync() {
    _setupConnectivityListener();
    _setupPeriodicSync();
    _setupRealtimeSync();
  }

  // Setup real-time sync subscriptions
  void _setupRealtimeSync() {
    if (!_auth.isAuthenticated) return;

    final userId = _auth.currentUser?.$id;
    if (userId == null) return;

    _logger.info('Setting up real-time sync subscriptions (Appwrite)');

    _subscribeCollection(
      tableName: 'prayer_requests',
      collectionId: AppwriteBackendConfig.prayerRequestsCollectionId,
      userId: userId,
      userFields: const ['user_id', 'userId', 'requestedById'],
    );
    _subscribeCollection(
      tableName: 'health_tracking',
      collectionId: AppwriteBackendConfig.healthTrackingCollectionId,
      userId: userId,
      userFields: const ['user_id'],
    );
    _subscribeCollection(
      tableName: 'mission_participants',
      collectionId: AppwriteBackendConfig.userMissionsCollectionId,
      userId: userId,
      userFields: const ['user_id'],
    );
    _subscribeCollection(
      tableName: 'study_guide_progress',
      collectionId: AppwriteBackendConfig.studyProgressCollectionId,
      userId: userId,
      userFields: const ['user_id'],
    );
    _subscribeCollection(
      tableName: 'user_profiles',
      collectionId: AppwriteBackendConfig.usersCollectionId,
      userId: userId,
      documentId: userId,
    );
    _subscribeCollection(
      tableName: 'missions',
      collectionId: AppwriteBackendConfig.missionsCollectionId,
    );
    _subscribeCollection(
      tableName: 'study_guides',
      collectionId: AppwriteBackendConfig.studyGuidesCollectionId,
    );
    _subscribeCollection(
      tableName: 'daily_verses',
      collectionId: AppwriteBackendConfig.dailyVersesCollectionId,
    );
  }

  void _subscribeCollection({
    required String tableName,
    required String collectionId,
    String? userId,
    List<String> userFields = const [],
    String? documentId,
  }) {
    final subscription = _realtime.subscribe([
      'databases.${AppwriteBackendConfig.databaseId}.tables.$collectionId.rows',
    ]);

    subscription.stream.listen((event) {
      final row = models.Row.fromMap(event.payload);
      if (documentId != null && row.$id != documentId) return;

      final data = Map<String, dynamic>.from(row.data);
      if (userId != null &&
          userFields.isNotEmpty &&
          !userFields.any((field) => data[field] == userId)) {
        return;
      }

      _handleRealtimeUpdate(tableName, {...data, 'id': row.$id});
    }, onError: (e) {
      _logger.error('$tableName realtime error: $e');
    });

    _realtimeChannels[tableName] = subscription;
  }

  // Handle real-time updates
  void _handleRealtimeUpdate(String tableName, Map<String, dynamic> data) {
    _logger.info('Processing real-time update for $tableName');

    // Emit update to listeners
    _realtimeUpdatesController.add(RealtimeUpdate(
      tableName: tableName,
      data: data,
      timestamp: DateTime.now(),
    ));

    // Trigger specific sync for the updated table
    _syncSpecificTable(tableName);
  }

  // Sync specific table based on real-time update
  Future<void> _syncSpecificTable(String tableName) async {
    try {
      switch (tableName) {
        case 'prayer_requests':
          await _syncPrayerRequests();
          break;
        case 'health_tracking':
          await _syncHealthActivities();
          break;
        case 'missions':
        case 'mission_participants':
          await _syncMissions();
          break;
        case 'study_guides':
        case 'study_guide_progress':
          await _syncStudyPrograms();
          break;
        case 'daily_verses':
          await _syncDailyVerses();
          break;
        case 'user_profiles':
          await _syncUserProfile();
          break;
      }
    } catch (e) {
      _logger.error('Failed to sync $tableName after real-time update: $e');
    }
  }

  // Get real-time updates stream
  Stream<RealtimeUpdate> get realtimeUpdates =>
      _realtimeUpdatesController.stream;

  // Enable/disable real-time sync
  void enableRealtimeSync() {
    if (_realtimeChannels.isEmpty) {
      _setupRealtimeSync();
    }
  }

  void disableRealtimeSync() {
    for (final channel in _realtimeChannels.values) {
      try {
        channel.close();
      } catch (e) {
        _logger.error('Error cancelling realtime subscription: $e');
      }
    }
    _realtimeChannels.clear();
    _logger.info('Disabled real-time sync');
  }

  // Setup connectivity listener
  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none) && _auth.isAuthenticated) {
        // Connection restored, trigger sync
        _triggerSync();
      }
    });
  }

  // Setup periodic sync
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_auth.isAuthenticated) {
        _triggerSync();
      }
    });
  }

  // Trigger sync if not already syncing
  void _triggerSync() {
    if (!_isSyncing) {
      syncAll();
    }
  }

  // Sync all data
  Future<SyncResult> syncAll({bool force = false}) async {
    if (_isSyncing && !force) {
      return SyncResult.inProgress();
    }

    _isSyncing = true;

    try {
      final results = <String, bool>{};

      // Check if user is authenticated
      if (!_auth.isAuthenticated) {
        return SyncResult.error('User not authenticated');
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        return SyncResult.error('No internet connection');
      }

      // Sync user profile
      results['userProfile'] = await _syncUserProfile();

      // Sync prayer requests
      results['prayerRequests'] = await _syncPrayerRequests();

      // Sync health activities
      results['healthActivities'] = await _syncHealthActivities();

      // Sync missions
      results['missions'] = await _syncMissions();

      // Sync study programs
      results['studyPrograms'] = await _syncStudyPrograms();

      // Sync daily verses
      results['dailyVerses'] = await _syncDailyVerses();

      // Update last sync timestamp
      await _storage.setString(
          StorageKeys.lastSyncTime, DateTime.now().toIso8601String());

      final hasErrors = results.values.any((success) => !success);

      return hasErrors
          ? SyncResult.partialSuccess(results)
          : SyncResult.success(results);
    } catch (e) {
      _logger.error('Sync error', e);
      return SyncResult.error(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // Sync user profile
  Future<bool> _syncUserProfile() async {
    try {
      // Get local profile
      final localProfileJson = await _storage.getJson(StorageKeys.userProfile);
      final localTimestamp =
          await _storage.getString('${StorageKeys.userProfile}_timestamp');

      // Get remote profile
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final remoteProfile =
          await _profileService.getUserProfileModel(currentUser.$id);

      if (remoteProfile != null) {
        final remoteTimestamp = remoteProfile.updatedAt.toIso8601String();

        // Compare timestamps and sync if needed
        if (localTimestamp == null) {
          // No local timestamp, update with remote
          await _storage.setJson(
              StorageKeys.userProfile, remoteProfile.toJson());
          await _storage.setString(
              '${StorageKeys.userProfile}_timestamp', remoteTimestamp);
        } else if (DateTime.parse(remoteTimestamp)
            .isAfter(DateTime.parse(localTimestamp))) {
          // Remote is newer, update local
          await _storage.setJson(
              StorageKeys.userProfile, remoteProfile.toJson());
          await _storage.setString(
              '${StorageKeys.userProfile}_timestamp', remoteTimestamp);
        } else if (localProfileJson != null) {
          // Local is newer, update remote
          try {
            final localProfile = UserProfile.fromJson(localProfileJson);
            await _profileService.updateUserProfile(
              userId: currentUser.$id,
              profileData:
                  _profileService.userProfileToAppwriteData(localProfile),
            );
          } catch (e) {
            _logger
                .warning('Failed to update remote user profile from local: $e');
          }
        }
      }

      return true;
    } catch (e) {
      _logger.error('User profile sync error', e);
      return false;
    }
  }

  // Sync prayer requests
  Future<bool> _syncPrayerRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final response = await _listDocuments(
        AppwriteBackendConfig.prayerRequestsCollectionId,
        queries: [
          Query.equal('user_id', user.$id),
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );

      // Store in local storage for offline access
      await _storage.setJsonList('prayer_requests', response);
      _logger.info('Prayer requests synced: ${response.length} items');
      return true;
    } catch (e) {
      _logger.error('Prayer requests sync error', e);
      return false;
    }
  }

  // Sync health activities
  Future<bool> _syncHealthActivities() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final response = await _listDocuments(
        AppwriteBackendConfig.healthTrackingCollectionId,
        queries: [
          Query.equal('user_id', user.$id),
          Query.orderDesc('date'),
          Query.limit(30),
        ],
      );

      // Store in local storage for offline access
      await _storage.setJsonList('health_tracking', response);
      _logger.info('Health activities synced: ${response.length} items');
      return true;
    } catch (e) {
      _logger.error('Health activities sync error', e);
      return false;
    }
  }

  // Sync missions
  Future<bool> _syncMissions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final missions = await _listDocuments(
        AppwriteBackendConfig.missionsCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );
      final participation = await _listDocuments(
        AppwriteBackendConfig.userMissionsCollectionId,
        queries: [
          Query.equal('user_id', user.$id),
          Query.limit(100),
        ],
      );

      // Store in local storage for offline access
      await _storage.setJsonList('missions', missions);
      await _storage.setJsonList('mission_participation', participation);
      _logger.info(
          'Missions synced (Appwrite): ${missions.length} missions, ${participation.length} participations');
      return true;
    } catch (e) {
      _logger.error('Missions sync error', e);
      return false;
    }
  }

  // Sync study programs
  Future<bool> _syncStudyPrograms() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final studyGuides = await _listDocuments(
        AppwriteBackendConfig.studyGuidesCollectionId,
        queries: [
          Query.orderDesc('created_at'),
          Query.limit(100),
        ],
      );
      final progress = await _listDocuments(
        AppwriteBackendConfig.studyProgressCollectionId,
        queries: [
          Query.equal('user_id', user.$id),
          Query.limit(100),
        ],
      );

      // Store in local storage for offline access
      await _storage.setJsonList('study_guides', studyGuides);
      await _storage.setJsonList('study_progress', progress);
      _logger.info(
          'Study programs synced (Appwrite): ${studyGuides.length} guides, ${progress.length} progress records');
      return true;
    } catch (e) {
      _logger.error('Study programs sync error', e);
      return false;
    }
  }

  // Sync daily verses
  Future<bool> _syncDailyVerses() async {
    try {
      _logger.info('Starting daily verses sync...');

      // Initialize verse generation system if needed
      await _verseGenerator.initializeVerseGeneration();

      // Check if auto-generation is enabled
      final autoGenEnabled = await _verseGenerator.isAutoGenerationEnabled();

      if (autoGenEnabled) {
        // Generate today's verse if it doesn't exist
        final todaysVerse = await _verseGenerator.generateDailyVerseForToday();
        if (todaysVerse != null) {
          _logger.info('✅ Today\'s verse generated: ${todaysVerse.reference}');
        }

        // Optionally generate verses for the next few days
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        await _verseGenerator.generateDailyVerseForDate(tomorrow);
      }

      // Fetch daily verses from Appwrite (last 30 days + next 7 days)
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now().add(const Duration(days: 7));

      final appwriteVerses = await DailyVerseRepository.instance
          .getDailyVersesInRange(startDate, endDate);
      final response = appwriteVerses.map((v) => v.toJson()).toList();

      // Store in local storage for offline access
      await _storage.setJsonList('daily_verses', response);

      // Store generation statistics
      final stats = await _verseGenerator.getGenerationStatistics();
      await _storage.setJson('daily_verse_stats', stats);

      _logger.info(
          'Daily verses synced (Appwrite) ${_formatDateForDatabase(DateTime.now())}: ${response.length} verses');
      return true;
    } catch (e) {
      _logger.error('❌ Daily verses sync error', e);
      return false;
    }
  }

  /// Format date for database queries
  String _formatDateForDatabase(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> _listDocuments(
    String collectionId, {
    List<String>? queries,
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows
        .map((row) => {
              ...Map<String, dynamic>.from(row.data),
              'id': row.$id,
            })
        .toList();
  }

  // Queue local change for sync
  Future<void> queueLocalChange(
    String dataType,
    String action, // 'create', 'update', 'delete'
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final pendingKey = '${dataType}_pending';
    final pendingChanges =
        await _storage.getJsonList(pendingKey) ?? <Map<String, dynamic>>[];

    final change = {
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (id != null) {
      change['id'] = id;
    }

    pendingChanges.add(change);
    await _storage.setJsonList(
        pendingKey, pendingChanges.cast<Map<String, dynamic>>());

    // Trigger immediate sync if online
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.contains(ConnectivityResult.none)) {
      _triggerSync();
    }
  }

  // Force sync specific data type
  Future<bool> syncDataType(String dataType) async {
    switch (dataType) {
      case 'userProfile':
        return await _syncUserProfile();
      case 'prayerRequests':
        return await _syncPrayerRequests();
      case 'healthActivities':
        return await _syncHealthActivities();
      case 'missions':
        return await _syncMissions();
      case 'studyPrograms':
        return await _syncStudyPrograms();
      case 'dailyVerses':
        return await _syncDailyVerses();
      default:
        return false;
    }
  }

  // Get sync status
  Future<SyncStatus> getSyncStatus() async {
    final lastSyncTime = await _storage.getString(StorageKeys.lastSyncTime);
    final connectivity = await Connectivity().checkConnectivity();

    return SyncStatus(
      lastSyncTime: lastSyncTime != null ? DateTime.parse(lastSyncTime) : null,
      isOnline: !connectivity.contains(ConnectivityResult.none),
      isSyncing: _isSyncing,
      isAuthenticated: _auth.isAuthenticated,
    );
  }

  // Clear all sync data
  Future<void> clearSyncData() async {
    final keys = [
      StorageKeys.lastSyncTime,
      '${StorageKeys.prayerRequests}_lastSync',
      '${StorageKeys.prayerRequests}_pending',
      '${StorageKeys.healthActivities}_lastSync',
      '${StorageKeys.healthActivities}_pending',
      '${StorageKeys.missions}_lastSync',
      '${StorageKeys.studyPrograms}_lastSync',
      '${StorageKeys.dailyVerses}_lastSync',
    ];

    for (final key in keys) {
      await _storage.remove(key);
    }
  }

  // Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    disableRealtimeSync();
    _realtimeUpdatesController.close();
  }
}

// Sync Result
class SyncResult {
  final bool isSuccess;
  final bool isPartialSuccess;
  final bool isInProgress;
  final String? error;
  final Map<String, bool>? results;

  SyncResult._(
      {required this.isSuccess,
      required this.isPartialSuccess,
      required this.isInProgress,
      this.error,
      this.results});

  factory SyncResult.success(Map<String, bool> results) {
    return SyncResult._(
      isSuccess: true,
      isPartialSuccess: false,
      isInProgress: false,
      results: results,
    );
  }

  factory SyncResult.partialSuccess(Map<String, bool> results) {
    return SyncResult._(
      isSuccess: false,
      isPartialSuccess: true,
      isInProgress: false,
      results: results,
    );
  }

  factory SyncResult.error(String error) {
    return SyncResult._(
      isSuccess: false,
      isPartialSuccess: false,
      isInProgress: false,
      error: error,
    );
  }

  factory SyncResult.inProgress() {
    return SyncResult._(
      isSuccess: false,
      isPartialSuccess: false,
      isInProgress: true,
    );
  }
}

// Sync Status
class SyncStatus {
  final DateTime? lastSyncTime;
  final bool isOnline;
  final bool isSyncing;
  final bool isAuthenticated;

  SyncStatus({
    required this.lastSyncTime,
    required this.isOnline,
    required this.isSyncing,
    required this.isAuthenticated,
  });

  bool get canSync => isOnline && isAuthenticated && !isSyncing;

  String get statusText {
    if (!isAuthenticated) return 'Not authenticated';
    if (!isOnline) return 'Offline';
    if (isSyncing) return 'Syncing...';
    if (lastSyncTime == null) return 'Never synced';

    final now = DateTime.now();
    final difference = now.difference(lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just synced';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

// Real-time Update Model
class RealtimeUpdate {
  final String tableName;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  RealtimeUpdate({
    required this.tableName,
    required this.data,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'RealtimeUpdate(table: $tableName, timestamp: $timestamp)';
  }
}

// Riverpod providers
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService.instance;
});

final realtimeUpdatesProvider = StreamProvider<RealtimeUpdate>((ref) {
  final syncService = ref.read(syncServiceProvider);
  return syncService.realtimeUpdates;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final syncService = ref.read(syncServiceProvider);

  // Initial status
  yield await syncService.getSyncStatus();

  // Update every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield await syncService.getSyncStatus();
  }
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final storage = StorageService.instance;
  final lastSyncString = await storage.getString(StorageKeys.lastSyncTime);
  return lastSyncString != null ? DateTime.parse(lastSyncString) : null;
});
