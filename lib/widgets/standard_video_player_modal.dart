import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_image.dart';

/// A modern, standard video player modal featuring:
/// - 16:9 video frame with clean dark cinematic backdrop
/// - Interactive controls: Play/Pause, Rewind 10s, Fast-Forward 10s
/// - Interactive seek bar (timeline slider) with current position and total duration
/// - Playback speed selector (0.75x, 1.0x, 1.25x, 1.5x, 2.0x)
/// - Fullscreen toggle and external video launcher (for YouTube/mp4 links)
/// - Title, presenter, category metadata, and study notes
class StandardVideoPlayerModal extends StatefulWidget {
  final Map<String, dynamic> videoData;

  const StandardVideoPlayerModal({
    super.key,
    required this.videoData,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> videoData,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StandardVideoPlayerModal(videoData: videoData),
    );
  }

  @override
  State<StandardVideoPlayerModal> createState() =>
      _StandardVideoPlayerModalState();
}

class _StandardVideoPlayerModalState extends State<StandardVideoPlayerModal> {
  bool _isPlaying = true;
  bool _isVertical = false;
  double _currentSeconds = 0.0;
  double _totalSeconds = 600.0; // Default 10 minutes
  double _playbackSpeed = 1.0;
  bool _showControls = true;
  Timer? _playbackTimer;
  Timer? _hideControlsTimer;

