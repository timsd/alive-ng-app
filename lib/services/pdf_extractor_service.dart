import 'dart:convert';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';

/// Curated ALIVE Nigeria colour palette definition used by the PDF extractor
/// and the Interactive Lesson Reader to give each lesson and section dynamic,
/// harmonious brand colour combinations.
class LessonColorPalette {
  final String id;
  final String name;
  final int primaryHex;
  final int darkGradientStartHex;
  final int darkGradientEndHex;
  final int accentHex;
  final int lightTintHex;
  final int darkTintHex;

  const LessonColorPalette({
    required this.id,
    required this.name,
    required this.primaryHex,
    required this.darkGradientStartHex,
    required this.darkGradientEndHex,
    required this.accentHex,
    required this.lightTintHex,
    required this.darkTintHex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryHex': '0x${primaryHex.toRadixString(16).toUpperCase()}',
        'darkGradientStartHex':
            '0x${darkGradientStartHex.toRadixString(16).toUpperCase()}',
        'darkGradientEndHex':
            '0x${darkGradientEndHex.toRadixString(16).toUpperCase()}',
        'accentHex': '0x${accentHex.toRadixString(16).toUpperCase()}',
        'lightTintHex': '0x${lightTintHex.toRadixString(16).toUpperCase()}',
        'darkTintHex': '0x${darkTintHex.toRadixString(16).toUpperCase()}',
      };

  static const List<LessonColorPalette> brandPalettes = [
    LessonColorPalette(
      id: 'emerald_forest',
      name: 'Emerald Forest',
      primaryHex: 0xFF166534,
      darkGradientStartHex: 0xFF14532D,
      darkGradientEndHex: 0xFF064E3B,
      accentHex: 0xFFF59E0B,
      lightTintHex: 0xFFF0FDF4,
      darkTintHex: 0xFF14241B,
    ),
    LessonColorPalette(
      id: 'royal_sapphire',
      name: 'Royal Sapphire',
      primaryHex: 0xFF233E5F,
      darkGradientStartHex: 0xFF1E3A8A,
      darkGradientEndHex: 0xFF172554,
      accentHex: 0xFFE5B94D,
      lightTintHex: 0xFFEFF6FF,
      darkTintHex: 0xFF131E33,
    ),
    LessonColorPalette(
      id: 'divine_gold',
      name: 'Divine Gold & Bronze',
      primaryHex: 0xFFB45309,
      darkGradientStartHex: 0xFF78350F,
      darkGradientEndHex: 0xFF451A03,
      accentHex: 0xFF10B981,
      lightTintHex: 0xFFFFFBEB,
      darkTintHex: 0xFF261C10,
    ),
    LessonColorPalette(
      id: 'teal_covenant',
      name: 'Teal Covenant',
      primaryHex: 0xFF0F766E,
      darkGradientStartHex: 0xFF115E59,
      darkGradientEndHex: 0xFF134E4A,
      accentHex: 0xFFFBBF24,
      lightTintHex: 0xFFF0FDFA,
      darkTintHex: 0xFF112625,
    ),
    LessonColorPalette(
      id: 'crimson_grace',
      name: 'Crimson Grace',
      primaryHex: 0xFF9F1239,
      darkGradientStartHex: 0xFF881337,
      darkGradientEndHex: 0xFF4C0519,
      accentHex: 0xFFF59E0B,
      lightTintHex: 0xFFFFF1F2,
      darkTintHex: 0xFF281118,
    ),
    LessonColorPalette(
      id: 'indigo_prophecy',
      name: 'Indigo Prophecy',
      primaryHex: 0xFF3730A3,
      darkGradientStartHex: 0xFF312E81,
      darkGradientEndHex: 0xFF1E1B4B,
      accentHex: 0xFF34D399,
      lightTintHex: 0xFFEEF2FF,
      darkTintHex: 0xFF171630,
    ),
  ];

  static LessonColorPalette byId(String? id, {int fallbackIndex = 0}) {
    if (id != null && id.isNotEmpty) {
      for (final p in brandPalettes) {
        if (p.id == id) return p;
      }
    }
    return brandPalettes[fallbackIndex.abs() % brandPalettes.length];
  }
}

/// Structured interactive study section extracted from a Tract PDF or markdown body.
class ExtractedLessonSection {
  final int number;
  final String title;
  final String bodyText;
  final List<String> scriptureReferences;
  final List<Map<String, String>> verseQuotes;
  final List<Map<String, String>> steps;
  final String? highlightNote;
  final String? principleNote;
  final bool checkableSteps;
  final List<Map<String, String>> qaItems;
  final bool isQuestion;
  final bool hasInputTarget;
  final String reflectionPrompt;
  final String paletteId;

