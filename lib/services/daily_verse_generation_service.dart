import 'dart:math';
import '../models/app_models.dart';
import '../data/bible_verses.dart' as bible_data;
import '../utils/logger.dart';
import 'supabase_service.dart';

class DailyVerseGenerationService {
  static DailyVerseGenerationService? _instance;
  static DailyVerseGenerationService get instance => 
      _instance ??= DailyVerseGenerationService._();

  DailyVerseGenerationService._();

  final Logger _logger = Logger('DailyVerseGenerationService');
  final SupabaseService _supabaseService = SupabaseService.instance;
  final Random _random = Random();

  /// Initialize the verse generation system
  Future<void> initializeVerseGeneration() async {
    try {
      _logger.info('Initializing daily verse generation system...');
      
      // Check if tracking table is populated
      final trackingCount = await _getTrackingTableCount();
      
      if (trackingCount == 0) {
        _logger.info('Populating verse tracking table...');
        await _populateVerseTrackingTable();
      }
      
      // Generate today's verse if it doesn't exist
      await generateDailyVerseForToday();
      
      _logger.info('✅ Daily verse generation system initialized');
    } catch (e) {
      _logger.error('❌ Failed to initialize verse generation: $e');
      rethrow;
    }
  }

  /// Get count of verses in tracking table
  Future<int> _getTrackingTableCount() async {
    try {
      final response = await _supabaseService.client
          .from('verse_generation_tracking')
          .select('count')
          .count();
      
      return response.count;
    } catch (e) {
      _logger.error('Error getting tracking table count: $e');
      return 0;
    }
  }

  /// Populate the verse tracking table with available verses
  Future<void> _populateVerseTrackingTable() async {
    try {
      final List<Map<String, dynamic>> trackingData = [];
      
      // Add verses from the local bible_verses.dart file
      for (final verse in bible_data.dailyVerses) {
        trackingData.add({
          'verse_reference': verse.reference,
          'book': _extractBookFromReference(verse.reference),
          'chapter': _extractChapterFromReference(verse.reference),
          'verse_number': _extractVerseNumberFromReference(verse.reference),
          'is_used': false,
          'translation': 'KJV', // Default translation since BibleVerse doesn't have translation property
        });
      }
      
      // Insert in batches to avoid overwhelming the database
      const batchSize = 50;
      for (int i = 0; i < trackingData.length; i += batchSize) {
        final batch = trackingData.skip(i).take(batchSize).toList();
        
        await _supabaseService.client
            .from('verse_generation_tracking')
            .upsert(batch, onConflict: 'verse_reference,translation');
      }
      
      _logger.info('✅ Populated ${trackingData.length} verses in tracking table');
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
      
      // Check if verse already exists for this date
      final existingVerse = await _supabaseService.getDailyVerse(date);
      if (existingVerse != null) {
        _logger.info('Daily verse already exists for $dateString');
        return existingVerse;
      }
      
      // Get next unused verse
      final nextVerse = await _getNextUnusedVerse();
      if (nextVerse == null) {
        _logger.warning('No unused verses available, resetting cycle');
        await _resetVerseUsageCycle();
        final resetVerse = await _getNextUnusedVerse();
        if (resetVerse == null) {
          throw Exception('No verses available for generation');
        }
        return await _createDailyVerseFromBibleVerse(resetVerse, date);
      }
      
      return await _createDailyVerseFromBibleVerse(nextVerse, date);
    } catch (e) {
      _logger.error('❌ Failed to generate daily verse for ${_formatDateForDatabase(date)}: $e');
      return null;
    }
  }

  /// Get next unused verse from tracking table
  Future<bible_data.BibleVerse?> _getNextUnusedVerse() async {
    try {
      final response = await _supabaseService.client
          .from('verse_generation_tracking')
          .select()
          .eq('is_used', false)
          .limit(100); // Get a batch to randomize from
      
      if (response.isEmpty) {
        return null;
      }
      
      // Randomly select from available unused verses
      final randomIndex = _random.nextInt(response.length);
      final selectedTracking = response[randomIndex];
      
      // Find the corresponding BibleVerse from local data
        final bibleVerse = bible_data.dailyVerses.firstWhere(
          (v) => v.reference == selectedTracking['verse_reference'],
          orElse: () => bible_data.dailyVerses[_random.nextInt(bible_data.dailyVerses.length)],
        );
      
      // Mark as used
      await _markVerseAsUsed(selectedTracking['verse_reference'], selectedTracking['translation']);
      
      return bibleVerse;
    } catch (e) {
      _logger.error('Error getting next unused verse: $e');
      return null;
    }
  }

