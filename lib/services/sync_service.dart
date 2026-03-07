import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_database_service.dart';
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

  final FirebaseDatabaseService _firebase = FirebaseDatabaseService.instance;
  final StorageService _storage = StorageService.instance;
  final AuthService _auth = AuthService.instance;
  final DailyVerseGenerationService _verseGenerator =
      DailyVerseGenerationService.instance;
  final Logger _logger = Logger('SyncService');

  // Supabase removed; stub eliminated

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  // Real-time subscriptions
  final Map<String, dynamic> _realtimeChannels = {};
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

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _logger.info('Setting up real-time sync subscriptions (Firebase)');

    // Prayer Requests (user-specific)
    final prSub = FirebaseFirestore.instance
        .collection('prayer_requests')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('prayer_requests', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Prayer requests realtime error: $e');
    });
    _realtimeChannels['prayer_requests'] = prSub;

    // Health Tracking (user-specific)
    final healthSub = FirebaseFirestore.instance
        .collection('health_tracking')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('health_tracking', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Health tracking realtime error: $e');
    });
    _realtimeChannels['health_tracking'] = healthSub;

    // Mission Participants (user-specific)
    final missionParticipantsSub = FirebaseFirestore.instance
        .collection('mission_participants')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('mission_participants', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Mission participants realtime error: $e');
    });
    _realtimeChannels['mission_participants'] = missionParticipantsSub;

    // Study Guide Progress (user-specific)
    final studyProgressSub = FirebaseFirestore.instance
        .collection('study_guide_progress')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('study_guide_progress', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Study guide progress realtime error: $e');
    });
    _realtimeChannels['study_guide_progress'] = studyProgressSub;

    // User Profiles (document-specific)
    final userProfileSub = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data != null) {
        final payload = {...data, 'id': doc.id};
        _handleRealtimeUpdate('user_profiles', payload);
      }
    }, onError: (e) {
      _logger.error('User profile realtime error: $e');
    });
    _realtimeChannels['user_profiles'] = userProfileSub;

    // Missions (global)
    final missionsSub = FirebaseFirestore.instance
        .collection('missions')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('missions', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Missions realtime error: $e');
    });
    _realtimeChannels['missions'] = missionsSub;

    // Study Guides (global)
    final studyGuidesSub = FirebaseFirestore.instance
        .collection('study_guides')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('study_guides', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Study guides realtime error: $e');
    });
    _realtimeChannels['study_guides'] = studyGuidesSub;

    // Daily Verses (global)
    final versesSub = FirebaseFirestore.instance
        .collection('daily_verses')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null) {
          final payload = {...data, 'id': change.doc.id};
          _handleRealtimeUpdate('daily_verses', payload);
        }
      }
    }, onError: (e) {
      _logger.error('Daily verses realtime error: $e');
    });
    _realtimeChannels['daily_verses'] = versesSub;
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
        if (channel is StreamSubscription) {
          channel.cancel();
        } else {
          // Fallback for any legacy channel types
          // ignore: invalid_use_of_protected_member
          channel.unsubscribe();
        }
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

      final remoteProfile = await _firebase.getUserProfile(currentUser.uid);

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
            await _firebase.updateUserProfile(localProfile);
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Fetch prayer requests from Firebase
      final snapshot = await FirebaseFirestore.instance
          .collection('prayer_requests')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .get();

      // Convert to list of maps for storage
      final response = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Fetch health tracking data from Firebase
      final snapshot = await FirebaseFirestore.instance
          .collection('health_tracking')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(30) // Last 30 days
          .get();

      // Convert to list of maps for storage
      final response = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Fetch missions data from Firestore
      final missionsSnapshot = await FirebaseFirestore.instance
          .collection('missions')
          .orderBy('created_at', descending: true)
          .get();
      final missions = missionsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Fetch user's mission participation
      final participationSnapshot = await FirebaseFirestore.instance
          .collection('mission_participants')
          .where('user_id', isEqualTo: user.uid)
          .get();
      final participation = participationSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Store in local storage for offline access
      await _storage.setJsonList('missions', missions);
      await _storage.setJsonList('mission_participation', participation);
      _logger.info(
          'Missions synced (Firestore): ${missions.length} missions, ${participation.length} participations');
      return true;
    } catch (e) {
      _logger.error('Missions sync error', e);
      return false;
    }
  }

  // Sync study programs
  Future<bool> _syncStudyPrograms() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Fetch study guides from Firestore
      final guidesSnapshot = await FirebaseFirestore.instance
          .collection('study_guides')
          .orderBy('created_at', descending: true)
          .get();
      final studyGuides = guidesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Fetch user's study progress
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('study_guide_progress')
          .where('user_id', isEqualTo: user.uid)
          .get();
      final progress = progressSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Store in local storage for offline access
      await _storage.setJsonList('study_guides', studyGuides);
      await _storage.setJsonList('study_progress', progress);
      _logger.info(
          'Study programs synced (Firestore): ${studyGuides.length} guides, ${progress.length} progress records');
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

      // Fetch daily verses from Firestore (last 30 days + next 7 days)
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now().add(const Duration(days: 7));

      final firestoreVerses = await DailyVerseRepository.instance
          .getDailyVersesInRange(startDate, endDate);
      final response = firestoreVerses.map((v) => v.toJson()).toList();

      // Store in local storage for offline access
      await _storage.setJsonList('daily_verses', response);

      // Store generation statistics
      final stats = await _verseGenerator.getGenerationStatistics();
      await _storage.setJson('daily_verse_stats', stats);

      _logger.info(
          '✅ Daily verses synced (Firestore) ${_formatDateForDatabase(DateTime.now())}: ${response.length} verses');
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
