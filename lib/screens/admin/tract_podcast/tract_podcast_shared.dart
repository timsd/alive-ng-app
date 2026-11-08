import '../../../models/podcast_models.dart';

const List<String> defaultTractCategoryNames = [
  'What the Bible Says',
  'Doctrine',
  'Prophecy',
  'Health',
  'Family',
  'Evangelism',
  'Youth',
  'Missions',
];

const List<String> defaultPodcastCategoryNames = [
  'MEC',
  'Devotional',
  'Prophecy',
  'Health',
  'Youth',
  'Family',
  'Leadership',
  'Evangelism',
];

Map<String, dynamic> podcastPayload(Podcast podcast, {String? category, String? notes, String? transcript}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    'title': podcast.title,
    'description': podcast.description,
    'category': category ?? podcast.categoryDisplayName,
    'host': podcast.host,
    'episodes': podcast.episodes,
    'rating': podcast.rating,
    'is_subscribed': podcast.isSubscribed,
    'tags': podcast.tags,
    'cover_image': podcast.coverImage,
    'audio_url': podcast.audioUrl,
    if ((notes ?? podcast.notes) != null && (notes ?? podcast.notes)!.isNotEmpty)
      'notes': notes ?? podcast.notes,
    if ((transcript ?? podcast.transcript) != null && (transcript ?? podcast.transcript)!.isNotEmpty)
      'transcript': transcript ?? podcast.transcript,
    'created_at': now,
    'updated_at': now,
  };
}

Map<String, dynamic> categoryPayload({
  required String name,
  required int order,
  String? imageUrl,
}) {
  return {
    'name': name,
    'description': '',
    'image_url': imageUrl,
    'order': order,
    'is_active': true,
  };
}

bool activeFlag(Map<String, dynamic> data) =>
    (data['is_active'] as bool?) ?? (data['isActive'] as bool?) ?? true;

extension StringCapitalizeExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
