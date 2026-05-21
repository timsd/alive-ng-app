// ignore_for_file: deprecated_member_use

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/podcast_models.dart';

class PodcastNotifier extends StateNotifier<List<Podcast>> {
  final Databases _databases;

  PodcastNotifier(this._databases) : super([]) {
    loadPodcasts();
  }

  Future<void> loadPodcasts() async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.podcastsCollectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(100)],
      );
      final podcasts = response.documents
          .map((doc) => Podcast.fromJson({...doc.data, 'id': doc.$id}))
          .toList();
      state = podcasts;
    } catch (e) {
      // If there is an error or no podcasts in Appwrite yet, keep the screen empty.
      state = [];
    }
  }

  Future<List<PodcastEpisode>> getEpisodesForPodcast(String podcastId) async {
    try {
      final response = await _databases.listDocuments(
        databaseId: AppwriteBackendConfig.databaseId,
        collectionId: AppwriteBackendConfig.podcastEpisodesCollectionId,
        queries: [
          Query.equal('podcast_id', podcastId),
          Query.orderDesc('publish_date'),
          Query.limit(100),
        ],
      );
      final episodesData =
          response.documents.map((doc) => {...doc.data, 'id': doc.$id});

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
  return PodcastNotifier(Databases(appwriteClient));
});

final podcastEpisodesProvider =
    FutureProvider.family<List<PodcastEpisode>, String>(
  (ref, podcastId) async {
    final podcastNotifier = ref.read(podcastProvider.notifier);
    return await podcastNotifier.getEpisodesForPodcast(podcastId);
  },
);
