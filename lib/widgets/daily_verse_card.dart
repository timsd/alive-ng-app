import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../services/tts_service.dart';
import '../utils/text_formatter.dart';
import 'bible_reference_widget.dart';
import 'shimmer_loading.dart';

/// Agency-grade Daily Verse Card ($50K+ Design)
/// Displays scripture with refined editorial typography, ambient depth,
/// interactive text-to-speech, and instant sharing.
class DailyVerseCard extends ConsumerStatefulWidget {
  final DailyVerse? verse;
  final bool isLoading;

  const DailyVerseCard({
    super.key,
    this.verse,
    this.isLoading = false,
  });

  @override
  ConsumerState<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends ConsumerState<DailyVerseCard> {
  final TTSService _tts = TTSService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _tts.initialize();
  }

  Future<void> _speakVerse() async {
    if (widget.verse == null) return;

    setState(() {
      _isSpeaking = true;
    });

    try {
      final verseText = widget.verse!.verse;
      final fullText = '$verseText. ${widget.verse!.reference}';
      await _tts.speak(fullText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to play verse: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final translate = ref.watch(translationProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  // Header badge row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              TextFormatter.formatText('daily_verse').toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y').format(DateTime.now()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (widget.isLoading) ...[
                    const ShimmerLoading(height: 18, borderRadius: 6),
                    const SizedBox(height: 10),
                    const ShimmerLoading(height: 18, borderRadius: 6),
                    const SizedBox(height: 10),
                    const ShimmerLoading(height: 18, width: 200, borderRadius: 6),
                    const SizedBox(height: 20),
                    const ShimmerLoading(height: 16, width: 140, borderRadius: 6),
                  ] else if (widget.verse != null) ...[
                    // Scripture quote
                    Text(
                      '"${widget.verse!.verse}"',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Actions toolbar + Reference
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: BibleReferenceWidget(
                            text: widget.verse!.reference,
                            preferredVersion: widget.verse?.translation,
                            textStyle: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // TTS Audio Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isSpeaking ? _stopSpeaking : _speakVerse,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isSpeaking
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.primary
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isSpeaking
                                            ? Icons.stop_rounded
                                            : Icons.volume_up_rounded,
                                        size: 16,
                                        color: _isSpeaking
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isSpeaking
                                            ? translate('stop')
                                            : translate('listen'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _isSpeaking
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Share Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _shareVerse(context, widget.verse!),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.share_rounded,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        translate('share'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (widget.verse!.reflection != null &&
                        widget.verse!.reflection!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary
                              .withValues(alpha: isDark ? 0.1 : 0.06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TextFormatter.formatText('reflection'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.verse!.reflection!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              TextFormatter.formatText('failed_to_load_verse'),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _shareVerse(BuildContext context, DailyVerse verse) {
    const webAppUrl = 'https://app.alivenigeria.org/#/daily';
    final shareText =
        '"${verse.verse}"\n— ${verse.reference}\n\nRead more on the ALIVE Nigeria app:\n$webAppUrl';
    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Daily Bible Verse - ${verse.reference}',
      ),
    );
  }
}