  const ExtractedLessonSection({
    required this.number,
    required this.title,
    required this.bodyText,
    required this.scriptureReferences,
    required this.verseQuotes,
    this.steps = const [],
    this.highlightNote,
    this.principleNote,
    this.checkableSteps = false,
    this.qaItems = const [],
    required this.isQuestion,
    required this.hasInputTarget,
    required this.reflectionPrompt,
    required this.paletteId,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'bodyText': bodyText,
        'scriptureReferences': scriptureReferences,
        'verseQuotes': verseQuotes,
        if (steps.isNotEmpty) 'steps': steps,
        if (highlightNote != null && highlightNote!.isNotEmpty)
          'highlightNote': highlightNote,
        if (principleNote != null && principleNote!.isNotEmpty)
          'principleNote': principleNote,
        if (checkableSteps) 'checkableSteps': true,
        if (qaItems.isNotEmpty) 'qaItems': qaItems,
        'isQuestion': isQuestion,
        'hasInputTarget': hasInputTarget,
        'reflectionPrompt': reflectionPrompt,
        'paletteId': paletteId,
      };

  factory ExtractedLessonSection.fromJson(Map<String, dynamic> json) {
    final rawRefs = json['scriptureReferences'];
    final rawQuotes = json['verseQuotes'];
    final rawSteps = json['steps'];
    final rawQa = json['qaItems'];
    return ExtractedLessonSection(
      number: (json['number'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Study Section',
      bodyText: json['bodyText']?.toString() ?? '',
      scriptureReferences: rawRefs is List
          ? rawRefs.map((e) => e.toString()).toList()
          : const [],
      verseQuotes: rawQuotes is List
          ? rawQuotes
              .whereType<Map>()
              .map((m) => {
                    'quote': m['quote']?.toString() ?? '',
                    'reference': m['reference']?.toString() ?? '',
                  })
              .toList()
          : const [],
      steps: rawSteps is List
          ? rawSteps
              .whereType<Map>()
              .map((m) => {
                    'title': m['title']?.toString() ?? '',
                    'text': m['text']?.toString() ?? '',
                  })
              .toList()
          : const [],
      highlightNote: json['highlightNote']?.toString(),
      principleNote: json['principleNote']?.toString(),
      checkableSteps: json['checkableSteps'] == true,
      qaItems: rawQa is List
          ? rawQa
              .whereType<Map>()
              .map((m) => {
                    'letter': m['letter']?.toString() ?? '',
                    'question': m['question']?.toString() ?? '',
                    'text': m['text']?.toString() ?? '',
                    'placeholder': m['placeholder']?.toString() ?? '',
                  })
              .toList()
          : const [],
      isQuestion: json['isQuestion'] == true,
      hasInputTarget: json['hasInputTarget'] ?? true,
      reflectionPrompt:
          json['reflectionPrompt']?.toString() ?? 'Your Personal Reflection',
      paletteId: json['paletteId']?.toString() ?? 'emerald_forest',
    );
  }
}

/// Structured result containing both WordPress-style organized tract content
/// and interactive study sections with dynamic brand colour palettes.
class ExtractedTractArticle {
  final String title;
  final String fullFormattedBody;
  final List<String> sections;
  final List<String> headings;
  final int totalWordCount;
  final String primaryPaletteId;
  final List<ExtractedLessonSection> interactiveSections;
  final String? introSummary;
  final String? heroVerse;
  final String? heroVerseRef;
  final String? estimatedReadTime;
  final List<String> extractionWarnings;

  const ExtractedTractArticle({
    required this.title,
    required this.fullFormattedBody,
    required this.sections,
    required this.headings,
    required this.totalWordCount,
    this.primaryPaletteId = 'emerald_forest',
    this.interactiveSections = const [],
    this.introSummary,
    this.heroVerse,
    this.heroVerseRef,
    this.estimatedReadTime,
    this.extractionWarnings = const [],
  });
}

/// Service responsible for extracting and structuring tract and lesson text from files (PDF, TXT)
/// locally without needing external APIs. Produces both clean WordPress-style markdown
/// and structured interactive study sections with scripture references, reflection inputs,
/// and dynamic ALIVE Nigeria colour palettes.
class PdfExtractorService {
  static final RegExp _scriptureRegex = RegExp(
    r'\b((?:[1-3]\s*)?(?:Genesis|Gen|Exodus|Exo|Ex|Leviticus|Lev|Numbers|Num|Deuteronomy|Deut|Joshua|Josh|Judges|Judg|Ruth|Samuel|Sam|Kings|Kgs|Chronicles|Chron|Chr|Ezra|Nehemiah|Neh|Esther|Est|Job|Psalms|Psalm|Ps|Proverbs|Prov|Ecclesiastes|Eccl|Song of Solomon|Song|Isaiah|Isa|Jeremiah|Jer|Lamentations|Lam|Ezekiel|Ezek|Daniel|Dan|Hosea|Hos|Joel|Amos|Obadiah|Obad|Jonah|Micah|Mic|Nahum|Nah|Habakkuk|Hab|Zephaniah|Zeph|Haggai|Hag|Zechariah|Zech|Malachi|Mal|Matthew|Matt|Mat|Mark|Mk|Luke|Lk|John|Jn|Acts|Romans|Rom|Corinthians|Cor|Galatians|Gal|Ephesians|Eph|Philippians|Phil|Colossians|Col|Thessalonians|Thess|Timothy|Tim|Titus|Tit|Philemon|Phlm|Hebrews|Heb|James|Jas|Peter|Pet|Jude|Revelation|Rev))\s+\d+:\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*\b',
    caseSensitive: false,
  );

  static final RegExp _questionHeadingRegex = RegExp(
    r'^(?:##\s*)?(?:(\d+)[\.\)\s]+|Question\s+(\d+)[\:\.\)\s]*|Q(\d+)[\:\.\)\s]*)(.+)$',
    caseSensitive: false,
  );

  /// Extracts raw text from the provided file bytes.
  /// Recognizes PDF and TXT formats based on the file extension.
  Future<String> extractTextFromBytes(Uint8List bytes, String fileName) async {
    final extension = fileName.split('.').last.toLowerCase();

    try {
      if (extension == 'pdf') {
        return await _extractFromPdf(bytes);
      } else if (extension == 'txt') {
        return _extractFromTxt(bytes);
      } else {
        throw Exception(
          'Unsupported file format: .$extension. Please upload a PDF or TXT file.',
        );
      }
    } catch (e) {
      debugPrint('Error extracting text: $e');
      throw Exception(
        'Failed to parse document. Ensure the file is valid and readable.',
      );
    }
  }

  /// Extracts and formats text into a structured, readable article and
  /// interactive study schema with dynamic colour palettes.
  Future<ExtractedTractArticle> extractAndFormatArticle(
    Uint8List bytes,
    String fileName, {
    String? fallbackTitle,
  }) async {
    final rawText = await extractTextFromBytes(bytes, fileName);
    return structureAsWordPressContent(
      rawText,
      fallbackTitle:
          fallbackTitle ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
  }

  /// Transforms raw unformatted PDF or markdown string into clean content
  /// plus structured interactive study sections and dynamic colour themes.
  ExtractedTractArticle structureAsWordPressContent(
    String rawText, {
    String? fallbackTitle,
    int? paletteSeed,
  }) {
    if (rawText.trim().isEmpty) {
      return ExtractedTractArticle(
        title: fallbackTitle ?? 'Untitled Tract',
        fullFormattedBody: '',
        sections: const [],
        headings: const [],
        totalWordCount: 0,
      );
    }

    // 1. Normalize line endings, typography, verse-range dots (10:2.4 -> 10:2-4), and hyphenated wraps
    var text = rawText.replaceAll(RegExp(r'\r\n?'), '\n');
    text = text.replaceAll('\u201C', '"').replaceAll('\u201D', '"');
    text = text.replaceAll('\u2018', "'").replaceAll('\u2019', "'");
    text = text.replaceAll(RegExp(r'(\w+)-\n(\w+)'), r'$1$2');
    text = text.replaceAllMapped(
      RegExp(r'(\d+:\d+)\.(\d+)'),
      (m) => '${m.group(1)}-${m.group(2)}',
    );

    final rawLines = text.split('\n');
    final cleanedParagraphs = <String>[];
    final headings = <String>[];
    String? detectedTitle = fallbackTitle;

    StringBuffer currentParagraph = StringBuffer();

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) {
        if (currentParagraph.isNotEmpty) {
          cleanedParagraphs.add(currentParagraph.toString().trim());
          currentParagraph = StringBuffer();
        }
        continue;
      }

      if (line.startsWith('# ') && detectedTitle == fallbackTitle) {
        detectedTitle = line.substring(2).trim();
        continue;
      }

      // Check if line is a heading or numbered study question
      final isMarkdownH2 = line.startsWith('## ');
      final isShort = line.length < 95;
      final isAllUpper = line.length > 3 &&
          line == line.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(line);
      final isHeaderPrefix = RegExp(
        r'^(Chapter|Section|Part|Lesson|Question\s+\d+|Q\d+|\d+[\.\)])\s+',
        caseSensitive: false,
      ).hasMatch(line);
      final isQuestionLine = isShort && line.endsWith('?');

      if (isMarkdownH2 ||
          (isShort && (isAllUpper || isHeaderPrefix || isQuestionLine))) {
        if (currentParagraph.isNotEmpty) {
          cleanedParagraphs.add(currentParagraph.toString().trim());
          currentParagraph = StringBuffer();
        }
        final cleanHeading =
            isMarkdownH2 ? line.substring(3).trim() : _cleanHeaderLine(line);
        if (detectedTitle == null || (detectedTitle == fallbackTitle && i < 2)) {
          if (!RegExp(r'^\d+[\.\)]').hasMatch(cleanHeading)) {
            detectedTitle = cleanHeading;
          }
        }
        final formattedHeading = '## $cleanHeading';
        cleanedParagraphs.add(formattedHeading);
        headings.add(cleanHeading);
      } else {
        if (currentParagraph.isNotEmpty) {
          currentParagraph.write('\n');
        }
        currentParagraph.write(line);
      }
    }

    if (currentParagraph.isNotEmpty) {
      cleanedParagraphs.add(currentParagraph.toString().trim());
    }

    // Split into readable multi-page sections (around 1800 characters per section)
    final sections = <String>[];
    StringBuffer sectionBuffer = StringBuffer();

    for (final p in cleanedParagraphs) {
      if (sectionBuffer.length + p.length > 1800 && sectionBuffer.isNotEmpty) {
        sections.add(sectionBuffer.toString().trim());
        sectionBuffer = StringBuffer();
      }
      if (sectionBuffer.isNotEmpty) {
        sectionBuffer.write('\n\n');
      }
      sectionBuffer.write(p);
    }
    if (sectionBuffer.isNotEmpty) {
      sections.add(sectionBuffer.toString().trim());
    }

    final fullBody = cleanedParagraphs.join('\n\n');
    final wordCount =
        fullBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final effectiveTitle = detectedTitle ?? fallbackTitle ?? 'Gospel Tract';
    final seed = paletteSeed ??
        effectiveTitle.codeUnits.fold<int>(0, (prev, elem) => prev + elem) +
            Random().nextInt(LessonColorPalette.brandPalettes.length);
    final primaryPalette =
        LessonColorPalette.brandPalettes[seed % LessonColorPalette.brandPalettes.length];

    final interactiveSections = parseInteractiveSections(
      fullBody,
      fallbackTitle: effectiveTitle,
      basePaletteIndex: seed,
    );

    // Extract hero verse & intro summary for auto-filling Admin forms
    String? heroVerse;
    String? heroVerseRef;
    String? introSummary;
    if (interactiveSections.isNotEmpty) {
      final firstWithQuote = interactiveSections
          .where((s) => s.verseQuotes.isNotEmpty)
          .firstOrNull;
      if (firstWithQuote != null) {
        heroVerse = firstWithQuote.verseQuotes.first['quote'];
        heroVerseRef = firstWithQuote.verseQuotes.first['reference'];
      }
      final introCandidates = cleanedParagraphs
          .where((p) =>
              !p.startsWith('## ') &&
              !p.startsWith('# ') &&
              p.length > 60)
          .toList();
      if (introCandidates.isNotEmpty) {
        introSummary = introCandidates.first.replaceAll('\n', ' ').trim();
      }
    }

    final estMinutes = max(10, 5 * ((wordCount / 130) / 5).round());
    final warnings = _lintSections(interactiveSections);

    return ExtractedTractArticle(
      title: effectiveTitle,
      fullFormattedBody: fullBody,
      sections: sections,
      headings: headings,
      totalWordCount: wordCount,
      primaryPaletteId: primaryPalette.id,
      interactiveSections: interactiveSections,
      introSummary: introSummary,
      heroVerse: heroVerse,
      heroVerseRef: heroVerseRef,
      estimatedReadTime: '$estMinutes–${estMinutes + 5} mins',
      extractionWarnings: warnings,
    );
  }

  /// Parses markdown or extracted tract text into structured interactive study sections,
  /// extracting scripture references, quoted verses, reflection prompts, and rotating
  /// brand colour palettes across sections.
  static List<ExtractedLessonSection> parseInteractiveSections(
    String content, {
    String? fallbackTitle,
    int basePaletteIndex = 0,
  }) {
    final normalized = content.replaceAll(RegExp(r'\r\n?'), '\n').trim();
    if (normalized.isEmpty) return const [];

    final lines = normalized.split('\n');
    final rawBlocks = <Map<String, dynamic>>[];

    String currentTitle = '';
    final currentBody = <String>[];

    void flushBlock() {
      final bodyStr = currentBody.join('\n').trim();
      if (currentTitle.isEmpty && bodyStr.isEmpty) return;
      rawBlocks.add({
        'title': currentTitle.isNotEmpty
            ? currentTitle
            : (fallbackTitle ?? 'Study Point ${rawBlocks.length + 1}'),
        'body': bodyStr,
      });
      currentTitle = '';
      currentBody.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('# ')) continue; // Skip top-level document title

      final isHeading = line.startsWith('## ') ||
          _questionHeadingRegex.hasMatch(line) ||
          (line.length < 90 && line.endsWith('?') && !line.startsWith('"'));

      if (isHeading) {
        if (currentTitle.isNotEmpty || currentBody.isNotEmpty) {
          flushBlock();
        }
        currentTitle = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
        currentTitle =
            currentTitle.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim();
      } else {
        currentBody.add(line);
      }
    }
    flushBlock();

    final result = <ExtractedLessonSection>[];
    final palettes = LessonColorPalette.brandPalettes;

    for (int i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i];
      final sectionNumber = i + 1;
      final title = block['title'] as String;
      final body = block['body'] as String;
      final combined = '$title\n$body';

      // Extract all unique Scripture references
      final refs = <String>{};
      for (final match in _scriptureRegex.allMatches(combined)) {
        final refStr = match.group(0)?.trim();
        if (refStr != null && refStr.isNotEmpty) {
          refs.add(refStr);
        }
      }

      // Extract quoted verses ("..." (Ref)) AND unquoted verse lines ending with a Scripture reference
      final verseQuotes = <Map<String, String>>[];
      final quotePattern = RegExp(
        r'"([^"]{10,360})"\s*(?:[—–-]\s*)?(?:\(([^)]+)\))?',
      );
      final unquotedVersePattern = RegExp(
        r'^(.{12,360}?)\s*(?:[—–-]\s*|\()?\s*((?:[1-3]\s*)?(?:Genesis|Gen|Exodus|Exo|Ex|Leviticus|Lev|Numbers|Num|Deuteronomy|Deut|Joshua|Josh|Judges|Judg|Ruth|Samuel|Sam|Kings|Kgs|Chronicles|Chron|Chr|Ezra|Nehemiah|Neh|Esther|Est|Job|Psalms|Psalm|Ps|Proverbs|Prov|Ecclesiastes|Eccl|Song of Solomon|Song|Isaiah|Isa|Jeremiah|Jer|Lamentations|Lam|Ezekiel|Ezek|Daniel|Dan|Hosea|Hos|Joel|Amos|Obadiah|Obad|Jonah|Micah|Mic|Nahum|Nah|Habakkuk|Hab|Zephaniah|Zeph|Haggai|Hag|Zechariah|Zech|Malachi|Mal|Matthew|Matt|Mat|Mark|Mk|Luke|Lk|John|Jn|Acts|Romans|Rom|Corinthians|Cor|Galatians|Gal|Ephesians|Eph|Philippians|Phil|Colossians|Col|Thessalonians|Thess|Timothy|Tim|Titus|Tit|Philemon|Phlm|Hebrews|Heb|James|Jas|Peter|Pet|Jude|Revelation|Rev)\s+\d+:\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)\s*\)?\.?$',
        caseSensitive: false,
      );

      final steps = <Map<String, String>>[];
      final stepPattern = RegExp(r'^(?:\d+[\.\)]\s*)?([A-Z][^:]{2,48}):\s+(.+)$');
      final isStepsSection = title.toLowerCase().contains('tip') ||
          title.toLowerCase().contains('step') ||
          title.toLowerCase().contains('practice');

      String? highlightNote;
      String? principleNote;
      final qaItems = <Map<String, String>>[];
      final remainingLines = <String>[];

      for (final rawBLine in body.split('\n')) {
        final bLine = rawBLine.trim();
        if (bLine.isEmpty) continue;

        final qMatch = quotePattern.firstMatch(bLine);
        if (qMatch != null) {
          final quoteText = qMatch.group(1)!.trim();
          String? refInLine = qMatch.group(2)?.trim();
          if (refInLine == null || refInLine.isEmpty) {
            final scriptMatch = _scriptureRegex.firstMatch(bLine);
            refInLine = scriptMatch?.group(0)?.trim();
          }
          if (refInLine != null && refInLine.isNotEmpty) {
            verseQuotes.add({
              'quote': quoteText,
              'reference': refInLine,
            });
            refs.add(refInLine);
            continue;
          }
        }

        final uMatch = unquotedVersePattern.firstMatch(bLine);
        if (uMatch != null) {
          final quoteText = uMatch
              .group(1)!
              .trim()
              .replaceFirst(RegExp(r'^["“]+'), '')
              .replaceFirst(RegExp(r'["”]+$'), '')
              .trim();
          final refInLine = uMatch.group(2)!.trim();
          if (quoteText.length >= 12 &&
              !quoteText.toLowerCase().startsWith('when this was spoken') &&
              !quoteText.toLowerCase().startsWith('this is ')) {
            verseQuotes.add({
              'quote': quoteText,
              'reference': refInLine,
            });
            refs.add(refInLine);
            continue;
          }
        }

        if (isStepsSection) {
          final sMatch = stepPattern.firstMatch(bLine);
          if (sMatch != null) {
            steps.add({
              'title': '${sMatch.group(1)!.trim()}:',
              'text': sMatch.group(2)!.trim(),
            });
            continue;
          }
        }

        if (highlightNote == null &&
            (bLine.startsWith('The Bible, from Genesis to Revelation') ||
                bLine.startsWith('Note:'))) {
          highlightNote = bLine
              .replaceFirst(RegExp(r'^Note:\s*', caseSensitive: false), '')
              .trim();
          continue;
        }

        if (principleNote == null &&
            RegExp(r'^(?:Key\s+)?Principle:\s*', caseSensitive: false)
                .hasMatch(bLine)) {
          principleNote = bLine
              .replaceFirst(
                  RegExp(r'^(?:Key\s+)?Principle:\s*', caseSensitive: false), '')
              .trim();
          continue;
        }

        final qaMatch = RegExp(r'^([A-Z])[\.\)]\s+([^?]+\?)\s*(.*)$')
            .firstMatch(bLine);
        if (qaMatch != null) {
          qaItems.add({
            'letter': qaMatch.group(1)!.trim(),
            'question': qaMatch.group(2)!.trim(),
            'text': qaMatch.group(3)?.trim() ?? '',
            'placeholder': 'Write your answer...',
          });
          continue;
        }

        remainingLines.add(bLine);
      }

      final palette = palettes[(basePaletteIndex + i) % palettes.length];
      final isQuestion = title.contains('?') ||
          body.contains('?') ||
          _questionHeadingRegex.hasMatch(title);

      result.add(
        ExtractedLessonSection(
          number: sectionNumber,
          title: title,
          bodyText: remainingLines.join('\n').trim(),
          scriptureReferences: refs.toList(),
          verseQuotes: verseQuotes,
          steps: steps,
          highlightNote: highlightNote,
          principleNote: principleNote,
          checkableSteps: isStepsSection && steps.isNotEmpty,
          qaItems: qaItems,
          isQuestion: isQuestion,
          hasInputTarget: !isStepsSection,
          reflectionPrompt: isQuestion
              ? 'Your Answer & Personal Reflection'
              : 'Key Takeaway & Application',
          paletteId: palette.id,
        ),
      );
    }

    return result;
  }

