import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/podcast_models.dart';
import '../services/firebase_database_service.dart';

class PodcastNotifier extends StateNotifier<List<Podcast>> {
  final FirebaseDatabaseService _firebaseService;
  
  PodcastNotifier(this._firebaseService) : super([]) {
    loadPodcasts();
  }

  Future<void> loadPodcasts() async {
    try {
      final podcastsData = await _firebaseService.getCollection('podcasts');
      final podcasts = podcastsData.map((data) => Podcast.fromJson(data)).toList();
      state = podcasts;
    } catch (e) {
      // If there's an error or no podcasts in Firebase yet, use sample data
      state = [];
    }
  }

  Future<List<PodcastEpisode>> getEpisodesForPodcast(String podcastId) async {
    try {
      final episodesData = await _firebaseService.getCollectionWhere(
        'podcast_episodes',
        'podcastId',
        podcastId,
      );
      
      if (episodesData.isEmpty) {
        return [];
      }
      
      return episodesData
          .map((data) => PodcastEpisode.fromJson(data))
          .toList()
          .cast<PodcastEpisode>();
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

final podcastProvider = StateNotifierProvider<PodcastNotifier, List<Podcast>>((ref) {
  return PodcastNotifier(FirebaseDatabaseService.instance);
});

final podcastEpisodesProvider = FutureProvider.family<List<PodcastEpisode>, String>(
  (ref, podcastId) async {
    final podcastNotifier = ref.read(podcastProvider.notifier);
    return await podcastNotifier.getEpisodesForPodcast(podcastId);
  },
);