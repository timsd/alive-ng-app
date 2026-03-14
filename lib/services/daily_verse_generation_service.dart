import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart' hide BibleVerse;
import 'offline_bible_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../constants/bible_verses.dart';
import 'bible_source.dart';
import '../utils/logger.dart';
import 'daily_verse_repository.dart';
import 'firebase_database_service.dart';

class DailyVerseGenerationService {
  static DailyVerseGenerationService? _instance;
  static DailyVerseGenerationService get instance =>
      _instance ??= DailyVerseGenerationService._();

  DailyVerseGenerationService._({
    DailyVerseRepository? repo,
    FirebaseDatabaseService? firebaseService,
  })  : _repo = repo ?? DailyVerseRepository.instance,
        _firebaseService = firebaseService ?? FirebaseDatabaseService.instance;

  @visibleForTesting
  factory DailyVerseGenerationService.test({
    required DailyVerseRepository repo,
    required FirebaseDatabaseService firebaseService,
  }) {
    return DailyVerseGenerationService._(
      repo: repo,
      firebaseService: firebaseService,
    );
  }

  final Logger _logger = Logger('DailyVerseGenerationService');
  final DailyVerseRepository _repo;
  final Random _random = Random();
  final FirebaseDatabaseService _firebaseService;

  /// Initialize the verse generation system
  Future<void> initializeVerseGeneration() async {
    try {
      _logger.info('Initializing daily verse generation system...');
      // We no longer populate a huge tracking table. The daily verse is now
      // dynamically generated deterministically passing the date as seed.

      // Pre-generate today's verse if not exists (so it's immediately available)
      await generateDailyVerseForToday();

      _logger.info('✅ Daily verse generation system initialized');
    } catch (e) {
      _logger.error('Failed to initialize daily verse system: $e');
    }
  }

  /// Get count of verses in tracking table
  Future<int> _getTrackingTableCount() async {
    try {
      final docs = await _firebaseService.getCollection('daily_verse_tracking');
      return docs.length;
    } catch (e) {
      _logger.error('Error getting tracking table count: $e');
      return 0;
    }
  }

  /// Populate the verse tracking table with available verses
  Future<void> _populateVerseTrackingTable() async {
    try {
      final List<Map<String, dynamic>> trackingData = [];

      // Add verses from the bundled BibleSource daily corpus
      for (final verse in BibleSource.instance.dailyCorpus) {
        trackingData.add({
          'verse_reference': verse.reference,
          'book': _extractBookFromReference(verse.reference),
          'chapter': _extractChapterFromReference(verse.reference),
          'verse_number': _extractVerseNumberFromReference(verse.reference),
          'is_used': false,
          'translation':
              'KJV', // Default translation since BibleVerse doesn't have translation property
        });
      }

      // Insert in batches to avoid overwhelming the database
      const batchSize = 50;
      for (int i = 0; i < trackingData.length; i += batchSize) {
        final batch = trackingData.skip(i).take(batchSize).toList();

        for (final item in batch) {
          final docId = '${item['translation']}|${item['verse_reference']}';
          await _firebaseService.createOrUpdateDocument(
              'daily_verse_tracking', docId, item);
        }
      }

      _logger
          .info('✅ Populated ${trackingData.length} verses in tracking table');
    } catch (e) {
      _logger.error('❌ Failed to populate verse tracking table: $e');
      rethrow;
    }
  }

  /// Extract book name from verse reference
  String _extractBookFromReference(String reference) {
    // Handle references like "John 3:16", "1 Corinthians 13:4-7", etc.
    final parts = reference.split(' ');
    if (parts.length >= 2 && RegExp(r'^\d+$').hasMatch(parts[0])) {
      // Handle books with numbers like "1 Corinthians"
      return '${parts[0]} ${parts[1]}';
    }
    return parts[0];
  }

