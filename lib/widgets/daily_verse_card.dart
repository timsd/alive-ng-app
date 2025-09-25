import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../services/tts_service.dart';
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
      debugPrint('TTS Error: $e');
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                    child: Icon(
                      Icons.auto_stories,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate('daily_verse'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          'Saturday, September 13, 2025',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                  Text(
                    '"${widget.verse!.verse}"',
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
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed: _isSpeaking ? _stopSpeaking : _speakVerse,
                              icon: Icon(
                                _isSpeaking ? Icons.stop : Icons.volume_up,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              tooltip: _isSpeaking ? translate('stop') : translate('listen'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed: () => _shareVerse(context, widget.verse!),
                              icon: Icon(
                                Icons.share,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
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
              if (widget.verse!.reflection != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('reflection'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.verse!.reflection!,
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
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translate('failed_to_load_verse'),
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
    final shareText = '"${verse.verse}" - ${verse.reference}\n\nShared from ALIVE App';
    Share.share(
      shareText,
      subject: 'Daily Bible Verse - ${verse.reference}',
    );
  }
}