  final List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    final rawRatio =
        widget.videoData['aspectRatio']?.toString().toLowerCase() ?? '';
    final isExplicitVertical = widget.videoData['isVertical'] == true ||
        rawRatio.contains('9:16') ||
        rawRatio.contains('9/16') ||
        rawRatio.contains('portrait');
    _isVertical = isExplicitVertical;
    _parseDuration();
    _startPlayback();
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _parseDuration() {
    final rawDuration = widget.videoData['duration']?.toString() ?? '';
    if (rawDuration.contains(':')) {
      final parts = rawDuration.split(':');
      if (parts.length == 2) {
        final m = double.tryParse(parts[0]) ?? 10.0;
        final s = double.tryParse(parts[1]) ?? 0.0;
        _totalSeconds = (m * 60) + s;
      } else if (parts.length == 3) {
        final h = double.tryParse(parts[0]) ?? 0.0;
        final m = double.tryParse(parts[1]) ?? 10.0;
        final s = double.tryParse(parts[2]) ?? 0.0;
        _totalSeconds = (h * 3600) + (m * 60) + s;
      }
    } else {
      final numMatch = RegExp(r'(\d+)').firstMatch(rawDuration);
      if (numMatch != null) {
        _totalSeconds = (double.tryParse(numMatch.group(1)!) ?? 10.0) * 60;
      }
    }
    if (_totalSeconds <= 0) _totalSeconds = 600.0;
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPlaying) return;
      setState(() {
        _currentSeconds += 1.0 * _playbackSpeed;
        if (_currentSeconds >= _totalSeconds) {
          _currentSeconds = _totalSeconds;
          _isPlaying = false;
          _showControls = true;
        }
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showControls = true;
    });
    _scheduleHideControls();
  }

  void _seekBy(double deltaSeconds) {
    setState(() {
      _currentSeconds =
          (_currentSeconds + deltaSeconds).clamp(0.0, _totalSeconds);
      _showControls = true;
    });
    _scheduleHideControls();
  }

  void _cycleSpeed() {
    final idx = _speeds.indexOf(_playbackSpeed);
    final nextIdx = (idx + 1) % _speeds.length;
    setState(() {
      _playbackSpeed = _speeds[nextIdx];
      _showControls = true;
    });
    _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  String _formatTime(double seconds) {
    final s = seconds.toInt();
    final m = s ~/ 60;
    final sec = s % 60;
    final h = m ~/ 60;
    final min = m % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String? _resolveVideoUrl() {
    final url = widget.videoData['videoUrl'] ??
        widget.videoData['video_url'] ??
        widget.videoData['url'] ??
        widget.videoData['link'];
    if (url is String && url.trim().isNotEmpty) return url.trim();
    return null;
  }

  Future<void> _launchExternalVideo() async {
    final url = _resolveVideoUrl();
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final title = widget.videoData['title']?.toString() ?? 'Bible Video';
    final author = widget.videoData['author']?.toString() ??
        widget.videoData['presenter']?.toString() ??
        'ALIVE Media';
    final category = widget.videoData['category']?.toString() ?? 'Bible Study';
    final thumbnailUrl = widget.videoData['thumbnailUrl']?.toString() ??
        widget.videoData['thumbnail_url']?.toString();
    final description = widget.videoData['description']?.toString() ??
        'Equipping believers across Nigeria with scripture-based video teachings, discipleship methods, and mission insights.';
    final externalUrl = _resolveVideoUrl();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Modal top drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top Title bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (externalUrl != null)
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        tooltip: 'Open in Fullscreen / Browser',
                        onPressed: _launchExternalVideo,
                      ),
                    // 16:9 Landscape vs 9:16 Portrait / Reels Toggle
                    IconButton(
                      icon: Icon(
                        _isVertical
                            ? Icons.stay_current_portrait_rounded
                            : Icons.stay_current_landscape_rounded,
                        size: 20,
                        color: _isVertical
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      tooltip: _isVertical
                          ? 'Switch to 16:9 Landscape'
                          : 'Switch to 9:16 Portrait / Reels',
                      onPressed: () {
                        setState(() {
                          _isVertical = !_isVertical;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      tooltip: 'Close Player',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Video Player Stage (16:9 or 9:16 Aspect Ratio)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height *
                          (_isVertical ? 0.60 : 0.40),
                    ),
                    child: AspectRatio(
                      aspectRatio: _isVertical ? (9 / 16) : (16 / 9),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.black,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showControls = !_showControls;
                          });
                          if (_showControls) _scheduleHideControls();
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail / Poster Backdrop
                            if (thumbnailUrl != null &&
                                thumbnailUrl.trim().isNotEmpty)
                              CustomImage(
                                imageUrl: thumbnailUrl,
                                fit: BoxFit.cover,
                              )
                            else
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF1E293B),
                                      Color(0xFF0F172A),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.video_library_rounded,
                                    size: 64,
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                              ),

                            // Dark overlay when paused or showing controls
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              color: (_showControls || !_isPlaying)
                                  ? Colors.black.withValues(alpha: 0.55)
                                  : Colors.transparent,
                            ),

                            // Center Play / Pause Indicator
                            if (_showControls || !_isPlaying)
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Rewind 10s
                                    IconButton(
                                      iconSize: 36,
                                      icon: const Icon(
                                        Icons.replay_10_rounded,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Rewind 10 seconds',
                                      onPressed: () => _seekBy(-10),
                                    ),
                                    const SizedBox(width: 20),
                                    // Big Play / Pause
                                    GestureDetector(
                                      onTap: _togglePlayPause,
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 18,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 38,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // Fast Forward 10s
                                    IconButton(
                                      iconSize: 36,
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Forward 10 seconds',
                                      onPressed: () => _seekBy(10),
                                    ),
                                  ],
                                ),
                              ),

                            // Bottom Standard Controls Bar
                            if (_showControls || !_isPlaying)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 18, 14, 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.9),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Progress Scrubber Slider
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3.5,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6.5),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                  overlayRadius: 14),
                                          activeTrackColor: colorScheme.primary,
                                          inactiveTrackColor: Colors.white30,
                                          thumbColor: colorScheme.primary,
                                        ),
                                        child: Slider(
                                          value: _currentSeconds.clamp(
                                              0.0, _totalSeconds),
                                          min: 0.0,
                                          max: _totalSeconds,
                                          onChanged: (val) {
                                            setState(() {
                                              _currentSeconds = val;
                                            });
                                          },
                                        ),
                                      ),

                                      // Time display & quick toggles
                                      Row(
                                        children: [
                                          Text(
                                            '${_formatTime(_currentSeconds)} / ${_formatTime(_totalSeconds)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          // Speed button
                                          InkWell(
                                            onTap: _cycleSpeed,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white24,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${_playbackSpeed}x',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Fullscreen external launcher
                                          if (externalUrl != null)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.fullscreen_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              tooltip: 'Fullscreen',
                                              onPressed: _launchExternalVideo,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

              // Scrollable Details & Study Notes
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Presented by $author',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Text(
                      'About this video',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _togglePlayPause,
                            icon: Icon(_isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                            label: Text(_isPlaying ? 'Pause' : 'Play'),
                          ),
                        ),
                        if (externalUrl != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _launchExternalVideo,
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 18),
                              label: const Text('Open Stream'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

