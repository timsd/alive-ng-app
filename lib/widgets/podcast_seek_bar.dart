import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PodcastSeekBar extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String fallbackDurationString;

  const PodcastSeekBar({
    super.key,
    required this.audioPlayer,
    required this.fallbackDurationString,
  });

  @override
  State<PodcastSeekBar> createState() => _PodcastSeekBarState();
}

class _PodcastSeekBarState extends State<PodcastSeekBar> {
  bool _isSeeking = false;
  double _dragPosition = 0.0;

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

  Duration _parseFallbackDuration(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.isEmpty) return const Duration(minutes: 15);
    final parts = clean.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0].trim()) ?? 0;
      final m = int.tryParse(parts[1].trim()) ?? 0;
      final s = int.tryParse(parts[2].split('.').first.trim()) ?? 0;
      final total = (h * 3600) + (m * 60) + s;
      if (total > 0) return Duration(seconds: total);
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0].trim()) ?? 0;
      final s = int.tryParse(parts[1].split('.').first.trim()) ?? 0;
      final total = (m * 60) + s;
      if (total > 0) return Duration(seconds: total);
    }
    // Natural formats like "48 min", "1h 15m", "1 hr 20 mins", "90 sec"
    final hMatch = RegExp(r'(\d+)\s*(?:h|hr|hrs|hour|hours)\b').firstMatch(clean);
    final mMatch = RegExp(r'(\d+)\s*(?:m|min|mins|minute|minutes)\b').firstMatch(clean);
    final sMatch = RegExp(r'(\d+)\s*(?:s|sec|secs|second|seconds)\b').firstMatch(clean);
    if (hMatch != null || mMatch != null || sMatch != null) {
      final h = int.tryParse(hMatch?.group(1) ?? '0') ?? 0;
      final m = int.tryParse(mMatch?.group(1) ?? '0') ?? 0;
      final s = int.tryParse(sMatch?.group(1) ?? '0') ?? 0;
      final total = (h * 3600) + (m * 60) + s;
      if (total > 0) return Duration(seconds: total);
    }
    final bareMinutes = int.tryParse(clean);
    if (bareMinutes != null && bareMinutes > 0) {
      return Duration(minutes: bareMinutes);
    }
    return const Duration(minutes: 15);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<Duration?>(
      stream: widget.audioPlayer.durationStream,
      builder: (context, durationSnapshot) {
        return StreamBuilder<Duration>(
          stream: widget.audioPlayer.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? widget.audioPlayer.position;
            final duration = durationSnapshot.data ??
                widget.audioPlayer.duration ??
                _parseFallbackDuration(widget.fallbackDurationString);

            final totalMs = duration.inMilliseconds.toDouble();
            final posMs = _isSeeking
                ? _dragPosition.clamp(0.0, totalMs > 0 ? totalMs : 1.0)
                : position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, totalMs > 0 ? totalMs : 1.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                      final maxSeekMs = totalMs > 1500
                          ? (totalMs - 1500).round()
                          : totalMs.round();
                      final targetMs = val.round().clamp(0, maxSeekMs);
                      setState(() {
                        _isSeeking = false;
                      });
                      widget.audioPlayer
                          .seek(Duration(milliseconds: targetMs));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(
                          _isSeeking
                              ? Duration(milliseconds: _dragPosition.round())
                              : position,
                        ),
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
        );
      },
    );
  }
}
