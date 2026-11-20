import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_image.dart';
import '../widgets/scripture_rich_text.dart';
import '../utils/podcast_share_helper.dart';
import 'podcast_control_buttons.dart';
import 'podcast_seek_bar.dart';

/// Fullscreen modern podcast player modal with live transcription,
/// interactive seeking, playback speed controls, and lively animations.
class ModernPodcastPlayerSheet extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final Map<String, dynamic> episodeData;
  final String podcastTitle;
  final String? coverImage;
  final VoidCallback? onDownload;

  const ModernPodcastPlayerSheet({
    super.key,
    required this.audioPlayer,
    required this.episodeData,
    required this.podcastTitle,
    this.coverImage,
    this.onDownload,
  });

  static Future<void> show(
    BuildContext context, {
    required AudioPlayer audioPlayer,
    required Map<String, dynamic> episodeData,
    required String podcastTitle,
    String? coverImage,
    VoidCallback? onDownload,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModernPodcastPlayerSheet(
        audioPlayer: audioPlayer,
        episodeData: episodeData,
        podcastTitle: podcastTitle,
        coverImage: coverImage,
        onDownload: onDownload,
      ),
    );
  }

  @override
  State<ModernPodcastPlayerSheet> createState() =>
      _ModernPodcastPlayerSheetState();
}

/// Structured transcript line model with millisecond-accurate start/end playback times for real-time synchronization.
class _PodcastTranscriptLine {
  final int startMs;
  final int endMs;
  final String time;
  final String speaker;
  final String text;

  const _PodcastTranscriptLine({
    required this.startMs,
    required this.endMs,
    required this.time,
    required this.speaker,
    required this.text,
  });

  int get startSeconds => startMs ~/ 1000;
  int get endSeconds => endMs ~/ 1000;
  int get seconds => startSeconds;

  _PodcastTranscriptLine copyWith({
    int? startMs,
    int? endMs,
    String? time,
    String? speaker,
    String? text,
  }) {
    return _PodcastTranscriptLine(
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      time: time ?? this.time,
      speaker: speaker ?? this.speaker,
      text: text ?? this.text,
    );
  }
}

