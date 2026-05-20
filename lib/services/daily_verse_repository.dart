import 'package:appwrite/appwrite.dart' hide Locale;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';

class DailyVerseRepository {
  DailyVerseRepository._();
  static final DailyVerseRepository instance = DailyVerseRepository._();

  final Logger _logger = Logger('DailyVerseRepository');
  final Databases _db = Databases(appwriteClient);

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<DailyVerse?> getDailyVerse(DateTime date) async {
    try {
      final id = _dateKey(date);
      // ignore: deprecated_member_use
      final doc = await _db.getDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.dailyVersesCollectionId,
        documentId: id,
      );
      return DailyVerse.fromJson(_dailyVerseData(doc.$id, doc.data));
    } catch (e) {
      if (e is AppwriteException && e.code == 404) return null;
      _logger.error('Error getting daily verse for ${_dateKey(date)}: $e');
      return null;
    }
  }

  Future<DailyVerse> createDailyVerse(DailyVerse dailyVerse) async {
    try {
      final id = _dateKey(dailyVerse.date);
      final data = {
        'verse': dailyVerse.verse,
        'reference': dailyVerse.reference,
        'translation': dailyVerse.translation,
        'date': _dateKey(dailyVerse.date),
        'reflection': dailyVerse.reflection,
        'book': _extractBook(dailyVerse.reference),
        'chapter': _extractChapter(dailyVerse.reference),
        'verse_number': _extractVerseNumber(dailyVerse.reference),
        'is_generated': true,
        'created_at': DateTime.now().toIso8601String(),
      };
      await _upsertDailyVerse(id, data);
      return DailyVerse.fromJson({
        'id': id,
        ...data,
      });
    } catch (e) {
      _logger
          .error('Error creating daily verse for ${_dateKey(dailyVerse.date)}: $e');
      rethrow;
    }
  }

  Future<List<DailyVerse>> getDailyVersesInRange(
      DateTime startDate, DateTime endDate) async {
    try {
      // ignore: deprecated_member_use
      final query = await _db.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.dailyVersesCollectionId,
        queries: [
          Query.greaterThanEqual('date', _dateKey(startDate)),
          Query.lessThanEqual('date', _dateKey(endDate)),
          Query.orderDesc('date'),
        ],
      );
      return query.documents
          .map((doc) => DailyVerse.fromJson(_dailyVerseData(doc.$id, doc.data)))
          .toList();
    } catch (e) {
      _logger.error('Error querying daily verses range: $e');
      return [];
    }
  }

  Future<void> _upsertDailyVerse(String id, Map<String, dynamic> data) async {
    try {
      // ignore: deprecated_member_use
      await _db.updateDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.dailyVersesCollectionId,
        documentId: id,
        data: data,
      );
    } catch (e) {
      if (e is! AppwriteException || e.code != 404) rethrow;
      // ignore: deprecated_member_use
      await _db.createDocument(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.dailyVersesCollectionId,
        documentId: id,
        data: data,
      );
    }
  }

  Map<String, dynamic> _dailyVerseData(String id, Map<String, dynamic> data) {
    final mapped = Map<String, dynamic>.from(data);
    mapped['id'] = id;
    mapped['date'] = _normalizeDate(mapped['date']);
    mapped['created_at'] = _normalizeDate(mapped['created_at']);
    return mapped;
  }

  String _normalizeDate(dynamic value) {
    if (value is String && value.contains('T')) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toIso8601String();
    }
    return DateTime.now().toIso8601String();
  }

  String _extractBook(String reference) => reference.split(' ').first;
  int _extractChapter(String reference) {
    final parts = reference.split(' ');
    if (parts.length < 2) return 1;
    return int.tryParse(parts[1].split(':').first) ?? 1;
  }

  int _extractVerseNumber(String reference) {
    final parts = reference.split(':');
    if (parts.length < 2) return 1;
    return int.tryParse(parts[1]) ?? 1;
  }
}
