import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

/// Internal representation of a PDF line enriched with typographic & spatial signals.
class _StyledPdfLine {
  final int pageIndex;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final String text;

  const _StyledPdfLine({
    required this.pageIndex,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.fontSize,
    required this.isBold,
    required this.isItalic,
    required this.text,
  });

  double get width => right - left;
  double get height => bottom - top;
}

/// Structured interactive study section extracted from ANY tract PDF or markdown body.
class ExtractedLessonSection {
  final int number;
  final String title;
  final String bodyText;
  final List<String> scriptureReferences;
  final List<Map<String, String>> verseQuotes;
  final List<Map<String, String>> steps;
  final List<Map<String, String>> checklistItems;
  final List<Map<String, String>> qaItems;
  final List<Map<String, String>> factItems;
  final Map<String, dynamic>? tableData;
  final Map<String, String>? testimony;
  final Map<String, String>? darkCallout;
  final String? highlightNote;
  final String? principleNote;
  final String? principleTitle;
  final bool checkableSteps;
  final bool isQuestion;
  final bool hasInputTarget;
  final String reflectionPrompt;
  final String reflectionPlaceholder;
  final String paletteId;

  const ExtractedLessonSection({
    required this.number,
    required this.title,
    required this.bodyText,
    required this.scriptureReferences,
    required this.verseQuotes,
    this.steps = const [],
    this.checklistItems = const [],
    this.qaItems = const [],
    this.factItems = const [],
    this.tableData,
    this.testimony,
    this.darkCallout,
    this.highlightNote,
    this.principleNote,
    this.principleTitle,
    this.checkableSteps = false,
    required this.isQuestion,
    required this.hasInputTarget,
    required this.reflectionPrompt,
    this.reflectionPlaceholder = 'Write your personal reflection or summary...',
    required this.paletteId,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'bodyText': bodyText,
        'scriptureReferences': scriptureReferences,
        'verseQuotes': verseQuotes,
        if (steps.isNotEmpty) 'steps': steps,
        if (checklistItems.isNotEmpty) 'checklistItems': checklistItems,
        if (qaItems.isNotEmpty) 'qaItems': qaItems,
        if (factItems.isNotEmpty) 'factItems': factItems,
        if (tableData != null) 'tableData': tableData,
        if (testimony != null) 'testimony': testimony,
        if (darkCallout != null) 'darkCallout': darkCallout,
        if (highlightNote != null && highlightNote!.isNotEmpty)
          'highlightNote': highlightNote,
        if (principleNote != null && principleNote!.isNotEmpty)
          'principleNote': principleNote,
        if (principleTitle != null && principleTitle!.isNotEmpty)
          'principleTitle': principleTitle,
        'checkableSteps': checkableSteps,
        'isQuestion': isQuestion,
        'hasInputTarget': hasInputTarget,
        'reflectionPrompt': reflectionPrompt,
        'reflectionPlaceholder': reflectionPlaceholder,
        'paletteId': paletteId,
      };

  factory ExtractedLessonSection.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>> parseMapList(dynamic raw, List<String> keys) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((m) {
        return {
          for (final k in keys) k: m[k]?.toString() ?? '',
        };
      }).toList();
    }

