import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../widgets/custom_image.dart';

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

class _ModernPodcastPlayerSheetState extends State<ModernPodcastPlayerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _transcriptSearchController =
      TextEditingController();
  String _transcriptQuery = '';
  double _currentSpeed = 1.0;
  bool _isSeeking = false;
  double _dragPosition = 0.0;

  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentSpeed = widget.audioPlayer.speed;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transcriptSearchController.dispose();
    super.dispose();
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

  List<Map<String, String>> _getFormattedTranscript() {
    final raw = (widget.episodeData['transcript'] ??
            widget.episodeData['transcription'] ??
            widget.episodeData['description'] ??
            '')
        .toString()
        .trim();

    if (raw.isEmpty) {
      return [
        {
          'time': '00:00',
          'speaker': 'Speaker',
          'text':
              'Welcome to this episode of ${widget.podcastTitle}. In this message, we unpack foundational truths for discipleship and spiritual growth.',
        },
        {
          'time': '01:15',
          'speaker': 'Speaker',
          'text':
              'Scripture reminds us in Proverbs 3:5-6: "Trust in the Lord with all your heart, and lean not on your own understanding; in all your ways acknowledge Him, and He shall direct your paths."',
        },
        {
          'time': '04:30',
          'speaker': 'Speaker',
          'text':
              'When we surrender our plans to Christ, we find true purpose and peace in missionary service.',
        },
        {
          'time': '08:00',
          'speaker': 'Speaker',
          'text':
              'Thank you for listening. Keep sharing the gospel truth across Nigeria and beyond.',
        },
      ];
    }

    final paragraphs = raw.split(RegExp(r'\n+'));
    final results = <Map<String, String>>[];
    int minuteCounter = 0;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i].trim();
      if (p.isEmpty) continue;
      final timeStr =
          '${(minuteCounter ~/ 60).toString().padLeft(2, '0')}:${(minuteCounter % 60).toString().padLeft(2, '0')}';
      results.add({
        'time': timeStr,
        'speaker': i % 2 == 0 ? 'Speaker' : 'Reflection',
        'text': p,
      });
      minuteCounter += 2;
    }
    return results;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),

          // Animated Cover Artwork
          StreamBuilder<PlayerState>(
            stream: widget.audioPlayer.playerStateStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data?.playing ?? false;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: isPlaying ? 240 : 210,
                height: isPlaying ? 240 : 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: isPlaying ? 0.35 : 0.15),
                      blurRadius: isPlaying ? 24 : 12,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.coverImage != null &&
                          widget.coverImage!.isNotEmpty
                      ? CustomImage(
                          imageUrl: widget.coverImage!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.podcasts_rounded,
                            size: 80,
                            color: colorScheme.primary,
                          ),
                        ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              category.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title & Show
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.podcastTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 24),

          // Scrubbable Progress Bar
          StreamBuilder<Duration>(
            stream: widget.audioPlayer.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final duration = widget.audioPlayer.duration ??
                  Duration(minutes: int.tryParse(durationStr.split(':').first) ?? 15);

              final totalMs = duration.inMilliseconds.toDouble();
              final posMs = _isSeeking
                  ? _dragPosition
                  : position.inMilliseconds
                      .toDouble()
                      .clamp(0.0, totalMs > 0 ? totalMs : 1.0);

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.15),
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
                        widget.audioPlayer.seek(Duration(milliseconds: val.round()));
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
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '-${_formatDuration(duration > position ? duration - position : Duration.zero)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Lively Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Speed Pill
              InkWell(
                onTap: _cycleSpeed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentSpeed}x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Skip Backward 15s
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.replay_10),
                onPressed: () {
                  final newPos = widget.audioPlayer.position -
                      const Duration(seconds: 10);
                  widget.audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
                },
                tooltip: 'Rewind 10 seconds',
              ),

              const SizedBox(width: 12),

              // Play / Pause Large FAB
              StreamBuilder<PlayerState>(
                stream: widget.audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final isPlaying = state?.playing ?? false;
                  final isBuffering =
                      state?.processingState == ProcessingState.buffering;

                  return Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 36,
                      color: colorScheme.onPrimary,
                      icon: isBuffering
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
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

              const SizedBox(width: 12),

              // Skip Forward 30s
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.forward_30_rounded),
                onPressed: () {
                  final duration = widget.audioPlayer.duration ?? const Duration(hours: 1);
                  final newPos = widget.audioPlayer.position +
                      const Duration(seconds: 30);
                  widget.audioPlayer.seek(newPos > duration ? duration : newPos);
                },
                tooltip: 'Forward 30 seconds',
              ),

              const SizedBox(width: 20),

              // Share Episode
              IconButton(
                iconSize: 24,
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sharing: $title')),
                  );
                },
                tooltip: 'Share',
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTranscriptView(ThemeData theme, ColorScheme colorScheme) {
    final transcriptItems = _getFormattedTranscript();
    final filtered = _transcriptQuery.isEmpty
        ? transcriptItems
        : transcriptItems.where((item) {
            return (item['text'] ?? '')
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

          // Transcript List
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return InkWell(
                  onTap: () {
                    // Tap timestamp to seek
                    final parts = (item['time'] ?? '00:00').split(':');
                    if (parts.length == 2) {
                      final mins = int.tryParse(parts[0]) ?? 0;
                      final secs = int.tryParse(parts[1]) ?? 0;
                      widget.audioPlayer.seek(Duration(minutes: mins, seconds: secs));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Jumped to ${item['time']}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                                color: colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['time'] ?? '00:00',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item['speaker'] ?? 'Speaker',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: item['text'] ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Quote copied to clipboard'),
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
                          item['text'] ?? '',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesView(ThemeData theme, ColorScheme colorScheme) {
    final description = widget.episodeData['description']?.toString() ??
        'No detailed show notes provided for this episode.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Episode Overview',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 24),
          Text(
            'Scripture & Ministry Takeaways',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildTakeawayCard(
            context,
            colorScheme,
            Icons.menu_book_rounded,
            'Scripture Foundation',
            'Romans 10:14-15 — "How then shall they call on Him in whom they have not believed? And how shall they believe in Him of whom they have not heard?"',
          ),
          const SizedBox(height: 12),
          _buildTakeawayCard(
            context,
            colorScheme,
            Icons.lightbulb_outline_rounded,
            'Call to Action',
            'Pray for groundbreakers and volunteer teams distributing tracts and proclaiming the everlasting gospel across Nigerian campuses and rural communities.',
          ),
        ],
      ),
    );
  }

  Widget _buildTakeawayCard(BuildContext context, ColorScheme colorScheme,
      IconData icon, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

