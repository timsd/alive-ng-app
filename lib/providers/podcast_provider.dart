import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/appwrite_facade.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/podcast_models.dart';

class PodcastNotifier extends StateNotifier<List<Podcast>> {
  final TablesDB _tables;
  static const String _cacheKey = 'podcast_list_cache_v1';

  PodcastNotifier(this._tables) : super([]) {
    loadPodcasts();
  }

  Future<void> loadPodcasts() async {
    if (state.isEmpty) {
      await _loadFromCache();
    }
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.podcastsCollectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(250)],
      );
      final podcasts = response.rows
          .map((row) => Podcast.fromJson({...row.data, 'id': row.$id}))
          .toList();
      state = podcasts;
      await _saveToCache(podcasts);
    } catch (e) {
      if (state.isEmpty) {
        await _loadFromCache();
      }
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .whereType<Map>()
          .map((e) => Podcast.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
  }

  Future<void> _saveToCache(List<Podcast> podcasts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(podcasts.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<List<PodcastEpisode>> getEpisodesForPodcast(String podcastId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.podcastEpisodesCollectionId,
        queries: [
          Query.equal('podcast_id', podcastId),
          Query.orderDesc('publish_date'),
          Query.limit(250),
        ],
      );
      final episodesData =
          response.rows.map((row) => {...row.data, 'id': row.$id});

      return episodesData.map(PodcastEpisode.fromJson).toList();
    } catch (e) {
      return [];
    }
  }

  void updatePodcast(Podcast updated) {
    final idx = state.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      final newList = List<Podcast>.from(state);
      newList[idx] = updated;
      state = newList;
    }
  }
}

final podcastProvider =
    StateNotifierProvider<PodcastNotifier, List<Podcast>>((ref) {
  return PodcastNotifier(TablesDB(appwriteClient));
});

final podcastEpisodesProvider =
    FutureProvider.family<List<PodcastEpisode>, String>(
  (ref, podcastId) async {
    final podcastNotifier = ref.read(podcastProvider.notifier);
    return await podcastNotifier.getEpisodesForPodcast(podcastId);
  },
);
