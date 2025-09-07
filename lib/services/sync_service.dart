import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'supabase_service.dart';
import 'storage_service.dart';
import 'auth_service.dart';
import '../models/app_models.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();

  SyncService._() {
    _initializeSync();
  }

  final SupabaseService _supabase = SupabaseService.instance;
  final StorageService _storage = StorageService.instance;
  final AuthService _auth = AuthService.instance;

  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 15);

  // Initialize sync service
  void _initializeSync() {
    _setupConnectivityListener();
    _setupPeriodicSync();
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
      debugPrint('Sync error: $e');
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
      final remoteProfile = await _supabase.getUserProfile(currentUser.id);

      if (remoteProfile != null) {
        final remoteTimestamp = remoteProfile.updatedAt.toIso8601String();

        // Compare timestamps and sync if needed
        if (localTimestamp == null) {
          // No local timestamp, update with remote
          await _storage.setJson(StorageKeys.userProfile, remoteProfile.toJson());
          await _storage.setString(
              '${StorageKeys.userProfile}_timestamp', remoteTimestamp);
        } else if (DateTime.parse(remoteTimestamp)
                .isAfter(DateTime.parse(localTimestamp))) {
          // Remote is newer, update local
          await _storage.setJson(StorageKeys.userProfile, remoteProfile.toJson());
          await _storage.setString(
              '${StorageKeys.userProfile}_timestamp', remoteTimestamp);
        } else if (localProfileJson != null &&
            DateTime.parse(localTimestamp)
                .isAfter(remoteProfile.updatedAt)) {
          // Local is newer, update remote
          final localProfile = UserProfile.fromJson(localProfileJson);
          await _supabase.updateUserProfile(localProfile);
        }
      }

      return true;
    } catch (e) {
      debugPrint('User profile sync error: $e');
      return false;
    }
  }

  // Sync prayer requests
  Future<bool> _syncPrayerRequests() async {
    try {
      // TODO: Implement prayer request sync when methods are available
      debugPrint('Prayer request sync not implemented yet');
      return true;
    } catch (e) {
      debugPrint('Prayer requests sync error: $e');
      return false;
    }
  }

  // Sync health activities
  Future<bool> _syncHealthActivities() async {
    try {
      // TODO: Implement health activities sync when methods are available
      debugPrint('Health activities sync not implemented yet');
      return true;
    } catch (e) {
      debugPrint('Health activities sync error: $e');
      return false;
    }
  }

  // Sync missions
  Future<bool> _syncMissions() async {
    try {
      // TODO: Implement missions sync when methods are available
      debugPrint('Missions sync not implemented yet');
      return true;
    } catch (e) {
      debugPrint('Missions sync error: $e');
      return false;
    }
  }

  // Sync study programs
  Future<bool> _syncStudyPrograms() async {
    try {
      // TODO: Implement study programs sync when methods are available
      debugPrint('Study programs sync not implemented yet');
      return true;
    } catch (e) {
      debugPrint('Study programs sync error: $e');
      return false;
    }
  }

  // Sync daily verses
  Future<bool> _syncDailyVerses() async {
    try {
      // TODO: Implement daily verses sync when methods are available
      debugPrint('Daily verses sync not implemented yet');
      return true;
    } catch (e) {
      debugPrint('Daily verses sync error: $e');
      return false;
    }
  }

  // Queue local change for sync
  Future<void> queueLocalChange(
    String dataType,
    String action, // 'create', 'update', 'delete'
    Map<String, dynamic> data, {
    String? id,
  }) async {
    final pendingKey = '${dataType}_pending';
    final pendingChanges = await _storage.getJsonList(pendingKey) ?? <Map<String, dynamic>>[];

    final change = {
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (id != null) {
      change['id'] = id;
    }

    pendingChanges.add(change);
    await _storage.setJsonList(pendingKey, pendingChanges.cast<Map<String, dynamic>>());

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

// Riverpod providers
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService.instance;
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
