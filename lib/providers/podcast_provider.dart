import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/podcast_models.dart';

class PodcastNotifier extends StateNotifier<List<Podcast>> {
  final TablesDB _tables;

  PodcastNotifier(this._tables) : super([]) {
    loadPodcasts();
  }

  Future<void> loadPodcasts() async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.podcastsCollectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(100)],
      );
      final podcasts = response.rows
          .map((row) => Podcast.fromJson({...row.data, 'id': row.$id}))
          .toList();
      state = podcasts;
    } catch (e) {
      // If there is an error or no podcasts in Appwrite yet, keep the screen empty.
      state = [];
    }
  }

  Future<List<PodcastEpisode>> getEpisodesForPodcast(String podcastId) async {
    try {
      final response = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.podcastEpisodesCollectionId,
        queries: [
          Query.equal('podcast_id', podcastId),
          Query.orderDesc('publish_date'),
          Query.limit(100),
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
