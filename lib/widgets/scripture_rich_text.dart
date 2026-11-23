import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'bible_reference_modal_sheet.dart';

/// Detects Bible scripture references in arbitrary text and turns them into
/// clickable spans that open [BibleReferenceModalSheet].
class ScriptureTextParser {
  ScriptureTextParser._();

  static const String _bookNamesPattern =
      r'(?:1|2|3|I|II|III)?\s*(?:'
      r'Genesis|Gen\.?|Exodus|Exod\.?|Exo\.?|Ex\.?|Leviticus|Lev\.?|Numbers|Num\.?|'
      r'Deuteronomy|Deut\.?|Joshua|Josh\.?|Judges|Judg\.?|Ruth|'
      r'Samuel|Sam\.?|Kings|Kgs\.?|Chronicles|Chron\.?|Chr\.?|'
      r'Ezra|Nehemiah|Neh\.?|Esther|Esth\.?|Job|'
      r'Psalms?|Psa\.?|Ps\.?|Proverbs|Prov\.?|Ecclesiastes|Eccl\.?|'
      r'Song\s+of\s+Solomon|Song|Isaiah|Isa\.?|Jeremiah|Jer\.?|'
      r'Lamentations|Lam\.?|Ezekiel|Ezek\.?|Eze\.?|Daniel|Dan\.?|Hosea|Hos\.?|'
      r'Joel|Amos|Obadiah|Obad\.?|Jonah|Micah|Mic\.?|Nahum|Nah\.?|'
      r'Habakkuk|Hab\.?|Zephaniah|Zeph\.?|Haggai|Hag\.?|Zechariah|Zech\.?|'
      r'Malachi|Mal\.?|'
      r'Matthew|Matt\.?|Mt\.?|Mark|Mk\.?|Luke|Lk\.?|John|Jn\.?|Acts|'
      r'Romans|Rom\.?|Corinthians|Cor\.?|Galatians|Gal\.?|Ephesians|Eph\.?|'
      r'Philippians|Phil\.?|Colossians|Col\.?|Thessalonians|Thess\.?|'
      r'Timothy|Tim\.?|Titus|Philemon|Phlm\.?|Hebrews|Heb\.?|James|Jas\.?|'
      r'Peter|Pet\.?|Jude|Revelation|Rev\.?'
      r')';

  static final RegExp referenceRegex = RegExp(
    r'\b(' +
        _bookNamesPattern +
        r')\s+\d{1,3}:\d{1,3}(?:\s*[-–—]\s*\d{1,3}(?::\d{1,3})?|\s*,\s*\d{1,3})*',
    caseSensitive: false,
  );

  static bool hasReferences(String text) => referenceRegex.hasMatch(text);

  /// Builds [TextSpan] children with clickable Bible references.
  static List<TextSpan> buildSpans(
    BuildContext context,
    String text, {
    TextStyle? baseStyle,
    Color? referenceColor,
  }) {
    final matches = referenceRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final accentColor = referenceColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF3BA42)
            : Theme.of(context).colorScheme.primary);

    final spans = <TextSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final refText = match.group(0)!.trim();
      spans.add(
        TextSpan(
          text: refText,
          style: (baseStyle ?? const TextStyle()).copyWith(
            color: accentColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: accentColor.withValues(alpha: 0.7),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final normalized = refText
                  .replaceFirst(
                      RegExp(r'^Eze\.?(?=\s)', caseSensitive: false),
                      'Ezekiel')
                  .replaceFirst(
                      RegExp(r'^Exo\.?(?=\s)', caseSensitive: false), 'Exodus')
                  .replaceFirst(
                      RegExp(r'^Psa\.?(?=\s)', caseSensitive: false), 'Psalms');
              BibleReferenceModalSheet.show(
                context,
                reference: normalized,
              );
            },
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    return spans;
  }
}

/// Renders [text] with any inline Bible references automatically underlined
/// and tappable to open [BibleReferenceModalSheet].
class ScriptureRichText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? referenceColor;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final bool selectable;

  const ScriptureRichText(
    this.text, {
    super.key,
    this.style,
    this.referenceColor,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final spans = ScriptureTextParser.buildSpans(
      context,
      text,
      baseStyle: effectiveStyle,
      referenceColor: referenceColor,
    );

    if (selectable) {
      return SelectableText.rich(
        TextSpan(style: effectiveStyle, children: spans),
        textAlign: textAlign,
        maxLines: maxLines,
      );
    }

    return Text.rich(
      TextSpan(style: effectiveStyle, children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
