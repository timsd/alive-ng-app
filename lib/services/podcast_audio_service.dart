import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Global persistent audio service for podcasts.
/// Ensures that when the user leaves the podcast screen and returns,
/// playback state, current position, and active episode are preserved.
class PodcastAudioService extends ChangeNotifier {
  static final PodcastAudioService _instance = PodcastAudioService._internal();
  factory PodcastAudioService() => _instance;
  PodcastAudioService._internal() {
    _player.playerStateStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? _currentEpisode;
  String? _currentPodcastTitle;
  String? _currentCoverImage;

  AudioPlayer get player => _player;
  Map<String, dynamic>? get currentEpisode => _currentEpisode;
  String? get currentPodcastTitle => _currentPodcastTitle;
  String? get currentCoverImage => _currentCoverImage;
  bool get hasActiveEpisode => _currentEpisode != null;
  bool get isPlaying => _player.playing;

  bool isCurrentEpisode(Map<String, dynamic> episode) {
    if (_currentEpisode == null) return false;
    final currId = (_currentEpisode!['id'] ?? _currentEpisode!['title'])?.toString();
    final newId = (episode['id'] ?? episode['title'])?.toString();
    if (currId != null && newId != null && currId == newId) return true;
    final currUrl = _currentEpisode!['audioUrl'] ?? _currentEpisode!['audio_url'];
    final newUrl = episode['audioUrl'] ?? episode['audio_url'];
    return currUrl != null && newUrl != null && currUrl == newUrl;
  }

  Future<void> playOrResumeEpisode({
    required Map<String, dynamic> episode,
    required String audioUrl,
    String? podcastTitle,
    String? coverImage,
  }) async {
    final same = isCurrentEpisode(episode);
    _currentEpisode = episode;
    _currentPodcastTitle = podcastTitle ?? episode['podcastTitle']?.toString();
    _currentCoverImage = coverImage ?? episode['coverImage']?.toString();

    if (same && _player.duration != null && _player.duration! > Duration.zero) {
      // If it's already the active episode, don't re-fetch URL or reset position!
      if (!_player.playing) {
        await _player.play();
      }
      notifyListeners();
      return;
    }

    // New episode or fresh start
    try {
      await _player.setUrl(audioUrl);
      await _player.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing podcast audio: $e');
      rethrow;
    }
  }

  void pause() {
    _player.pause();
    notifyListeners();
  }

  void resume() {
    _player.play();
    notifyListeners();
  }

  void stop() {
    _player.stop();
    _currentEpisode = null;
    notifyListeners();
  }
}