  /// Extract chapter number from verse reference
  int _extractChapterFromReference(String reference) {
    final match = RegExp(r'(\d+):').firstMatch(reference);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  /// Extract verse number from verse reference
  int _extractVerseNumberFromReference(String reference) {
    final match = RegExp(r':(\d+)').firstMatch(reference);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  /// Generate daily verse for today
  Future<DailyVerse?> generateDailyVerseForToday() async {
    final today = DateTime.now();
    return await generateDailyVerseForDate(today);
  }

  /// Generate daily verse for a specific date
  Future<DailyVerse?> generateDailyVerseForDate(DateTime date) async {
    try {
      final dateString = _formatDateForDatabase(date);
      
      // Check if verse already exists for this date (Firestore)
      final existingVerse = await _repo.getDailyVerse(date);
      if (existingVerse != null) {
        _logger.info('Daily verse already exists for $dateString');
        return existingVerse;
      }
      
      // Deterministically pick a verse based on the date seed
      final random = Random(date.year * 10000 + date.month * 100 + date.day);
      
      try {
        final String booksJson = await rootBundle.loadString('assets/bible/books_en.json');
        final List<dynamic> booksList = json.decode(booksJson);
        final book = booksList[random.nextInt(booksList.length)];
        final chapterNum = random.nextInt(book['chapters']) + 1;
        
        final chapterData = await OfflineBibleService().getBibleChapter(
          book: book['name'], 
          chapter: chapterNum, 
          version: 'KJV', 
          language: 'en'
        );
        
        if (chapterData != null && chapterData.verses.isNotEmpty) {
          final verseObj = chapterData.verses[random.nextInt(chapterData.verses.length)];
          final dynamicVerse = BibleVerse(
            reference: '${book['name']} $chapterNum:${verseObj.number}',
            text: {'KJV': verseObj.text, 'BM': verseObj.text}, 
          );
          return await _createDailyVerseFromBibleVerse(dynamicVerse, date);
        }
      } catch (e) {
        _logger.error('Failed dynamic pick, falling back to static corpus: $e');
      }

      // Fallback to static corpus if dynamic selection fails
      final staticCorpus = BibleSource.instance.dailyCorpus;
      final fallback = staticCorpus[random.nextInt(staticCorpus.length)];
      return await _createDailyVerseFromBibleVerse(fallback, date);
    } catch (e) {
      _logger.error('❌ Failed to generate daily verse for ${_formatDateForDatabase(date)}: $e');
      return null;
    }
  }

  /// Get next unused verse from tracking table
  Future<BibleVerse?> _getNextUnusedVerse() async {
    try {
      final response = await _firebaseService.getCollection(
        'daily_verse_tracking',
        where: {'is_used': false},
        limit: 100,
      );

      if (response.isEmpty) {
        return null;
      }

      // Randomly select from available unused verses
      final randomIndex = _random.nextInt(response.length);
      final selectedTracking = response[randomIndex];

      // Find the corresponding BibleVerse from bundled BibleSource corpus
      final corpus = BibleSource.instance.dailyCorpus;
      final bibleVerse = corpus.firstWhere(
        (v) => v.reference == selectedTracking['verse_reference'],
        orElse: () => corpus[_random.nextInt(corpus.length)],
      );

      // Mark as used
      await _markVerseAsUsed(
          selectedTracking['verse_reference'], selectedTracking['translation']);

      return bibleVerse;
    } catch (e) {
      _logger.error('Error getting next unused verse: $e');
      return null;
    }
  }

  /// Mark a verse as used in the tracking table (No-op now)
  Future<void> _markVerseAsUsed(String reference, String translation) async {}

  /// Reset verse usage cycle (No-op now)
  Future<void> _resetVerseUsageCycle() async {}

  /// Create a DailyVerse from a BibleVerse and save to database
  Future<DailyVerse> _createDailyVerseFromBibleVerse(
      BibleVerse bibleVerse, DateTime date) async {
    try {
      final dailyVerse = DailyVerse(
        id: '', // Will be generated by database
        verse: bibleVerse.text['KJV'] ?? bibleVerse.text.values.first,
        reference: bibleVerse.reference,
        translation: 'KJV', // Default to KJV
        date: date,
        reflection: _generateReflection(bibleVerse),
        createdAt: DateTime.now(),
      );

      // Insert into Firestore via repository
      final createdVerse = await _repo.createDailyVerse(dailyVerse);
      await _markVerseAsUsed(bibleVerse.reference, createdVerse.translation);
      _logger.info(
          '✅ Created daily verse for ${_formatDateForDatabase(date)}: ${bibleVerse.reference}');

      return createdVerse;
    } catch (e) {
      _logger.error('❌ Failed to create daily verse: $e');
      rethrow;
    }
  }

  /// Generate a simple reflection for the verse (optional)
  String? _generateReflection(BibleVerse verse) {
    // For now, return null. This could be enhanced with AI-generated reflections
    // or pre-written reflections based on verse themes
    return null;
  }

  /// Format date for database storage
  String _formatDateForDatabase(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Compute a deterministic sequential verse for the given date.
  /// This uses a fixed anchor date and loops over available verses.
  BibleVerse _getSequentialVerseForDate(DateTime date) {
    // Choose a stable anchor to ensure consistent ordering for all users
    final anchor = DateTime(2024, 1, 1);
    final totalVerses = BibleSource.instance.dailyCorpus.length;
    if (totalVerses == 0) {
      // Fallback safety: shouldn't happen, but avoid crashing
      return const BibleVerse(
        reference: 'John 11:35',
        text: {
          'KJV': 'Jesus wept.',
        },
      );
    }
    final days = date.difference(anchor).inDays;
    // Support past dates by normalizing modulo length
    final index = ((days % totalVerses) + totalVerses) % totalVerses;
    return BibleSource.instance.dailyCorpus[index];
  }

  /// Get verse generation statistics
  Future<Map<String, dynamic>> getGenerationStatistics() async {
    try {
      final all = await _firebaseService.getCollection('daily_verse_tracking');
      final usedVerses = all.where((e) => e['is_used'] == true).length;
      final totalVerses = all.length;
      final range = await _firebaseService.getCollection('daily_verses');
      final generatedVerses = range.length;

      return {
        'total_verses': totalVerses,
        'used_verses': usedVerses,
        'unused_verses': totalVerses - usedVerses,
        'generated_daily_verses': generatedVerses,
        'completion_percentage':
            totalVerses > 0 ? (usedVerses / totalVerses * 100).round() : 0,
      };
    } catch (e) {
      _logger.error('Error getting generation statistics: $e');
      return {
        'total_verses': 0,
        'used_verses': 0,
        'unused_verses': 0,
        'generated_daily_verses': 0,
        'completion_percentage': 0,
      };
    }
  }

  /// Manually trigger verse generation for multiple days ahead
  Future<List<DailyVerse>> generateVersesForDateRange(
      DateTime startDate, int days) async {
    final List<DailyVerse> generatedVerses = [];

    for (int i = 0; i < days; i++) {
      final targetDate = startDate.add(Duration(days: i));
      final verse = await generateDailyVerseForDate(targetDate);
      if (verse != null) {
        generatedVerses.add(verse);
      }
    }

    _logger.info('✅ Generated ${generatedVerses.length} verses for $days days');
    return generatedVerses;
  }

  /// Check if auto-generation is enabled
  Future<bool> isAutoGenerationEnabled() async {
    try {
      final doc = await _firebaseService.getDocument(
          'app_settings', 'daily_verse_auto_generation');
      final value = doc != null ? doc['value'] : null;
      if (value is bool) return value;
      return true;
    } catch (e) {
      _logger.error('Error checking auto-generation setting: $e');
      return true;
    }
  }

  /// Update auto-generation setting
  Future<void> setAutoGenerationEnabled(bool enabled) async {
    try {
      await _firebaseService.updateAppSetting(
          'daily_verse_auto_generation', enabled);

      _logger.info('✅ Auto-generation ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.error('❌ Failed to update auto-generation setting: $e');
      rethrow;
    }
  }
}
