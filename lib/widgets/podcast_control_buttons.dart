import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PodcastControlButtons extends StatelessWidget {
  final AudioPlayer audioPlayer;
  final double currentSpeed;
  final VoidCallback onCycleSpeed;
  final VoidCallback onShare;
  final double fabSize;
  final double fabIconSize;
  final double controlIconSize;

  const PodcastControlButtons({
    super.key,
    required this.audioPlayer,
    required this.currentSpeed,
    required this.onCycleSpeed,
    required this.onShare,
    this.fabSize = 64.0,
    this.fabIconSize = 36.0,
    this.controlIconSize = 34.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Speed Pill
        InkWell(
          onTap: onCycleSpeed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${currentSpeed}x',
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
            final newPos = audioPlayer.position - const Duration(seconds: 10);
            audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
          },
          tooltip: 'Rewind 10 seconds',
        ),

        const SizedBox(width: 8),

        // Play / Pause Large FAB
        StreamBuilder<PlayerState>(
          stream: audioPlayer.playerStateStream,
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
                    colorScheme.primary.withValues(alpha: 0.85),
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
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                onPressed: () {
                  if (isPlaying) {
                    audioPlayer.pause();
                  } else {
                    audioPlayer.play();
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
            final duration = audioPlayer.duration ?? const Duration(hours: 1);
            final newPos = audioPlayer.position + const Duration(seconds: 30);
            audioPlayer.seek(newPos > duration ? duration : newPos);
          },
          tooltip: 'Forward 30 seconds',
        ),

        const SizedBox(width: 14),

        // Share Episode
        IconButton(
          iconSize: 22,
          icon: const Icon(Icons.share_outlined),
          onPressed: onShare,
          tooltip: 'Share',
        ),
      ],
    );
  }
}