    final rawRefs = json['scriptureReferences'];
    return ExtractedLessonSection(
      number: (json['number'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Study Section',
      bodyText: json['bodyText']?.toString() ?? '',
      scriptureReferences: rawRefs is List
          ? rawRefs.map((e) => e.toString()).toList()
          : const [],
      verseQuotes:
          parseMapList(json['verseQuotes'], const ['quote', 'reference', 'lead']),
      steps: parseMapList(json['steps'], const ['title', 'text']),
      checklistItems:
          parseMapList(json['checklistItems'], const ['label', 'text']),
      qaItems: parseMapList(
          json['qaItems'], const ['letter', 'question', 'text', 'placeholder']),
      factItems: parseMapList(
          json['factItems'], const ['tag', 'title', 'quote', 'text']),
      tableData: json['tableData'] is Map
          ? Map<String, dynamic>.from(json['tableData'] as Map)
          : null,
      testimony: json['testimony'] is Map
          ? (json['testimony'] as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
      darkCallout: json['darkCallout'] is Map
          ? (json['darkCallout'] as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
      highlightNote: json['highlightNote']?.toString(),
      principleNote: json['principleNote']?.toString(),
      principleTitle: json['principleTitle']?.toString(),
      checkableSteps: json['checkableSteps'] == true,
      isQuestion: json['isQuestion'] == true,
      hasInputTarget: json['hasInputTarget'] ?? true,
      reflectionPrompt:
          json['reflectionPrompt']?.toString() ?? 'Your Personal Reflection',
      reflectionPlaceholder: json['reflectionPlaceholder']?.toString() ??
          'Write your personal reflection or summary...',
      paletteId: json['paletteId']?.toString() ?? 'emerald_forest',
    );
  }
}

/// Structured result containing organized tract content,
/// interactive study sections, and the complete lesson JSON schema.
class ExtractedTractArticle {
  final String title;
  final String fullFormattedBody;
  final List<String> sections;
  final List<String> headings;
  final int totalWordCount;
  final String primaryPaletteId;
  final List<ExtractedLessonSection> interactiveSections;
  final String? introSummary;
  final String? introHighlight;
  final String? heroVerse;
  final String? heroVerseRef;
  final String? estimatedReadTime;
  final String enquiryPhone;
  final List<String> decisionQuestions;
  final String? commitmentText;
  final Map<String, dynamic> lessonJson;
  final List<String> reviewNotes;

  const ExtractedTractArticle({
    required this.title,
    required this.fullFormattedBody,
    required this.sections,
    required this.headings,
    required this.totalWordCount,
    this.primaryPaletteId = 'emerald_forest',
    this.interactiveSections = const [],
    this.introSummary,
    this.introHighlight,
    this.heroVerse,
    this.heroVerseRef,
    this.estimatedReadTime,
    this.enquiryPhone = '07014331481',
    this.decisionQuestions = const [],
    this.commitmentText,
    this.lessonJson = const {},
    this.reviewNotes = const [],
  });
}

/// 100% Offline, Typographic & Spatial Layout-Driven PDF Extractor.
/// Uses font size, font weight (bold/italic), 2D XY-Cut column segmentation,
/// and structural grammar rather than hardcoded tract phrases or external LLMs.
class PdfExtractorService {
  static const Map<String, String> _bookAbbreviations = {
    'Gen': 'Genesis',
    'Ex': 'Exodus',
    'Exo': 'Exodus',
    'Exod': 'Exodus',
    'Lev': 'Leviticus',
    'Num': 'Numbers',
    'Deut': 'Deuteronomy',
    'Josh': 'Joshua',
    'Judg': 'Judges',
    'Sam': 'Samuel',
    'Kgs': 'Kings',
    'Chr': 'Chronicles',
    'Chron': 'Chronicles',
    'Neh': 'Nehemiah',
    'Est': 'Esther',
    'Esth': 'Esther',
    'Ps': 'Psalms',
    'Psa': 'Psalms',
    'Psalm': 'Psalms',
    'Prov': 'Proverbs',
    'Eccl': 'Ecclesiastes',
    'Song': 'Song of Solomon',
    'Isa': 'Isaiah',
    'Jer': 'Jeremiah',
    'Lam': 'Lamentations',
    'Ezek': 'Ezekiel',
    'Dan': 'Daniel',
    'Hos': 'Hosea',
    'Obad': 'Obadiah',
    'Mic': 'Micah',
    'Nah': 'Nahum',
    'Hab': 'Habakkuk',
    'Zeph': 'Zephaniah',
    'Hag': 'Haggai',
    'Zech': 'Zechariah',
    'Mal': 'Malachi',
    'Matt': 'Matthew',
    'Mat': 'Matthew',
    'Mk': 'Mark',
    'Lk': 'Luke',
    'Jn': 'John',
    'Rom': 'Romans',
    'Cor': 'Corinthians',
    'Gal': 'Galatians',
    'Eph': 'Ephesians',
    'Phil': 'Philippians',
    'Col': 'Colossians',
    'Thess': 'Thessalonians',
    'Tim': 'Timothy',
    'Tit': 'Titus',
    'Phlm': 'Philemon',
    'Heb': 'Hebrews',
    'Jas': 'James',
    'Pet': 'Peter',
    'Rev': 'Revelation',
  };

  static const String _booksPattern =
      r'(?:[1-3]\s*)?(?:Genesis|Gen|Exodus|Exod?|Leviticus|Lev|Numbers|Num|Deuteronomy|Deut|Joshua|Josh|Judges|Judg|Ruth|Samuel|Sam|Kings|Kgs|Chronicles|Chron|Chr|Ezra|Nehemiah|Neh|Esther|Esth?|Job|Psalms?|Psa?|Proverbs|Prov|Ecclesiastes|Eccl|Song of Solomon|Song|Isaiah|Isa|Jeremiah|Jer|Lamentations|Lam|Ezekiel|Ezek|Daniel|Dan|Hosea|Hos|Joel|Amos|Obadiah|Obad|Jonah|Micah|Mic|Nahum|Nah|Habakkuk|Hab|Zephaniah|Zeph|Haggai|Hag|Zechariah|Zech|Malachi|Mal|Matthew|Matt?|Mark|Mk|Luke|Lk|John|Jn|Acts|Romans|Rom|Corinthians|Cor|Galatians|Gal|Ephesians|Eph|Philippians|Phil|Colossians|Col|Thessalonians|Thess|Timothy|Tim|Titus|Tit|Philemon|Phlm|Hebrews|Heb|James|Jas|Peter|Pet|Jude|Revelation|Rev)\.?';

  static final RegExp _scriptureRegex = RegExp(
    r'\b(' +
        _booksPattern +
        r')\s*(?:chapters?\s+)?\d+(?:\s*[:.]\s*\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)?(?:\s*,?\s*(?:first|second|last)\s+part|\s*,?\s*margin|\s*,?\s*NKJV|\s*,?\s*KJV)?',
    caseSensitive: false,
  );

  /// Expands abbreviated Bible book names and repairs generic OCR reference glitches.
  static String normalizeScriptureRef(String rawRef) {
    var ref = rawRef.trim().replaceAll(RegExp(r'\s+'), ' ');
    ref = ref.replaceAll(RegExp(r'\.$'), '');

    // Fix missing space between book name and chapter ("1 Timothy6:13-16", "Eccl.9:5")
    ref = ref.replaceAllMapped(
      RegExp(r'([A-Za-z])\.?(\d+[:.]\d+)'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // Fix period used instead of colon in single verse ("John 1.14" -> "John 1:14")
    ref = ref.replaceAllMapped(
      RegExp(r'\b([1-3]?\s*[A-Za-z]+)\s+(\d{1,3})\.(\d{1,3})\b'),
      (m) => '${m.group(1)} ${m.group(2)}:${m.group(3)}',
    );

    // Fix garbled trailing colons ("John 1318,19,26:" -> "John 13:18, 19, 26")
    final garbled = RegExp(
            r'^([1-3]?\s*[A-Za-z]+)\s+(\d{1,2})(\d{2}(?:[,\-]\s*\d+)*):$')
        .firstMatch(ref);
    if (garbled != null) {
      ref = '${garbled.group(1)} ${garbled.group(2)}:${garbled.group(3)}';
    }

    // Fix dot in verse range: "10:2.4" -> "10:2-4"
    ref = ref.replaceAllMapped(
      RegExp(r'(\d+:\d+)\.(\d+)'),
      (m) => '${m.group(1)}-${m.group(2)}',
    );
    ref = ref.replaceAllMapped(RegExp(r',(\d)'), (m) => ', ${m.group(1)}');
    ref = ref.replaceAll(RegExp(r':\s+'), ':');

    // Expand book abbreviations
    for (final entry in _bookAbbreviations.entries) {
      final abbr = entry.key;
      final full = entry.value;
      ref = ref.replaceAllMapped(
        RegExp(r'\b([1-3]\s+)?' + abbr + r'\.?(?=\s+\d)', caseSensitive: false),
        (m) => '${m.group(1) ?? ''}$full',
      );
    }
    return ref.trim();
  }

  /// Extracts raw ordered text from PDF or TXT bytes using spatial & typographic analysis.
  Future<String> extractTextFromBytes(Uint8List bytes, String fileName) async {
    final extension = fileName.split('.').last.toLowerCase();
    try {
      if (extension == 'pdf') {
        final styledLines = _extractStyledLinesFromPdf(bytes);
        return _renderStyledLinesToAnnotatedMarkdown(styledLines);
      } else if (extension == 'txt') {
        return utf8.decode(bytes).trim();
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

  /// Main entrypoint called by TractManagementTab when a PDF or TXT file is uploaded.
  Future<ExtractedTractArticle> extractAndFormatArticle(
    Uint8List bytes,
    String fileName, {
    String? fallbackTitle,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final defaultTitle =
        fallbackTitle ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

    if (extension == 'pdf') {
      final styledLines = _extractStyledLinesFromPdf(bytes);
      return _buildArticleFromStyledLines(
        styledLines,
        fallbackTitle: defaultTitle,
      );
    }

    final rawText = await extractTextFromBytes(bytes, fileName);
    return structureAsWordPressContent(
      rawText,
      fallbackTitle: defaultTitle,
    );
  }

  // ===========================================================================
  // STEP 1: EXTRACT TYPOGRAPHY + GEOMETRY FROM PDF (syncfusion_flutter_pdf)
  // ===========================================================================
  List<_StyledPdfLine> _extractStyledLinesFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final allStyled = <_StyledPdfLine>[];

    try {
      for (int pageIdx = 0; pageIdx < document.pages.count; pageIdx++) {
        final rawLines = extractor.extractTextLines(
          startPageIndex: pageIdx,
          endPageIndex: pageIdx,
        );
        if (rawLines.isEmpty) continue;

        final pageStyled = rawLines
            .where((l) => l.text.trim().isNotEmpty)
            .map((l) {
              final fName = l.fontName.toLowerCase();
              final isBold = fName.contains('bold') ||
                  fName.contains('black') ||
                  fName.contains('heavy') ||
                  fName.contains('demi') ||
                  fName.contains('semibold');
              final isItalic =
                  fName.contains('italic') || fName.contains('oblique');
              return _StyledPdfLine(
                pageIndex: pageIdx,
                left: l.bounds.left,
                top: l.bounds.top,
                right: l.bounds.right,
                bottom: l.bounds.bottom,
                fontSize: l.fontSize,
                isBold: isBold,
                isItalic: isItalic,
                text: l.text.trim(),
              );
            })
            .toList();

        // Segment page into vertical columns using XY-cut whitespace gutters
        final orderedPageLines = _segmentPageColumnsXYCut(pageStyled);
        allStyled.addAll(orderedPageLines);
      }
    } finally {
      document.dispose();
    }

    return _orderPagesByLogicalSequence(allStyled);
  }

  /// Classic 2D XY-Cut Column Segmenter:
  /// Finds true vertical whitespace gutters across the page (works for 1, 2, 3, or 4 columns)
  /// rather than guessing column widths.
  List<_StyledPdfLine> _segmentPageColumnsXYCut(List<_StyledPdfLine> lines) {
    if (lines.length <= 1) return lines;

    // Filter out tiny isolated numeric badges on images (e.g., photo drawer numbers)
    // by keeping them attached to their nearest horizontal column band
    final minX = lines.map((l) => l.left).reduce(min);
    final maxX = lines.map((l) => l.right).reduce(max);
    final pageSpan = maxX - minX;
    if (pageSpan < 150) {
      return List<_StyledPdfLine>.from(lines)
        ..sort((a, b) => a.top.compareTo(b.top));
    }

    // Build a 1D horizontal projection histogram (1pt resolution) of substantial text lines
    final histLen = (maxX - minX).ceil() + 2;
    final coverage = List<int>.filled(histLen, 0);

    for (final l in lines) {
      // Ignore very narrow single-number badges when finding column gutters
      if (l.width < 22 && RegExp(r'^\d{1,2}$').hasMatch(l.text)) continue;
      final start = (l.left - minX).floor().clamp(0, histLen - 1);
      final end = (l.right - minX).ceil().clamp(0, histLen - 1);
      for (int x = start; x <= end; x++) {
        coverage[x]++;
      }
    }

    // Find empty vertical gutters (coverage == 0) at least 12pt wide
    final splitPoints = <double>[];
    int zeroRunStart = -1;
    for (int x = 0; x < histLen; x++) {
      if (coverage[x] == 0) {
        if (zeroRunStart == -1) zeroRunStart = x;
      } else {
        if (zeroRunStart != -1 && (x - zeroRunStart) >= 12) {
          final mid = minX + (zeroRunStart + x) / 2.0;
          // Ensure there is real content on both sides of the gutter
          if (mid > minX + 60 && mid < maxX - 60) {
            splitPoints.add(mid);
          }
        }
        zeroRunStart = -1;
      }
    }

    // Bucket lines into the discovered column bands
    final bounds = <double>[minX - 10, ...splitPoints, maxX + 10];
    final columns = List<List<_StyledPdfLine>>.generate(
        bounds.length - 1, (_) => <_StyledPdfLine>[]);

    for (final line in lines) {
      final center = (line.left + line.right) / 2.0;
      int targetCol = 0;
      for (int c = 0; c < bounds.length - 1; c++) {
        if (center >= bounds[c] && center < bounds[c + 1]) {
          targetCol = c;
          break;
        }
      }
      columns[targetCol].add(line);
    }

    // Sort each column strictly top-to-bottom (with 3.5pt line-baseline tolerance)
    final result = <_StyledPdfLine>[];
    for (final col in columns) {
      if (col.isEmpty) continue;
      col.sort((a, b) {
        final dy = a.top - b.top;
        if (dy.abs() > 3.5) return a.top.compareTo(b.top);
        return a.left.compareTo(b.left);
      });
      result.addAll(col);
    }
    return result;
  }

  /// Automatically orders pages by finding which page starts with Section #1
  /// (works for 2-page trifold spreads where cover/back is page 0, or any multi-page PDF).
  List<_StyledPdfLine> _orderPagesByLogicalSequence(
      List<_StyledPdfLine> lines) {
    if (lines.isEmpty) return lines;
    final byPage = <int, List<_StyledPdfLine>>{};
    for (final l in lines) {
      (byPage[l.pageIndex] ??= []).add(l);
    }
    final pageIds = byPage.keys.toList()..sort();
    if (pageIds.length <= 1) return lines;

    int firstContentPage = 0;
    for (int i = 0; i < pageIds.length; i++) {
      final pLines = byPage[pageIds[i]]!;
      final hasItemOne = pLines.any((l) =>
          RegExp(r'^1[\.\)]?$').hasMatch(l.text) ||
          RegExp(r'^1[\.\)]\s+[A-Z]').hasMatch(l.text));
      if (hasItemOne) {
        firstContentPage = i;
        break;
      }
    }

    final orderedIds = [
      ...pageIds.sublist(firstContentPage),
      ...pageIds.sublist(0, firstContentPage),
    ];
    return [
      for (final pid in orderedIds) ...byPage[pid]!,
    ];
  }

  // ===========================================================================
  // STEP 2: TYPOGRAPHIC ROLE CLASSIFICATION (Heading vs Body vs Quote vs Table)
  // ===========================================================================
  double _computeMedianFontSize(List<_StyledPdfLine> lines) {
    final sizes = lines
        .where((l) => l.text.length > 15 && l.fontSize > 4)
        .map((l) => l.fontSize)
        .toList()
      ..sort();
    if (sizes.isEmpty) return 10.0;
    return sizes[sizes.length ~/ 2];
  }

  String _renderStyledLinesToAnnotatedMarkdown(List<_StyledPdfLine> lines) {
    if (lines.isEmpty) return '';
    final article = _buildArticleFromStyledLines(lines);
    return article.fullFormattedBody;
  }

  ExtractedTractArticle _buildArticleFromStyledLines(
    List<_StyledPdfLine> lines, {
    String? fallbackTitle,
  }) {
    if (lines.isEmpty) {
      return ExtractedTractArticle(
        title: fallbackTitle ?? 'Untitled Tract',
        fullFormattedBody: '',
        sections: const [],
        headings: const [],
        totalWordCount: 0,
      );
    }

    final bodyFontSize = _computeMedianFontSize(lines);
    final maxFontSize = lines.map((l) => l.fontSize).reduce(max);

    // 1. Detect Cover Title & Enquiry Phone using font size hierarchy
    String detectedTitle = fallbackTitle ?? 'Interactive Bible Study';
    String enquiryPhone = '07014331481';
    String seriesName = 'What The Bible Says';

    final titleLines = <_StyledPdfLine>[];
    for (final l in lines) {
      final phoneM =
          RegExp(r'(?:Enquiry|call|Tel)[:\s]+(\+?\d[\d\s-]{8,14})',
                  caseSensitive: false)
              .firstMatch(l.text);
      if (phoneM != null) {
        enquiryPhone = phoneM.group(1)!.replaceAll(RegExp(r'\s+'), '');
      }
      if (l.text.toLowerCase().startsWith('series')) {
        seriesName = l.text;
      }
      // Largest font on the cover page (excluding "HOLY BIBLE") is the tract title
      if (l.fontSize >= maxFontSize - 1.5 &&
          l.fontSize > bodyFontSize + 2.5 &&
          !RegExp(r'^(HOLY|BIBLE|KING JAMES)', caseSensitive: false)
              .hasMatch(l.text)) {
        titleLines.add(l);
      }
    }
    if (titleLines.isNotEmpty) {
      final candidate = titleLines.map((l) => l.text).join(' ').trim();
      if (candidate.length >= 4 && candidate.length <= 70) {
        detectedTitle = candidate;
      }
    }

    // 2. Group consecutive lines into visual paragraphs / headings using font & Y-gaps
    final blocks = <Map<String, dynamic>>[];
    List<_StyledPdfLine> currentGroup = [];

    bool isHeadingLine(_StyledPdfLine l) {
      if (RegExp(r'^\d{1,2}\.?$').hasMatch(l.text) && l.isBold) return true;
      if (l.fontSize >= bodyFontSize + 1.0 && l.text.length < 110) return true;
      if (l.isBold &&
          l.text.length < 100 &&
          !l.text.startsWith('"') &&
          (l.text.endsWith('?') ||
              l.text.endsWith(':') ||
              RegExp(r'^\d{1,2}[\.\)]\s+').hasMatch(l.text))) {
        return true;
      }
      return false;
    }

    void flushGroup() {
      if (currentGroup.isEmpty) return;
      final joined = _rejoinHyphenatedLines(
          currentGroup.map((l) => l.text).toList());
      final anyBold = currentGroup.any((l) => l.isBold);
      final anyItalic = currentGroup.every((l) => l.isItalic);
      final avgFont = currentGroup
              .map((l) => l.fontSize)
              .reduce((a, b) => a + b) /
          currentGroup.length;
      final minLeft = currentGroup.map((l) => l.left).reduce(min);

      blocks.add({
        'text': joined,
        'isBold': anyBold,
        'isAllItalic': anyItalic,
        'fontSize': avgFont,
        'left': minLeft,
        'pageIndex': currentGroup.first.pageIndex,
      });
      currentGroup = [];
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip cover boilerplate stamps
      if (RegExp(r'^(HOLY|BIBLE|KING JAMES V\w+|ALIVE|Nigeria|Series[:.]?\s*\d*|What The Bible Says)$',
              caseSensitive: false)
          .hasMatch(line.text)) {
        continue;
      }
      if (line.text.toLowerCase().startsWith('for enquiry')) continue;
      if (titleLines.contains(line)) continue;

      // Skip cropped decorative banner fragments that start mid-word/lowercase in huge display font
      if (line.fontSize > bodyFontSize + 3.0 &&
          RegExp(r'^[a-z]').hasMatch(line.text)) {
        continue;
      }

      // Deduplicate repeated leading badge numbers ("10 10 What was..." -> "10 What was...")
      final cleanedLineText = line.text.replaceFirstMapped(
        RegExp(r'^(\d{1,2})\s+\1[\.\)]?\s+'),
        (m) => '${m.group(1)} ',
      );

      final processedLine = _StyledPdfLine(
        pageIndex: line.pageIndex,
        left: line.left,
        top: line.top,
        right: line.right,
        bottom: line.bottom,
        fontSize: line.fontSize,
        isBold: line.isBold,
        isItalic: line.isItalic,
        text: cleanedLineText,
      );

      if (currentGroup.isEmpty) {
        currentGroup.add(processedLine);
        continue;
      }

      final prev = currentGroup.last;
      final samePage = processedLine.pageIndex == prev.pageIndex;
      final sameColumn = (processedLine.left - prev.left).abs() < 45;
      final verticalGap = processedLine.top - prev.bottom;
      final prevIsHeading = isHeadingLine(prev);
      final currIsHeading = isHeadingLine(processedLine);

      // Merge multi-line headings together, or merge body lines with small vertical gap
      final shouldMerge = samePage &&
          sameColumn &&
          verticalGap >= -4 &&
          verticalGap <= max(prev.height * 0.65, 8.0) &&
          ((prevIsHeading && currIsHeading && !prev.text.endsWith('?')) ||
              (!prevIsHeading && !currIsHeading && !processedLine.text.startsWith('"')));

      if (shouldMerge) {
        currentGroup.add(processedLine);
      } else {
        flushGroup();
        currentGroup.add(processedLine);
      }
    }
    flushGroup();

    // 3. Pair standalone bold numbers ("1", "2", "10") with the heading block right after them
    final mergedBlocks = <Map<String, dynamic>>[];
    int bIdx = 0;
    while (bIdx < blocks.length) {
      final blk = blocks[bIdx];
      final txt = blk['text'] as String;
      if (RegExp(r'^\d{1,2}\.?$').hasMatch(txt) && bIdx + 1 < blocks.length) {
        final nextBlk = blocks[bIdx + 1];
        final nextTxt = nextBlk['text'] as String;
        final nextIsHeading = (nextBlk['isBold'] == true) ||
            (nextBlk['fontSize'] as double) >= bodyFontSize + 0.8 ||
            nextTxt.endsWith('?');
        if (nextIsHeading && nextTxt.length < 130) {
          final numVal = int.parse(txt.replaceAll('.', ''));
          mergedBlocks.add({
            ...nextBlk,
            'num': numVal,
            'isSectionHeader': true,
          });
          bIdx += 2;
          continue;
        }
      }

      final inlineNum =
          RegExp(r'^(\d{1,2})[\.\)]?\s+(.+)$').firstMatch(txt);
      final isHeaderFont = (blk['isBold'] == true) ||
          (blk['fontSize'] as double) >= bodyFontSize + 0.8;

      if (inlineNum != null &&
          (isHeaderFont || txt.endsWith('?')) &&
          txt.length < 130) {
        mergedBlocks.add({
          ...blk,
          'num': int.parse(inlineNum.group(1)!),
          'text': inlineNum.group(2)!.trim(),
          'isSectionHeader': true,
        });
      } else if (isHeaderFont &&
          txt.length >= 6 &&
          txt.length < 110 &&
          !txt.startsWith('"') &&
          (txt.endsWith('?') || txt.endsWith(':') || (blk['fontSize'] as double) >= bodyFontSize + 1.2)) {
        mergedBlocks.add({
          ...blk,
          'num': null,
          'isSectionHeader': true,
        });
      } else {
        mergedBlocks.add({
          ...blk,
          'isSectionHeader': false,
        });
      }
      bIdx++;
    }

    // 4. Separate Intro, Numbered Sections (sorted 1..N), Unnumbered Sidebars, and Closing Decision
    final introBlocks = <Map<String, dynamic>>[];
    final numberedSections = <int, Map<String, dynamic>>{};
    final unnumberedSections = <Map<String, dynamic>>[];
    final decisionQuestions = <String>[];

    Map<String, dynamic>? activeSec;
    for (final blk in mergedBlocks) {
      final txt = blk['text'] as String;
      if (blk['isSectionHeader'] == true) {
        // Check if this is a closing personal decision question ("Do you...", "Will you...", "Would you...")
        if (blk['num'] == null &&
            RegExp(r'^(Do you |Will you |Would you )', caseSensitive: false)
                .hasMatch(txt) &&
            txt.endsWith('?')) {
          decisionQuestions.add(txt);
          continue;
        }
        activeSec = {
          'num': blk['num'],
          'title': txt,
          'children': <Map<String, dynamic>>[],
        };
        if (blk['num'] != null) {
          numberedSections[blk['num'] as int] = activeSec;
        } else {
          unnumberedSections.add(activeSec);
        }
      } else {
        if (activeSec == null) {
          introBlocks.add(blk);
        } else {
          (activeSec['children'] as List<Map<String, dynamic>>).add(blk);
        }
      }
    }

    // Fallback: If no section headers were detected (pure narrative tract),
    // automatically chunk blocks into narrative sections so the user doesn't get a single wall of text!
    if (numberedSections.isEmpty && unnumberedSections.isEmpty && introBlocks.isNotEmpty) {
      final totalBlocks = introBlocks.length;
      if (totalBlocks >= 2) {
        final introCount = totalBlocks > 4 ? 1 : 0;
        final realIntro = introBlocks.take(introCount).toList();
        final bodyBlocks = introBlocks.skip(introCount).toList();

        introBlocks.clear();
        introBlocks.addAll(realIntro);

        // Group every 2-3 paragraphs into a section
        final chunkSize = bodyBlocks.length > 8 ? 2 : 1;
        int sectionCounter = 1;
        for (int i = 0; i < bodyBlocks.length; i += chunkSize) {
          final chunk = bodyBlocks.sublist(i, min(i + chunkSize, bodyBlocks.length));
          final firstTxt = chunk.first['text'] as String;
          // Generate a section title from the first sentence of the section
          final firstSentence = firstTxt.split(RegExp(r'[.!?]')).first.trim();
          final secTitle = firstSentence.length > 55
              ? '${firstSentence.substring(0, 52)}...'
              : firstSentence.isNotEmpty
                  ? firstSentence
                  : 'Section $sectionCounter';

          numberedSections[sectionCounter] = {
            'num': sectionCounter,
            'title': secTitle,
            'children': chunk,
          };
          sectionCounter++;
        }
      }
    }

    // Sort numbered sections strictly 1 -> N
    final sortedSectionKeys = numberedSections.keys.toList()..sort();
    final orderedSections = [
      for (final k in sortedSectionKeys) numberedSections[k]!,
      ...unnumberedSections,
    ];

    // Build Interactive Sections + Clean Markdown
    final seed = detectedTitle.codeUnits.fold<int>(0, (p, e) => p + e);
    final palettes = LessonColorPalette.brandPalettes;
    final primaryPalette = palettes[seed % palettes.length];

    final interactiveSections = <ExtractedLessonSection>[];
    final headings = <String>[];
    final mdBuf = StringBuffer('# $detectedTitle\n\n');

    final introTexts =
        introBlocks.map((b) => b['text'] as String).where((t) => t.isNotEmpty).toList();
    final introSummary = introTexts.isNotEmpty ? introTexts.first : '';
    final introHighlight =
        introTexts.length > 1 ? introTexts.sublist(1).join('\n\n') : null;

    if (introSummary.isNotEmpty) mdBuf.writeln('$introSummary\n');

    for (int i = 0; i < orderedSections.length; i++) {
      final sec = orderedSections[i];
      final num = (sec['num'] as int?) ?? (i + 1);
      final title = sec['title'] as String;
      final children = sec['children'] as List<Map<String, dynamic>>;
      headings.add(title);

      final parsed = _classifySectionChildren(
        number: num,
        title: title,
        children: children,
        paletteId: palettes[(seed + i) % palettes.length].id,
      );
      interactiveSections.add(parsed);

      mdBuf.writeln('## $num. $title');
      for (final v in parsed.verseQuotes) {
        mdBuf.writeln('"${v['quote']}" — ${v['reference']}');
      }
      if (parsed.bodyText.isNotEmpty) mdBuf.writeln(parsed.bodyText);
      for (final st in parsed.steps) {
        mdBuf.writeln('- **${st['title']}** ${st['text']}');
      }
      mdBuf.writeln();
    }

    final fullBody = mdBuf.toString().trim();
    final wordCount =
        fullBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final estMinutes = max(10, 5 * ((wordCount / 130) / 5).round());
    final estimatedReadTime = '$estMinutes–${estMinutes + 5} mins';

    String? heroVerse;
    String? heroVerseRef;
    final firstWithQuote =
        interactiveSections.where((s) => s.verseQuotes.isNotEmpty).firstOrNull;
    if (firstWithQuote != null) {
      heroVerse = firstWithQuote.verseQuotes.first['quote'];
      heroVerseRef = firstWithQuote.verseQuotes.first['reference'];
    }

    // Prevent hero card from repeating the exact same text as the intro summary
    if (heroVerse != null && introSummary.isNotEmpty && introSummary.contains(heroVerse)) {
      heroVerse = null;
      heroVerseRef = null;
    }

    if (decisionQuestions.isEmpty) {
      // Generate tract-aware questions based on title and verses
      final lowerTitle = detectedTitle.toLowerCase();
      if (lowerTitle.contains('heart') || lowerTitle.contains('transplant') || lowerTitle.contains('new life')) {
        decisionQuestions.addAll([
          'Do you recognize your personal need for a spiritual heart transplant?',
          'Will you ask God to replace your natural heart with a new heart of flesh today?',
          'Will you commit to walking in the new life Christ gives you?',
        ]);
      } else {
        decisionQuestions.add(
          'Will you apply the truths of God\'s Word from this study in your daily life?',
        );
      }
    }

    // Dynamically extract lesson number from series name or title
    final lessonNumMatch = RegExp(r'(\d+)').firstMatch(seriesName) ??
        RegExp(r'Lesson\s*(\d+)', caseSensitive: false)
            .firstMatch(fallbackTitle ?? '');
    final detectedLessonNum =
        lessonNumMatch != null ? int.parse(lessonNumMatch.group(1)!) : 1;

    final lessonJson = _buildLessonJsonSchema(
      lessonNumber: detectedLessonNum,
      title: detectedTitle,
      series: seriesName,
      phone: enquiryPhone,
      heroVerse: heroVerse ??
          'Thy word is a lamp unto my feet, and a light unto my path.',
      heroVerseRef: heroVerseRef ?? 'Psalms 119:105',
      introHeading: detectedTitle,
      introSummary: introSummary,
      introHighlight: introHighlight,
      estimatedReadTime: estimatedReadTime,
      interactiveSections: interactiveSections,
      decisionQuote: '',
      decisionQuestions: decisionQuestions,
      commitmentText:
          'I commit to studying God\'s Word prayerfully and following its truth.',
      reviewNotes: const [],
    );

    return ExtractedTractArticle(
      title: detectedTitle,
      fullFormattedBody: fullBody,
      sections: [fullBody],
      headings: headings,
      totalWordCount: wordCount,
      primaryPaletteId: primaryPalette.id,
      interactiveSections: interactiveSections,
      introSummary: introSummary,
      introHighlight: introHighlight,
      heroVerse: heroVerse,
      heroVerseRef: heroVerseRef,
      estimatedReadTime: estimatedReadTime,
      enquiryPhone: enquiryPhone,
      decisionQuestions: decisionQuestions,
      lessonJson: lessonJson,
    );
  }

  /// Classifies child blocks inside a section using typographic & structural signals
  /// (italics, quotes + Bible references, numbered lists, lettered sub-questions, tables).
  ExtractedLessonSection _classifySectionChildren({
    required int number,
    required String title,
    required List<Map<String, dynamic>> children,
    required String paletteId,
  }) {
    final refs = <String>{};
    final verseQuotes = <Map<String, String>>[];
    final steps = <Map<String, String>>[];
    final qaItems = <Map<String, String>>[];
    final factItems = <Map<String, String>>[];
    final bodyParas = <String>[];
    String? highlightNote;
    String? testimonyText;
    String? testimonyTitle;
    Map<String, dynamic>? tableData;
    final checklistItems = <Map<String, String>>[];

    // Universal verse regex:
    // Handles optional wrapped closing quote right before the Bible reference ("John 6:57,58.)
    // and normalizes OCR digit '0' at start of quote ("0 taste -> "O taste)
    final verseRegex = RegExp(
      r'((?:The Bible says,\s*|Jesus said,\s*|But He answered and said,\s*)?)"([^"]{10,750}?)(?:"|\.(?=\s*"?\s*' +
          _booksPattern +
          r'))\s*\.?\s*"?\s*\(?(' +
          _booksPattern +
          r'\s*\d+\s*[:.]\s*\d+(?:\s*[-–,]\s*\d+)*(?:\s*\.?\s*(?:first|second|last)\s+part|\s*,?\s*margin|\s*,?\s*NKJV)?)\)?\.?(?:\s*\(See\s+[^)]+\))?',
      caseSensitive: false,
    );

    for (final child in children) {
      var txt = (child['text'] as String).trim();
      final isItalic = child['isAllItalic'] == true;
      if (txt.isEmpty) continue;

      // Extract any Scripture references
      for (final m in _scriptureRegex.allMatches(txt)) {
        refs.add(normalizeScriptureRef(m.group(0)!));
      }

      // 1. Scripture Quote + Reference block
      final vMatches = verseRegex.allMatches(txt).toList();
      if (vMatches.isNotEmpty) {
        // Split on matched spans so text before, between, and after verses
        // keeps clean paragraph boundaries without stray punctuation.
        int lastEnd = 0;
        final remainingParts = <String>[];
        for (final m in vMatches) {
          final lead = (m.group(1) ?? '').trim();
          var quote = (m.group(2) ?? '').trim();
          if (quote.startsWith('0 ')) {
            quote = 'O ${quote.substring(2)}';
          }
          final ref = normalizeScriptureRef(m.group(3)!);
          verseQuotes.add({
            'quote': quote,
            'reference': ref,
            if (lead.isNotEmpty) 'lead': lead,
          });
          if (m.start > lastEnd) {
            final before = txt
                .substring(lastEnd, m.start)
                .replaceFirst(RegExp(r'^[.,;:\s]+'), '')
                .trim();
            if (before.isNotEmpty) remainingParts.add(before);
          }
          lastEnd = m.end;
        }
        if (lastEnd < txt.length) {
          final after = txt
              .substring(lastEnd)
              .replaceFirst(RegExp(r'^[.,;:\s]+'), '')
              .trim();
          if (after.isNotEmpty) remainingParts.add(after);
        }
        txt = remainingParts.join('\n\n').trim();
        if (txt.isEmpty) continue;
      }

      // 2. Lettered sub-questions / facts ("A. Where did I come from? ...")
      final letterMatch = RegExp(r'^([A-D])\.\s+(.+)$').firstMatch(txt);
      if (letterMatch != null) {
        final letter = letterMatch.group(1)!;
        final rest = letterMatch.group(2)!.trim();
        final qSplit = RegExp(r'^([^?]+\?)\s*(.+)$').firstMatch(rest);
        if (qSplit != null) {
          qaItems.add({
            'letter': letter,
            'question': qSplit.group(1)!.trim(),
            'text': qSplit.group(2)!.trim(),
            'placeholder': 'Enter your note on ${qSplit.group(1)!.trim()}',
          });
        } else {
          steps.add({'title': '$letter.', 'text': rest});
        }
        continue;
      }

      // 3. Numbered steps / list items ("1. Start with prayer: ...", "2. ...")
      final stepMatch = RegExp(r'^(\d{1,2})[\.\)]\s+(.+)$').firstMatch(txt);
      if (stepMatch != null) {
        final numStr = stepMatch.group(1)!;
        final rest = stepMatch.group(2)!.trim();
        final colon = RegExp(r'^([^:]{2,35}:)\s*(.+)$').firstMatch(rest);
        if (colon != null) {
          steps.add({'title': colon.group(1)!, 'text': colon.group(2)!});
        } else {
          steps.add({'title': 'Point $numStr:', 'text': rest});
        }
        continue;
      }

      // 4. Quotations with author attribution (e.g. C.S. Lewis, Surprised by Joy) or first-person testimonies
      final quoteWithAuthorMatch = RegExp(
              r'["“]([^"”]{40,600}?)["”]\s*\(([^)]+)\)',
              caseSensitive: false)
          .firstMatch(txt);
      if (quoteWithAuthorMatch != null) {
        final quoteContent = quoteWithAuthorMatch.group(1)!.trim();
        final attribution = quoteWithAuthorMatch.group(2)!.trim();
        testimonyTitle = attribution;
        testimonyText = quoteContent;
        txt = txt.replaceFirst(quoteWithAuthorMatch.group(0)!, '').trim();
        if (txt.isEmpty) continue;
      } else if ((isItalic ||
              RegExp(r'^\b(My|Our|I)\b.+\b(experience|testimony|changed|family)\b',
                      caseSensitive: false)
                  .hasMatch(txt)) &&
          txt.length > 140) {
        testimonyTitle = 'Personal Testimony';
        testimonyText = txt;
        continue;
      }

      // 5. Bold summary callout block
      if (child['isBold'] == true && txt.length > 60 && highlightNote == null) {
        highlightNote = txt;
        continue;
      }

      // 6. Pipe-delimited table rows (e.g. "OT Prediction | NT Fulfillment")
      if (txt.contains(' | ') && tableData == null) {
        final rows = txt
            .split('\n')
            .where((r) => r.contains(' | '))
            .map((r) => r
                .split('|')
                .map((c) => normalizeScriptureRef(c.trim()))
                .where((c) => c.isNotEmpty)
                .toList())
            .where((r) => r.length >= 2)
            .toList();
        if (rows.length >= 2) {
          tableData = {
            'title': title,
            'columns': rows.first,
            'rows': rows.sublist(1),
          };
          continue;
        }
      }

      // 7. Bullet / checklist items (•, -, ▪)
      final checklistMatch =
          RegExp(r'^[\u2022•\-▪]\s+(.+)$').firstMatch(txt);
      if (checklistMatch != null) {
        checklistItems.add({'label': checklistMatch.group(1)!, 'text': ''});
        continue;
      }

      bodyParas.add(txt);
    }

    final isQuestion = title.contains('?');
    return ExtractedLessonSection(
      number: number,
      title: title,
      bodyText: bodyParas.join('\n\n').trim(),
      scriptureReferences: refs.toList(),
      verseQuotes: verseQuotes,
      steps: steps,
      qaItems: qaItems,
      factItems: factItems,
      tableData: tableData,
      checklistItems: checklistItems,
      testimony: testimonyText != null
          ? {'title': testimonyTitle ?? 'Reflection & Testimony', 'text': testimonyText}
          : null,
      highlightNote: highlightNote,
      checkableSteps: title.toLowerCase().contains('tip') || title.toLowerCase().contains('practice'),
      isQuestion: isQuestion,
      hasInputTarget: qaItems.isEmpty && steps.isEmpty,
      reflectionPrompt: isQuestion
          ? 'Your Personal Reflection / Note:'
          : 'Key Takeaway & Application:',
      reflectionPlaceholder: 'Write your reflection on: $title',
      paletteId: paletteId,
    );
  }

  static String _rejoinHyphenatedLines(List<String> rawLines) {
    final buf = StringBuffer();
    for (final raw in rawLines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (buf.isEmpty) {
        buf.write(line);
      } else {
        final cur = buf.toString();
        if (cur.endsWith('-') &&
            cur.length >= 2 &&
            RegExp(r'[a-zA-Z]$').hasMatch(cur.substring(0, cur.length - 1)) &&
            RegExp(r'^[a-zA-Z]').hasMatch(line)) {
          final withoutHyphen = cur.substring(0, cur.length - 1);
          buf.clear();
          buf.write('$withoutHyphen$line');
        } else {
          buf.write(' $line');
        }
      }
    }
    var result = buf.toString();
    result = result.replaceAll('\u201C', '"').replaceAll('\u201D', '"');
    result = result.replaceAll('\u2018', "'").replaceAll('\u2019', "'");
    result = result.replaceAllMapped(
      RegExp('($_booksPattern)\\.?(\\d+:\\d+)', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'(\d+:\d+)\.(\d+)'),
      (m) => '${m.group(1)}-${m.group(2)}',
    );
    return result.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Backwards-compatible text-based entrypoint (for TXT files or already-extracted markdown).
  ExtractedTractArticle structureAsWordPressContent(
    String rawText, {
    String? fallbackTitle,
    int? paletteSeed,
  }) {
    final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final synthetic = <_StyledPdfLine>[];
    double y = 0;
    for (final l in lines) {
      final trimmed = l.trim();
      final isMdHeader = trimmed.startsWith('## ') || trimmed.startsWith('# ');
      synthetic.add(_StyledPdfLine(
        pageIndex: 0,
        left: 0,
        top: y,
        right: 400,
        bottom: y + 12,
        fontSize: isMdHeader ? 13.0 : 10.0,
        isBold: isMdHeader,
        isItalic: false,
        text: trimmed.replaceFirst(RegExp(r'^#{1,2}\s+'), ''),
      ));
      y += 18;
    }
    return _buildArticleFromStyledLines(synthetic, fallbackTitle: fallbackTitle);
  }

  static List<ExtractedLessonSection> parseInteractiveSections(
    String content, {
    String? fallbackTitle,
    int basePaletteIndex = 0,
  }) {
    return PdfExtractorService()
        .structureAsWordPressContent(
          content,
          fallbackTitle: fallbackTitle,
          paletteSeed: basePaletteIndex,
        )
        .interactiveSections;
  }

  static Map<String, dynamic> _buildLessonJsonSchema({
    required int lessonNumber,
    required String title,
    required String series,
    required String phone,
    required String heroVerse,
    required String heroVerseRef,
    required String introHeading,
    required String introSummary,
    String? introHighlight,
    required String estimatedReadTime,
    required List<ExtractedLessonSection> interactiveSections,
    required String decisionQuote,
    required List<String> decisionQuestions,
    required String commitmentText,
    required List<String> reviewNotes,
  }) {
    final jsonSections = <Map<String, dynamic>>[];

    for (final s in interactiveSections) {
      final blocks = <Map<String, dynamic>>[];

      if (s.verseQuotes.isNotEmpty) {
        blocks.add({
          'type': 'verses',
          'items': s.verseQuotes
              .map((v) => {
                    if (v['lead'] != null && v['lead']!.isNotEmpty)
                      'lead': v['lead'],
                    'text': v['quote'] ?? '',
                    'ref': v['reference'] ?? '',
                  })
              .toList(),
        });
      }

      if (s.bodyText.isNotEmpty) {
        final paras = s.bodyText
            .split('\n\n')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
        blocks.add({
          'type': 'text',
          'text': paras.length == 1 ? paras.first : paras,
        });
      }

      if (s.highlightNote != null && s.highlightNote!.isNotEmpty) {
        blocks.add({
          'type': 'note',
          'style': 'highlight',
          'text': s.highlightNote,
        });
      }

      if (s.testimony != null) {
        blocks.add({'type': 'testimony', ...s.testimony!});
      }

      if (s.checklistItems.isNotEmpty) {
        blocks.add({'type': 'checklist', 'items': s.checklistItems});
      }

      if (s.tableData != null) {
        blocks.add({'type': 'table', ...s.tableData!});
      }

      if (s.steps.isNotEmpty) {
        blocks.add({
          'type': 'steps',
          'checkable': s.checkableSteps,
          'items': s.steps,
        });
      }

      if (s.qaItems.isNotEmpty) {
        blocks.add({'type': 'qa', 'items': s.qaItems});
      }

      jsonSections.add({
        if (s.isQuestion) 'num': s.number else 'icon': 'fa-solid fa-book-bible',
        'title': s.title,
        'blocks': blocks,
        if (s.hasInputTarget)
          'reflection': {
            'id': 'q${s.number}',
            'label': s.reflectionPrompt,
            'placeholder': s.reflectionPlaceholder,
            'multiline': s.number == 1 || s.number == 5 || s.number == 13,
          },
      });
    }

    return {
      'lesson_number': lessonNumber,
      'title': title,
      'short_title': title.replaceAll(RegExp(r'[!?.]+$'), '').trim(),
      'series': series,
      'badge': 'ALIVE Nigeria',
      'phone': phone,
      'study_time': estimatedReadTime,
      'footer_verse': '"$heroVerse" — $heroVerseRef',
      'hero': {
        'eyebrow': 'Interactive Scripture Tract Guide',
        'verse': heroVerse,
        'verse_ref': heroVerseRef,
        'card': {
          'icon': 'fa-solid fa-book-open-reader',
          'label': series,
          'quote': '…searched the Scriptures daily, whether those things were so.',
        },
      },
      'intro': {
        'heading': introHeading,
        'icon': 'fa-solid fa-compass',
        'text': introSummary,
        if (introHighlight != null && introHighlight.isNotEmpty)
          'highlight': introHighlight,
      },
      'sections': jsonSections,
      'decision': {
        'eyebrow': 'Personal Response & Commitment',
        'title': 'Making God\'s Word Your Foundation',
        if (decisionQuote.isNotEmpty) 'quote': decisionQuote,
        'questions': [
          for (int i = 0; i < decisionQuestions.length; i++)
            {'id': 'decision_${i + 1}', 'text': decisionQuestions[i]},
        ],
        'commitment': {
          'title': 'My Study Commitment:',
          'text': commitmentText,
        },
        'collect_contact': true,
      },
      if (reviewNotes.isNotEmpty) 'review': reviewNotes,
    };
  }
}