  /// Lint extracted sections for truncation, missing punctuation, or empty text
  /// (modeled on the ALIVE interactive lesson builder lint pass).
  static List<String> _lintSections(List<ExtractedLessonSection> sections) {
    final warnings = <String>[];
    void checkText(String text, String where) {
      final t = text.replaceAll(RegExp(r'[*_]'), '').trimRight();
      if (t.isEmpty) {
        warnings.add('$where: empty text');
      } else if (t.endsWith('…') || t.endsWith('...')) {
        warnings.add('$where: ends with an ellipsis (source truncated?)');
      } else if (!RegExp(r'[.!?\"”\x27\):;,]$').hasMatch(t)) {
        warnings.add('$where: no closing punctuation (truncated?)');
      }
    }

    for (final sec in sections) {
      if (sec.bodyText.trim().isNotEmpty) {
        checkText(sec.bodyText, 'Section ${sec.number} ("${sec.title}") body');
      }
      for (final q in sec.verseQuotes) {
        final qt = q['quote'] ?? '';
        if (qt.trim().isNotEmpty) {
          checkText(qt, 'Section ${sec.number} verse ${q['reference'] ?? '?'}');
        }
      }
      for (int i = 0; i < sec.steps.length; i++) {
        checkText(sec.steps[i]['text'] ?? '', 'Section ${sec.number} step ${i + 1}');
      }
      for (final qa in sec.qaItems) {
        if ((qa['text'] ?? '').trim().isNotEmpty) {
          checkText(qa['text']!, 'Section ${sec.number} Q&A ${qa['letter'] ?? ''}');
        }
      }
    }
    return warnings;
  }

