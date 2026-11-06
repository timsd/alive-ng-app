import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_image.dart';
import '../utils/podcast_share_helper.dart';

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

/// Structured transcript line model with pre-parsed playback seconds for instant Spotify-style sync.
class _PodcastTranscriptLine {
  final int seconds;
  final String time;
  final String speaker;
  final String text;

  const _PodcastTranscriptLine({
    required this.seconds,
    required this.time,
    required this.speaker,
    required this.text,
  });
}

class _ModernPodcastPlayerSheetState extends State<ModernPodcastPlayerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _transcriptSearchController =
      TextEditingController();
  final ScrollController _transcriptScrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;

  String _transcriptQuery = '';
  double _currentSpeed = 1.0;
  bool _isSeeking = false;
  double _dragPosition = 0.0;

  // Transcript Sync State (Spotify-style)
  List<_PodcastTranscriptLine> _transcriptLines = [];
  int _activeTranscriptIndex = -1;
  bool _userIsScrollingTranscript = false;
  Timer? _userScrollTimer;
  final Map<int, GlobalKey> _transcriptItemKeys = {};

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
    _transcriptLines = _parseTranscriptLines();
    _loadUserNote();
    _startPositionSync();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      // Switched to Transcript tab: immediately center current playing line
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToActiveIndex(_activeTranscriptIndex, animate: false);
        }
      });
    }
  }

  void _startPositionSync() {
    _positionSubscription = widget.audioPlayer.positionStream.listen((pos) {
      if (!mounted || _transcriptLines.isEmpty) return;
      final currentSeconds = pos.inSeconds;
      final newIndex = _findActiveTranscriptIndex(currentSeconds);

      if (newIndex != _activeTranscriptIndex) {
        setState(() {
          _activeTranscriptIndex = newIndex;
        });

        // Instant Spotify-style scroll sync when viewing Transcript tab
        if (_tabController.index == 1 &&
            !_userIsScrollingTranscript &&
            _transcriptQuery.isEmpty &&
            newIndex >= 0) {
          _scrollToActiveIndex(newIndex, animate: true);
        }
      }
    });
  }

  void _scrollToActiveIndex(int index, {bool animate = true}) {
    if (!_transcriptScrollController.hasClients || index < 0) return;
    if (_userIsScrollingTranscript) return;

    final key = _transcriptItemKeys[index];
    final keyContext = key?.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        alignment: 0.32, // Centered nicely ~32% from the top
        duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    } else {
      // Fallback estimate if item is not rendered yet
      if (_transcriptLines.isNotEmpty &&
          _transcriptScrollController.position.maxScrollExtent > 0) {
        final ratio = (index / _transcriptLines.length).clamp(0.0, 1.0);
        final targetOffset = ratio * _transcriptScrollController.position.maxScrollExtent;
        if (animate) {
          _transcriptScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _transcriptScrollController.jumpTo(targetOffset);
        }
      }
    }
  }

  int _findActiveTranscriptIndex(int currentSeconds) {
    if (_transcriptLines.isEmpty) return -1;
    // O(log n) binary search for instant real-time lookup
    int low = 0;
    int high = _transcriptLines.length - 1;
    int best = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_transcriptLines[mid].seconds <= currentSeconds) {
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
    final clean = raw.trim();
    final parts = clean.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2].split('.')[0]) ?? 0;
      return (h * 3600) + (m * 60) + s;
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1].split('.')[0]) ?? 0;
      return (m * 60) + s;
    }
    final numSec = double.tryParse(clean);
    if (numSec != null) return numSec.toInt();
    return 0;
  }

  List<_PodcastTranscriptLine> _parseTranscriptLines() {
    final raw = (widget.episodeData['transcript'] ??
            widget.episodeData['transcription'] ??
            widget.episodeData['description'] ??
            '')
        .toString()
        .trim();

    if (raw.isEmpty) {
      return const [
        _PodcastTranscriptLine(
          seconds: 0,
          time: '00:00',
          speaker: 'Speaker',
          text:
              'Welcome to this episode. Foundational truths for discipleship and spiritual growth.',
        ),
      ];
    }

    final paragraphs = raw.split(RegExp(r'\n+'));
    final parsedItems = <_PodcastTranscriptLine>[];
    bool hasExplicitTimestamps = false;

    // Matches [hh:mm:ss], (hh:mm:ss), hh:mm:ss, [mm:ss], (mm:ss), mm:ss, with optional milliseconds
    final timestampRegex = RegExp(
      r'^(?:\[|\()?(?:(\d{1,2}):)?(\d{1,3}):(\d{2})(?:\.\d{1,3})?(?:\]|\))?\s*[-–—:]?\s*',
    );
    final cueRegex = RegExp(
      r'^(?:(?:\d{1,2}:)?\d{2}:\d{2}(?:[.,]\d+)?)\s*-->\s*(?:(?:\d{1,2}:)?\d{2}:\d{2}(?:[.,]\d+)?)\s*',
    );
    final speakerRegex = RegExp(
      r'^\*?\*?([A-Za-z0-9\s_]+)\*?\*?:\s*',
    );

    for (int i = 0; i < paragraphs.length; i++) {
      var p = paragraphs[i].trim();
      if (p.isEmpty) continue;

      // Strip leading bullet markers like "* ****" or "* "
      p = p.replaceAll(RegExp(r'^\*+\s*(\*+\s*)*'), '').trim();

      // Check and strip SRT/VTT cue headers if present
      final cueMatch = cueRegex.firstMatch(p);
      if (cueMatch != null) {
        p = p.substring(cueMatch.end).trim();
      }

      int? itemSeconds;
      String? timeStr;

      // Match timestamp at the beginning of the line
      final timeMatch = timestampRegex.firstMatch(p);
      if (timeMatch != null) {
        final hStr = timeMatch.group(1);
        final mStr = timeMatch.group(2);
        final sStr = timeMatch.group(3);

        final h = hStr != null ? (int.tryParse(hStr) ?? 0) : 0;
        final m = int.tryParse(mStr ?? '0') ?? 0;
        final s = int.tryParse(sStr ?? '0') ?? 0;

        itemSeconds = (h * 3600) + (m * 60) + s;
        if (h > 0) {
          timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        } else {
          timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
        }
        p = p.substring(timeMatch.end).trim();
        hasExplicitTimestamps = true;
      }

      String speaker = i % 2 == 0 ? 'Speaker' : 'Reflection';
      final speakerMatch = speakerRegex.firstMatch(p);
      if (speakerMatch != null && speakerMatch.group(1)!.length < 32) {
        speaker = speakerMatch.group(1)!.trim();
        p = p.substring(speakerMatch.end).trim();
      }

      // Check if timestamp is trailing e.g. "Speaker [01:23]: hello"
      if (itemSeconds == null) {
        final trailingTime = timestampRegex.firstMatch(p);
        if (trailingTime != null) {
          final hStr = trailingTime.group(1);
          final mStr = trailingTime.group(2);
          final sStr = trailingTime.group(3);
          final h = hStr != null ? (int.tryParse(hStr) ?? 0) : 0;
          final m = int.tryParse(mStr ?? '0') ?? 0;
          final s = int.tryParse(sStr ?? '0') ?? 0;
          itemSeconds = (h * 3600) + (m * 60) + s;
          timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
          p = p.substring(trailingTime.end).trim();
          hasExplicitTimestamps = true;
        }
      }

      // Clean remaining asterisks and artifacts
      p = p.replaceAll('**', '').replaceAll('*', '').trim();
      if (p.isEmpty) continue;

      parsedItems.add(_PodcastTranscriptLine(
        seconds: itemSeconds ?? 0,
        time: timeStr ?? '',
        speaker: speaker,
        text: p,
      ));
    }

    if (parsedItems.isEmpty) {
      return const [
        _PodcastTranscriptLine(
          seconds: 0,
          time: '00:00',
          speaker: 'Speaker',
          text: 'Foundational truths for discipleship and spiritual growth.',
        ),
      ];
    }

    // If explicit timestamps were not present throughout, distribute time dynamically
    // based on paragraph lengths and known or estimated duration!
    if (!hasExplicitTimestamps) {
      final totalSeconds = _parseSecondsFromString(widget.episodeData['duration']?.toString());
      final effectiveDuration = totalSeconds > 0
          ? totalSeconds
          : (widget.audioPlayer.duration?.inSeconds ?? (parsedItems.length * 15));

      final totalChars = parsedItems.fold<int>(0, (sum, item) => sum + item.text.length);
      int accumulatedSeconds = 0;

      final redistributed = <_PodcastTranscriptLine>[];
      for (int i = 0; i < parsedItems.length; i++) {
        final item = parsedItems[i];
        final itemSec = accumulatedSeconds;
        final mins = itemSec ~/ 60;
        final secs = itemSec % 60;
        final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

        redistributed.add(_PodcastTranscriptLine(
          seconds: itemSec,
          time: timeStr,
          speaker: item.speaker,
          text: item.text,
        ));

        // Weight next start by character count
        final fraction = totalChars > 0 ? (item.text.length / totalChars) : (1.0 / parsedItems.length);
        final step = (fraction * effectiveDuration).round().clamp(3, 120);
        accumulatedSeconds += step;
      }
      return redistributed;
    }

    return parsedItems;
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

                    // Tab 2: Interactive Live Transcript
                    _buildTranscriptView(theme, colorScheme),

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
              StreamBuilder<Duration>(
                stream: widget.audioPlayer.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = widget.audioPlayer.duration ??
                      Duration(
                          minutes:
                              int.tryParse(durationStr.split(':').first) ?? 15);

                  final totalMs = duration.inMilliseconds.toDouble();
                  final posMs = _isSeeking
                      ? _dragPosition
                      : position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, totalMs > 0 ? totalMs : 1.0);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: colorScheme.primary,
                          inactiveTrackColor:
                              colorScheme.onSurface.withValues(alpha: 0.15),
                          thumbColor: colorScheme.primary,
                        ),
                        child: Slider(
                          min: 0.0,
                          max: totalMs > 0 ? totalMs : 1.0,
                          value: posMs,
                          onChangeStart: (val) {
                            setState(() {
                              _isSeeking = true;
                              _dragPosition = val;
                            });
                          },
                          onChanged: (val) {
                            setState(() {
                              _dragPosition = val;
                            });
                          },
                          onChangeEnd: (val) {
                            _isSeeking = false;
                            widget.audioPlayer
                                .seek(Duration(milliseconds: val.round()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_isSeeking
                                  ? Duration(milliseconds: _dragPosition.round())
                                  : position),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              '-${_formatDuration(duration > position ? duration - position : Duration.zero)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              // 4. Playback Controls Row (Speed, Rewind 10, Play/Pause FAB, Forward 30, Share)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Speed Pill
                  InkWell(
                    onTap: _cycleSpeed,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentSpeed}x',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Skip Backward 10s
                  IconButton(
                    iconSize: controlIconSize,
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      final newPos = widget.audioPlayer.position -
                          const Duration(seconds: 10);
                      widget.audioPlayer.seek(
                          newPos < Duration.zero ? Duration.zero : newPos);
                    },
                    tooltip: 'Rewind 10 seconds',
                  ),

                  const SizedBox(width: 8),

                  // Play / Pause Large FAB
                  StreamBuilder<PlayerState>(
                    stream: widget.audioPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final isPlaying = state?.playing ?? false;
                      final isBuffering =
                          state?.processingState == ProcessingState.buffering;

                      return Container(
                        width: fabSize,
                        height: fabSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.85)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: fabIconSize,
                          color: colorScheme.onPrimary,
                          icon: isBuffering
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded),
                          onPressed: () {
                            if (isPlaying) {
                              widget.audioPlayer.pause();
                            } else {
                              widget.audioPlayer.play();
                            }
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  // Skip Forward 30s
                  IconButton(
                    iconSize: controlIconSize,
                    icon: const Icon(Icons.forward_30_rounded),
                    onPressed: () {
                      final duration = widget.audioPlayer.duration ??
                          const Duration(hours: 1);
                      final newPos = widget.audioPlayer.position +
                          const Duration(seconds: 30);
                      widget.audioPlayer
                          .seek(newPos > duration ? duration : newPos);
                    },
                    tooltip: 'Forward 30 seconds',
                  ),

                  const SizedBox(width: 14),

                  // Share Episode
                  IconButton(
                    iconSize: 22,
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      PodcastShareHelper.shareEpisode(
                        context,
                        episode: widget.episodeData,
                        podcastTitle: widget.podcastTitle,
                      );
                    },
                    tooltip: 'Share',
                  ),
                ],
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

          const SizedBox(height: 12),

          // Transcript List with Spotify-style live time synchronization
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      if (notification.dragDetails != null) {
                        _userScrollTimer?.cancel();
                        setState(() {
                          _userIsScrollingTranscript = true;
                        });
                      }
                    } else if (notification is ScrollEndNotification) {
                      if (notification.dragDetails != null || _userIsScrollingTranscript) {
                        _userScrollTimer?.cancel();
                        _userScrollTimer = Timer(const Duration(milliseconds: 1800), () {
                          if (mounted) {
                            setState(() {
                              _userIsScrollingTranscript = false;
                            });
                            _scrollToActiveIndex(_activeTranscriptIndex, animate: true);
                          }
                        });
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
                      final isActive = _transcriptQuery.isEmpty &&
                          index == _activeTranscriptIndex;
                      final itemKey = _transcriptItemKeys.putIfAbsent(index, () => GlobalKey());

                      return KeyedSubtree(
                        key: itemKey,
                        child: InkWell(
                    onTap: () {
                      // Tap timestamp or line to seek instantly
                      widget.audioPlayer
                          .seek(Duration(seconds: item.seconds));
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
                              Text(
                                item.speaker,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? colorScheme.primary
                                      : null,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
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
                              const Spacer(),
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
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
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
                  Row(
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
                      const Spacer(),
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
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _saveUserNote(_noteController.text),
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

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        ));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.6,
            color: colorScheme.onSurface,
          ),
        ));
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
      ));
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

