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
        'isQuestion': isQuestion,
        'hasInputTarget': hasInputTarget,
        'reflectionPrompt': reflectionPrompt,
        'paletteId': paletteId,
      };

  factory ExtractedLessonSection.fromJson(Map<String, dynamic> json) {
    final rawRefs = json['scriptureReferences'];
    final rawQuotes = json['verseQuotes'];
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

  const ExtractedTractArticle({
    required this.title,
    required this.fullFormattedBody,
    required this.sections,
    required this.headings,
    required this.totalWordCount,
    this.primaryPaletteId = 'emerald_forest',
    this.interactiveSections = const [],
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

    // 1. Normalize line endings and fix broken PDF hyphenated line-wraps
    var text = rawText.replaceAll(RegExp(r'\r\n?'), '\n');
    text = text.replaceAll(RegExp(r'(\w+)-\n(\w+)'), r'$1$2');

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

    return ExtractedTractArticle(
      title: effectiveTitle,
      fullFormattedBody: fullBody,
      sections: sections,
      headings: headings,
      totalWordCount: wordCount,
      primaryPaletteId: primaryPalette.id,
      interactiveSections: interactiveSections,
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

      // Extract quoted verses e.g. "All scripture is given..." (2 Timothy 3:16)
      final verseQuotes = <Map<String, String>>[];
      final quotePattern = RegExp(
        r'"([^"]{10,320})"\s*(?:\(([^)]+)\))?',
      );
      final remainingLines = <String>[];

      for (final bLine in body.split('\n')) {
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
          isQuestion: isQuestion,
          hasInputTarget: true,
          reflectionPrompt: isQuestion
              ? 'Your Answer & Personal Reflection'
              : 'Key Takeaway & Application',
          paletteId: palette.id,
        ),
      );
    }

    return result;
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

  /// Parses a PDF file using syncfusion_flutter_pdf
  Future<String> _extractFromPdf(Uint8List bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final String text = extractor.extractText();
    document.dispose();
    return text.trim();
  }

  /// Parses a plain text file natively
  String _extractFromTxt(Uint8List bytes) {
    return utf8.decode(bytes).trim();
  }
}
