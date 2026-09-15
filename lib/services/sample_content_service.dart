import 'package:shared_preferences/shared_preferences.dart';
import '../models/podcast_models.dart';
import '../utils/logger.dart';

/// Central registry of the SAMPLE (seed) content that user-facing screens
/// show out of the box — sample podcasts, downloaded episodes, etc.
///
/// Admins can hide (delete) any sample from the Sample Content admin screen;
/// hidden ids are persisted locally so user-facing screens stop showing them.
class SampleContentService {
  static final SampleContentService _instance =
      SampleContentService._internal();
  factory SampleContentService() => _instance;
  SampleContentService._internal();

  static final Logger _logger = Logger('SampleContentService');
  static const String _hiddenKey = 'hidden_sample_content_ids';

  Set<String> _hiddenIds = {};
  bool _loaded = false;

  /// Sample podcasts shown on the user-facing Podcasts screen.
  static const List<Map<String, dynamic>> samplePodcasts = [
    {
      'id': 'sample-podcast-1',
      'type': 'podcast',
      'title': 'Daily Devotions with Pastor John',
      'description': 'Start your day with a short devotional and prayer.',
      'host': 'Pastor John',
      'category': 'devotional',
      'episodes': 24,
      'rating': 4.8,
      'hasAudio': true,
    },
    {
      'id': 'sample-podcast-2',
      'type': 'podcast',
      'title': 'Prophecy Unveiled',
      'description': 'Deep dives into Bible prophecy and last-day events.',
      'host': 'Pr. Daniel Adeyemi',
      'category': 'prophecy',
      'episodes': 12,
      'rating': 4.6,
      'hasAudio': true,
    },
    {
      'id': 'sample-podcast-3',
      'type': 'podcast',
      'title': 'Health and Wellness',
      'description': 'Practical Adventist health ministry for daily living.',
      'host': 'Dr. Mary Balogun',
      'category': 'health',
      'episodes': 18,
      'rating': 4.7,
      'hasAudio': true,
    },
  ];

  /// Converted sample podcasts into real Podcast models for user screens.
  List<Podcast> get visibleSamplePodcasts =>
      samplePodcasts.where((s) => !_hiddenIds.contains(s['id'])).map((s) {
        final categoryName = (s['category'] ?? 'devotional').toString();
        final category = PodcastCategory.values.firstWhere(
          (e) => e.name == categoryName || e.displayName == categoryName,
          orElse: () => PodcastCategory.devotional,
        );
        return Podcast(
          id: s['id'].toString(),
          title: (s['title'] ?? 'Sample podcast').toString(),
          description: (s['description'] ?? '').toString(),
          category: category,
          host: (s['host'] ?? '').toString(),
          episodes: (s['episodes'] as num?)?.toInt() ?? 0,
          rating: (s['rating'] as num?)?.toDouble() ?? 0,
          isSubscribed: false,
          tags: const ['sample'],
        );
      }).toList();

  List<Map<String, dynamic>> get visibleEpisodes =>
      sampleEpisodes.where((s) => !_hiddenIds.contains(s['id'])).toList();

  /// Sample downloaded episodes shown on the Downloaded tab.
  static const List<Map<String, dynamic>> sampleEpisodes = [
    {
      'id': 'sample-episode-1',
      'type': 'episode',
      'title': 'The Power of Prayer in Daily Life',
      'podcastTitle': 'Daily Devotions with Pastor John',
      'duration': '25 min',
      'downloadDate': '2024-01-15',
      'category': 'devotional',
      'hasAudio': true,
    },
    {
      'id': 'sample-episode-2',
      'type': 'episode',
      'title': 'Understanding Bible Prophecy - Part 1',
      'podcastTitle': 'Prophecy Unveiled',
      'duration': '35 min',
      'downloadDate': '2024-01-14',
      'category': 'prophecy',
      'hasAudio': true,
    },
    {
      'id': 'sample-episode-3',
      'type': 'episode',
      'title': 'Health Tips for Busy Christians',
      'podcastTitle': 'Health and Wellness',
      'duration': '20 min',
      'downloadDate': '2024-01-13',
      'category': 'health',
      'hasAudio': true,
    },
  ];

  /// Every sample item (podcasts + episodes) for the admin screen.
  List<Map<String, dynamic>> get allSamples => [
        ...samplePodcasts,
        ...sampleEpisodes,
      ];

  List<Map<String, dynamic>> get visibleSamples =>
      allSamples.where((s) => !isHidden(s['id'] as String)).toList();

  bool isHidden(String id) => _hiddenIds.contains(id);

  static const String _deletedKey = 'deleted_sample_content_ids';
  Set<String> _deletedIds = {};

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _hiddenIds = (prefs.getStringList(_hiddenKey) ?? []).toSet();
      _deletedIds = (prefs.getStringList(_deletedKey) ?? []).toSet();
      _loaded = true;
    } catch (e) {
      _logger.error('Failed to load hidden sample ids: $e');
      _loaded = true;
    }
  }

  /// Ensures hidden ids are loaded before the UI checks visibility.
  Future<void> ensureLoaded() => _ensureLoaded();

  /// Whether a sample has been permanently deleted on this device.
  bool isDeleted(String id) => _deletedIds.contains(id);

  /// Permanently delete a sample from this device's registry. The sample
  /// disappears from the admin list AND from every user-facing screen.
  Future<bool> deleteSample(String id) async {
    try {
      await _ensureLoaded();
      _hiddenIds.add(id);
      _deletedIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      await prefs.setStringList(_deletedKey, _deletedIds.toList());
      return true;
    } catch (e) {
      _logger.error('Failed to delete sample $id: $e');
      return false;
    }
  }

  /// Hide (soft-delete) a sample so user-facing screens stop showing it.
  Future<bool> hideSample(String id) async {
    try {
      await _ensureLoaded();
      _hiddenIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      return true;
    } catch (e) {
      _logger.error('Failed to hide sample $id: $e');
      return false;
    }
  }

  /// Restore a previously hidden or deleted sample.
  Future<bool> restoreSample(String id) async {
    try {
      await _ensureLoaded();
      _hiddenIds.remove(id);
      _deletedIds.remove(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, _hiddenIds.toList());
      await prefs.setStringList(_deletedKey, _deletedIds.toList());
      return true;
    } catch (e) {
      _logger.error('Failed to restore sample $id: $e');
      return false;
    }
  }
}
