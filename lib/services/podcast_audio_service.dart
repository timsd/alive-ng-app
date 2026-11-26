// ignore_for_file: experimental_member_use
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Range-aware [StreamAudioSource] for native mobile (Android / iOS) playback.
///
/// Appwrite's `/storage/.../view` and `/download` endpoints omit both
/// `Content-Length` and `Accept-Ranges` on plain `GET` requests (no `Range`
/// header), which causes ExoPlayer's `Mp3Extractor` to treat CBR MP3s without
/// Xing/VBRI headers as unseekable (restarting from 00:00 on every seek).
///
/// However, Appwrite ALWAYS returns `206 Partial Content` with an exact
/// `Content-Range: bytes start-end/total` and `Accept-Ranges: bytes` whenever
/// a `Range` header is sent. This source always sends `Range: bytes=start-end`
/// so ExoPlayer receives the exact total file length, duration, and byte-level
/// seeking on the very first request.
class _RangeSeekingAudioSource extends StreamAudioSource {
  final Uri uri;
  int? _knownSourceLength;
  String _knownContentType = 'audio/mpeg';

  _RangeSeekingAudioSource(this.uri, {super.tag});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final rangeHeader = end != null
        ? 'bytes=$effectiveStart-${end - 1}'
        : 'bytes=$effectiveStart-';

    final client = http.Client();
    try {
      final req = http.Request('GET', uri);
      req.headers['Range'] = rangeHeader;
      req.headers['Accept-Encoding'] = 'identity';

      final streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 20));
      if (streamed.statusCode == 416) {
        // Range Not Satisfiable (often requested right at EOF by ExoPlayer).
        // Parse total length from Content-Range: bytes */TOTAL if present and return clean EOF.
        int? totalLength = _knownSourceLength;
        final cr = streamed.headers['content-range'];
        if (cr != null) {
          final m = RegExp(r'bytes\s+\*/(\d+)').firstMatch(cr);
          if (m != null) {
            totalLength = int.tryParse(m.group(1)!) ?? totalLength;
          }
        }
        client.close();
        return StreamAudioResponse(
          sourceLength: totalLength,
          contentLength: 0,
          offset: effectiveStart,
          stream: const Stream<List<int>>.empty(),
          contentType: _knownContentType,
          rangeRequestsSupported: totalLength != null,
        );
      }
      if (streamed.statusCode != 200 && streamed.statusCode != 206) {
        client.close();
        throw Exception('Audio HTTP ${streamed.statusCode}');
      }

      final ct = streamed.headers['content-type'];
      if (ct != null && ct.trim().isNotEmpty) {
        _knownContentType = ct.split(';').first.trim();
      }

      int? totalLength = _knownSourceLength;
      int? rangeStart;
      int? rangeEnd;

      final contentRange = streamed.headers['content-range'];
      if (contentRange != null) {
        final match =
            RegExp(r'bytes\s+(\d+)-(\d+)/(\d+|\*)').firstMatch(contentRange);
        if (match != null) {
          rangeStart = int.tryParse(match.group(1)!);
          rangeEnd = int.tryParse(match.group(2)!);
          final totalStr = match.group(3)!;
          if (totalStr != '*') {
            totalLength = int.tryParse(totalStr) ?? totalLength;
          }
        }
      }

      final headerContentLen = streamed.contentLength;
      if (totalLength == null &&
          streamed.statusCode == 200 &&
          headerContentLen != null &&
          headerContentLen > 0) {
        totalLength = headerContentLen;
      }
      if (totalLength != null && totalLength > 0) {
        _knownSourceLength = totalLength;
      }

      final int effectiveOffset = rangeStart ?? effectiveStart;
      int? responseContentLength;
      if (rangeStart != null && rangeEnd != null && rangeEnd >= rangeStart) {
        responseContentLength = rangeEnd - rangeStart + 1;
      } else if (headerContentLen != null && headerContentLen > 0) {
        responseContentLength = headerContentLen;
      } else if (totalLength != null && totalLength > effectiveOffset) {
        final upper = end != null && end <= totalLength ? end : totalLength;
        responseContentLength = upper - effectiveOffset;
      }

      // Wrap the byte stream so the underlying http.Client is always closed
      // when ExoPlayer finishes reading OR cancels mid-stream during a seek.
      late StreamController<List<int>> controller;
      StreamSubscription<List<int>>? sub;
      controller = StreamController<List<int>>(
        onListen: () {
          sub = streamed.stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              client.close();
              if (!controller.isClosed) {
                controller.close();
              }
            },
            cancelOnError: true,
          );
        },
        onCancel: () async {
          await sub?.cancel();
          client.close();
        },
      );

      return StreamAudioResponse(
        sourceLength: totalLength,
        contentLength: responseContentLength,
        offset: effectiveOffset,
        stream: controller.stream,
        contentType: _knownContentType,
        rangeRequestsSupported: totalLength != null,
      );
    } catch (e) {
      client.close();
      rethrow;
    }
  }
}

/// Global persistent audio service for podcasts.
/// Ensures that when the user leaves the podcast screen and returns,
/// playback state, current position, and active episode are preserved.
class PodcastAudioService extends ChangeNotifier {
  static final PodcastAudioService _instance = PodcastAudioService._internal();
  factory PodcastAudioService() => _instance;
  PodcastAudioService._internal();

  static Future<void>? _initFuture;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSub;
  Map<String, dynamic>? _currentEpisode;
  String? _currentPodcastTitle;
  String? _currentCoverImage;