class _ModernPodcastPlayerSheetState extends State<ModernPodcastPlayerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _transcriptSearchController =
      TextEditingController();
  final ScrollController _transcriptScrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  String _transcriptQuery = '';
  double _currentSpeed = 1.0;

  // Transcript Sync State (Spotify-style)
  List<_PodcastTranscriptLine> _transcriptLines = [];
  bool _wasTimelineNormalized = false;
  int _lastKnownDurationMs = 0;
  int _activeTranscriptIndex = -1;
  int _currentPositionMs = 0;
  DateTime? _lastProgressUiTick;
  bool _userIsScrollingTranscript = false;
  Timer? _userScrollTimer;
  DateTime? _lastManualSeekAt;
  int _scrollGeneration = 0;
  final Map<int, GlobalKey> _transcriptItemKeys = {};
  final Map<int, double> _measuredItemHeights = {};

  // Personal Notes State
  String _userNote = '';
  bool _isEditingNote = false;
  final TextEditingController _noteController = TextEditingController();

  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  String get _episodeStorageKey {
    final epId = widget.episodeData['id'] ??
        widget.episodeData[r'$id'] ??
        widget.episodeData['title'] ??
        'unknown';
    return 'podcast_note_$epId';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _currentSpeed = widget.audioPlayer.speed;
    _currentPositionMs = widget.audioPlayer.position.inMilliseconds;
    _transcriptLines = _parseTranscriptLines();
    _activeTranscriptIndex = _findActiveTranscriptIndex(_currentPositionMs);
    _loadUserNote();
    _startPositionSync();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      final currentMs = widget.audioPlayer.position.inMilliseconds;
      final activeIdx = _findActiveTranscriptIndex(currentMs);
      if (activeIdx != _activeTranscriptIndex || currentMs != _currentPositionMs) {
        setState(() {
          _currentPositionMs = currentMs;
          _activeTranscriptIndex = activeIdx;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeTranscriptIndex >= 0 && !_userIsScrollingTranscript) {
          _scrollToActiveIndex(_activeTranscriptIndex, animate: false);
        }
      });
    }
  }

  void _startPositionSync() {
    _durationSubscription = widget.audioPlayer.durationStream.listen((dur) {
      if (!mounted || dur == null || dur.inMilliseconds <= 0) return;
      final newDurMs = dur.inMilliseconds;
      if ((newDurMs - _lastKnownDurationMs).abs() > 1000) {
        final updatedLines = _parseTranscriptLines();
        final posMs = widget.audioPlayer.position.inMilliseconds;
        final newIndex = _findActiveTranscriptIndexIn(updatedLines, posMs);
        setState(() {
          _transcriptLines = updatedLines;
          _currentPositionMs = posMs;
          _activeTranscriptIndex = newIndex;
        });
        if (_tabController.index == 1 &&
            !_userIsScrollingTranscript &&
            _transcriptQuery.isEmpty &&
            newIndex >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToActiveIndex(newIndex, animate: false);
          });
        }
      }
    });

    _positionSubscription = widget.audioPlayer.positionStream.listen((pos) {
      if (!mounted || _transcriptLines.isEmpty) return;
      if (_lastManualSeekAt != null &&
          DateTime.now().difference(_lastManualSeekAt!) <
              const Duration(milliseconds: 350)) {
        return;
      }
      final currentMs = pos.inMilliseconds;
      final newIndex = _findActiveTranscriptIndex(currentMs);
      final indexChanged = newIndex != _activeTranscriptIndex;
      final now = DateTime.now();
      final shouldTickIntraProgress = _tabController.index == 1 &&
          (_lastProgressUiTick == null ||
              now.difference(_lastProgressUiTick!) >=
                  const Duration(milliseconds: 250));

      if (indexChanged || shouldTickIntraProgress) {
        _lastProgressUiTick = now;
        setState(() {
          _currentPositionMs = currentMs;
          _activeTranscriptIndex = newIndex;
        });
      } else {
        _currentPositionMs = currentMs;
      }

      if (indexChanged &&
          _tabController.index == 1 &&
          !_userIsScrollingTranscript &&
          _transcriptQuery.isEmpty &&
          newIndex >= 0) {
        _scrollToActiveIndex(newIndex, animate: true);
      }
    });
  }

  /// Estimates a transcript card's rendered height accurately from measured boxes
  /// or character length (~38 chars/line on standard mobile widths + header/padding).
  double _estimateItemHeight(int index) {
    final measured = _measuredItemHeights[index];
    if (measured != null && measured > 40) return measured;
    if (index < 0 || index >= _transcriptLines.length) return 180.0;
    final chars = _transcriptLines[index].text.length;
    final wrappedLines = (chars / 38.0).ceil().clamp(1, 24);
    // Card header + padding + vertical spacing (~76px) + 21px per body line + 10px separator
    return 86.0 + (wrappedLines * 21.5);
  }

  double _estimateOffsetForIndex(int index) {
    double offset = 0.0;
    final limit = index.clamp(0, _transcriptLines.length);
    for (int i = 0; i < limit; i++) {
      offset += _estimateItemHeight(i);
    }
    return offset;
  }

  void _scrollToActiveIndex(
    int index, {
    bool animate = true,
    int attempt = 0,
    int? generation,
  }) {
    if (!_transcriptScrollController.hasClients ||
        index < 0 ||
        index >= _transcriptLines.length) {
      return;
    }
    if (_userIsScrollingTranscript) return;

    final gen = generation ?? (++_scrollGeneration);
    if (gen != _scrollGeneration) return;

    // 1. Direct exact scroll when the target card is already mounted in the viewport/cache
    final keyContext = _transcriptItemKeys[index]?.currentContext;
    if (keyContext != null && keyContext.mounted) {
      Scrollable.ensureVisible(
        keyContext,
        alignment: 0.25, // Upper quarter for comfortable reading ahead
        duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // 2. Target card is off-screen (unmounted in lazy ListView): compute refined offset
    //    using mounted neighbors + measured/char-estimated heights, jump to mount it,
    //    then converge cleanly onto the exact card via Scrollable.ensureVisible.
    final pos = _transcriptScrollController.position;
    if (!pos.hasContentDimensions) return;

    double targetOffset;
    // Find nearest currently-mounted item to anchor offset precisely
    int? nearestMounted;
    int bestDist = 1 << 30;
    for (final entry in _transcriptItemKeys.entries) {
      if (entry.value.currentContext != null) {
        final d = (entry.key - index).abs();
        if (d < bestDist) {
          bestDist = d;
          nearestMounted = entry.key;
        }
      }
    }

    if (index >= _transcriptLines.length - 3) {
      targetOffset = pos.maxScrollExtent;
    } else if (nearestMounted != null && attempt > 0) {
      // Refine incrementally from current scroll offset using exact delta from nearest mounted card
      double delta = 0.0;
      if (index > nearestMounted) {
        for (int i = nearestMounted; i < index; i++) {
          delta += _estimateItemHeight(i);
        }
      } else {
        for (int i = index; i < nearestMounted; i++) {
          delta -= _estimateItemHeight(i);
        }
      }
      targetOffset = (pos.pixels + delta - 120.0).clamp(0.0, pos.maxScrollExtent);
    } else {
      targetOffset = (_estimateOffsetForIndex(index) - 120.0)
          .clamp(0.0, pos.maxScrollExtent);
    }

    // Jump directly so ListView mounts the target window on the very next frame
    _transcriptScrollController.jumpTo(targetOffset);

    if (attempt < 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _userIsScrollingTranscript || gen != _scrollGeneration) {
          return;
        }
        final refreshedCtx = _transcriptItemKeys[index]?.currentContext;
        if (refreshedCtx != null && refreshedCtx.mounted) {
          Scrollable.ensureVisible(
            refreshedCtx,
            alignment: 0.25,
            duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollToActiveIndex(
            index,
            animate: animate,
            attempt: attempt + 1,
            generation: gen,
          );
        }
      });
    }
  }

  int _findActiveTranscriptIndex(int currentMs) =>
      _findActiveTranscriptIndexIn(_transcriptLines, currentMs);

  int _findActiveTranscriptIndexIn(
      List<_PodcastTranscriptLine> lines, int currentMs) {
    if (lines.isEmpty) return -1;
    // Audio has not yet reached the first segment
    if (currentMs < lines.first.startMs) {
      return -1;
    }
    // Audio has reached or passed the start of the last segment
    if (currentMs >= lines.last.startMs) {
      return lines.length - 1;
    }

    int low = 0;
    int high = lines.length - 1;
    int best = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].startMs <= currentMs) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _userScrollTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _transcriptSearchController.dispose();
    _transcriptScrollController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadUserNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_episodeStorageKey) ?? '';
      if (mounted) {
        setState(() {
          _userNote = saved;
          _noteController.text = saved;
        });
      }
    } catch (e) {
      debugPrint('Failed to load podcast note: $e');
    }
  }

  Future<void> _saveUserNote(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        await prefs.remove(_episodeStorageKey);
      } else {
        await prefs.setString(_episodeStorageKey, trimmed);
      }
      if (mounted) {
        setState(() {
          _userNote = trimmed;
          _isEditingNote = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trimmed.isEmpty ? 'Note cleared' : 'Note saved!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save podcast note: $e');
    }
  }

  Future<void> _deleteUserNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_episodeStorageKey);
      if (mounted) {
        setState(() {
          _userNote = '';
          _noteController.clear();
          _isEditingNote = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to delete podcast note: $e');
    }
  }

  void _insertCurrentTimestamp() {
    final pos = widget.audioPlayer.position;
    final stamp = '[${_formatDuration(pos)}] ';
    final currentText = _noteController.text;
    final selection = _noteController.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText =
          currentText.replaceRange(selection.start, selection.end, stamp);
      _noteController.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: selection.start + stamp.length),
      );
    } else {
      _noteController.text = '$currentText\n$stamp';
      _noteController.selection =
          TextSelection.collapsed(offset: _noteController.text.length);
    }
  }

  String _cleanMojibake(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€˜', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€\u009d', '"')
        .replaceAll('â€"', '"')
        .replaceAll('â€”', ' — ')
        .replaceAll('â€“', ' - ')
        .replaceAll('Â', '')
        .replaceAll('\uFFFD', "'");
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _cycleSpeed() {
    final nextIndex = (_speeds.indexOf(_currentSpeed) + 1) % _speeds.length;
    final newSpeed = _speeds[nextIndex];
    setState(() {
      _currentSpeed = newSpeed;
    });
    widget.audioPlayer.setSpeed(newSpeed);
  }

  int _parseSecondsFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final clean = raw.trim().toLowerCase();
    final parts = clean.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final m = int.tryParse(parts[1].trim()) ?? 0;
      final s = int.tryParse(parts[2].split('.')[0].trim()) ?? 0;
      return (h * 3600) + (m * 60) + s;
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0].trim()) ?? 0;
      final s = int.tryParse(parts[1].split('.')[0].trim()) ?? 0;
      return (m * 60) + s;
    }
    // Natural formats like "48 min", "1h 15m", "1 hr 20 mins", "90 sec"
    final hMatch = RegExp(r'(\d+)\s*(?:h|hr|hrs|hour|hours)\b').firstMatch(clean);
    final mMatch = RegExp(r'(\d+)\s*(?:m|min|mins|minute|minutes)\b').firstMatch(clean);
    final sMatch = RegExp(r'(\d+)\s*(?:s|sec|secs|second|seconds)\b').firstMatch(clean);
    if (hMatch != null || mMatch != null || sMatch != null) {
      final h = int.tryParse(hMatch?.group(1) ?? '0') ?? 0;
      final m = int.tryParse(mMatch?.group(1) ?? '0') ?? 0;
      final s = int.tryParse(sMatch?.group(1) ?? '0') ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    final numSec = double.tryParse(clean);
    if (numSec != null) return numSec.toInt();
    return 0;
  }

  String _formatMsShort(int ms) {
    final totalSecs = (ms ~/ 1000).clamp(0, 86400);
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  List<_PodcastTranscriptLine> _parseTranscriptLines() {
    final raw = (widget.episodeData['transcript'] ??
            widget.episodeData['transcription'] ??
            widget.episodeData['description'] ??
            '')
        .toString()
        .trim();

    final defaultSpeaker = (widget.episodeData['speaker'] ??
            widget.episodeData['host'] ??
            widget.episodeData['author'] ??
            'Speaker')
        .toString()
        .trim();
    final resolvedDefaultSpeaker =
        defaultSpeaker.isNotEmpty ? defaultSpeaker : 'Speaker';

    if (raw.isEmpty) {
      _wasTimelineNormalized = false;
      return [
        _PodcastTranscriptLine(
          startMs: 0,
          endMs: 60000,
          time: '00:00',
          speaker: resolvedDefaultSpeaker,
          text:
              'Welcome to this episode. Foundational truths for discipleship and spiritual growth.',
        ),
      ];
    }

    // Matches timestamp: [00:30], [00:30.500], (00:30), 00:30, [01:15:30], [00:30 - 01:00], etc.
    final timestampRegex = RegExp(
      r'^(?:\[|\()?(?:(\d{1,2}):)?(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?(?:\s*[-–—:]\s*(?:(?:(\d{1,2}):)?(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?))?(?:\]|\))?\s*[-–—:]?\s*',
    );
    final cueRegex = RegExp(
      r'^(?:(\d{1,2}):)?(\d{2}):(\d{2})(?:[.,](\d{1,3}))?\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})(?:[.,](\d{1,3}))?\s*',
    );
    final speakerRegex = RegExp(
      r'^\*?\*?([A-Za-z][A-Za-z0-9\s._-]{0,30})\*?\*?:\s+',
    );

    final rawLines = raw.split(RegExp(r'\r?\n'));

    // First pass: check whether the transcript uses explicit timestamps anywhere
    final detectedAnyTimestamp = rawLines.any((line) {
      final t = line
          .trim()
          .replaceAll(RegExp(r'^(?:[-•*]|\d+\.)\s+'), '')
          .replaceAll(RegExp(r'^\*\*'), '')
          .trim();
      return cueRegex.hasMatch(t) || timestampRegex.hasMatch(t);
    });

    final rawSegments = <_PodcastTranscriptLine>[];

    int? currentStartMs;
    int? currentEndMs;
    String? currentTimeStr;
    String currentSpeaker = resolvedDefaultSpeaker;
    final currentTextLines = <String>[];

    int parseFracMs(String? frac) {
      if (frac == null || frac.isEmpty) return 0;
      return int.tryParse(frac.padRight(3, '0').substring(0, 3)) ?? 0;
    }

    void commitCurrentSegment() {
      final combinedText = currentTextLines.join(' ').trim();
      if (combinedText.isNotEmpty || currentStartMs != null) {
        final startMs = currentStartMs ?? 0;
        final formattedTime = currentTimeStr ?? _formatMsShort(startMs);

        rawSegments.add(_PodcastTranscriptLine(
          startMs: startMs,
          endMs: currentEndMs ?? (startMs + 30000),
          time: formattedTime,
          speaker: currentSpeaker,
          text: combinedText.isEmpty ? '...' : combinedText,
        ));
      }
      currentStartMs = null;
      currentEndMs = null;
      currentTimeStr = null;
      currentTextLines.clear();
    }

    bool hasExplicitTimestamps = false;

    if (!detectedAnyTimestamp) {
      // Un-timestamped plain transcript: commit EVERY non-empty paragraph (or split long single walls
      // into ~3-sentence paragraphs) so proportional audio sync actually moves line by line!
      final nonEmptyParas = <String>[];
      for (final line in rawLines) {
        final cleaned = line
            .trim()
            .replaceAll(RegExp(r'^(?:[-•*])\s+'), '')
            .replaceAll('**', '')
            .replaceAll('*', '')
            .trim();
        if (cleaned.isNotEmpty) {
          nonEmptyParas.add(cleaned);
        }
      }
      final expandedParas = <String>[];
      if (nonEmptyParas.length == 1 && nonEmptyParas.first.length > 350) {
        final sentences = nonEmptyParas.first.split(RegExp(r'(?<=[.!?])\s+'));
        for (int i = 0; i < sentences.length; i += 3) {
          expandedParas.add(
            sentences.sublist(i, (i + 3).clamp(0, sentences.length)).join(' ').trim(),
          );
        }
      } else {
        expandedParas.addAll(nonEmptyParas);
      }

      for (var p in expandedParas) {
        final spkMatch = speakerRegex.firstMatch(p);
        String segSpeaker = resolvedDefaultSpeaker;
        if (spkMatch != null && spkMatch.group(1)!.length < 32) {
          segSpeaker = spkMatch.group(1)!.trim();
          p = p.substring(spkMatch.end).trim();
        }
        if (p.isNotEmpty) {
          rawSegments.add(_PodcastTranscriptLine(
            startMs: 0,
            endMs: 15000,
            time: '00:00',
            speaker: segSpeaker,
            text: p,
          ));
        }
      }
    } else {
      for (var line in rawLines) {
        var p = line.trim();
        if (p.isEmpty) {
          continue;
        }
        // Skip standalone SRT cue sequence numbers ("1", "2", "3") or "WEBVTT" header
        if (RegExp(r'^(?:WEBVTT|\d{1,5})$', caseSensitive: false).hasMatch(p)) {
          continue;
        }

        // Strip leading bullet / numbered / bold markers like "* ", "- ", "1. ", "**"
        p = p
            .replaceAll(RegExp(r'^(?:[-•*]|\d+\.)\s+'), '')
            .replaceAll(RegExp(r'^\*\*'), '')
            .trim();

        // Parse SRT/VTT cue headers into explicit start/end timestamps
        final cueMatch = cueRegex.firstMatch(p);
        if (cueMatch != null) {
          if (currentStartMs != null || currentTextLines.isNotEmpty) {
            commitCurrentSegment();
          }
          hasExplicitTimestamps = true;
          final sh = int.tryParse(cueMatch.group(1) ?? '0') ?? 0;
          final sm = int.tryParse(cueMatch.group(2) ?? '0') ?? 0;
          final ss = int.tryParse(cueMatch.group(3) ?? '0') ?? 0;
          final sms = parseFracMs(cueMatch.group(4));
          currentStartMs = ((sh * 3600) + (sm * 60) + ss) * 1000 + sms;

          final eh = int.tryParse(cueMatch.group(5) ?? '0') ?? 0;
          final em = int.tryParse(cueMatch.group(6) ?? '0') ?? 0;
          final es = int.tryParse(cueMatch.group(7) ?? '0') ?? 0;
          final ems = parseFracMs(cueMatch.group(8));
          currentEndMs = ((eh * 3600) + (em * 60) + es) * 1000 + ems;

          p = p.substring(cueMatch.end).trim();
          if (p.isEmpty) continue;
        }

        final timeMatch = timestampRegex.firstMatch(p);
        if (timeMatch != null) {
          if (currentStartMs != null || currentTextLines.isNotEmpty) {
            commitCurrentSegment();
          }

          hasExplicitTimestamps = true;
          final hStr = timeMatch.group(1);
          final mStr = timeMatch.group(2);
          final sStr = timeMatch.group(3);
          final msStr = timeMatch.group(4);

          final h = hStr != null ? (int.tryParse(hStr) ?? 0) : 0;
          final m = int.tryParse(mStr ?? '0') ?? 0;
          final s = int.tryParse(sStr ?? '0') ?? 0;
          final ms = parseFracMs(msStr);
          currentStartMs = ((h * 3600) + (m * 60) + s) * 1000 + ms;

          final endHStr = timeMatch.group(5);
          final endMStr = timeMatch.group(6);
          final endSStr = timeMatch.group(7);
          final endMsStr = timeMatch.group(8);
          if (endMStr != null && endSStr != null) {
            final eh = endHStr != null ? (int.tryParse(endHStr) ?? 0) : 0;
            final em = int.tryParse(endMStr) ?? 0;
            final es = int.tryParse(endSStr) ?? 0;
            final ems = parseFracMs(endMsStr);
            currentEndMs = ((eh * 3600) + (em * 60) + es) * 1000 + ems;
          }

          currentTimeStr = _formatMsShort(currentStartMs!);
          p = p.substring(timeMatch.end).trim();
        }

        // Only match explicit colon-delimited speaker labels ("Pastor Agana: ...", "Speaker: ...")
        // so normal sentences starting with "Pastor told us..." never lose their first word!
        final spkMatch = speakerRegex.firstMatch(p);
        if (spkMatch != null && spkMatch.group(1)!.length < 32) {
          currentSpeaker = spkMatch.group(1)!.trim();
          p = p.substring(spkMatch.end).trim();
        }

        p = p.replaceAll('**', '').replaceAll('*', '').trim();
        if (p.isNotEmpty) {
          currentTextLines.add(p);
        }
      }

      if (currentStartMs != null || currentTextLines.isNotEmpty) {
        commitCurrentSegment();
      }
    }

    _wasTimelineNormalized = false;

    if (rawSegments.isEmpty) {
      return [
        _PodcastTranscriptLine(
          startMs: 0,
          endMs: 60000,
          time: '00:00',
          speaker: resolvedDefaultSpeaker,
          text: 'Foundational truths for discipleship and spiritual growth.',
        ),
      ];
    }

    // Prefer live AudioPlayer duration so transcript timing matches the actual audio file
    final playerDurationMs = widget.audioPlayer.duration?.inMilliseconds ?? 0;
    final metadataSeconds =
        _parseSecondsFromString(widget.episodeData['duration']?.toString());
    final effectiveDurationMs =
        playerDurationMs > 0 ? playerDurationMs : (metadataSeconds * 1000);
    _lastKnownDurationMs = effectiveDurationMs;

    if (hasExplicitTimestamps) {
      rawSegments.sort((a, b) => a.startMs.compareTo(b.startMs));

      // Timeline overflow guard: if explicit timestamps significantly exceed the real audio duration
      // (e.g., 99:15 transcript timestamps on a 59:33 MP3), proportionally rescale every cue into
      // 0 .. effectiveDurationMs so 100% of paragraphs stay reachable and synced with the speaker!
      List<_PodcastTranscriptLine> workingSegments = rawSegments;
      if (effectiveDurationMs > 10000 &&
          rawSegments.length >= 2 &&
          rawSegments.last.startMs > (effectiveDurationMs * 1.05).round()) {
        final maxStartMs = rawSegments.last.startMs;
        // Reserve final ~1.2% (capped at 15s) for the closing segment
        final closingTailMs = (effectiveDurationMs * 0.012).round().clamp(3000, 15000);
        final targetSpanMs = (effectiveDurationMs - closingTailMs).clamp(1000, effectiveDurationMs);
        final scale = targetSpanMs / maxStartMs;
        _wasTimelineNormalized = true;
        workingSegments = rawSegments.map((seg) {
          final scaledStart = (seg.startMs * scale).round();
          return seg.copyWith(
            startMs: scaledStart,
            time: _formatMsShort(scaledStart),
          );
        }).toList();
      }

      final resolved = <_PodcastTranscriptLine>[];
      for (int i = 0; i < workingSegments.length; i++) {
        final seg = workingSegments[i];
        int segEnd;
        if (i < workingSegments.length - 1) {
          final nextStart = workingSegments[i + 1].startMs;
          segEnd = nextStart > seg.startMs ? nextStart : (seg.startMs + 5000);
        } else {
          segEnd = effectiveDurationMs > seg.startMs
              ? effectiveDurationMs
              : (seg.startMs + 30000);
        }
        resolved.add(seg.copyWith(endMs: segEnd));
      }
      return resolved;
    }

    // When explicit timestamps are absent, distribute audio duration proportionally
    // by word count (accurate to spoken cadence) with double-precision milliseconds.
    int countWords(String s) =>
        s.trim().isEmpty ? 1 : s.trim().split(RegExp(r'\s+')).length;
    final wordCounts = rawSegments.map((e) => countWords(e.text)).toList();
    final totalWords = wordCounts.fold<int>(0, (sum, w) => sum + w);
    final fallbackDurationMs =
        effectiveDurationMs > 0 ? effectiveDurationMs : (rawSegments.length * 15000);
    double accumulatedMs = 0.0;
    final redistributed = <_PodcastTranscriptLine>[];

    for (int i = 0; i < rawSegments.length; i++) {
      final item = rawSegments[i];
      final itemStartMs = accumulatedMs.round();
      final fraction =
          totalWords > 0 ? (wordCounts[i] / totalWords) : (1.0 / rawSegments.length);
      final stepMs = fraction * fallbackDurationMs;
      accumulatedMs += stepMs;
      final itemEndMs = (i == rawSegments.length - 1)
          ? fallbackDurationMs
          : accumulatedMs.round();

      redistributed.add(_PodcastTranscriptLine(
        startMs: itemStartMs,
        endMs: itemEndMs > itemStartMs ? itemEndMs : (itemStartMs + 500),
        time: _formatMsShort(itemStartMs),
        speaker: item.speaker,
        text: item.text,
      ));
    }

    return redistributed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final title = widget.episodeData['title']?.toString() ?? 'Episode';
    final durationStr = widget.episodeData['duration']?.toString() ?? '';
    final category = widget.episodeData['category']?.toString() ?? 'Podcast';

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101924) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag pill
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              // Header Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 32),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Collapse',
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PLAYING FROM SHOW',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            widget.podcastTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onDownload != null)
                      IconButton(
                        icon: const Icon(Icons.download_rounded),
                        onPressed: widget.onDownload,
                        tooltip: 'Download',
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // Navigation Tabs (Player, Transcript, Notes)
              TabBar(
                controller: _tabController,
                indicatorColor: colorScheme.primary,
                indicatorWeight: 3,
                labelColor: colorScheme.primary,
                unselectedLabelColor:
                    colorScheme.onSurface.withValues(alpha: 0.6),
                tabs: const [
                  Tab(icon: Icon(Icons.play_circle_outline), text: 'Player'),
                  Tab(icon: Icon(Icons.subtitles_outlined), text: 'Transcript'),
                  Tab(icon: Icon(Icons.notes_rounded), text: 'Show Notes'),
                ],
              ),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Lively Player
                    _buildPlayerView(theme, colorScheme, isDark, title,
                        category, durationStr),

                    // Tab 2: Interactive Live Transcript (keep-alive preserves scroll state across tab switches)
                    _KeepAliveTabPage(
                      child: _buildTranscriptView(theme, colorScheme),
                    ),

                    // Tab 3: Show Notes
                    _buildNotesView(theme, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerView(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
    String title,
    String category,
    String durationStr,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 560;

        // Proportional sizing so all controls ALWAYS fit without vertical scrolling
        final maxArtwork = (availableHeight - (isCompact ? 220 : 255)).clamp(100.0, 220.0);
        final titleFontSize = isCompact ? 17.0 : 19.0;
        final fabSize = isCompact ? 58.0 : 64.0;
        final fabIconSize = isCompact ? 32.0 : 36.0;
        final controlIconSize = isCompact ? 30.0 : 34.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: isCompact ? 4 : 8,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Responsive Animated Cover Artwork (fits dynamically into screen height)
              StreamBuilder<PlayerState>(
                stream: widget.audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.playing ?? false;
                  final size = isPlaying ? maxArtwork : (maxArtwork * 0.90);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary
                              .withValues(alpha: isPlaying ? 0.35 : 0.15),
                          blurRadius: isPlaying ? 20 : 10,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ((widget.coverImage != null && widget.coverImage!.isNotEmpty) ||
                              (widget.episodeData['coverImage'] != null && widget.episodeData['coverImage'].toString().isNotEmpty) ||
                              (widget.episodeData['cover_image'] != null && widget.episodeData['cover_image'].toString().isNotEmpty))
                          ? CustomImage(
                              imageUrl: (widget.coverImage != null && widget.coverImage!.isNotEmpty)
                                  ? widget.coverImage!
                                  : (widget.episodeData['coverImage'] ?? widget.episodeData['cover_image']).toString(),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              child: Icon(
                                Icons.podcasts_rounded,
                                size: (size * 0.4).clamp(36.0, 72.0),
                                color: colorScheme.primary,
                              ),
                            ),
                    ),
                  );
                },
              ),

              // 2. Category Badge & Title & Podcast Name
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category.trim().isNotEmpty) ...[
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: titleFontSize,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.podcastTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              // 3. Scrubbable Progress Bar & Duration
              PodcastSeekBar(
                audioPlayer: widget.audioPlayer,
                fallbackDurationString: durationStr,
              ),

              // 4. Playback Controls Row (Speed, Rewind 10, Play/Pause FAB, Forward 30, Share)
              PodcastControlButtons(
                audioPlayer: widget.audioPlayer,
                currentSpeed: _currentSpeed,
                onCycleSpeed: _cycleSpeed,
                fabSize: fabSize,
                fabIconSize: fabIconSize,
                controlIconSize: controlIconSize,
                onShare: () {
                  PodcastShareHelper.shareEpisode(
                    context,
                    episode: widget.episodeData,
                    podcastTitle: widget.podcastTitle,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptView(ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _transcriptQuery.isEmpty
        ? _transcriptLines
        : _transcriptLines.where((item) {
            return item.text
                .toLowerCase()
                .contains(_transcriptQuery.toLowerCase());
          }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search in transcript
          TextField(
            controller: _transcriptSearchController,
            decoration: InputDecoration(
              hintText: 'Search in transcript...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _transcriptQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _transcriptSearchController.clear();
                          _transcriptQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _transcriptQuery = val;
              });
            },
          ),

          const SizedBox(height: 10),
          if (_wasTimelineNormalized) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_rounded, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Transcript timeline auto-aligned to episode audio length.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Transcript List with live real-time audio synchronization
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      if (notification is UserScrollNotification) {
                        if (notification.direction != ScrollDirection.idle) {
                          _userScrollTimer?.cancel();
                          if (!_userIsScrollingTranscript) {
                            setState(() {
                              _userIsScrollingTranscript = true;
                            });
                          }
                        } else {
                          // Drag released: resume sync after brief delay
                          _userScrollTimer?.cancel();
                          _userScrollTimer =
                              Timer(const Duration(milliseconds: 2400), () {
                            if (mounted) {
                              setState(() {
                                _userIsScrollingTranscript = false;
                              });
                              _scrollToActiveIndex(_activeTranscriptIndex,
                                  animate: true);
                            }
                          });
                        }
                      }
                    }
                    return false;
                  },
                  child: ListView.separated(
                    controller: _transcriptScrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final fullIdx = _transcriptQuery.isEmpty
                          ? index
                          : _transcriptLines.indexOf(item);
                      final isActive = fullIdx >= 0 && fullIdx == _activeTranscriptIndex;
                      final itemKey = _transcriptQuery.isEmpty
                          ? _transcriptItemKeys.putIfAbsent(index, () => GlobalKey())
                          : null;

                      if (_transcriptQuery.isEmpty && itemKey != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final rb = itemKey.currentContext?.findRenderObject();
                          if (rb is RenderBox && rb.hasSize) {
                            _measuredItemHeights[index] = rb.size.height + 10.0;
                          }
                        });
                      }

                      final segDurMs = (item.endMs - item.startMs).clamp(1, 3600000);
                      final segProgress = isActive
                          ? ((_currentPositionMs - item.startMs) / segDurMs)
                              .clamp(0.0, 1.0)
                          : 0.0;

                      return KeyedSubtree(
                        key: itemKey,
                        child: InkWell(
                          onTap: () async {
                            final targetIdx = fullIdx >= 0 ? fullIdx : index;
                            final dur = widget.audioPlayer.duration;
                            var targetMs = item.startMs;
                            if (dur != null && dur.inMilliseconds > 0) {
                              targetMs = targetMs.clamp(0, dur.inMilliseconds);
                            }
                            _lastManualSeekAt = DateTime.now();
                            final wasFiltering = _transcriptQuery.isNotEmpty;
                            setState(() {
                              _currentPositionMs = targetMs;
                              _activeTranscriptIndex = targetIdx;
                              _userIsScrollingTranscript = false;
                              if (wasFiltering) {
                                _transcriptSearchController.clear();
                                _transcriptQuery = '';
                              }
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _scrollToActiveIndex(targetIdx, animate: true);
                              }
                            });
                            try {
                              await widget.audioPlayer
                                  .seek(Duration(milliseconds: targetMs));
                              if (!widget.audioPlayer.playing) {
                                await widget.audioPlayer.play();
                              }
                            } catch (e) {
                              debugPrint('Transcript seek error: $e');
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colorScheme.primary.withValues(
                                alpha: isDark ? 0.25 : 0.14)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: isDark ? 0.3 : 0.45),
                        border: Border.all(
                          color: isActive
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: isActive ? 1.8 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.primary
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? colorScheme.onPrimary
                                        : colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  item.speaker,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.graphic_eq_rounded,
                                          size: 11,
                                          color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PLAYING',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              IconButton(
                                icon:
                                    const Icon(Icons.copy_rounded, size: 16),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: item.text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Quote copied to clipboard'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                tooltip: 'Copy quote',
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ScriptureRichText(
                            item.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isActive
                                  ? (isDark
                                      ? Colors.white
                                      : colorScheme.onSurface)
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.72),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: segProgress,
                                minHeight: 3,
                                backgroundColor: colorScheme.primary
                                    .withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  );
                },
              ),
            ),
            // Floating "Resume Sync" button when user scrolls away
            if (_userIsScrollingTranscript &&
                _transcriptQuery.isEmpty &&
                _activeTranscriptIndex >= 0)
              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  color: colorScheme.primary,
                  child: InkWell(
                    onTap: () {
                      _userScrollTimer?.cancel();
                      setState(() {
                        _userIsScrollingTranscript = false;
                      });
                      _scrollToActiveIndex(_activeTranscriptIndex, animate: true);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Resume Sync',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildNotesView(ThemeData theme, ColorScheme colorScheme) {
    final rawDescription = widget.episodeData['description']?.toString() ??
        'No detailed show notes provided for this episode.';
    final description = _cleanMojibake(rawDescription);
    final rawNotes = widget.episodeData['notes']?.toString();
    final customNotes = rawNotes != null ? _cleanMojibake(rawNotes) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Episode Overview
          Text(
            'Episode Overview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _hasMarkdownSyntax(description)
              ? _buildFormattedMarkdownNotes(context, theme, colorScheme, description)
              : Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),

          // 2. Published Key Notes & Outline (from Appwrite)
          if (customNotes != null && customNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Show Notes & Outline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildFormattedMarkdownNotes(context, theme, colorScheme, customNotes),
          ],

          const SizedBox(height: 24),

          // 3. Member Personal Notes (Saved locally like Bible Notes)
          Row(
            children: [
              Icon(Icons.edit_note_rounded,
                  color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My Notes & Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_userNote.isNotEmpty && !_isEditingNote)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit Note',
                  onPressed: () {
                    setState(() {
                      _isEditingNote = true;
                      _noteController.text = _userNote;
                    });
                  },
                ),
              if (_userNote.isNotEmpty && !_isEditingNote)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Delete Note',
                  onPressed: () => _confirmDeleteUserNote(context),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Active Note Editor or Display Card
          if (_isEditingNote || _userNote.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF16202C)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'Record your personal takeaways, study reflections, or revelations while listening...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Timestamp stamp button
                      OutlinedButton.icon(
                        onPressed: _insertCurrentTimestamp,
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: Text(
                          'Stamp ${_formatDuration(widget.audioPlayer.position)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_userNote.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingNote = false;
                                  _noteController.text = _userNote;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            onPressed: () =>
                                _saveUserNote(_noteController.text),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Save Note'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Saved Note Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _userNote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy Note',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _userNote));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Note copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasMarkdownSyntax(String text) {
    return text.contains('##') ||
        text.contains('# ') ||
        text.contains('**') ||
        text.contains('* ') ||
        text.contains('- ') ||
        text.contains('• ');
  }

  Widget _buildFormattedMarkdownNotes(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String rawNotes,
  ) {
    final lines = rawNotes.split(RegExp(r'\r?\n'));
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Divider lines
      if (line.startsWith('---') || line.startsWith('___') || line.startsWith('***')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
        );
        continue;
      }

      // Isolated heading marker (e.g. "##" alone on a line without title)
      if (RegExp(r'^#{1,6}$').hasMatch(line)) {
        if (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty) {
          i++; // Consume next line as the heading title
          final title = lines[i].trim().replaceAll(RegExp(r'\*+'), '').trim();
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        continue;
      }

      // Level 3 heading: ### Title or ###Title
      if (RegExp(r'^###\s*(.*)$').hasMatch(line)) {
        final match = RegExp(r'^###\s*(.*)$').firstMatch(line)!;
        final title = match.group(1)!.replaceAll(RegExp(r'\*+'), '').trim();
        if (title.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          );
          continue;
        }
      }

      // Level 2 heading: ## Title or ##Title
      if (RegExp(r'^##\s*(.*)$').hasMatch(line)) {
        final match = RegExp(r'^##\s*(.*)$').firstMatch(line)!;
        final title = match.group(1)!.replaceAll(RegExp(r'\*+'), '').trim();
        if (title.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          continue;
        }
      }

      // Level 1 heading: # Title or #Title
      if (RegExp(r'^#\s*(.*)$').hasMatch(line)) {
        final match = RegExp(r'^#\s*(.*)$').firstMatch(line)!;
        final title = match.group(1)!.replaceAll(RegExp(r'\*+'), '').trim();
        if (title.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
          continue;
        }
      }

      // Bullet lists: * item, - item, • item, + item
      if (line.startsWith('* ') || line.startsWith('- ') || line.startsWith('• ') || line.startsWith('+ ')) {
        final content = line.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Container(
                    width: 5.5,
                    height: 5.5,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildInlineMarkdownRichText(theme, colorScheme, content),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered lists: 1. item
      if (RegExp(r'^\d+\.\s+').hasMatch(line)) {
        final match = RegExp(r'^(\d+)\.\s+').firstMatch(line)!;
        final numStr = match.group(1)!;
        final content = line.substring(match.end).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  margin: const EdgeInsets.only(right: 10, top: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    numStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildInlineMarkdownRichText(theme, colorScheme, content),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Standard body paragraph
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildInlineMarkdownRichText(theme, colorScheme, line),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildInlineMarkdownRichText(
    ThemeData theme,
    ColorScheme colorScheme,
    String text,
  ) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    int lastEnd = 0;

    void addSpans(String segment, TextStyle? style) {
      spans.addAll(
        ScriptureTextParser.buildSpans(
          context,
          segment,
          baseStyle: style,
        ),
      );
    }

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        addSpans(
          text.substring(lastEnd, match.start),
          theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        );
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        addSpans(
          matchedText.substring(2, matchedText.length - 2),
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.6,
            color: colorScheme.onSurface,
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        addSpans(
          matchedText.substring(1, matchedText.length - 1),
          theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      addSpans(
        text.substring(lastEnd),
        theme.textTheme.bodyMedium?.copyWith(height: 1.6),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  void _confirmDeleteUserNote(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text(
            'Are you sure you want to delete your personal note for this episode?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUserNote();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Preserves scroll position and measured card heights across TabBarView switches.
class _KeepAliveTabPage extends StatefulWidget {
  final Widget child;
  const _KeepAliveTabPage({required this.child});

  @override
  State<_KeepAliveTabPage> createState() => _KeepAliveTabPageState();
}

class _KeepAliveTabPageState extends State<_KeepAliveTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

