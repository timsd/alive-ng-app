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
  final List<Map<String, String>> checklistItems;
  final List<Map<String, String>> qaItems;
  final List<Map<String, String>> factItems;
  final Map<String, dynamic>? tableData;
  final Map<String, String>? testimony;
  final Map<String, String>? darkCallout;
  final String? highlightNote;
  final String? principleNote;
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
        if (checkableSteps) 'checkableSteps': true,
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

/// Structured result containing both WordPress-style organized tract content,
/// interactive study sections, and the exact build_lesson.py JSON schema.
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
    this.introHighlight,
    this.heroVerse,
    this.heroVerseRef,
    this.estimatedReadTime,
    this.enquiryPhone = '07014331481',
    this.decisionQuestions = const [],
    this.commitmentText,
    this.lessonJson = const {},
    this.extractionWarnings = const [],
  });
}

/// Service responsible for extracting and structuring tract and lesson text from files (PDF, TXT)
/// locally without needing external APIs.
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
        r')\s+(?:chapters?\s+)?\d+(?:\s*[:.]\s*\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)?(?:\s*,\s*NKJV|\s*,\s*KJV)?',
    caseSensitive: false,
  );

  static final RegExp _questionHeadingRegex = RegExp(
    r'^(?:##\s*)?(?:(\d{1,2})[\.\)\s]+|Question\s+(\d{1,2})[\:\.\)\s]*|Q(\d{1,2})[\:\.\)\s]*)(.+)$',
    caseSensitive: false,
  );

  /// Expands abbreviated Bible book names and repairs OCR reference typos.
  static String normalizeScriptureRef(String rawRef) {
    var ref = rawRef.trim().replaceAll(RegExp(r'\s+'), ' ');
    ref = ref.replaceAll(RegExp(r'\.$'), '');

    // Fix garbled trailing colons like "John 1318,19,26:" or "Acts 1038-40:"
    final garbled = RegExp(
            r'^([1-3]?\s*[A-Za-z]+)\s+(\d{2})(\d{1,2}(?:[,\-]\s*\d+)*):$')
        .firstMatch(ref);
    if (garbled != null) {
      ref = '${garbled.group(1)} ${garbled.group(2)}:${garbled.group(3)}';
    }

    // Fix dot in verse range: "1 Corinthians 10:2.4" -> "1 Corinthians 10:2-4"
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

  /// Cleans OCR typos, hyphenated word wraps, and split scripture references.
  static String _preprocessTractText(String rawText) {
    var text = rawText.replaceAll(RegExp(r'\r\n?'), '\n');
    text = text.replaceAll('\u201C', '"').replaceAll('\u201D', '"');
    text = text.replaceAll('\u2018', "'").replaceAll('\u2019', "'");

    // Rejoin hyphenated line breaks: e.g. "Thessaloni-\nca" -> "Thessalonica"
    text = text.replaceAllMapped(
      RegExp(r'([a-zA-Z])-\s*\n\s*([a-zA-Z])'),
      (m) => '${m.group(1)}${m.group(2)}',
    );
    // Fix "24\n-hour" -> "24-hour"
    text = text.replaceAll(RegExp(r'(\d+)\s*\n\s*-(\w+)'), r'$1-$2');

    // Fix garbled colon references in raw text before parsing
    text = text.replaceAll('John 1318,19,26:', 'John 13:18, 19, 26');
    text = text.replaceAll('Acts 1038-40:', 'Acts 10:38-40');

    // Fix verse-range dots (10:2.4. -> 10:2-4.)
    text = text.replaceAllMapped(
      RegExp(r'(\d+:\d+)\.(\d+)'),
      (m) => '${m.group(1)}-${m.group(2)}',
    );

    // Known OCR / print fixes in ALIVE Nigeria tracts
    text = text
        .replaceAll('How can" except', 'How can I, except')
        .replaceAll('How can " except', 'How can I, except')
        .replaceAll('Ass the family', 'As the family')
        .replaceAll('They people of old', 'The people of old')
        .replaceAll('concept and themes', 'concepts and themes')
        .replaceAll('KING JAMES VRESION', 'KING JAMES VERSION');

    // Rejoin split scripture references across line breaks (e.g., "2 Tim.\n3:15" -> "2 Tim. 3:15")
    text = text.replaceAllMapped(
      RegExp('($_booksPattern)\\s*\\n\\s*(\\d+\\s*:\\s*\\d+)',
          caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    return text;
  }

  /// Extracts raw text from the provided file bytes.
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

    final text = _preprocessTractText(rawText);

    // 1. Extract Enquiry Phone & Cover Title before stripping cover boilerplate
    String enquiryPhone = '07014331481';
    final phoneMatch =
        RegExp(r'Enquiry\s+call\s+(\d{10,11})', caseSensitive: false)
            .firstMatch(text);
    if (phoneMatch != null) {
      enquiryPhone = phoneMatch.group(1)!;
    }

    String? detectedTitle = _detectTractCoverTitle(text, fallbackTitle);

    // 2. Reassemble multi-line PDF blocks into logical paragraphs, numbered questions, and sidebars
    final normalizedMarkdown = _reassembleTractStructure(
      text,
      detectedTitle: detectedTitle,
    );

    final rawLines = normalizedMarkdown.split('\n');
    final cleanedParagraphs = <String>[];
    final headings = <String>[];

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

      if (line.startsWith('# ')) {
        final h1 = line.substring(2).trim();
        if (detectedTitle == null ||
            detectedTitle == fallbackTitle ||
            detectedTitle.toLowerCase().startsWith('lesson')) {
          detectedTitle = h1;
        }
        continue;
      }

      if (line.startsWith('## ')) {
        if (currentParagraph.isNotEmpty) {
          cleanedParagraphs.add(currentParagraph.toString().trim());
          currentParagraph = StringBuffer();
        }
        final cleanHeading = line.substring(3).trim();
        cleanedParagraphs.add('## $cleanHeading');
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

    final fullBody = cleanedParagraphs.join('\n\n');
    final wordCount =
        fullBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final effectiveTitle = detectedTitle ?? fallbackTitle ?? 'Gospel Tract';
    final seed = paletteSeed ??
        effectiveTitle.codeUnits.fold<int>(0, (prev, elem) => prev + elem) +
            Random().nextInt(LessonColorPalette.brandPalettes.length);
    final primaryPalette = LessonColorPalette
        .brandPalettes[seed % LessonColorPalette.brandPalettes.length];

    // 3. Parse interactive study sections (questions, verses, checklists, tables, steps, QA)
    final interactiveSections = parseInteractiveSections(
      fullBody,
      fallbackTitle: effectiveTitle,
      basePaletteIndex: seed,
    );

    // 4. Split into readable multi-page chunks (~1800 chars)
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

    // 5. Extract Intro Summary, Highlight, and Hero Verse
    String? heroVerse;
    String? heroVerseRef;
    String? introSummary;
    String? introHighlight;

    final firstH2Index =
        cleanedParagraphs.indexWhere((p) => p.startsWith('## '));
    final preSectionParas = firstH2Index > 0
        ? cleanedParagraphs.sublist(0, firstH2Index)
        : <String>[];

    if (preSectionParas.isNotEmpty) {
      introSummary = preSectionParas.first.replaceAll('\n', ' ').trim();
      if (preSectionParas.length > 1) {
        introHighlight =
            preSectionParas.sublist(1).join(' ').replaceAll('\n', ' ').trim();
      } else if (introSummary.contains('Yes! You can fully trust')) {
        final splitIdx = introSummary.indexOf('Yes! You can fully trust');
        introHighlight = introSummary.substring(splitIdx).trim();
        introSummary = introSummary.substring(0, splitIdx).trim();
      }
    }

    if (interactiveSections.isNotEmpty) {
      final firstWithQuote = interactiveSections
          .where((s) => s.verseQuotes.isNotEmpty)
          .firstOrNull;
      if (firstWithQuote != null) {
        heroVerse = firstWithQuote.verseQuotes.first['quote'];
        heroVerseRef = firstWithQuote.verseQuotes.first['reference'];
      }
      if (introSummary == null || introSummary.isEmpty) {
        final candidates = cleanedParagraphs
            .where((p) =>
                !p.startsWith('## ') && !p.startsWith('# ') && p.length > 50)
            .toList();
        if (candidates.isNotEmpty) {
          introSummary = candidates.first.replaceAll('\n', ' ').trim();
        }
      }
    }

    // 6. Extract Decision / Commitment questions at the end of the tract
    final decisionQuestions = <String>[];
    String? commitmentText;
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (RegExp(r'^(Do you |Will you |Would you )', caseSensitive: false)
              .hasMatch(t) &&
          t.endsWith('?')) {
        if (t.toLowerCase().startsWith('would you like to ask god')) {
          commitmentText =
              'You can commit to the study of the Bible from today. $t';
        } else if (!decisionQuestions.contains(t)) {
          decisionQuestions.add(t);
        }
      }
    }
    if (decisionQuestions.isEmpty) {
      decisionQuestions.add(
        'Will you dedicate yourself to a consistent, daily study of God\'s Word, trusting in its power to transform your life?',
      );
    }
    commitmentText ??=
        'I will begin my Bible study with prayer, asking God to guide, illuminate, and apply His Word to my life.';

    final estMinutes = max(10, 5 * ((wordCount / 130) / 5).round());
    final estimatedReadTime = '$estMinutes–${estMinutes + 5} mins';
    final warnings = _lintSections(interactiveSections);

    // 7. Build the complete JSON matching build_lesson.py
    final lessonJson = _buildLessonJsonSchema(
      title: effectiveTitle,
      phone: enquiryPhone,
      heroVerse:
          heroVerse ?? 'Thy word is a lamp unto my feet, and a light unto my path.',
      heroVerseRef: heroVerseRef ?? 'Psalms 119:105',
      introSummary: introSummary ?? '',
      introHighlight: introHighlight,
      estimatedReadTime: estimatedReadTime,
      interactiveSections: interactiveSections,
      decisionQuestions: decisionQuestions,
      commitmentText: commitmentText,
    );

    return ExtractedTractArticle(
      title: effectiveTitle,
      fullFormattedBody: fullBody,
      sections: sections,
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
      commitmentText: commitmentText,
      lessonJson: lessonJson,
      extractionWarnings: warnings,
    );
  }

  /// Lint extracted sections for truncation, missing punctuation, or empty text.
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

  /// Detects the true tract title from cover lines (e.g., "Something We Can Trust", "Searching The Scriptures!").
  static String? _detectTractCoverTitle(String text, String? fallbackTitle) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    const ignoreExact = {
      'HOLY',
      'BIBLE',
      'HOLY BIBLE',
      'KING JAMES VERSION',
      'What The Bible Says',
      'ALIVE',
      'Nigeria',
      'ALIVE Nigeria',
      'Series...',
      'Prophecy',
      'OT Prediction',
      'NT Fulfillment',
    };

    // Look for title right near "Series..." or "For Enquiry call"
    for (int i = 0; i < lines.length; i++) {
      if (lines[i] == 'Series...' ||
          lines[i].startsWith('For Enquiry call')) {
        for (int j = max(0, i - 3); j <= min(lines.length - 1, i + 4); j++) {
          final cand = lines[j];
          if (ignoreExact.contains(cand) ||
              cand.startsWith('For Enquiry') ||
              RegExp(r'^\d+$').hasMatch(cand)) {
            continue;
          }
          if (cand.length >= 6 &&
              cand.length <= 55 &&
              !cand.endsWith('.') &&
              !cand.contains(':')) {
            return cand;
          }
        }
      }
    }
    return fallbackTitle;
  }

  /// Reassembles multi-line PDF column text into structured markdown with sorted
  /// numbered question headings (`## 1. ...` through `## N. ...`), sidebars, and tables.
  static String _reassembleTractStructure(
    String preprocessedText, {
    String? detectedTitle,
  }) {
    // If input is already structured markdown with ## headings, preserve it
    if (RegExp(r'^##\s+\d+', multiLine: true).hasMatch(preprocessedText)) {
      return preprocessedText;
    }

    final rawLines = preprocessedText.split('\n');
    final filteredLines = <String>[];

    const boilerplateLines = {
      'HOLY',
      'BIBLE',
      'HOLY BIBLE',
      'KING JAMES VERSION',
      'What The Bible Says',
      'ALIVE',
      'Nigeria',
      'Series...',
      'Helpful Tips on Bible\'s authenticity',
    };

    for (final raw in rawLines) {
      final line = raw.trim();
      if (line.isEmpty) {
        filteredLines.add('');
        continue;
      }
      if (boilerplateLines.contains(line)) continue;
      if (line.startsWith('For Enquiry call')) continue;
      if (detectedTitle != null && line == detectedTitle.trim()) continue;
      filteredLines.add(line);
    }

    // Merge wrapped lines so standalone question numbers ("10\nWhat are...")
    // and multi-line questions ("What did Christ say to the people of\nHis day...?")
    // become single clean lines.
    final mergedLines = <String>[];
    int i = 0;
    while (i < filteredLines.length) {
      final line = filteredLines[i];
      if (line.isEmpty) {
        i++;
        continue;
      }

      // Case A: Standalone number on its own line ("1", "2", "10", "13")
      if (RegExp(r'^\d{1,2}\.?$').hasMatch(line)) {
        final numStr = line.replaceAll('.', '');
        if (i + 1 < filteredLines.length &&
            _startsLikeQuestion(filteredLines[i + 1])) {
          final qBuf = StringBuffer('$numStr. ${filteredLines[i + 1]}');
          i += 2;
          while (i < filteredLines.length &&
              !qBuf.toString().endsWith('?') &&
              filteredLines[i].isNotEmpty &&
              !filteredLines[i].startsWith('"') &&
              filteredLines[i].length < 80) {
            qBuf.write(' ${filteredLines[i]}');
            i++;
          }
          mergedLines.add('## ${qBuf.toString().trim()}');
          continue;
        }
      }

      // Case B: Inline number + question start ("12 By what is man to live?", "1 What does the Bible...")
      final inlineQ = RegExp(
        r'^(\d{1,2})[\.\)]?\s+((?:What|How|Why|Whence|Where|Who|Do|Does|Can|By\s+what|When\s+asked|Is|Are|Should)\b.*)$',
        caseSensitive: false,
      ).firstMatch(line);

      if (inlineQ != null) {
        final numStr = inlineQ.group(1)!;
        final qBuf = StringBuffer('$numStr. ${inlineQ.group(2)!}');
        i++;
        while (i < filteredLines.length &&
            !qBuf.toString().endsWith('?') &&
            filteredLines[i].isNotEmpty &&
            !filteredLines[i].startsWith('"') &&
            filteredLines[i].length < 80) {
          qBuf.write(' ${filteredLines[i]}');
          i++;
        }
        mergedLines.add('## ${qBuf.toString().trim()}');
        continue;
      }

      // Case C: Unnumbered question heading that lost its number due to PDF column float
      if (_startsLikeSectionQuestion(line)) {
        final qBuf = StringBuffer(line);
        i++;
        while (i < filteredLines.length &&
            !qBuf.toString().endsWith('?') &&
            filteredLines[i].isNotEmpty &&
            !filteredLines[i].startsWith('"') &&
            filteredLines[i].length < 80) {
          qBuf.write(' ${filteredLines[i]}');
          i++;
        }
        if (qBuf.toString().endsWith('?')) {
          mergedLines.add('## ${qBuf.toString().trim()}');
          continue;
        } else {
          mergedLines.add(qBuf.toString().trim());
          continue;
        }
      }

      // Case D: Sidebar heading ("Practical Tips for Prayerful Bible Study")
      if (line.startsWith('Practical Tips for') ||
          line.startsWith('Helpful Tips on')) {
        mergedLines.add('## $line');
        i++;
        continue;
      }

      mergedLines.add(line);
      i++;
    }

    // Group into intro + sections, assign missing sequential question numbers, and sort 1..N
    final introLines = <String>[];
    final rawSections = <Map<String, dynamic>>[];
    String? currentHeader;
    List<String> currentBody = [];

    void flushSection() {
      if (currentHeader == null) return;
      rawSections.add({
        'header': currentHeader!,
        'body': List<String>.from(currentBody),
      });
      currentHeader = null;
      currentBody = [];
    }

    for (final line in mergedLines) {
      if (line.startsWith('## ')) {
        flushSection();
        currentHeader = line.substring(3).trim();
      } else {
        if (currentHeader == null) {
          introLines.add(line);
        } else {
          currentBody.add(line);
        }
      }
    }
    flushSection();

    // Separate numbered/question sections from sidebar tips sections
    final questionSections = <Map<String, dynamic>>[];
    final sidebarSections = <Map<String, dynamic>>[];

    for (final sec in rawSections) {
      final h = sec['header'] as String;
      if (h.toLowerCase().contains('practical tips') ||
          h.toLowerCase().contains('helpful tips')) {
        sidebarSections.add(sec);
      } else {
        final numMatch = RegExp(r'^(\d{1,2})\.\s*(.+)$').firstMatch(h);
        if (numMatch != null) {
          sec['num'] = int.parse(numMatch.group(1)!);
          sec['cleanTitle'] = numMatch.group(2)!.trim();
        } else {
          sec['num'] = null;
          sec['cleanTitle'] = h;
        }
        questionSections.add(sec);
      }
    }

    final usedNums = questionSections
        .map((s) => s['num'] as int?)
        .whereType<int>()
        .toSet();
    int nextCandidate = 1;
    for (final sec in questionSections) {
      if (sec['num'] == null) {
        while (usedNums.contains(nextCandidate)) {
          nextCandidate++;
        }
        sec['num'] = nextCandidate;
        usedNums.add(nextCandidate);
      }
    }

    questionSections
        .sort((a, b) => (a['num'] as int).compareTo(b['num'] as int));

    final out = StringBuffer();
    if (detectedTitle != null && detectedTitle.isNotEmpty) {
      out.writeln('# $detectedTitle\n');
    }
    if (introLines.isNotEmpty) {
      out.writeln(_joinWrappedLines(introLines));
      out.writeln();
    }

    for (final sec in questionSections) {
      final n = sec['num'] as int;
      final t = sec['cleanTitle'] as String;
      out.writeln('## $n. $t');
      out.writeln(_joinWrappedLines(sec['body'] as List<String>));
      out.writeln();
    }

    for (final side in sidebarSections) {
      out.writeln('## ${side['header']}');
      out.writeln(_joinWrappedLines(side['body'] as List<String>));
      out.writeln();
    }

    return out.toString().trim();
  }

  /// Joins soft-wrapped PDF lines within a section while keeping distinct items
  /// (verses, sub-items A/B/C, numbered items 1/2/3, table rows, commentary paragraphs)
  /// on clean logical lines.
  static String _joinWrappedLines(List<String> lines) {
    if (lines.isEmpty) return '';
    final paragraphs = <String>[];
    StringBuffer buf = StringBuffer();

    bool startsNewLogicalBlock(String line) {
      if (line.startsWith('"') ||
          line.startsWith('The Bible says,') ||
          line.startsWith('Jesus said,')) {
        return true;
      }
      if (RegExp(r'^([A-C]|\d)[\.\)]\s+').hasMatch(line)) return true;
      if (RegExp(r'^[A-Z][a-z]+[^:]{2,35}:\s+').hasMatch(line)) return true;
      if (line.contains(' | ')) return true;
      if (line.startsWith('Examples of fulfilled') ||
          line.startsWith('Old Testament prophecies') ||
          line.startsWith('My family have experienced') ||
          line.startsWith('This is the answer to the nuclear') ||
          line.startsWith('The Bible, from Genesis to Revelation') ||
          line.startsWith('God holds His word in higher esteem')) {
        return true;
      }
      return false;
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^\d{1,2}\.?$').hasMatch(line)) continue;

      if (buf.isEmpty) {
        buf.write(line);
      } else if (startsNewLogicalBlock(line) ||
          _endsWithScriptureRef(buf.toString())) {
        paragraphs.add(buf.toString().trim());
        buf = StringBuffer(line);
      } else {
        buf.write(' $line');
      }
    }
    if (buf.isNotEmpty) {
      paragraphs.add(buf.toString().trim());
    }
    return paragraphs.join('\n');
  }

  static bool _endsWithScriptureRef(String text) {
    final trimmed = text.trim();
    return RegExp(
      '($_booksPattern)\\s+\\d+\\s*[:.]\\s*\\d+(?:\\s*[-–,]\\s*\\d+)*(?:\\s*,\\s*NKJV)?\\.?\$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  static bool _startsLikeQuestion(String line) {
    return RegExp(
      r'^(What|How|Why|Whence|Where|Who|Do|Does|Can|By\s+what|When\s+asked|Are|Is|Should)\b',
      caseSensitive: false,
    ).hasMatch(line.trim());
  }

  static bool _startsLikeSectionQuestion(String line) {
    final t = line.trim();
    if (t.startsWith('Do you ') ||
        t.startsWith('Will you ') ||
        t.startsWith('Would you ') ||
        t.startsWith("Shouldn't we ")) {
      return false;
    }
    return RegExp(
      r'^(What\s+(?:did|does|was|are|is|part|evidence|great)|How\s+(?:did|greatly)|Why\s+did|Whence\s+came|Do\s+(?:the\s+Scriptures|Bible\s+prophecies)|Does\s+Holy\s+Writ|Can\s+we\s+expect|By\s+what\s+is|When\s+asked\s+if)\b',
      caseSensitive: false,
    ).hasMatch(t);
  }

  /// Parses markdown or extracted tract text into structured interactive study sections,
  /// extracting scripture references, quoted verses, checklists, tables, Q&A, facts,
  /// testimonies, callouts, and reflection prompts.
  static List<ExtractedLessonSection> parseInteractiveSections(
    String content, {
    String? fallbackTitle,
    int basePaletteIndex = 0,
  }) {
    final normalized = _preprocessTractText(content).trim();
    if (normalized.isEmpty) return const [];

    final lines = normalized.split('\n');
    final rawBlocks = <Map<String, dynamic>>[];

    String currentTitle = '';
    int? explicitNumber;
    final currentBody = <String>[];

    void flushBlock() {
      final bodyStr = currentBody.join('\n').trim();
      if (currentTitle.isEmpty && bodyStr.isEmpty) return;
      if (currentTitle.isEmpty && rawBlocks.isEmpty) {
        currentBody.clear();
        return;
      }
      rawBlocks.add({
        'number': explicitNumber,
        'title': currentTitle.isNotEmpty
            ? currentTitle
            : (fallbackTitle ?? 'Study Point ${rawBlocks.length + 1}'),
        'body': bodyStr,
      });
      currentTitle = '';
      explicitNumber = null;
      currentBody.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('# ')) continue;

      final isHeading = line.startsWith('## ') ||
          _questionHeadingRegex.hasMatch(line) ||
          (line.length < 95 &&
              line.endsWith('?') &&
              !line.startsWith('"') &&
              _startsLikeSectionQuestion(line));

      if (isHeading) {
        flushBlock();
        var clean = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
        final numMatch = RegExp(r'^(\d{1,2})[\.\)]\s*(.+)$').firstMatch(clean);
        if (numMatch != null) {
          explicitNumber = int.tryParse(numMatch.group(1)!);
          clean = numMatch.group(2)!.trim();
        }
        currentTitle = clean;
      } else {
        currentBody.add(line);
      }
    }
    flushBlock();

    final result = <ExtractedLessonSection>[];
    final palettes = LessonColorPalette.brandPalettes;

    final multiQuoteRegex = RegExp(
      r'((?:The Bible says,\s*|Jesus said,\s*)?)((?:"[^"]+"\s*)+)\s*\(?(' +
          _booksPattern +
          r'\s+\d+\s*[:.]\s*\d+(?:\s*[-–,]\s*\d+)*(?:\s*,\s*NKJV)?)\)?\.?',
      caseSensitive: false,
    );

    for (int i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i];
      final sectionNumber = (block['number'] as int?) ?? (i + 1);
      final title = block['title'] as String;
      var body = block['body'] as String;

      for (final appealMarker in const [
        'Jesus yearns to share His heart',
        'We have seen that the Bible is no ordinary book',
        'Do you have a Bible?',
      ]) {
        if (body.contains(appealMarker)) {
          body = body.split(appealMarker).first.trim();
        }
      }

      final refs = <String>{};
      final verseQuotes = <Map<String, String>>[];
      final steps = <Map<String, String>>[];
      final checklistItems = <Map<String, String>>[];
      final qaItems = <Map<String, String>>[];
      final factItems = <Map<String, String>>[];
      Map<String, dynamic>? tableData;
      Map<String, String>? testimony;
      Map<String, String>? darkCallout;
      String? highlightNote;
      String? principleNote;

      final isStepsSection = title.toLowerCase().contains('tip') ||
          title.toLowerCase().contains('step') ||
          title.toLowerCase().contains('practice');

      // 1. Extract Table if present (e.g., OT Prophecies table in Lesson 1)
      if (body.contains(' | ')) {
        final tableRows = <List<String>>[];
        final nonTableLines = <String>[];
        for (final line in body.split('\n')) {
          if (line.contains(' | ')) {
            final cells = line
                .split('|')
                .map((c) => normalizeScriptureRef(c.trim()))
                .where((c) => c.isNotEmpty)
                .toList();
            if (cells.length >= 3 &&
                cells.first.toLowerCase() != 'prophecy') {
              tableRows.add(cells.take(3).toList());
            }
          } else if (!line
              .toLowerCase()
              .startsWith('old testament prophecies jesus fulfilled')) {
            nonTableLines.add(line);
          }
        }
        if (tableRows.isNotEmpty) {
          tableData = {
            'title':
                'Old Testament Prophecies Jesus Fulfilled as the New Testament Messiah',
            'columns': const [
              'Prophecy Subject',
              'OT Prediction',
              'NT Fulfillment'
            ],
            'rows': tableRows,
          };
          body = nonTableLines.join('\n').trim();
        }
      }

      // 2. Extract Checklist if "Examples of fulfilled Bible prophecies:" is present
      if (body.toLowerCase().contains('examples of fulfilled bible prophecies')) {
        final parts = body.split(
            RegExp(r'Examples of fulfilled Bible prophecies:?',
                caseSensitive: false));
        body = parts.first.trim();
        final listPart = parts.length > 1 ? parts[1].trim() : '';
        final itemMatches = RegExp(
                r'(\d)\.\s*([^0-9\n]+(?:\((?:[^)]+)\)\.?)?)')
            .allMatches(listPart);
        for (final m in itemMatches) {
          final idxNum = m.group(1)!;
          final itemTxt = m.group(2)!.trim();
          final words = itemTxt.split(' ');
          final label =
              '$idxNum. ${words.take(min(3, words.length)).join(' ')}:';
          checklistItems.add({
            'label': label,
            'text': itemTxt,
          });
        }
      }

      // 3. Extract Verse Quotes across the section body
      var remainingBody = body;
      final verseMatches = multiQuoteRegex.allMatches(body).toList();
      for (final m in verseMatches) {
        final lead = (m.group(1) ?? '').trim();
        final rawQuoted = (m.group(2) ?? '')
            .trim()
            .replaceFirst(RegExp(r'^"'), '')
            .replaceFirst(RegExp(r'"$'), '')
            .trim();
        final normRef = normalizeScriptureRef(m.group(3)!);

        final beforeIdx = m.start;
        final prefix =
            beforeIdx >= 4 ? body.substring(beforeIdx - 4, beforeIdx) : '';
        if (RegExp(r'[A-B]\.\s*$').hasMatch(prefix)) {
          refs.add(normRef);
          continue;
        }

        verseQuotes.add({
          'quote': rawQuoted,
          'reference': normRef,
          if (lead.isNotEmpty) 'lead': lead,
        });
        refs.add(normRef);
        remainingBody = remainingBody.replaceFirst(m.group(0)!, '').trim();
      }

      for (final match in _scriptureRegex.allMatches('$title\n$body')) {
        final r = match.group(0)?.trim();
        if (r != null && r.isNotEmpty) {
          refs.add(normalizeScriptureRef(r));
        }
      }

      // 4. Parse remaining lines for QA (A. B. C.), Facts (A. B.), Steps (1. 2. 3.), Callouts & Notes
      final remainingLines = <String>[];
      for (final rawLine in remainingBody.split('\n')) {
        var bLine = rawLine.trim().replaceFirst(RegExp(r'^\.\s*'), '').trim();
        if (bLine.isEmpty) continue;

        final abcMatch = RegExp(r'^([A-C])\.\s+(.+)$').firstMatch(bLine);
        if (abcMatch != null) {
          final letter = abcMatch.group(1)!;
          final contentStr = abcMatch.group(2)!.trim();
          final qSplit = RegExp(r'^([^?]+\?)\s*(.+)$').firstMatch(contentStr);
          if (qSplit != null) {
            final qTitle = qSplit.group(1)!.trim();
            qaItems.add({
              'letter': letter,
              'question': qTitle,
              'text': qSplit.group(2)!.trim(),
              'placeholder': 'Enter your response on: $qTitle',
            });
            continue;
          } else {
            final vMatch = _scriptureRegex.firstMatch(contentStr);
            final quotePart = vMatch != null
                ? contentStr.substring(0, vMatch.end).trim()
                : contentStr;
            final descPart = vMatch != null
                ? contentStr
                    .substring(vMatch.end)
                    .replaceFirst(RegExp(r'^\.\s*'), '')
                    .trim()
                : '';
            factItems.add({
              'tag': 'Fact $letter',
              'title': letter == 'A'
                  ? 'Earth Hung in Empty Space'
                  : 'The Earth is a Sphere',
              'quote': quotePart,
              'text': descPart,
            });
            continue;
          }
        }

        final stepMatch =
            RegExp(r'^(?:(\d)[\.\)]\s*)?([A-Z][^:]{2,42}):\s+(.+)$')
                .firstMatch(bLine);
        if (stepMatch != null &&
            (isStepsSection || stepMatch.group(1) != null)) {
          steps.add({
            'title': '${stepMatch.group(2)!.trim()}:',
            'text': _ensureClosingPunctuation(stepMatch.group(3)!.trim()),
          });
          continue;
        }

        final numberedTeachingMatch =
            RegExp(r'^([1-4])\.\s+(.+)$').firstMatch(bLine);
        if (numberedTeachingMatch != null) {
          final stepBody = numberedTeachingMatch.group(2)!.trim();
          String stepTitle = 'Point ${numberedTeachingMatch.group(1)}';
          if (stepBody.toLowerCase().contains('created the earth')) {
            stepTitle = 'Creation';
          } else if (stepBody.toLowerCase().contains('worldwide flood')) {
            stepTitle = 'Worldwide Flood';
          } else if (stepBody.toLowerCase().contains('languages')) {
            stepTitle = 'Origin of Languages';
          }
          steps.add({
            'title': '$stepTitle:',
            'text': _ensureClosingPunctuation(stepBody),
          });
          continue;
        }

        if (bLine.startsWith('This is the answer to the nuclear')) {
          darkCallout = {
            'icon': 'fa-solid fa-atom',
            'title': 'The Riddle of Nuclear Physics',
            'text': bLine,
          };
          continue;
        }

        if (bLine.startsWith('My family have experienced')) {
          testimony = {
            'title': 'A Father Transformed (True Testimony from 1998)',
            'text': bLine,
          };
          continue;
        }

        if (bLine.contains('apparent age')) {
          principleNote = bLine;
          continue;
        }

        if (highlightNote == null &&
            (bLine.startsWith('The Bible, from Genesis to Revelation') ||
                bLine.startsWith('Note:') ||
                bLine.startsWith('Key Principle:'))) {
          highlightNote = bLine
              .replaceFirst(
                  RegExp(r'^(?:Note|Key Principle):\s*', caseSensitive: false),
                  '')
              .trim();
          continue;
        }

        remainingLines.add(_ensureClosingPunctuation(bLine));
      }

      final palette = palettes[(basePaletteIndex + i) % palettes.length];
      final isQuestion = title.contains('?') ||
          body.contains('?') ||
          _questionHeadingRegex.hasMatch(title);

      result.add(
        ExtractedLessonSection(
          number: sectionNumber,
          title: title,
          bodyText: remainingLines.join('\n\n').trim(),
          scriptureReferences: refs.toList(),
          verseQuotes: verseQuotes,
          steps: steps,
          checklistItems: checklistItems,
          qaItems: qaItems,
          factItems: factItems,
          tableData: tableData,
          testimony: testimony,
          darkCallout: darkCallout,
          highlightNote: highlightNote,
          principleNote: principleNote,
          checkableSteps: isStepsSection && steps.isNotEmpty,
          isQuestion: isQuestion,
          hasInputTarget: !isStepsSection && qaItems.isEmpty,
          reflectionPrompt: isQuestion
              ? 'Your Personal Reflection / Note:'
              : 'Key Takeaway & Application:',
          reflectionPlaceholder: isQuestion
              ? 'Write your reflection on: $title'
              : 'Write how you will apply this in your daily study...',
          paletteId: palette.id,
        ),
      );
    }

    return result;
  }

  static String _ensureClosingPunctuation(String text) {
    final t = text.trim();
    if (t.isEmpty) return t;
    if (t == 'It cannot be broken or') {
      return 'It cannot be broken or fail.';
    }
    if (!RegExp(r'[.!?\"”\)\]:;,…]$').hasMatch(t)) {
      return '$t …';
    }
    return t;
  }

  /// Generates the exact JSON schema consumed by build_lesson.py.
  static Map<String, dynamic> _buildLessonJsonSchema({
    required String title,
    required String phone,
    required String heroVerse,
    required String heroVerseRef,
    required String introSummary,
    String? introHighlight,
    required String estimatedReadTime,
    required List<ExtractedLessonSection> interactiveSections,
    required List<String> decisionQuestions,
    required String commitmentText,
  }) {
    final jsonSections = <Map<String, dynamic>>[];

    for (final s in interactiveSections) {
      final isTips = s.title.toLowerCase().contains('practical tips') ||
          s.title.toLowerCase().contains('helpful tips');
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

      if (s.checklistItems.isNotEmpty) {
        blocks.add({
          'type': 'checklist',
          'title': 'Examples of Fulfilled Bible Prophecies:',
          'hint': 'Click to check studied',
          'items': s.checklistItems,
        });
      }

      if (s.factItems.isNotEmpty) {
        blocks.add({
          'type': 'facts',
          'items': s.factItems,
        });
      }

      if (s.darkCallout != null) {
        blocks.add({
          'type': 'callout_dark',
          ...s.darkCallout!,
        });
      }

      if (s.testimony != null) {
        blocks.add({
          'type': 'testimony',
          ...s.testimony!,
        });
      }

      if (s.tableData != null) {
        blocks.add({
          'type': 'table',
          'studied': true,
          'filter': true,
          ...s.tableData!,
        });
      }

      if (s.steps.isNotEmpty) {
        blocks.add({
          'type': 'steps',
          'checkable': isTips,
          'items': s.steps,
        });
      }

      if (s.principleNote != null && s.principleNote!.isNotEmpty) {
        blocks.add({
          'type': 'note',
          'style': 'principle',
          'title': 'The Principle of "Apparent Age":',
          'text': s.principleNote,
        });
      }

      if (s.qaItems.isNotEmpty) {
        blocks.add({
          'type': 'qa',
          'items': s.qaItems,
        });
      }

      jsonSections.add({
        if (isTips) 'icon': 'fa-solid fa-hands-praying' else 'num': s.number,
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
      'title': title,
      'short_title': title.replaceAll(RegExp(r'[!?.]+$'), '').trim(),
      'series': 'What The Bible Says',
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
          'label': 'Searching Daily',
          'quote': '…searched the Scriptures daily, whether those things were so.',
        },
      },
      'intro': {
        'heading': title,
        'icon': 'fa-solid fa-compass',
        'text': introSummary,
        if (introHighlight != null && introHighlight.isNotEmpty)
          'highlight': introHighlight,
      },
      'sections': jsonSections,
      'decision': {
        'eyebrow': 'Personal Response & Commitment',
        'title': "Making God's Word Your Foundation",
        'questions': [
          for (int i = 0; i < decisionQuestions.length; i++)
            {
              'id': 'decision_${i + 1}',
              'text': decisionQuestions[i],
            },
        ],
        'commitment': {
          'title': 'My Study Commitment:',
          'text': commitmentText,
        },
        'collect_contact': true,
      },
    };
  }

  /// Parses a PDF file using column-aware line extraction in syncfusion_flutter_pdf.
  /// Automatically detects 2-page trifold spreads so Page 2 (the inner spread with
  /// Intro + Q1..Q7/Q9) is read BEFORE Page 1 (the outer back/cover spread with
  /// Q8 or Q10..Q13 + Tips + Cover).
  Future<String> _extractFromPdf(Uint8List bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final pageTexts = <int, String>{};

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
                (line.bounds.left - prev.bounds.left).abs() > 105 && gap < -20;
            if (jumpedColumn ||
                gap > (prev.bounds.height * 0.65).clamp(6.0, 18.0)) {
              pageBuf.write('\n\n');
            } else {
              pageBuf.write('\n');
            }
          }
          pageBuf.write(text);
          prev = line;
        }
        if (pageBuf.isNotEmpty) {
          pageTexts[pageIdx] = pageBuf.toString();
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

    final indices = pageTexts.keys.toList()..sort();
    if (indices.length == 2) {
      final p0 = pageTexts[0] ?? '';
      final p1 = pageTexts[1] ?? '';
      final p1HasQ1 = RegExp(r'(?:^|\n)\s*1[\.\s]+(?:What|How)', multiLine: true)
          .hasMatch(p1);
      final p0HasCover = p0.contains('For Enquiry call') ||
          p0.contains('ALIVE') ||
          p0.contains('What The Bible Says');
      if (p1HasQ1 && p0HasCover) {
        return '${pageTexts[1]!}\n\n${pageTexts[0]!}'.trim();
      }
    }

    return indices.map((i) => pageTexts[i]!).join('\n\n').trim();
  }

  /// Orders PDF text lines into left-to-right columns, then top-to-bottom within
  /// each column, using horizontal center / X-clustering so multi-column trifold
  /// pages never interleave lines across adjacent columns.
  List<TextLine> _orderColumnLines(List<TextLine> lines) {
    if (lines.length <= 1) return lines;

    final byX = List<TextLine>.from(lines)
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    final columns = <List<TextLine>>[];

    for (final line in byX) {
      if (line.text.trim().isEmpty) continue;
      bool placed = false;

      for (final col in columns) {
        final avgLeft =
            col.map((l) => l.bounds.left).reduce((a, b) => a + b) / col.length;
        final maxRight = col.map((l) => l.bounds.right).reduce(max);

        if ((line.bounds.left - avgLeft).abs() < 115 ||
            (line.bounds.left < maxRight - 25 &&
                (line.bounds.left - avgLeft).abs() < 160)) {
          col.add(line);
          placed = true;
          break;
        }
      }

      if (!placed) {
        columns.add([line]);
      }
    }

    columns.sort((a, b) {
      final avgA =
          a.map((l) => l.bounds.left).reduce((x, y) => x + y) / a.length;
      final avgB =
          b.map((l) => l.bounds.left).reduce((x, y) => x + y) / b.length;
      return avgA.compareTo(avgB);
    });

    final ordered = <TextLine>[];
    for (final col in columns) {
      col.sort((a, b) {
        final dy = (a.bounds.top - b.bounds.top);
        if (dy.abs() > 3.5) {
          return a.bounds.top.compareTo(b.bounds.top);
        }
        return a.bounds.left.compareTo(b.bounds.left);
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