  static String _cleanHeaderLine(String input) {
    final trimmed = input.trim();
    if (trimmed == trimmed.toUpperCase() && trimmed.length > 4) {
      return _capitalizeWords(trimmed);
    }
    return trimmed;
  }

  static String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Parses a PDF file using column-aware line extraction in syncfusion_flutter_pdf
  /// so multi-column trifold / booklet tracts read in exact panel order.
  Future<String> _extractFromPdf(Uint8List bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final pageTexts = <String>[];

    try {
      for (int pageIdx = 0; pageIdx < document.pages.count; pageIdx++) {
        final lines = extractor.extractTextLines(
          startPageIndex: pageIdx,
          endPageIndex: pageIdx,
        );
        if (lines.isEmpty) continue;

        final orderedLines = _orderColumnLines(lines);
        final pageBuf = StringBuffer();
        TextLine? prev;
        for (final line in orderedLines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          if (prev != null) {
            final gap = line.bounds.top - prev.bounds.bottom;
            final jumpedColumn =
                (line.bounds.left - prev.bounds.left).abs() > 110 && gap < -20;
            if (jumpedColumn || gap > (prev.bounds.height * 0.65).clamp(6.0, 18.0)) {
              pageBuf.write('\n\n');
            } else {
              pageBuf.write('\n');
            }
          }
          pageBuf.write(text);
          prev = line;
        }
        if (pageBuf.isNotEmpty) {
          pageTexts.add(pageBuf.toString());
        }
      }
    } catch (e) {
      debugPrint('Column-aware extraction fallback triggered: $e');
      final fallback = extractor.extractText();
      document.dispose();
      return fallback.trim();
    }

    document.dispose();
    if (pageTexts.isEmpty) return '';
    return pageTexts.join('\n\n').trim();
  }