  /// Mark a verse as used in the tracking table
  Future<void> _markVerseAsUsed(String reference, String translation) async {
    try {
      await _supabaseService.client
          .from('verse_generation_tracking')
          .update({
            'is_used': true,
            'used_date': DateTime.now().toIso8601String().split('T')[0],
          })
          .eq('verse_reference', reference)
          .eq('translation', translation);
    } catch (e) {
      _logger.error('Error marking verse as used: $e');
    }
  }

  /// Reset verse usage cycle (mark all verses as unused)
  Future<void> _resetVerseUsageCycle() async {
    try {
      _logger.info('Resetting verse usage cycle...');
      
      await _supabaseService.client
          .from('verse_generation_tracking')
          .update({
            'is_used': false,
            'used_date': null,
          })
          .neq('id', '00000000-0000-0000-0000-000000000000'); // Update all rows
      
      _logger.info('✅ Verse usage cycle reset');
    } catch (e) {
      _logger.error('❌ Failed to reset verse usage cycle: $e');
      rethrow;
    }
  }

  /// Create a DailyVerse from a BibleVerse and save to database
  Future<DailyVerse> _createDailyVerseFromBibleVerse(bible_data.BibleVerse bibleVerse, DateTime date) async {
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
      
      // Insert into database
      final response = await _supabaseService.client
          .from('daily_verses')
          .insert({
            'verse': dailyVerse.verse,
            'reference': dailyVerse.reference,
            'translation': dailyVerse.translation,
            'date': _formatDateForDatabase(date),
            'reflection': dailyVerse.reflection,
            'book': _extractBookFromReference(bibleVerse.reference),
            'chapter': _extractChapterFromReference(bibleVerse.reference),
            'verse_number': _extractVerseNumberFromReference(bibleVerse.reference),
            'is_generated': true,
          })
          .select()
          .single();
      
      final createdVerse = DailyVerse.fromJson(response);
      _logger.info('✅ Created daily verse for ${_formatDateForDatabase(date)}: ${bibleVerse.reference}');
      
      return createdVerse;
    } catch (e) {
      _logger.error('❌ Failed to create daily verse: $e');
      rethrow;
    }
  }

  /// Generate a simple reflection for the verse (optional)
  String? _generateReflection(bible_data.BibleVerse verse) {
    // For now, return null. This could be enhanced with AI-generated reflections
    // or pre-written reflections based on verse themes
    return null;
  }

  /// Format date for database storage
  String _formatDateForDatabase(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get verse generation statistics
  Future<Map<String, dynamic>> getGenerationStatistics() async {
    try {
      // Get total verses in tracking
      final totalResponse = await _supabaseService.client
          .from('verse_generation_tracking')
          .select('count')
          .count();
      
      // Get used verses count
      final usedResponse = await _supabaseService.client
          .from('verse_generation_tracking')
          .select('count')
          .eq('is_used', true)
          .count();
      
      // Get generated daily verses count
      final generatedResponse = await _supabaseService.client
          .from('daily_verses')
          .select('count')
          .eq('is_generated', true)
          .count();
      
      final totalVerses = totalResponse.count;
      final usedVerses = usedResponse.count;
      final generatedVerses = generatedResponse.count;
      
      return {
        'total_verses': totalVerses,
        'used_verses': usedVerses,
        'unused_verses': totalVerses - usedVerses,
        'generated_daily_verses': generatedVerses,
        'completion_percentage': totalVerses > 0 ? (usedVerses / totalVerses * 100).round() : 0,
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
  Future<List<DailyVerse>> generateVersesForDateRange(DateTime startDate, int days) async {
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
      final response = await _supabaseService.client
          .from('daily_verse_settings')
          .select('setting_value')
          .eq('setting_key', 'auto_generation_enabled')
          .single();
      
      return response['setting_value']?.toLowerCase() == 'true';
    } catch (e) {
      _logger.error('Error checking auto-generation setting: $e');
      return true; // Default to enabled
    }
  }

  /// Update auto-generation setting
  Future<void> setAutoGenerationEnabled(bool enabled) async {
    try {
      await _supabaseService.client
          .from('daily_verse_settings')
          .upsert({
            'setting_key': 'auto_generation_enabled',
            'setting_value': enabled.toString(),
            'description': 'Enable automatic daily verse generation',
          }, onConflict: 'setting_key');
      
      _logger.info('✅ Auto-generation ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.error('❌ Failed to update auto-generation setting: $e');
      rethrow;
    }
  }
}