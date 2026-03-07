import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../services/tts_service.dart';
import '../utils/text_formatter.dart';
import '../utils/layout_fix_utils.dart';
import 'bible_reference_widget.dart';

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
    final translate = ref.watch(translationProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LayoutFixUtils.responsiveIcon(
                      Icons.auto_stories,
                      context: context,
                      baseSize: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutFixUtils.responsiveText(
                          TextFormatter.formatText('daily_verse'),
                          context: context,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        LayoutFixUtils.responsiveText(
                          DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                          context: context,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (widget.verse != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutFixUtils.responsiveText(
                    '"${widget.verse!.verse}"',
                    context: context,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: BibleReferenceWidget(
                          text: '— ${widget.verse!.reference}',
                          textStyle: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed:
                                  _isSpeaking ? _stopSpeaking : _speakVerse,
                              icon: LayoutFixUtils.responsiveIcon(
                                _isSpeaking ? Icons.stop : Icons.volume_up,
                                context: context,
                                baseSize: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              tooltip: _isSpeaking
                                  ? translate('stop')
                                  : translate('listen'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed: () =>
                                  _shareVerse(context, widget.verse!),
                              icon: LayoutFixUtils.responsiveIcon(
                                Icons.share,
                                context: context,
                                baseSize: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              tooltip: translate('share'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: LayoutFixUtils.responsiveText(
                  "Today, let God's Word guide your heart and mind. ALIVE Nigeria encourages you to meditate on His promises and find strength for your daily journey.",
                  context: context,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                ),
              ),
              if (widget.verse!.reflection != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutFixUtils.responsiveText(
                        TextFormatter.formatText('reflection'),
                        context: context,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      LayoutFixUtils.responsiveText(
                        widget.verse!.reflection!,
                        context: context,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    LayoutFixUtils.responsiveIcon(
                      Icons.error_outline,
                      context: context,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutFixUtils.responsiveText(
                        TextFormatter.formatText('failed_to_load_verse'),
                        context: context,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _shareVerse(BuildContext context, DailyVerse verse) {
    final shareText =
        '"${verse.verse}" - ${verse.reference}\n\n> Shared from ALIVE App';
    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Daily Bible Verse - ${verse.reference}',
      ),
    );
  }
}
