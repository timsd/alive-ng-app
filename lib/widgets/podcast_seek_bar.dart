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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<Duration>(
      stream: widget.audioPlayer.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final duration = widget.audioPlayer.duration ??
            Duration(
              minutes: int.tryParse(
                    widget.fallbackDurationString.split(':').first,
                  ) ??
                  15,
            );

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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
  }
}
