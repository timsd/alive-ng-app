import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';

class DailyVerseRepository {
  DailyVerseRepository._();
  static final DailyVerseRepository instance = DailyVerseRepository._();

  final Logger _logger = Logger('DailyVerseRepository');
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<DailyVerse?> getDailyVerse(DateTime date) async {
    try {
      final id = _dateKey(date);
      final snap = await _db.collection('daily_verses').doc(id).get();
      final data = snap.data();
      if (data == null) return null;
      // Ensure fields are compatible with model
      data['id'] = snap.id;
      // Firestore stores timestamps; normalize strings if present
      if (data['date'] is Timestamp) {
        final ts = data['date'] as Timestamp;
        data['date'] = ts.toDate().toIso8601String();
      }
      if (data['created_at'] is Timestamp) {
        final ts = data['created_at'] as Timestamp;
        data['created_at'] = ts.toDate().toIso8601String();
      }
      return DailyVerse.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
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
      await _db.collection('daily_verses').doc(id).set(data);
      return DailyVerse.fromJson({
        'id': id,
        ...data,
      });
    } catch (e) {
      _logger.error('Error creating daily verse for ${_dateKey(dailyVerse.date)}: $e');
      rethrow;
    }
  }

  Future<List<DailyVerse>> getDailyVersesInRange(DateTime startDate, DateTime endDate) async {
    try {
      // Since date is stored as YYYY-MM-DD string, lexicographic queries work
      final startKey = _dateKey(startDate);
      final endKey = _dateKey(endDate);
      final query = await _db
          .collection('daily_verses')
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: endKey)
          .orderBy('date', descending: true)
          .get();
      return query.docs.map((doc) {
        final data = doc.data();
        final mapped = {
          'id': doc.id,
          ...data,
        };
        return DailyVerse.fromJson(Map<String, dynamic>.from(mapped));
      }).toList();
    } catch (e) {
      _logger.error('Error querying daily verses range: $e');
      return [];
    }
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
