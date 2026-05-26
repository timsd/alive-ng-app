import 'package:appwrite/appwrite.dart' hide Locale;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';

class DailyVerseRepository {
  DailyVerseRepository._();
  static final DailyVerseRepository instance = DailyVerseRepository._();

  final Logger _logger = Logger('DailyVerseRepository');
  final TablesDB _tables = TablesDB(appwriteClient);

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<DailyVerse?> getDailyVerse(DateTime date) async {
    try {
      final id = _dateKey(date);
      final row = await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.dailyVersesCollectionId,
        rowId: id,
      );
      return DailyVerse.fromJson(_dailyVerseData(row.$id, row.data));
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
      _logger.error(
          'Error creating daily verse for ${_dateKey(dailyVerse.date)}: $e');
      rethrow;
    }
  }

  Future<List<DailyVerse>> getDailyVersesInRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final query = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.dailyVersesCollectionId,
        queries: [
          Query.greaterThanEqual('date', _dateKey(startDate)),
          Query.lessThanEqual('date', _dateKey(endDate)),
          Query.orderDesc('date'),
        ],
      );
      return query.rows
          .map((row) => DailyVerse.fromJson(_dailyVerseData(row.$id, row.data)))
          .toList();
    } catch (e) {
      _logger.error('Error querying daily verses range: $e');
      return [];
    }
  }

  Future<int> countDailyVerses() async {
    try {
      final result = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.dailyVersesCollectionId,
        queries: [Query.limit(1)],
      );
      return result.total;
    } catch (e) {
      _logger.error('Error counting daily verses: $e');
      return 0;
    }
  }

  Future<void> _upsertDailyVerse(String id, Map<String, dynamic> data) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.dailyVersesCollectionId,
        rowId: id,
        data: data,
      );
    } catch (e) {
      if (e is! AppwriteException || e.code != 404) rethrow;
      await _tables.createRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.dailyVersesCollectionId,
        rowId: id,
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
