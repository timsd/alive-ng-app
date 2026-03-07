import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bible_models.dart';
import '../models/tract_models.dart';
import 'bible_database_helper.dart';
import 'tract_database_helper.dart';
import 'offline_bible_service.dart';
import 'tract_service.dart';
import 'firebase_storage_service.dart';
import 'firebase_database_service.dart';
import '../utils/logger.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BibleDatabaseHelper _bibleDbHelper = BibleDatabaseHelper();
  final TractDatabaseHelper _tractDbHelper = TractDatabaseHelper();
  // Removed unused AdminDatabaseHelper
  final OfflineBibleService _bibleService = OfflineBibleService();
  final TractService _tractService = TractService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirebaseDatabaseService _databaseService = FirebaseDatabaseService.instance;
  final Logger _logger = Logger('OfflineSyncService');
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  
  static const String _lastSyncKey = 'last_sync_time';
  static const String _syncSettingsKey = 'sync_settings';
  
  // Sync settings
  final Map<String, dynamic> _syncSettings = {
    'autoSync': true,
    'syncOnWifiOnly': false,
    'syncInterval': 3600000, // 1 hour in milliseconds
    'syncBible': true,
    'syncTracts': true,
    'syncUserData': true,
  };

  /// Initialize the offline sync service
  Future<void> initialize() async {
    try {
      await _loadSyncSettings();
      await _loadLastSyncTime();
      await _checkConnectivity();
      _startConnectivityListener();
      
      if (_syncSettings['autoSync'] == true) {
        _startPeriodicSync();
      }
    } catch (e) {
      _logger.warning('Error initializing offline sync service: $e');
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      
      if (_isOnline && _shouldAutoSync()) {
        await performFullSync();
      }
    } catch (e) {
      _logger.warning('Error checking connectivity: $e');
    }
  }

  /// Start listening for connectivity changes
  void _startConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      
      if (!wasOnline && _isOnline) {
        // Just came online
        _logger.info('Device came online, starting sync...');
        if (_syncSettings['autoSync'] == true) {
          await performFullSync();
        }
      }
    });
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    final interval = Duration(milliseconds: _syncSettings['syncInterval'] as int);
    Timer.periodic(interval, (timer) async {
      if (_isOnline && _shouldAutoSync()) {
        await performFullSync();
      }
    });
  }

  /// Check if auto sync should be performed
  bool _shouldAutoSync() {
    if (!_syncSettings['autoSync']) return false;
    if (_isSyncing) return false;
    
    final now = DateTime.now();
    if (_lastSyncTime != null) {
      final timeSinceLastSync = now.difference(_lastSyncTime!);
      final syncInterval = Duration(milliseconds: _syncSettings['syncInterval'] as int);
      if (timeSinceLastSync < syncInterval) return false;
    }
    
    return true;
  }

  /// Perform full synchronization
  Future<SyncResult> performFullSync() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
        syncedItems: 0,
      );
    }

    if (!_isOnline) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
        syncedItems: 0,
      );
    }

    _isSyncing = true;
    int totalSyncedItems = 0;
    final errors = <String>[];

    try {
      _logger.info('Starting full sync...');

      // Sync Bible data
      if (_syncSettings['syncBible'] == true) {
        try {
          final bibleResult = await _syncBibleData();
          totalSyncedItems += bibleResult.syncedItems;
          if (!bibleResult.success) {
            errors.add('Bible sync: ${bibleResult.message}');
          }
        } catch (e) {
          errors.add('Bible sync error: $e');
        }
      }

      // Sync Tract data
      if (_syncSettings['syncTracts'] == true) {
        try {
          final tractResult = await _syncTractData();
          totalSyncedItems += tractResult.syncedItems;
          if (!tractResult.success) {
            errors.add('Tract sync: ${tractResult.message}');
          }
        } catch (e) {
          errors.add('Tract sync error: $e');
        }
      }

      // Sync User data
      if (_syncSettings['syncUserData'] == true) {
        try {
          final userResult = await _syncUserData();
          totalSyncedItems += userResult.syncedItems;
          if (!userResult.success) {
            errors.add('User data sync: ${userResult.message}');
          }
        } catch (e) {
          errors.add('User data sync error: $e');
        }
      }

      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      final success = errors.isEmpty;
      final message = success 
          ? 'Sync completed successfully'
          : 'Sync completed with errors: ${errors.join('; ')}';

      return SyncResult(
        success: success,
        message: message,
        syncedItems: totalSyncedItems,
      );
    } catch (e) {
      _logger.warning('Error during full sync: $e');
      return SyncResult(
        success: false,
        message: 'Error during sync: $e',
        syncedItems: 0,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync Bible data with Firebase and local database
  Future<SyncResult> _syncBibleData() async {
    try {
      _logger.info('Starting Bible data synchronization');
      int syncedItems = 0;
      final errors = <String>[];
      
      // 1. Sync Bible versions from Firebase
      _logger.debug('Syncing Bible versions');
      try {
        final firebaseVersions = await _databaseService.firestore
            .collection('bible_versions')
            .get();
            
        for (final doc in firebaseVersions.docs) {
          final versionData = doc.data();
          final version = BibleVersion(
            code: versionData['code'] ?? (versionData['version'] ?? ''),
            name: versionData['name'] ?? '',
            language: versionData['language'] ?? '',
            languageCode: versionData['languageCode'] ?? (versionData['language'] ?? ''),
            description: versionData['description'] ?? '',
            isDownloaded: versionData['isDefault'] == true,
            downloadedAt: (versionData['downloadedAt'] as Timestamp?)?.toDate(),
            totalSize: (versionData['totalSize'] as num?)?.toInt(),
            metadata: versionData['metadata'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(versionData['metadata'])
                : null,
          );
          
          await _bibleDbHelper.insertVersion(version);
          syncedItems++;
        }
        _logger.debug('Synced ${firebaseVersions.docs.length} Bible versions');
      } catch (e) {
        _logger.error('Error syncing Bible versions: $e');
        errors.add('Bible versions sync failed: $e');
      }

      // 2. Sync downloaded Bible books and chapters
      final downloadedVersions = await _bibleDbHelper.getDownloadedVersions();
      _logger.debug('Found ${downloadedVersions.length} downloaded versions to sync');
      
      for (final version in downloadedVersions) {
        try {
          // 2.1 Sync books for this version
          _logger.debug('Syncing books for ${version.language}/${version.code}');
          final booksSnapshot = await _databaseService.firestore
              .collection('bible_books')
              .where('language', isEqualTo: version.language)
              .get();
              
          for (final _ in booksSnapshot.docs) {
            // Default books are present in local DB; skip insertion to avoid duplicates
            syncedItems++;
          }
          
          // 2.2 Check for chapters that need updating
          _logger.debug('Checking for chapter updates in ${version.language}/${version.code}');
          final lastSyncTime = await _getLastBibleSyncTime(version.language, version.code);
          
          final chaptersQuery = _databaseService.firestore
              .collection('bible_chapters')
              .where('language', isEqualTo: version.language)
              .where('version', isEqualTo: version.code);
              
          final chaptersSnapshot = lastSyncTime != null ?
              await chaptersQuery.where('lastUpdated', isGreaterThan: Timestamp.fromDate(lastSyncTime)).get() :
              await chaptersQuery.get();
          
          for (final doc in chaptersSnapshot.docs) {
            final chapterData = doc.data();
            final bookName = chapterData['book'] ?? '';
            final chapterNumber = chapterData['chapter'] ?? 0;
            
            _logger.debug('Syncing chapter: $bookName $chapterNumber');
            
            // Get full chapter from Firebase or Storage via service
            final chapter = await _bibleService.getBibleChapter(
              book: bookName,
              chapter: chapterNumber,
              version: version.code,
              language: version.languageCode,
            );
            
            if (chapter != null) {
              // Chapter insertion is handled by OfflineBibleService; just count as synced
              syncedItems++;
            }
          }
          
          // Update last sync time for this version
          await _saveLastBibleSyncTime(version.language, version.code);
          
        } catch (e) {
          _logger.error('Error syncing version ${version.language}/${version.code}: $e');
          errors.add('${version.language}/${version.code} sync failed: $e');
        }
      }

      final success = errors.isEmpty;
      final message = success 
          ? 'Bible data synced successfully'
          : 'Bible data synced with errors: ${errors.join(', ')}';
          
      _logger.info('Bible sync completed: $message');
      
      return SyncResult(
        success: success,
        message: message,
        syncedItems: syncedItems,
        errors: errors,
      );
    } catch (e) {
      _logger.error('Failed to sync Bible data: $e');
      return SyncResult(
        success: false,
        message: 'Failed to sync Bible data: $e',
        syncedItems: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Sync Tract data
  Future<SyncResult> _syncTractData() async {
    try {
      int syncedItems = 0;
      
      // Sync tract metadata from Firebase
      await _tractService.syncWithFirebase();
      
      // Download tract PDFs from Firebase Storage
      final tractFiles = await _storageService.getTractFiles();
      for (final ref in tractFiles) {
        final fileName = ref.name;
        final isDownloaded = await _storageService.isTractDownloaded(fileName);
        if (!isDownloaded) {
          final downloadPath = await _storageService.downloadTractPDF(fileName);
          if (downloadPath != null) {
            syncedItems++;
          }
        }
      }

      // Sync "What the Bible Says" lessons
      final lessons = await _storageService.downloadAllWhatTheBibleSaysLessons();
      syncedItems += lessons.length;

      return SyncResult(
        success: true,
        message: 'Tract data synced successfully',
        syncedItems: syncedItems,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Failed to sync tract data: $e',
        syncedItems: 0,
      );
    }
  }

  /// Sync User data (reading progress, answers, etc.)
  Future<SyncResult> _syncUserData() async {
    try {
      int syncedItems = 0;
      
      // Sync user reading progress
      final progressSnapshot = await _firestore
          .collection('user_progress')
          .get();
      
      // Count synced items directly to avoid unused local variable
      syncedItems += progressSnapshot.docs.length;
      
      for (final doc in progressSnapshot.docs) {
        final data = doc.data();
        await _bibleDbHelper.saveUserProgress(
          data['userId'] ?? '',
          data['book'] ?? '',
          data['chapter'] is int ? data['chapter'] : int.tryParse(data['chapter'].toString()) ?? 0,
          data['verse'] is int ? data['verse'] : (data['verse'] != null ? int.tryParse(data['verse'].toString()) : null),
          data['version'] ?? '',
          data['progressType'] ?? 'reading',
          data['progressData'] is Map ? Map<String, dynamic>.from(data['progressData']) : null,
        );
      }

      // Sync user tract answers
      final answersSnapshot = await _firestore
          .collection('user_tract_answers')
          .get();
      
      for (final doc in answersSnapshot.docs) {
        final data = doc.data();
        final questionId = data['questionId'] ?? '';
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final userAnswer = (data['answer'] ?? '').toString();
        final isCorrect = data['isCorrect'] == true;
        final scoreValue = (data['score'] is num)
            ? (data['score'] as num).toInt()
            : (isCorrect ? 1 : 0);
        final answer = UserTractAnswer(
          id: doc.id,
          userId: data['userId'] ?? '',
          tractId: data['tractId'] ?? '',
          answers: { if (questionId.isNotEmpty) questionId: userAnswer },
          completedAt: submittedAt,
          isCompleted: true,
          score: scoreValue,
        );
        
        await _tractDbHelper.insertUserAnswer(answer);
        syncedItems++;
      }

      return SyncResult(
        success: true,
        message: 'User data synced successfully',
        syncedItems: syncedItems,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Failed to sync user data: $e',
        syncedItems: 0,
      );
    }
  }

  /// Force sync specific data type
  Future<SyncResult> forceSyncDataType(String dataType) async {
    if (!_isOnline) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
        syncedItems: 0,
      );
    }

    switch (dataType.toLowerCase()) {
      case 'bible':
        return await _syncBibleData();
      case 'tracts':
        return await _syncTractData();
      case 'userdata':
        return await _syncUserData();
      default:
        return SyncResult(
          success: false,
          message: 'Unknown data type: $dataType',
          syncedItems: 0,
        );
    }
  }

  /// Get sync status
  SyncStatus getSyncStatus() {
    return SyncStatus(
      isOnline: _isOnline,
      isSyncing: _isSyncing,
      lastSyncTime: _lastSyncTime,
      autoSyncEnabled: _syncSettings['autoSync'] as bool,
    );
  }

  /// Update sync settings
  Future<void> updateSyncSettings(Map<String, dynamic> newSettings) async {
    _syncSettings.addAll(newSettings);
    await _saveSyncSettings();
  }

  /// Get current sync settings
  Map<String, dynamic> getSyncSettings() {
    return Map<String, dynamic>.from(_syncSettings);
  }

  /// Load sync settings from SharedPreferences
  Future<void> _loadSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_syncSettingsKey);
      if (settingsJson != null) {
        final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
        _syncSettings.addAll(settings);
      }
    } catch (e) {
      _logger.warning('Error loading sync settings: $e');
    }
  }

  /// Save sync settings to SharedPreferences
  Future<void> _saveSyncSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncSettingsKey, jsonEncode(_syncSettings));
    } catch (e) {
      _logger.warning('Error saving sync settings: $e');
    }
  }

  /// Load last sync time from SharedPreferences
  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(_lastSyncKey);
      if (lastSyncMillis != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
      }
    } catch (e) {
      _logger.warning('Error loading last sync time: $e');
    }
  }

  /// Save last sync time to SharedPreferences
  Future<void> _saveLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastSyncTime != null) {
        await prefs.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.warning('Error saving last sync time: $e');
    }
  }
  
  /// Get last Bible sync time for specific version
  Future<DateTime?> _getLastBibleSyncTime(String language, String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('bible_sync_${language}_$version');
      if (value != null && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    } catch (e) {
      _logger.warning('Error loading Bible sync time: $e');
      return null;
    }
  }
  
  /// Save last Bible sync time for specific version
  Future<void> _saveLastBibleSyncTime(String language, String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bible_sync_${language}_$version', DateTime.now().toIso8601String());
    } catch (e) {
      _logger.warning('Error saving Bible sync time: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

/// Sync result model
class SyncResult {
  final bool success;
  final String message;
  final int syncedItems;
  final List<String>? errors;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedItems,
    this.errors,
  });
}

/// Sync status model
class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final bool autoSyncEnabled;

  SyncStatus({
    required this.isOnline,
    required this.isSyncing,
    this.lastSyncTime,
    required this.autoSyncEnabled,
  });
}