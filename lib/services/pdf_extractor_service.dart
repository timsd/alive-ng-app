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
  final String fontName;
  final int? badgeNumber;
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
    this.fontName = '',
    this.badgeNumber,
    required this.text,
  });

  double get width => right - left;
  double get height => bottom - top;

  _StyledPdfLine copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    String? fontName,
    int? badgeNumber,
    String? text,
  }) {
    return _StyledPdfLine(
      pageIndex: pageIndex,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      fontName: fontName ?? this.fontName,
      badgeNumber: badgeNumber ?? this.badgeNumber,
      text: text ?? this.text,
    );
  }
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
    'Eze': 'Ezekiel',
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
      r'(?:[1-3]\s*)?(?:Genesis|Gen|Exodus|Exod?|Leviticus|Lev|Numbers|Num|Deuteronomy|Deut|Joshua|Josh|Judges|Judg|Ruth|Samuel|Sam|Kings|Kgs|Chronicles|Chron|Chr|Ezra|Nehemiah|Neh|Esther|Esth?|Job|Psalms?|Psa?|Proverbs|Prov|Ecclesiastes|Eccl|Song of Solomon|Song|Isaiah|Isa|Jeremiah|Jer|Lamentations|Lam|Ezekiel|Ezek|Eze|Daniel|Dan|Hosea|Hos|Joel|Amos|Obadiah|Obad|Jonah|Micah|Mic|Nahum|Nah|Habakkuk|Hab|Zephaniah|Zeph|Haggai|Hag|Zechariah|Zech|Malachi|Mal|Matthew|Matt?|Mark|Mk|Luke|Lk|John|Jn|Acts|Romans|Rom|Corinthians|Cor|Galatians|Gal|Ephesians|Eph|Philippians|Phil|Colossians|Col|Thessalonians|Thess|Timothy|Tim|Titus|Tit|Philemon|Phlm|Hebrews|Heb|James|Jas|Peter|Pet|Jude|Revelation|Rev)\.?';

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

  /// Normalizes invisible/non-breaking Unicode spaces, soft hyphens & common OCR typos.
  static String _normalizePdfText(String raw) {
    return raw
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\u00AD', '')
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        // OCR lowercase 'l' in "lsa. 53:5" -> "Isa. 53:5"
        .replaceAllMapped(
          RegExp(r'\blsa\.?(\s+\d+\s*[:.]\s*\d+)'),
          (m) => 'Isa.${m.group(1)}',
        )
        // Normalize extra space after colon in Bible refs like "Gen. 2: 17." -> "Gen. 2:17."
        .replaceAllMapped(
          RegExp(r'(\d):\s+(\d)'),
          (m) => '${m.group(1)}:${m.group(2)}',
        )
        // Normalize space before closing quote like '. "' -> '."'
        .replaceAll('. "', '."')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Normalizes a PDF font name to its base family (stripping subset prefix & weight suffixes).
  static String _normalizeFontFamily(String fontName) {
    var f = fontName.trim();
    final plusIdx = f.indexOf('+');
    if (plusIdx >= 0 && plusIdx < f.length - 1) {
      f = f.substring(plusIdx + 1);
    }
    f = f.toLowerCase();
    f = f.replaceAll(
      RegExp(r'[-,_\s]*(bold|italic|oblique|regular|roman|mt|psmt|std|medium|semibold|demi|light|black|heavy)+$'),
      '',
    );
    return f.trim();
  }

  /// Fixes kerning gaps in stylized PDF headers like "T ruth F or Th e W orld" -> "Truth For The World".
  static String _compactSpacedLetters(String text) {
    return text.replaceAllMapped(
      RegExp(r'\b([A-Za-z])\s+([a-z]{1,4})\b'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
  }

  static bool _isPublisherOrBoilerplateLine(String text) {
    final compact = _compactSpacedLetters(text).toLowerCase().trim();
    if (compact.isEmpty) return true;
    final squashed = compact.replaceAll(RegExp(r'\s+'), '');
    if (squashed.contains('truthfortheworld') ||
        squashed.contains('creativecommons') ||
        squashed.contains('bethelsprings')) {
      return true;
    }
    final patterns = <RegExp>[
      RegExp(r'creative\s+commons|attribution-noncommercial|unported\s+license|all\s+rights\s+reserved'),
      RegExp(r'\b(?:p\.?\s*o\.?\s*box|bethel\s+springs|truthfortheworld\.org|info@|www\.[a-z0-9.-]+\.[a-z]{2,})'),
      RegExp(r'^(?:published|printed|distributed)\s+by\b'),
      RegExp(r'^(?:u\.?\s*s\.?\s*a\.?|\d{5}(?:\s*u\.?\s*s\.?\s*a\.?)?)$'),
      RegExp(r'^(?:truth\s+for\s+the\s+world|for\s+enquiry|call\s+us|contact\s+us)\b'),
      RegExp(r'^(?:page\s*\d+(?:\s*of\s*\d+)?|-\s*\d+\s*-)$'),
    ];
    return patterns.any((r) => r.hasMatch(compact));
  }

  static bool _isAuthorByline(String text) {
    final t = text.trim();
    return RegExp(
          r'^(?:by|written\s+by|compiled\s+by|author:?)\s+[A-Z][A-Za-z\.\s\-]{2,45}$',
          caseSensitive: false,
        ).hasMatch(t) &&
        t.split(RegExp(r'\s+')).length <= 6 &&
        !t.endsWith('?') &&
        !t.contains(':');
  }

  static double _trigramSimilarity(String a, String b) {
    final na = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final nb = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1.0;
    if (na.length < 3 || nb.length < 3) return na == nb ? 1.0 : 0.0;
    final sa = <String>{for (int i = 0; i <= na.length - 3; i++) na.substring(i, i + 3)};
    final sb = <String>{for (int i = 0; i <= nb.length - 3; i++) nb.substring(i, i + 3)};
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    return union == 0 ? 0.0 : inter / union;
  }

  // ===========================================================================
  // STEP 1: EXTRACT TYPOGRAPHY + GEOMETRY FROM PDF (syncfusion_flutter_pdf)
  // ===========================================================================
  List<_StyledPdfLine> _extractStyledLinesFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final pageMap = <int, List<_StyledPdfLine>>{};
    final pageHeights = <int, double>{};
    final pageWidths = <int, double>{};

    try {
      for (int pageIdx = 0; pageIdx < document.pages.count; pageIdx++) {
        final pageSize = document.pages[pageIdx].size;
        pageHeights[pageIdx] = pageSize.height;
        pageWidths[pageIdx] = pageSize.width;

        final rawLines = extractor.extractTextLines(
          startPageIndex: pageIdx,
          endPageIndex: pageIdx,
        );
        if (rawLines.isEmpty) continue;

        final pageStyled = <_StyledPdfLine>[];
        for (final l in rawLines) {
          final cleaned = _normalizePdfText(l.text);
          if (cleaned.isEmpty) continue;
          final fName = l.fontName.toLowerCase();
          final isBold = fName.contains('bold') ||
              fName.contains('black') ||
              fName.contains('heavy') ||
              fName.contains('demi') ||
              fName.contains('semibold');
          final isItalic =
              fName.contains('italic') || fName.contains('oblique');
          pageStyled.add(_StyledPdfLine(
            pageIndex: pageIdx,
            left: l.bounds.left,
            top: l.bounds.top,
            right: l.bounds.right,
            bottom: l.bounds.bottom,
            fontSize: l.fontSize,
            isBold: isBold,
            isItalic: isItalic,
            fontName: _normalizeFontFamily(l.fontName),
            text: cleaned,
          ));
        }

        if (pageStyled.isNotEmpty) {
          pageMap[pageIdx] = pageStyled;
        }
      }
    } finally {
      document.dispose();
    }

    // Strip repeated running headers/footers & standalone page numbers on multi-page PDFs
    _stripRunningHeadersFootersAndPageNumbers(pageMap, pageHeights);

    final allStyled = <_StyledPdfLine>[];
    final sortedPages = pageMap.keys.toList()..sort();
    for (final pageIdx in sortedPages) {
      final pLines = pageMap[pageIdx]!;
      final orderedPageLines = _segmentPageColumnsXYCut(
        pLines,
        pageWidth: pageWidths[pageIdx] ?? 612.0,
      );
      allStyled.addAll(orderedPageLines);
    }

    return _orderPagesByLogicalSequence(allStyled);
  }

  /// Removes repeated running headers/footers across pages (even with slight OCR
  /// typos like "WHAT DO THESE THINGS MEAN ?" vs "WHAT 1)0 THESE THINGS MEAN?")
  /// and standalone page numbers in the top/bottom page margins.
  void _stripRunningHeadersFootersAndPageNumbers(
    Map<int, List<_StyledPdfLine>> pageMap,
    Map<int, double> pageHeights,
  ) {
    final pageCount = pageMap.length;
    if (pageCount < 2) return;

    // 1. Collect candidate top/bottom margin lines per page
    final marginTextsByPage = <int, List<String>>{};
    for (final entry in pageMap.entries) {
      final pIdx = entry.key;
      final h = pageHeights[pIdx] ?? 792.0;
      final topBand = h * 0.11;
      final bottomBand = h * 0.89;
      marginTextsByPage[pIdx] = entry.value
          .where((l) =>
              (l.top <= topBand || l.bottom >= bottomBand) &&
              l.text.length >= 4 &&
              l.text.length <= 90 &&
              !RegExp(r'^\d{1,3}$').hasMatch(l.text))
          .map((l) => l.text)
          .toList();
    }

    // 2. Identify running header/footer templates appearing on >= 3 pages (or >= 50% of >= 3 pages)
    final runningTemplates = <String>[];
    if (pageCount >= 3) {
      final allMarginSamples = marginTextsByPage.values.expand((e) => e).toList();
      for (final sample in allMarginSamples) {
        if (runningTemplates.any((t) => _trigramSimilarity(t, sample) >= 0.72)) {
          continue;
        }
        int matchingPages = 0;
        for (final pSamples in marginTextsByPage.values) {
          if (pSamples.any((s) => _trigramSimilarity(s, sample) >= 0.72)) {
            matchingPages++;
          }
        }
        if (matchingPages >= 3 || (pageCount >= 4 && matchingPages >= (pageCount * 0.4).ceil())) {
          runningTemplates.add(sample);
        }
      }
    }

    // 3. Filter each page
    for (final entry in pageMap.entries) {
      final pIdx = entry.key;
      final h = pageHeights[pIdx] ?? 792.0;
      final topBand = h * 0.12;
      final bottomBand = h * 0.88;
      final lines = entry.value;

      pageMap[pIdx] = lines.where((l) {
        final inTopOrBottomMargin = l.top <= topBand || l.bottom >= bottomBand;

        // Strip standalone page numbers in top/bottom margin (unless clearly a question badge paired on same Y with text)
        if (inTopOrBottomMargin && RegExp(r'^(?:page\s*)?\d{1,3}$', caseSensitive: false).hasMatch(l.text)) {
          final hasSameBaselineText = lines.any((other) =>
              other != l &&
              (other.top - l.top).abs() <= 6.0 &&
              other.left > l.right &&
              other.text.length >= 8);
          if (!hasSameBaselineText) {
            return false;
          }
        }

        // Also strip standalone page numbers on multi-page books/booklets (>= 4 pages) that match page number +/- 2
        if (pageCount >= 4 && RegExp(r'^\d{1,3}$').hasMatch(l.text)) {
          final n = int.tryParse(l.text) ?? -1;
          final hasSameBaselineText = lines.any((other) =>
              other != l &&
              (other.top - l.top).abs() <= 6.0 &&
              other.left > l.right &&
              other.text.length >= 8);
          if (!hasSameBaselineText && (n == pIdx + 1 || n == pIdx || n == pIdx + 2 || inTopOrBottomMargin)) {
            return false;
          }
        }

        // Strip repeated running header/footer on all pages after the very first occurrence (keep page 0 for title detection)
        if (runningTemplates.isNotEmpty && pIdx > 0 && inTopOrBottomMargin) {
          final isRunning = runningTemplates
              .any((t) => _trigramSimilarity(t, l.text) >= 0.72);
          if (isRunning) return false;
        }
        return true;
      }).toList();
    }
  }

  /// Classic 2D XY-Cut Column Segmenter with full-width banner preservation and
  /// minimum column-width guards so narrow letter fragments are never sliced off.
  List<_StyledPdfLine> _segmentPageColumnsXYCut(
    List<_StyledPdfLine> lines, {
    double pageWidth = 612.0,
  }) {
    if (lines.length <= 1) return lines;

    final minX = lines.map((l) => l.left).reduce(min);
    final maxX = lines.map((l) => l.right).reduce(max);
    final pageSpan = maxX - minX;
    if (pageSpan < 180) {
      return List<_StyledPdfLine>.from(lines)
        ..sort((a, b) {
          final dy = a.top - b.top;
          if (dy.abs() > 3.5) return a.top.compareTo(b.top);
          return a.left.compareTo(b.left);
        });
    }

    // Separate full-width lines (titles/banners spanning > 58% of content span) so they don't hide column gutters
    final fullWidthLines = <_StyledPdfLine>[];
    final bodyCandidates = <_StyledPdfLine>[];
    for (final l in lines) {
      if (l.width > pageSpan * 0.58) {
        fullWidthLines.add(l);
      } else {
        bodyCandidates.add(l);
      }
    }

    // If most lines are full-width (single-column document), just sort top-to-bottom!
    if (bodyCandidates.length < 6 || fullWidthLines.length > bodyCandidates.length * 0.45) {
      return List<_StyledPdfLine>.from(lines)
        ..sort((a, b) {
          final dy = a.top - b.top;
          if (dy.abs() > 3.5) return a.top.compareTo(b.top);
          return a.left.compareTo(b.left);
        });
    }

    // Build 1D horizontal projection histogram from multi-word lines only
    final histLen = (maxX - minX).ceil() + 2;
    final coverage = List<int>.filled(histLen, 0);

    for (final l in bodyCandidates) {
      // Ignore tiny isolated badges/fragments when locating true column gutters
      if (l.width < 28 && l.text.length <= 3) continue;
      final start = (l.left - minX).floor().clamp(0, histLen - 1);
      final end = (l.right - minX).ceil().clamp(0, histLen - 1);
      for (int x = start; x <= end; x++) {
        coverage[x]++;
      }
    }

    // Find true vertical gutters (coverage == 0) at least 14pt wide, with each column >= 95pt wide
    final splitPoints = <double>[];
    int zeroRunStart = -1;
    double lastBoundary = minX;
    for (int x = 0; x < histLen; x++) {
      if (coverage[x] == 0) {
        if (zeroRunStart == -1) zeroRunStart = x;
      } else {
        if (zeroRunStart != -1 && (x - zeroRunStart) >= 14) {
          final mid = minX + (zeroRunStart + x) / 2.0;
          if (mid - lastBoundary >= 95 && maxX - mid >= 95) {
            splitPoints.add(mid);
            lastBoundary = mid;
          }
        }
        zeroRunStart = -1;
      }
    }

    if (splitPoints.isEmpty) {
      return List<_StyledPdfLine>.from(lines)
        ..sort((a, b) {
          final dy = a.top - b.top;
          if (dy.abs() > 3.5) return a.top.compareTo(b.top);
          return a.left.compareTo(b.left);
        });
    }

    // Separate top full-width banners vs bottom full-width footers around the columns
    final minBodyTop = bodyCandidates.map((l) => l.top).reduce(min);
    final maxBodyBottom = bodyCandidates.map((l) => l.bottom).reduce(max);
    final topBanners = fullWidthLines.where((l) => l.bottom <= minBodyTop + 16).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    final bottomBanners = fullWidthLines.where((l) => l.top >= maxBodyBottom - 16).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    final midFullWidth = fullWidthLines
        .where((l) => !topBanners.contains(l) && !bottomBanners.contains(l))
        .toList();

    // Bucket column lines into discovered column bands
    final bounds = <double>[minX - 10, ...splitPoints, maxX + 10];
    final columns = List<List<_StyledPdfLine>>.generate(
        bounds.length - 1, (_) => <_StyledPdfLine>[]);

    for (final line in [...bodyCandidates, ...midFullWidth]) {
      final anchor = line.left + min(line.width * 0.35, 35.0);
      int targetCol = 0;
      for (int c = 0; c < bounds.length - 1; c++) {
        if (anchor >= bounds[c] && anchor < bounds[c + 1]) {
          targetCol = c;
          break;
        }
      }
      columns[targetCol].add(line);
    }

    // Spatially pair standalone large question badges ("1".."25") with the first
    // question line to their right BEFORE baseline merging, without polluting the
    // text line's fontSize or bottom coordinate (prevents verticalGap breakages on
    // 2-line questions and prevents 20pt digits from masking 18pt cover titles).
    List<_StyledPdfLine> pairBadgesAndMergeBaseline(List<_StyledPdfLine> colLines) {
      if (colLines.length <= 1) return colLines;

      final badgeIndices = <int>{};
      final pairedBadges = <int, int>{}; // targetIdx -> badgeNum

      for (int i = 0; i < colLines.length; i++) {
        final b = colLines[i];
        if (!RegExp(r'^\d{1,2}\.?$').hasMatch(b.text)) continue;
        final badgeNum = int.tryParse(b.text.replaceAll('.', ''));
        if (badgeNum == null || badgeNum < 1 || badgeNum > 40) continue;
        if (b.width > 42) continue;

        // Find the top-most alphabetic text line immediately to the right of this badge
        int bestTarget = -1;
        double bestTop = double.infinity;
        for (int j = 0; j < colLines.length; j++) {
          if (i == j || pairedBadges.containsKey(j)) continue;
          final t = colLines[j];
          if (RegExp(r'^\d{1,2}\.?$').hasMatch(t.text)) continue;
          if (!RegExp(r'[A-Za-z]{2,}').hasMatch(t.text)) continue;
          final horizDist = t.left - b.right;
          if (horizDist < -4 || horizDist > 65) continue;
          // Badge may sit slightly below line 1 top (e.g. 20pt badge centered across 2 lines)
          final overlapsVertically = t.top >= b.top - 10.0 && t.top <= b.bottom + 3.0;
          if (overlapsVertically && t.top < bestTop) {
            bestTop = t.top;
            bestTarget = j;
          }
        }

        if (bestTarget != -1) {
          badgeIndices.add(i);
          pairedBadges[bestTarget] = badgeNum;
        }
      }

      final cleanedCol = <_StyledPdfLine>[];
      for (int i = 0; i < colLines.length; i++) {
        if (badgeIndices.contains(i)) continue;
        final line = colLines[i];
        final pairedNum = pairedBadges[i];
        cleanedCol.add(
          pairedNum != null ? line.copyWith(badgeNumber: pairedNum) : line,
        );
      }

      if (cleanedCol.length <= 1) return cleanedCol;
      cleanedCol.sort((a, b) {
        final dy = a.top - b.top;
        if (dy.abs() > 3.5) return a.top.compareTo(b.top);
        return a.left.compareTo(b.left);
      });
      final merged = <_StyledPdfLine>[];
      for (final l in cleanedCol) {
        if (merged.isEmpty) {
          merged.add(l);
          continue;
        }
        final prev = merged.last;
        final sameBaseline = (l.top - prev.top).abs() <= 3.5;
        final horizGap = l.left - prev.right;
        if (sameBaseline && horizGap >= -4 && horizGap <= 28) {
          final sep = horizGap < 1.5 ? '' : ' ';
          merged[merged.length - 1] = _StyledPdfLine(
            pageIndex: prev.pageIndex,
            left: min(prev.left, l.left),
            top: min(prev.top, l.top),
            right: max(prev.right, l.right),
            bottom: max(prev.bottom, l.bottom),
            fontSize: max(prev.fontSize, l.fontSize),
            isBold: prev.isBold || l.isBold,
            isItalic: prev.isItalic && l.isItalic,
            fontName: prev.fontName.isNotEmpty ? prev.fontName : l.fontName,
            badgeNumber: prev.badgeNumber ?? l.badgeNumber,
            text: _normalizePdfText('${prev.text}$sep${l.text}'),
          );
        } else {
          merged.add(l);
        }
      }
      return merged;
    }

    final result = <_StyledPdfLine>[...topBanners];
    for (final col in columns) {
      if (col.isEmpty) continue;
      result.addAll(pairBadgesAndMergeBaseline(col));
    }
    result.addAll(bottomBanners);
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
          l.badgeNumber == 1 ||
          RegExp(r'^1[\.\)]?$').hasMatch(l.text) ||
          RegExp(r'^1[\.\)]?\s+[A-Z]').hasMatch(l.text));
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
  /// Character-weighted mode of font sizes so footnotes/headers never skew body size.
  double _computeMedianFontSize(List<_StyledPdfLine> lines) {
    final weightBySize = <double, int>{};
    for (final l in lines) {
      if (l.text.length < 12 || l.fontSize <= 4) continue;
      // Round to nearest 0.5pt bucket
      final bucket = (l.fontSize * 2).round() / 2.0;
      weightBySize[bucket] = (weightBySize[bucket] ?? 0) + l.text.length;
    }
    if (weightBySize.isEmpty) return 10.0;
    double bestSize = 10.0;
    int bestWeight = -1;
    weightBySize.forEach((size, weight) {
      if (weight > bestWeight) {
        bestWeight = weight;
        bestSize = size;
      }
    });
    return bestSize;
  }

  /// Character-weighted dominant font family of the document body (e.g. "timesnewromanps").
  String _computeBodyFontFamily(List<_StyledPdfLine> lines) {
    final weightByFont = <String, int>{};
    for (final l in lines) {
      if (l.text.length < 15 || l.fontName.isEmpty) continue;
      weightByFont[l.fontName] = (weightByFont[l.fontName] ?? 0) + l.text.length;
    }
    if (weightByFont.isEmpty) return '';
    String bestFont = '';
    int bestWeight = -1;
    weightByFont.forEach((font, weight) {
      if (weight > bestWeight) {
        bestWeight = weight;
        bestFont = font;
      }
    });
    return bestFont;
  }

  /// True if text looks like a genuine heading/question rather than a mid-sentence fragment.
  static bool _isPlausibleHeadingText(String text) {
    final t = text.trim();
    if (t.length < 4 || t.length > 135) return false;
    if (!RegExp(r'[A-Za-z]{2,}').hasMatch(t)) return false;
    if (_isPublisherOrBoilerplateLine(t) || _isAuthorByline(t)) return false;
    // Never a standalone Bible quote or pure verse reference
    if (t.startsWith('"') || t.startsWith("'")) return false;
    if (RegExp(r'^[a-z]').hasMatch(t)) return false;
    // Reject obvious trailing mid-sentence connectors (unless it's a question)
    if (!t.endsWith('?') &&
        RegExp(
          r'\b(?:the|a|an|of|to|in|for|with|by|from|and|or|but|that|which|who|whom|whose|their|his|her|its|our|your|as|at|on|into|unto|upon|about|against)$',
          caseSensitive: false,
        ).hasMatch(t)) {
      return false;
    }
    if (t.endsWith(',') || t.endsWith(';')) return false;
    return true;
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
        reviewNotes: const ['No readable text could be extracted from this PDF.'],
      );
    }

    final rawInputWordCount = lines
        .map((l) => l.text)
        .join(' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    final bodyFontSize = _computeMedianFontSize(lines);
    final bodyFontFamily = _computeBodyFontFamily(lines);
    final reviewNotes = <String>[];

    // Compute largest font size strictly over genuine alphabetic non-question lines
    // (NEVER bare digits like "1..16" or numbered questions!)
    final nonNumericLines = lines
        .where((l) =>
            l.badgeNumber == null &&
            RegExp(r'[A-Za-z]{3,}').hasMatch(l.text) &&
            !_isPublisherOrBoilerplateLine(l.text) &&
            !_isAuthorByline(l.text) &&
            !RegExp(r'^(HOLY|BIBLE|KING JAMES|ALIVE|Nigeria|Series[:.]?\s*\d*|What The Bible Says)$',
                    caseSensitive: false)
                .hasMatch(l.text))
        .toList();
    final maxAlphaFontSize = nonNumericLines.isNotEmpty
        ? nonNumericLines.map((l) => l.fontSize).reduce(max)
        : bodyFontSize;

    // 1. Detect Cover Title & Enquiry Phone using font size hierarchy + cover-top heuristics
    String detectedTitle = fallbackTitle ?? 'Interactive Bible Study';
    String enquiryPhone = '07014331481';
    String seriesName = 'What The Bible Says';
    bool usedFilenameFallback = true;

    final titleLines = <_StyledPdfLine>[];
    final firstPageIdx = lines.map((l) => l.pageIndex).reduce(min);

    for (final l in lines) {
      final phoneM = RegExp(
        r'(?:Enquiry|call|Tel)[:\s]+(\+?\d[\d\s-]{8,14})',
        caseSensitive: false,
      ).firstMatch(l.text);
      if (phoneM != null) {
        enquiryPhone = phoneM.group(1)!.replaceAll(RegExp(r'\s+'), '');
      }
      if (l.text.toLowerCase().startsWith('series')) {
        seriesName = l.text;
      }
    }

    // Strategy A: Largest alphabetic display font block (must be > bodyFontSize + 2.0, excluding numbered questions!)
    if (maxAlphaFontSize > bodyFontSize + 2.0) {
      final largeCandidates = nonNumericLines
          .where((l) =>
              l.fontSize >= maxAlphaFontSize - 1.5 &&
              l.fontSize > bodyFontSize + 2.0 &&
              !RegExp(r'^\d{1,2}[\.\)]?\s+').hasMatch(l.text) &&
              !RegExp(r'^["' "'" r']').hasMatch(l.text) &&
              !RegExp(r'^[a-z]').hasMatch(l.text) &&
              !l.text.endsWith('?'))
          .toList();
      if (largeCandidates.isNotEmpty) {
        final anchorPage = largeCandidates.first.pageIndex;
        final anchorTop = largeCandidates.first.top;
        for (final c in largeCandidates) {
          if (c.pageIndex == anchorPage && (c.top - anchorTop).abs() <= 140) {
            titleLines.add(c);
          }
        }
      }
    }

    // Strategy B: If no display font found (uniform-font tracts like 123/137/138, Character_of_God),
    // inspect top non-boilerplate lines on first page and merge multi-line cover titles!
    if (titleLines.isEmpty) {
      final topPageLines = nonNumericLines
          .where((l) => l.pageIndex == firstPageIdx)
          .take(10)
          .toList();
      for (int idx = 0; idx < topPageLines.length; idx++) {
        final c = topPageLines[idx];
        final t = c.text.trim();
        final looksLikeTitle = t.length >= 4 &&
            t.length <= 85 &&
            !t.startsWith('"') &&
            !RegExp(r'^\d{1,2}[\.\)]?\s+').hasMatch(t) &&
            !RegExp(r'^[a-z]').hasMatch(t) &&
            (c.isBold ||
                c.fontSize >= bodyFontSize + 0.8 ||
                t == t.toUpperCase() ||
                t.endsWith('?'));
        if (looksLikeTitle) {
          // Include immediately preceding title line if this line is line 2 of a 2-line question/title
          if (idx > 0) {
            final prev = topPageLines[idx - 1];
            final vGap = c.top - prev.bottom;
            if (vGap >= -4 &&
                vGap <= max(prev.height * 1.4, 18.0) &&
                (c.fontSize - prev.fontSize).abs() <= 1.5 &&
                prev.text.length <= 65 &&
                !prev.text.endsWith('.') &&
                !RegExp(r'^\d{1,2}[\.\)]?\s+').hasMatch(prev.text)) {
              titleLines.add(prev);
            }
          }
          titleLines.add(c);
          // Also include immediately following continuation line of a multi-line title
          if (idx + 1 < topPageLines.length && !t.endsWith('?') && !t.endsWith('.')) {
            final next = topPageLines[idx + 1];
            final vGap = next.top - c.bottom;
            if (vGap >= -4 &&
                vGap <= max(c.height * 1.4, 18.0) &&
                (next.fontSize - c.fontSize).abs() <= 1.5 &&
                next.text.length <= 65 &&
                !RegExp(r'^\d{1,2}[\.\)]?\s+').hasMatch(next.text)) {
              titleLines.add(next);
            }
          }
          break;
        }
      }
    }

    if (titleLines.isNotEmpty) {
      var candidate = titleLines.map((l) => l.text).join(' ').trim();
      candidate = candidate.replaceAll(RegExp(r'\s+'), ' ');
      // Strip leading "Series: 4 " prefix if followed by actual title
      final strippedSeries = candidate
          .replaceFirst(RegExp(r'^Series[:.]?\s*\d+\s+', caseSensitive: false), '')
          .trim();
      if (strippedSeries.length >= 4) {
        candidate = strippedSeries;
      }
      if (candidate.length >= 4 &&
          candidate.length <= 95 &&
          RegExp(r'[A-Za-z]{3,}').hasMatch(candidate)) {
        detectedTitle = candidate;
        usedFilenameFallback = false;
      }
    }

    if (usedFilenameFallback) {
      reviewNotes.add(
        'Could not detect a cover title automatically; fell back to filename "$detectedTitle".',
      );
    }

    // 2. Group consecutive lines into visual paragraphs / headings using font & Y-gaps
    final blocks = <Map<String, dynamic>>[];
    List<_StyledPdfLine> currentGroup = [];

    // Any bold, badged, or distinct-heading-font non-quote line (even line 1 of a 2-line question
    // before the "?") is treated as a heading-style line during grouping so multi-line questions stay intact!
    bool isDistinctHeadingFontLine(_StyledPdfLine l) {
      return bodyFontFamily.isNotEmpty &&
          l.fontName.isNotEmpty &&
          l.fontName != bodyFontFamily &&
          l.text.length < 130 &&
          !l.text.startsWith('"');
    }

    bool isHeadingStyleLine(_StyledPdfLine l) {
      if (l.badgeNumber != null) return true;
      if (RegExp(r'^\d{1,2}\.?$').hasMatch(l.text) &&
          (l.isBold || l.fontSize >= bodyFontSize + 1.5)) {
        return true;
      }
      if (isDistinctHeadingFontLine(l)) return true;
      // Non-bold line in the body font family (e.g. 12pt TimesNewRoman verse quote or closing note)
      // must be dramatically larger (>= +3pt) to be treated as a heading.
      final sizeThreshold = (l.fontName.isNotEmpty &&
              l.fontName == bodyFontFamily &&
              !l.isBold)
          ? bodyFontSize + 3.0
          : bodyFontSize + 1.5;
      if (l.fontSize >= sizeThreshold &&
          l.text.length < 115 &&
          !l.text.startsWith('"')) {
        return true;
      }
      if (l.isBold && l.text.length < 115 && !l.text.startsWith('"')) {
        return true;
      }
      return false;
    }

    void flushGroup() {
      if (currentGroup.isEmpty) return;
      final joined = _rejoinHyphenatedLines(
        currentGroup.map((l) => l.text).toList(),
      );
      if (joined.isEmpty) {
        currentGroup = [];
        return;
      }
      final allBold = currentGroup.every((l) => l.isBold);
      final anyBold = currentGroup.any((l) => l.isBold);
      final allItalic = currentGroup.every((l) => l.isItalic);
      final allDistinctHeadingFont =
          currentGroup.every((l) => isDistinctHeadingFontLine(l));
      final badgeNum = currentGroup
          .map((l) => l.badgeNumber)
          .whereType<int>()
          .firstOrNull;
      final avgFont =
          currentGroup.map((l) => l.fontSize).reduce((a, b) => a + b) /
              currentGroup.length;
      final minLeft = currentGroup.map((l) => l.left).reduce(min);

      blocks.add({
        'text': joined,
        'isBold': anyBold,
        'isAllBold': allBold,
        'isAllItalic': allItalic,
        'isDistinctHeadingFont': allDistinctHeadingFont,
        'badgeNumber': badgeNum,
        'fontSize': avgFont,
        'left': minLeft,
        'pageIndex': currentGroup.first.pageIndex,
      });
      currentGroup = [];
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip cover boilerplate stamps, publisher footers & author bylines
      if (RegExp(
        r'^(HOLY|BIBLE|KING JAMES V\w+|ALIVE|Nigeria|Series[:.]?\s*\d*|What The Bible Says)$',
        caseSensitive: false,
      ).hasMatch(line.text)) {
        continue;
      }
      if (_isPublisherOrBoilerplateLine(line.text)) continue;
      if (_isAuthorByline(line.text)) continue;
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

      final processedLine = line.copyWith(text: cleanedLineText);

      if (currentGroup.isEmpty) {
        currentGroup.add(processedLine);
        continue;
      }

      final prev = currentGroup.last;
      final firstInGroup = currentGroup.first;
      final samePage = processedLine.pageIndex == prev.pageIndex;
      // Allow hanging-indent continuation and wrap-around below an inline drop-cap/illustration
      final leftDelta = processedLine.left - prev.left;
      final sameColumn = leftDelta >= -95 && leftDelta <= 85;
      final verticalGap = processedLine.top - prev.bottom;
      final prevIsHeading = isHeadingStyleLine(prev);
      final currIsHeading = isHeadingStyleLine(processedLine);
      final prevIsBareNum = RegExp(r'^\d{1,2}\.?$').hasMatch(prev.text);
      final currIsBareNum = RegExp(r'^\d{1,2}\.?$').hasMatch(processedLine.text);
      final currStartsNewNumber = processedLine.badgeNumber != null ||
          RegExp(r'^\d{1,2}[\.\)]?\s+[A-Z]').hasMatch(processedLine.text);
      final groupStartsNumbered = firstInGroup.badgeNumber != null ||
          RegExp(r'^\d{1,2}[\.\)]?\s+[A-Z]').hasMatch(firstInGroup.text);
      final prevIncompleteHeading = (prevIsHeading || groupStartsNumbered) &&
          !prev.text.endsWith('?') &&
          !prev.text.endsWith(':') &&
          !prev.text.endsWith('.') &&
          !prev.text.endsWith('!');

      // Merge multi-line headings/questions (including hyphenated or non-bold line 2 continuations),
      // or merge body lines with normal line spacing
      final shouldMerge = samePage &&
          sameColumn &&
          !prevIsBareNum &&
          !currIsBareNum &&
          !currStartsNewNumber &&
          verticalGap >= -6 &&
          ((prevIncompleteHeading &&
                  verticalGap <= max(prev.height * 1.6, 16.0) &&
                  !processedLine.text.startsWith('"') &&
                  (currIsHeading ||
                      processedLine.text.endsWith('?') ||
                      RegExp(r'^[a-z]').hasMatch(processedLine.text) ||
                      prev.text.endsWith('-'))) ||
              (!prevIsHeading &&
                  !currIsHeading &&
                  verticalGap <= max(prev.height * 0.9, 9.5) &&
                  !processedLine.text.startsWith('"')));

      if (shouldMerge) {
        currentGroup.add(processedLine);
      } else {
        flushGroup();
        currentGroup.add(processedLine);
      }
    }
    flushGroup();

    // 3. Pair standalone question numbers ("1", "2", "10") with the heading block right after them,
    //    and classify blocks into Section Headers vs Body using strict structural & typographic guards.
    final mergedBlocks = <Map<String, dynamic>>[];
    int bIdx = 0;
    while (bIdx < blocks.length) {
      final blk = blocks[bIdx];
      final txt = blk['text'] as String;

      // Standalone number badge ("1", "2.")
      if (RegExp(r'^\d{1,2}\.?$').hasMatch(txt)) {
        if (bIdx + 1 < blocks.length) {
          final nextBlk = blocks[bIdx + 1];
          final nextTxt = nextBlk['text'] as String;
          final nextIsHeading = (nextBlk['isBold'] == true) ||
              (nextBlk['fontSize'] as double) >= bodyFontSize + 0.8 ||
              nextTxt.endsWith('?');
          if (nextIsHeading && _isPlausibleHeadingText(nextTxt)) {
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
        // Orphan bare number not followed by a heading (e.g. stray page number) -> drop safely
        bIdx++;
        continue;
      }

      // Split accidentally merged two-question lines like "Who wrote this? 2. When was this written?"
      final inlineTwoQuestions = RegExp(r'^([^?]+\?)\s+(\d{1,2})[\.\)]\s+(.+\?)$')
          .firstMatch(txt);
      if (inlineTwoQuestions != null) {
        final q1Raw = inlineTwoQuestions.group(1)!.trim();
        final q1NumMatch = RegExp(r'^(\d{1,2})[\.\)]\s+(.+)$').firstMatch(q1Raw);
        mergedBlocks.add({
          ...blk,
          'num': q1NumMatch != null ? int.parse(q1NumMatch.group(1)!) : null,
          'text': q1NumMatch != null ? q1NumMatch.group(2)!.trim() : q1Raw,
          'isSectionHeader': true,
        });
        mergedBlocks.add({
          ...blk,
          'num': int.parse(inlineTwoQuestions.group(2)!),
          'text': inlineTwoQuestions.group(3)!.trim(),
          'isSectionHeader': true,
        });
        bIdx++;
        continue;
      }

      final inlineNum = RegExp(r'^(\d{1,2})[\.\)]?\s+([A-Z].+)$').firstMatch(txt);
      final badgeNum = blk['badgeNumber'] as int?;
      final fontSize = blk['fontSize'] as double;
      final isAllBold = blk['isAllBold'] == true;
      final isBold = blk['isBold'] == true;
      final isDistinctHeadingFont = blk['isDistinctHeadingFont'] == true;
      final isLargerHeaderFont = fontSize >= bodyFontSize + 1.8;

      if (badgeNum != null && _isPlausibleHeadingText(txt)) {
        mergedBlocks.add({
          ...blk,
          'num': badgeNum,
          'text': txt,
          'isSectionHeader': true,
        });
      } else if (inlineNum != null &&
          (isBold ||
              isDistinctHeadingFont ||
              fontSize >= bodyFontSize + 0.8 ||
              txt.endsWith('?')) &&
          _isPlausibleHeadingText(inlineNum.group(2)!)) {
        mergedBlocks.add({
          ...blk,
          'num': int.parse(inlineNum.group(1)!),
          'text': inlineNum.group(2)!.trim(),
          'isSectionHeader': true,
        });
      } else if (_isPlausibleHeadingText(txt) &&
          ((isDistinctHeadingFont &&
                  txt.length <= 125 &&
                  (txt.endsWith('?') || txt.endsWith(':') || !txt.endsWith('.'))) ||
              (isLargerHeaderFont && txt.length <= 95 && !txt.endsWith('.')) ||
              (isAllBold &&
                  txt.length <= 95 &&
                  (txt.endsWith('?') ||
                      txt.endsWith(':') ||
                      (txt == txt.toUpperCase() && txt.length >= 6) ||
                      (txt.split(RegExp(r'\s+')).length <= 8 && !txt.endsWith('.')))))) {
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

    // 4. Separate Intro, Sections (never overwriting duplicate section numbers!), and Closing Decision
    final introBlocks = <Map<String, dynamic>>[];
    final rawSectionsList = <Map<String, dynamic>>[];
    final decisionQuestions = <String>[];

    Map<String, dynamic>? activeSec;
    for (final blk in mergedBlocks) {
      final txt = blk['text'] as String;
      if (blk['isSectionHeader'] == true) {
        // Closing personal decision question ("Do you...", "Will you...", "Would you...")
        if (blk['num'] == null &&
            RegExp(r'^(Do you |Will you |Would you )', caseSensitive: false)
                .hasMatch(txt) &&
            txt.endsWith('?')) {
          decisionQuestions.add(txt);
          continue;
        }
        activeSec = {
          'num': blk['num'],
          'order': rawSectionsList.length,
          'title': txt,
          'children': <Map<String, dynamic>>[],
        };
        rawSectionsList.add(activeSec);
      } else {
        if (activeSec == null) {
          introBlocks.add(blk);
        } else {
          (activeSec['children'] as List<Map<String, dynamic>>).add(blk);
        }
      }
    }

    // Remove empty shell sections (e.g. a heading with zero children followed immediately by another heading)
    // by folding consecutive header-only blocks into the next section's title or dropping pure noise headers
    final cleanedSections = <Map<String, dynamic>>[];
    for (int i = 0; i < rawSectionsList.length; i++) {
      final sec = rawSectionsList[i];
      final children = sec['children'] as List<Map<String, dynamic>>;
      if (children.isEmpty) {
        // Keep question headings only if there is no adjacent body, otherwise skip empty shells
        final title = sec['title'] as String;
        if (title.endsWith('?') && sec['num'] != null) {
          cleanedSections.add(sec);
        }
        continue;
      }
      cleanedSections.add(sec);
    }

    // Helper to create clean readable titles when chunking pure-narrative tracts
    String makeCleanChunkTitle(String text, int index) {
      final clean = text.trim();
      // Prefer a short question sentence if present at the start
      final qMatch = RegExp(r'^([A-Z][^.!?]{8,75}\?)').firstMatch(clean);
      if (qMatch != null) return qMatch.group(1)!.trim();
      // Otherwise look for the first complete capitalized sentence
      for (final sent in clean.split(RegExp(r'(?<=[.!?])\s+'))) {
        final s = sent.trim().replaceAll(RegExp(r'["()]'), '').trim();
        if (s.length >= 10 &&
            s.length <= 68 &&
            RegExp(r'^[A-Z]').hasMatch(s) &&
            !s.endsWith(',')) {
          return s.replaceAll(RegExp(r'[.]+$'), '').trim();
        }
      }
      // Fallback: clean capitalized lead-in words without trailing punctuation/connectors
      final lead = clean.replaceFirst(RegExp(r'^[^A-Z]+'), '').trim();
      final words = lead
          .replaceAll(RegExp(r'["(),;:]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .take(7)
          .toList();
      while (words.length > 3 &&
          RegExp(r'^(?:the|a|an|of|to|in|for|with|by|and|or|but|that|which|his|her|their|its|as|at|on)$',
                  caseSensitive: false)
              .hasMatch(words.last)) {
        words.removeLast();
      }
      if (words.length >= 3) {
        var candidate = words.join(' ');
        if (candidate.length > 56) {
          candidate = '${candidate.substring(0, 53).trim()}...';
        }
        return candidate;
      }
      return 'Study Section $index';
    }

    // If a large tract ended up with 0 sections (pure narrative) OR 1 giant monolithic section (>= 6 blocks),
    // chunk paragraphs into 4-8 clean readable study sections so nothing gets lost or shattered!
    List<Map<String, dynamic>> orderedSections;
    if (cleanedSections.isEmpty && introBlocks.isNotEmpty) {
      final introCount = introBlocks.length > 3 ? 1 : 0;
      final realIntro = introBlocks.take(introCount).toList();
      final bodyBlocks = introBlocks.skip(introCount).toList();
      introBlocks
        ..clear()
        ..addAll(realIntro);

      final targetSectionCount = bodyBlocks.length <= 4 ? bodyBlocks.length : 6;
      final chunkSize = max(1, (bodyBlocks.length / targetSectionCount).ceil());
      orderedSections = [];
      int secNum = 1;
      for (int i = 0; i < bodyBlocks.length; i += chunkSize) {
        final chunk = bodyBlocks.sublist(i, min(i + chunkSize, bodyBlocks.length));
        orderedSections.add({
          'num': secNum,
          'order': secNum - 1,
          'title': makeCleanChunkTitle(chunk.first['text'] as String, secNum),
          'children': chunk,
        });
        secNum++;
      }
    } else if (cleanedSections.length == 1 &&
        (cleanedSections.first['children'] as List<Map<String, dynamic>>).length >= 6) {
      final kids = cleanedSections.first['children'] as List<Map<String, dynamic>>;
      final chunkSize = max(3, (kids.length / 6).ceil());
      orderedSections = [];
      int secNum = 1;
      for (int i = 0; i < kids.length; i += chunkSize) {
        final chunk = kids.sublist(i, min(i + chunkSize, kids.length));
        orderedSections.add({
          'num': secNum,
          'order': secNum - 1,
          'title': secNum == 1
              ? (cleanedSections.first['title'] as String)
              : makeCleanChunkTitle(chunk.first['text'] as String, secNum),
          'children': chunk,
        });
        secNum++;
      }
    } else {
      // Preserve logical order: if numbered sections exist, sort numbered ones 1..N stably, then unnumbered
      final numbered = cleanedSections.where((s) => s['num'] != null).toList()
        ..sort((a, b) {
          final cmp = (a['num'] as int).compareTo(b['num'] as int);
          return cmp != 0 ? cmp : (a['order'] as int).compareTo(b['order'] as int);
        });
      final unnumbered = cleanedSections.where((s) => s['num'] == null).toList();
      orderedSections = [...numbered, ...unnumbered];
    }

    // Never drop excess intro paragraphs: if > 2 paragraphs landed in introBlocks before the first heading,
    // keep the first as introSummary and promote the rest into an Opening Overview section!
    if (introBlocks.length > 2) {
      final overflow = introBlocks.sublist(1);
      final firstIntro = introBlocks.first;
      introBlocks
        ..clear()
        ..add(firstIntro);
      orderedSections.insert(0, {
        'num': null,
        'order': -1,
        'title': 'Introduction & Background',
        'children': overflow,
      });
    }

    // Build Interactive Sections + Clean Markdown
    final seed = detectedTitle.codeUnits.fold<int>(0, (p, e) => p + e);
    final palettes = LessonColorPalette.brandPalettes;
    final primaryPalette = palettes[seed % palettes.length];

    final interactiveSections = <ExtractedLessonSection>[];
    final headings = <String>[];
    final mdBuf = StringBuffer('# $detectedTitle\n\n');

    final introTexts = introBlocks
        .map((b) => b['text'] as String)
        .where((t) => t.isNotEmpty)
        .toList();
    final introSummary = introTexts.isNotEmpty ? introTexts.first : '';
    final introHighlight =
        introTexts.length > 1 ? introTexts.sublist(1).join('\n\n') : null;

    if (introSummary.isNotEmpty) mdBuf.writeln('$introSummary\n');
    if (introHighlight != null && introHighlight.isNotEmpty) {
      mdBuf.writeln('$introHighlight\n');
    }

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
      if (parsed.highlightNote != null && parsed.highlightNote!.isNotEmpty) {
        mdBuf.writeln(parsed.highlightNote);
      }
      if (parsed.testimony != null && (parsed.testimony!['text'] ?? '').isNotEmpty) {
        mdBuf.writeln('"${parsed.testimony!['text']}" (${parsed.testimony!['title'] ?? ''})');
      }
      for (final st in parsed.steps) {
        mdBuf.writeln('- **${st['title']}** ${st['text']}');
      }
      for (final qa in parsed.qaItems) {
        mdBuf.writeln('- **${qa['letter']}. ${qa['question']}** ${qa['text']}');
      }
      for (final ck in parsed.checklistItems) {
        mdBuf.writeln('- ${ck['label']}');
      }
      mdBuf.writeln();
    }

    final fullBody = mdBuf.toString().trim();
    final wordCount =
        fullBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final estMinutes = max(10, 5 * ((wordCount / 130) / 5).round());
    final estimatedReadTime = '$estMinutes–${estMinutes + 5} mins';

    // Real automatic extraction quality diagnostics (`reviewNotes`)
    if (rawInputWordCount > 40) {
      final retentionRatio = wordCount / rawInputWordCount;
      if (retentionRatio < 0.85) {
        reviewNotes.add(
          'Low word retention (${(retentionRatio * 100).toStringAsFixed(1)}%: $wordCount of $rawInputWordCount raw words). Please verify no content was missed.',
        );
      } else if (retentionRatio > 1.20) {
        reviewNotes.add(
          'Word count expanded (${(retentionRatio * 100).toStringAsFixed(1)}%). Check for duplicated headings or repeated fragments.',
        );
      }
    }
    if (interactiveSections.isEmpty) {
      reviewNotes.add('No structured study sections were detected.');
    }
    final emptySecs = interactiveSections
        .where((s) =>
            s.bodyText.isEmpty &&
            s.verseQuotes.isEmpty &&
            s.steps.isEmpty &&
            s.qaItems.isEmpty &&
            s.checklistItems.isEmpty &&
            s.tableData == null &&
            s.testimony == null &&
            (s.highlightNote == null || s.highlightNote!.isEmpty))
        .length;
    if (emptySecs > 0) {
      reviewNotes.add('$emptySecs section(s) have a heading without extracted body content.');
    }

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
      reviewNotes: reviewNotes,
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
      reviewNotes: reviewNotes,
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
