import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../data/bible_verses.dart';
import '../screens/bible/bible_reader_screen.dart';

class BibleReferenceWidget extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final TextAlign? textAlign;

  const BibleReferenceWidget({
    super.key,
    required this.text,
    this.textStyle,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _parseTextWithReferences(context, text);
    
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(
        style: textStyle ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseTextWithReferences(BuildContext context, String text) {
    final List<TextSpan> spans = [];
    final RegExp bibleRefPattern = RegExp(
      r'\b(Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|1\s*Samuel|2\s*Samuel|1\s*Kings|2\s*Kings|1\s*Chronicles|2\s*Chronicles|Ezra|Nehemiah|Esther|Job|Psalms?|Proverbs|Ecclesiastes|Song\s*of\s*Songs?|Isaiah|Jeremiah|Lamentations|Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|Luke|John|Acts|Romans|1\s*Corinthians|2\s*Corinthians|Galatians|Ephesians|Philippians|Colossians|1\s*Thessalonians|2\s*Thessalonians|1\s*Timothy|2\s*Timothy|Titus|Philemon|Hebrews|James|1\s*Peter|2\s*Peter|1\s*John|2\s*John|3\s*John|Jude|Revelation)\s+\d+:\d+(?:-\d+)?(?:\s*,\s*\d+(?:-\d+)?)*',
      caseSensitive: false,
    );

    int lastEnd = 0;
    for (final match in bibleRefPattern.allMatches(text)) {
      // Add text before the reference
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
        ));
      }

      // Add the clickable Bible reference
      final reference = match.group(0)!;
      spans.add(TextSpan(
        text: reference,
        style: TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _openBibleReference(context, reference),
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
      ));
    }

    return spans;
  }

  void _openBibleReference(BuildContext context, String reference) {
    // First try to find the verse in our local data
    final verse = _findVerseInLocalData(reference);
    
    if (verse != null) {
      _showVerseDialog(context, verse);
    } else {
      // Navigate to Bible reader screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BibleReaderScreen(initialReference: reference),
        ),
      );
    }
  }

  BibleVerse? _findVerseInLocalData(String reference) {
    // Clean up the reference for comparison
    final cleanRef = reference.trim();
    
    // Search in daily verses
    for (final verse in dailyVerses) {
      if (verse.reference.toLowerCase() == cleanRef.toLowerCase()) {
        return verse;
      }
    }
    
    return null;
  }

  void _showVerseDialog(BuildContext context, BibleVerse verse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          verse.reference,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (verse.text.containsKey('KJV')) ..[
                const Text(
                  'King James Version (KJV):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  verse.text['KJV']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (verse.text.containsKey('NKJV')) ..[
                const Text(
                  'New King James Version (NKJV):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  verse.text['NKJV']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (verse.text.containsKey('NIV')) ..[
                const Text(
                  'New International Version (NIV):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  verse.text['NIV']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BibleReaderScreen(
                    initialReference: verse.reference,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Read More',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to easily convert regular text widgets to Bible reference widgets
Widget buildTextWithBibleReferences({
  required String text,
  TextStyle? style,
  TextAlign? textAlign,
}) {
  return BibleReferenceWidget(
    text: text,
    textStyle: style,
    textAlign: textAlign,
  );
}