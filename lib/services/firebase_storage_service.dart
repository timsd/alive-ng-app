import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();
  factory FirebaseStorageService() => _instance;
  FirebaseStorageService._internal();

  static final Logger _logger = Logger('FirebaseStorageService');

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Tract storage paths
  static const String tractsPath = 'Tracts';
  static const String whatTheBibleSaysPath = 'Tracts/What_The_Bible_Says';
  // Board Documents storage path
  static const String boardDocumentsPath = 'board_documents';

  /// Upload board document from bytes
  Future<String?> uploadBoardDocument(
      Uint8List bytes, String fileName, String contentType) async {
    try {
      final ref = _storage.ref('$boardDocumentsPath/$fileName');
      final uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
          ));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error uploading board document', e);
      throw StorageException('Failed to upload board document',
          originalError: e);
    }
  }

  /// Get board document download URL
  Future<String?> getBoardDocumentDownloadURL(String fileName) async {
    try {
      final ref = _storage.ref('$boardDocumentsPath/$fileName');
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error getting board document download URL', e);
      throw StorageException('Failed to get board document download URL',
          originalError: e);
    }
  }

  /// Get list of all tract files from Firebase Storage
  Future<List<Reference>> getTractFiles() async {
    try {
      final ListResult result = await _storage.ref(tractsPath).listAll();
      return result.items;
    } catch (e) {
      _logger.error('Error getting tract files', e);
      throw StorageException('Failed to get tract files', originalError: e);
    }
  }

  /// Get list of "What the Bible Says" tract files
  Future<List<Reference>> getWhatTheBibleSaysFiles() async {
    try {
      final ListResult result =
          await _storage.ref(whatTheBibleSaysPath).listAll();
      return result.items;
    } catch (e) {
      _logger.error('Error getting What the Bible Says files', e);
      throw StorageException('Failed to get What the Bible Says files',
          originalError: e);
    }
  }

  /// Download tract PDF file (returns a public download URL instead of a local path for web compatibility)
  Future<String?> downloadTractPDF(String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      _logger.error('Error getting tract PDF URL', e);
      throw StorageException('Failed to get tract PDF URL', originalError: e);
    }
  }

  /// Get download URL for a tract file
  Future<String?> getTractDownloadURL(String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error getting tract download URL', e);
      throw StorageException('Failed to get tract download URL',
          originalError: e);
    }
  }

  /// Upload tract PDF file (bytes-based, web-safe)
  Future<String?> uploadTractPDF(Uint8List bytes, String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      final uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType: 'application/pdf',
          ));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error uploading tract PDF', e);
      throw StorageException('Failed to upload tract PDF', originalError: e);
    }
  }

  /// Upload tract PDF file from bytes
  Future<String?> uploadTractPDFFromBytes(
      Uint8List bytes, String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      final uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType: 'application/pdf',
          ));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _logger.error('Error uploading tract PDF from bytes', e);
      throw StorageException('Failed to upload tract PDF from bytes',
          originalError: e);
    }
  }

  /// Delete tract PDF file (remote only)
  Future<bool> deleteTractPDF(String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      await ref.delete();
      return true;
    } catch (e) {
      _logger.error('Error deleting tract PDF', e);
      throw StorageException('Failed to delete tract PDF', originalError: e);
    }
  }

  /// Get local tract file path (not applicable on web)
  Future<String?> getLocalTractPath(String fileName) async {
    return null;
  }

  /// Check if tract file exists locally (not applicable on web)
  Future<bool> isTractDownloaded(String fileName) async {
    return false;
  }

  /// Get file size from Firebase Storage
  Future<int?> getTractFileSize(String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      final metadata = await ref.getMetadata();
      return metadata.size;
    } catch (e) {
      _logger.error('Error getting tract file size', e);
      throw StorageException('Failed to get tract file size', originalError: e);
    }
  }

  /// Get file metadata from Firebase Storage
  Future<FullMetadata?> getTractFileMetadata(String fileName) async {
    try {
      final ref = _storage.ref('$tractsPath/$fileName');
      return await ref.getMetadata();
    } catch (e) {
      _logger.error('Error getting tract file metadata', e);
      throw StorageException('Failed to get tract file metadata',
          originalError: e);
    }
  }

  /// Clear local tract cache (no-op on web)
  Future<void> clearTractCache() async {
    // No local cache on web
  }

  /// Get total size of local tract cache (no-op on web)
  Future<int> getTractCacheSize() async {
    return 0;
  }

  /// Sync tract files with Firebase Storage (web-safe: returns empty list)
  Future<List<String>> syncTractFiles() async {
    try {
      // On web, we don't download files to local storage.
      return [];
    } catch (e) {
      _logger.error('Error syncing tract files', e);
      throw StorageException('Failed to sync tract files', originalError: e);
    }
  }

  /// Get "What the Bible Says" lesson files (Lessons 1-11)
  Future<Map<int, String>> getWhatTheBibleSaysLessons() async {
    try {
      final files = await getWhatTheBibleSaysFiles();
      final lessons = <int, String>{};
      for (final ref in files) {
        final fileName = ref.name;
        final match = RegExp(r'lesson[_\s]*(\d+)', caseSensitive: false)
            .firstMatch(fileName);
        if (match != null) {
          final lessonNumber = int.tryParse(match.group(1)!);
          if (lessonNumber != null && lessonNumber >= 1 && lessonNumber <= 11) {
            final downloadUrl = await ref.getDownloadURL();
            lessons[lessonNumber] = downloadUrl;
          }
        }
      }
      return lessons;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error getting What the Bible Says lessons', e);
      throw StorageException('Failed to get What the Bible Says lessons',
          originalError: e);
    }
  }

  /// Download all "What the Bible Says" lessons (web-safe: returns map of lesson -> download URL)
  Future<Map<int, String>> downloadAllWhatTheBibleSaysLessons() async {
    try {
      final files = await getWhatTheBibleSaysFiles();
      final urls = <int, String>{};
      for (final ref in files) {
        final fileName = ref.name;
        final match = RegExp(r'lesson[_\s]*(\d+)', caseSensitive: false)
            .firstMatch(fileName);
        if (match != null) {
          final lessonNumber = int.tryParse(match.group(1)!);
          if (lessonNumber != null && lessonNumber >= 1 && lessonNumber <= 11) {
            final url = await ref.getDownloadURL();
            urls[lessonNumber] = url;
          }
        }
      }
      return urls;
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Error downloading What the Bible Says lessons', e);
      throw StorageException('Failed to download What the Bible Says lessons',
          originalError: e);
    }
  }
}