  /// Lazily initializes [JustAudioBackground] right before first podcast play
  /// so cold app launch never blocks the Android main thread (ANR) and
  /// AudioService is not left running when the user never plays podcasts.
  /// Uses a shared Future so concurrent taps await the same initialization.
  static Future<void> _ensureBackgroundAudioInitialized() {
    if (kIsWeb) return Future.value();
    if (_initFuture != null) return _initFuture!;
    final future = JustAudioBackground.init(
      androidNotificationChannelId:
          'com.alive.alivengandroidapp.channel.audio',
      androidNotificationChannelName: 'ALIVE Podcasts',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_notification',
    ).catchError((Object e) {
      debugPrint('JustAudioBackground lazy init note: $e');
      _initFuture = null;
    });
    _initFuture = future;
    return future;
  }

  AudioPlayer _getOrCreatePlayer() {
    if (_player == null) {
      _player = AudioPlayer();
      _playerStateSub = _player!.playerStateStream.listen((_) => notifyListeners());
    }
    return _player!;
  }

  AudioPlayer get player => _getOrCreatePlayer();
  Map<String, dynamic>? get currentEpisode => _currentEpisode;
  String? get currentPodcastTitle => _currentPodcastTitle;
  String? get currentCoverImage => _currentCoverImage;
  bool get hasActiveEpisode => _currentEpisode != null;
  bool get isPlaying => _player?.playing ?? false;

  bool isCurrentEpisode(Map<String, dynamic> episode) {
    if (_currentEpisode == null) return false;
    final currId =
        (_currentEpisode!['id'] ?? _currentEpisode!['title'])?.toString();
    final newId = (episode['id'] ?? episode['title'])?.toString();
    if (currId != null && newId != null && currId == newId) return true;
    final currUrl =
        _currentEpisode!['audioUrl'] ?? _currentEpisode!['audio_url'];
    final newUrl = episode['audioUrl'] ?? episode['audio_url'];
    return currUrl != null && newUrl != null && currUrl == newUrl;
  }

  Future<void> playOrResumeEpisode({
    required Map<String, dynamic> episode,
    required String audioUrl,
    String? podcastTitle,
    String? coverImage,
  }) async {
    await _ensureBackgroundAudioInitialized();
    final activePlayer = _getOrCreatePlayer();
    final same = isCurrentEpisode(episode);
    final nextPodcastTitle = podcastTitle ?? episode['podcastTitle']?.toString();
    final nextCoverImage = coverImage ?? episode['coverImage']?.toString();

    if (same &&
        activePlayer.duration != null &&
        activePlayer.duration! > Duration.zero) {
      // If it's already the active episode, don't re-fetch URL or reset position!
      _currentEpisode = episode;
      _currentPodcastTitle = nextPodcastTitle;
      _currentCoverImage = nextCoverImage;
      if (activePlayer.processingState == ProcessingState.completed) {
        await activePlayer.seek(Duration.zero);
      }
      if (!activePlayer.playing) {
        // NOTE: In just_audio, play() does not complete until paused/finished!
        unawaited(
          activePlayer.play().catchError((Object e) {
            debugPrint('Podcast play() warning: $e');
          }),
        );
      }
      notifyListeners();
      return;
    }

    // New episode or fresh start — only commit active metadata after setAudioSource succeeds
    try {
      final episodeId =
          (episode['id'] ?? episode['title'] ?? audioUrl).toString();
      final episodeTitle =
          (episode['title'] ?? 'ALIVE Podcast Episode').toString();
      final podcastAlbum = nextPodcastTitle ?? 'ALIVE Nigeria Podcasts';
      final speaker = (episode['speaker'] ??
              episode['author'] ??
              episode['host'] ??
              podcastAlbum)
          .toString();
      final parsedArt = (nextCoverImage != null &&
              nextCoverImage.trim().startsWith('http'))
          ? Uri.tryParse(nextCoverImage.trim())
          : null;

      final uri = Uri.parse(audioUrl);
      final mediaItem = MediaItem(
        id: episodeId,
        album: podcastAlbum,
        title: episodeTitle,
        artist: speaker,
        artUri: parsedArt,
      );

      final AudioSource source;
      if (!kIsWeb && (uri.scheme == 'http' || uri.scheme == 'https')) {
        // Use our Range-aware source on Android/iOS so Appwrite Storage files
        // always supply Content-Length + Accept-Ranges to ExoPlayer for exact seeking.
        source = _RangeSeekingAudioSource(uri, tag: mediaItem);
      } else {
        source = AudioSource.uri(uri, tag: mediaItem);
      }

      await activePlayer.setAudioSource(source);
      _currentEpisode = episode;
      _currentPodcastTitle = nextPodcastTitle;
      _currentCoverImage = nextCoverImage;
      // Do NOT await play() — in just_audio its Future resolves only
      // when playback finishes or pauses, which would block opening the player sheet!
      unawaited(
        activePlayer.play().catchError((Object e) {
          debugPrint('Podcast play() warning: $e');
        }),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing podcast audio: $e');
      rethrow;
    }
  }

  void pause() {
    _player?.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    final activePlayer = _player;
    if (activePlayer == null) return;
    if (activePlayer.processingState == ProcessingState.completed) {
      await activePlayer.seek(Duration.zero);
    }
    unawaited(
      activePlayer.play().catchError((Object e) {
        debugPrint('Podcast resume() warning: $e');
      }),
    );
    notifyListeners();
  }

  void stop() {
    _player?.stop();
    _currentEpisode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