  /// Orders PDF text lines into left-to-right columns, then top-to-bottom within
  /// each column, preventing trifold/2-column tract text from scrambling.
  List<TextLine> _orderColumnLines(List<TextLine> lines) {
    if (lines.length <= 1) return lines;

    // Sort by X first to discover horizontal column clusters (> 45pt gutter gap)
    final byX = List<TextLine>.from(lines)
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    final columns = <List<TextLine>>[];
    double currentMaxRight = -1;

    for (final line in byX) {
      if (columns.isEmpty) {
        columns.add([line]);
        currentMaxRight = line.bounds.right;
        continue;
      }

      // If this line starts noticeably to the right of the previous column's typical left
      // and doesn't heavily overlap, start a new column band.
      final avgColLeft = columns.last
              .map((l) => l.bounds.left)
              .reduce((a, b) => a + b) /
          columns.last.length;
      if (line.bounds.left - avgColLeft > 130 && line.bounds.left > currentMaxRight - 18) {
        columns.add([line]);
        currentMaxRight = line.bounds.right;
      } else {
        columns.last.add(line);
        if (line.bounds.right > currentMaxRight) {
          currentMaxRight = line.bounds.right;
        }
      }
    }

    // Sort each column top-to-bottom
    final ordered = <TextLine>[];
    for (final col in columns) {
      col.sort((a, b) {
        final dy = a.bounds.top.compareTo(b.bounds.top);
        return dy != 0 ? dy : a.bounds.left.compareTo(b.bounds.left);
      });
      ordered.addAll(col);
    }
    return ordered;
  }

  /// Parses a plain text file natively
  String _extractFromTxt(Uint8List bytes) {
    return utf8.decode(bytes).trim();
  }
}
