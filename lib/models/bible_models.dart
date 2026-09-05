import 'package:json_annotation/json_annotation.dart';

part 'bible_models.g.dart';

@JsonSerializable()
class BibleBook {
  final String name;
  final String abbreviation;
  final int chapters;
  final String testament; // 'Old' or 'New'
  final int order;
  final Map<String, String>? translations; // Language code -> translated name

  const BibleBook({
    required this.name,
    required this.abbreviation,
    required this.chapters,
    required this.testament,
    required this.order,
    this.translations,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) => _$BibleBookFromJson(json);
  Map<String, dynamic> toJson() => _$BibleBookToJson(this);

  BibleBook copyWith({
    String? name,
    String? abbreviation,
    int? chapters,
    String? testament,
    int? order,
    Map<String, String>? translations,
  }) {
    return BibleBook(
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      chapters: chapters ?? this.chapters,
      testament: testament ?? this.testament,
      order: order ?? this.order,
      translations: translations ?? this.translations,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleBook &&
        other.name == name &&
        other.abbreviation == abbreviation &&
        other.chapters == chapters &&
        other.testament == testament &&
        other.order == order;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        abbreviation.hashCode ^
        chapters.hashCode ^
        testament.hashCode ^
        order.hashCode;
  }

  @override
  String toString() {
    return 'BibleBook(name: $name, abbreviation: $abbreviation, chapters: $chapters, testament: $testament, order: $order)';
  }
}

@JsonSerializable()
class BibleVerse {
  final int number;
  final String text;
  final Map<String, String>? footnotes;
  final List<String>? crossReferences;

  const BibleVerse({
    required this.number,
    required this.text,
    this.footnotes,
    this.crossReferences,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) => _$BibleVerseFromJson(json);
  Map<String, dynamic> toJson() => _$BibleVerseToJson(this);

  BibleVerse copyWith({
    int? number,
    String? text,
    Map<String, String>? footnotes,
    List<String>? crossReferences,
  }) {
    return BibleVerse(
      number: number ?? this.number,
      text: text ?? this.text,
      footnotes: footnotes ?? this.footnotes,
      crossReferences: crossReferences ?? this.crossReferences,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleVerse &&
        other.number == number &&
        other.text == text;
  }

  @override
  int get hashCode => number.hashCode ^ text.hashCode;

  @override
  String toString() {
    return 'BibleVerse(number: $number, text: $text)';
  }
}

@JsonSerializable()
class BibleChapter {
  final String book;
  final int chapter;
  final String version;
  final String language;
  final List<BibleVerse> verses;
  final Map<String, dynamic>? metadata;
  final DateTime? lastUpdated;

  const BibleChapter({
    required this.book,
    required this.chapter,
    required this.version,
    required this.language,
    required this.verses,
    this.metadata,
    this.lastUpdated,
  });

  factory BibleChapter.fromJson(Map<String, dynamic> json) => _$BibleChapterFromJson(json);
  Map<String, dynamic> toJson() => _$BibleChapterToJson(this);

  BibleChapter copyWith({
    String? book,
    int? chapter,
    String? version,
    String? language,
    List<BibleVerse>? verses,
    Map<String, dynamic>? metadata,
    DateTime? lastUpdated,
  }) {
    return BibleChapter(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      version: version ?? this.version,
      language: language ?? this.language,
      verses: verses ?? this.verses,
      metadata: metadata ?? this.metadata,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Get verse by number
  BibleVerse? getVerse(int verseNumber) {
    try {
      return verses.firstWhere((verse) => verse.number == verseNumber);
    } catch (e) {
      return null;
    }
  }

  // Get verse range
  List<BibleVerse> getVerseRange(int startVerse, int endVerse) {
    return verses
        .where((verse) => verse.number >= startVerse && verse.number <= endVerse)
        .toList();
  }

  // Get chapter reference string
  String get reference => '$book $chapter';

  // Get full reference with version
  String get fullReference => '$book $chapter ($version)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleChapter &&
        other.book == book &&
        other.chapter == chapter &&
        other.version == version &&
        other.language == language;
  }

  @override
  int get hashCode {
    return book.hashCode ^
        chapter.hashCode ^
        version.hashCode ^
        language.hashCode;
  }

  @override
  String toString() {
    return 'BibleChapter(book: $book, chapter: $chapter, version: $version, language: $language, verses: ${verses.length})';
  }
}

@JsonSerializable()
class BibleSearchResult {
  final String book;
  final int chapter;
  final int verse;
  final String text;
  final String version;
  final String language;
  final String reference;
  final double? relevanceScore;
  final List<String>? highlightedTerms;

  const BibleSearchResult({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.version,
    required this.language,
    required this.reference,
    this.relevanceScore,
    this.highlightedTerms,
  });

  factory BibleSearchResult.fromJson(Map<String, dynamic> json) => _$BibleSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$BibleSearchResultToJson(this);

  BibleSearchResult copyWith({
    String? book,
    int? chapter,
    int? verse,
    String? text,
    String? version,
    String? language,
    String? reference,
    double? relevanceScore,
    List<String>? highlightedTerms,
  }) {
    return BibleSearchResult(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      text: text ?? this.text,
      version: version ?? this.version,
      language: language ?? this.language,
      reference: reference ?? this.reference,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      highlightedTerms: highlightedTerms ?? this.highlightedTerms,
    );
  }

  // Get full verse reference
  String get fullReference => '$book $chapter:$verse';

  // Get verse reference with version
  String get fullReferenceWithVersion => '$book $chapter:$verse ($version)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleSearchResult &&
        other.book == book &&
        other.chapter == chapter &&
        other.verse == verse &&
        other.version == version &&
        other.language == language;
  }

  @override
  int get hashCode {
    return book.hashCode ^
        chapter.hashCode ^
        verse.hashCode ^
        version.hashCode ^
        language.hashCode;
  }

  @override
  String toString() {
    return 'BibleSearchResult(reference: $fullReference, version: $version, language: $language)';
  }
}

@JsonSerializable()
class BibleVersion {
  final String code;
  final String name;
  final String language;
  final String languageCode;
  final String description;
  final bool isDownloaded;
  final DateTime? downloadedAt;
  final int? totalSize;
  final Map<String, dynamic>? metadata;

  const BibleVersion({
    required this.code,
    required this.name,
    required this.language,
    required this.languageCode,
    required this.description,
    this.isDownloaded = false,
    this.downloadedAt,
    this.totalSize,
    this.metadata,
  });

  factory BibleVersion.fromJson(Map<String, dynamic> json) => _$BibleVersionFromJson(json);
  Map<String, dynamic> toJson() => _$BibleVersionToJson(this);

  BibleVersion copyWith({
    String? code,
    String? name,
    String? language,
    String? languageCode,
    String? description,
    bool? isDownloaded,
    DateTime? downloadedAt,
    int? totalSize,
    Map<String, dynamic>? metadata,
  }) {
    return BibleVersion(
      code: code ?? this.code,
      name: name ?? this.name,
      language: language ?? this.language,
      languageCode: languageCode ?? this.languageCode,
      description: description ?? this.description,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      totalSize: totalSize ?? this.totalSize,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get display name with language
  String get displayName => '$name ($language)';

  // Get formatted size
  String get formattedSize {
    if (totalSize == null) return 'Unknown size';
    final sizeInMB = totalSize! / (1024 * 1024);
    return '${sizeInMB.toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleVersion &&
        other.code == code &&
        other.languageCode == languageCode;
  }

  @override
  int get hashCode => code.hashCode ^ languageCode.hashCode;

  @override
  String toString() {
    return 'BibleVersion(code: $code, name: $name, language: $language, isDownloaded: $isDownloaded)';
  }
}

@JsonSerializable()
class BibleReadingPlan {
  final String id;
  final String name;
  final String description;
  final int totalDays;
  final List<BibleReadingDay> days;
  final DateTime? startDate;
  final DateTime? completedDate;
  final Map<String, dynamic>? metadata;

  const BibleReadingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.totalDays,
    required this.days,
    this.startDate,
    this.completedDate,
    this.metadata,
  });

  factory BibleReadingPlan.fromJson(Map<String, dynamic> json) => _$BibleReadingPlanFromJson(json);
  Map<String, dynamic> toJson() => _$BibleReadingPlanToJson(this);

  BibleReadingPlan copyWith({
    String? id,
    String? name,
    String? description,
    int? totalDays,
    List<BibleReadingDay>? days,
    DateTime? startDate,
    DateTime? completedDate,
    Map<String, dynamic>? metadata,
  }) {
    return BibleReadingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      totalDays: totalDays ?? this.totalDays,
      days: days ?? this.days,
      startDate: startDate ?? this.startDate,
      completedDate: completedDate ?? this.completedDate,
      metadata: metadata ?? this.metadata,
    );
  }

  // Get current day based on start date
  int? get currentDay {
    if (startDate == null) return null;
    final daysSinceStart = DateTime.now().difference(startDate!).inDays + 1;
    return daysSinceStart <= totalDays ? daysSinceStart : null;
  }

  // Get progress percentage
  double get progressPercentage {
    final current = currentDay;
    if (current == null) return 0.0;
    return (current / totalDays).clamp(0.0, 1.0);
  }

  // Check if plan is completed
  bool get isCompleted => completedDate != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleReadingPlan && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BibleReadingPlan(id: $id, name: $name, totalDays: $totalDays)';
  }
}

@JsonSerializable()
class BibleReadingDay {
  final int day;
  final List<String> readings; // e.g., ["Genesis 1-2", "Matthew 1"]
  final String? theme;
  final String? reflection;
  final bool isCompleted;
  final DateTime? completedAt;

  const BibleReadingDay({
    required this.day,
    required this.readings,
    this.theme,
    this.reflection,
    this.isCompleted = false,
    this.completedAt,
  });

  factory BibleReadingDay.fromJson(Map<String, dynamic> json) => _$BibleReadingDayFromJson(json);
  Map<String, dynamic> toJson() => _$BibleReadingDayToJson(this);

  BibleReadingDay copyWith({
    int? day,
    List<String>? readings,
    String? theme,
    String? reflection,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return BibleReadingDay(
      day: day ?? this.day,
      readings: readings ?? this.readings,
      theme: theme ?? this.theme,
      reflection: reflection ?? this.reflection,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Get formatted readings string
  String get formattedReadings => readings.join(', ');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleReadingDay && other.day == day;
  }

  @override
  int get hashCode => day.hashCode;

  @override
  String toString() {
    return 'BibleReadingDay(day: $day, readings: $formattedReadings, isCompleted: $isCompleted)';
  }
}

/// Domain model representing user reading progress or interaction in the Bible.
class BibleUserProgress {
  final int? id;
  final String userId;
  final String book;
  final int chapter;
  final int? verse;
  final String version;
  final String progressType;
  final Map<String, dynamic>? progressData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BibleUserProgress({
    this.id,
    required this.userId,
    required this.book,
    required this.chapter,
    this.verse,
    required this.version,
    required this.progressType,
    this.progressData,
    this.createdAt,
    this.updatedAt,
  });

  factory BibleUserProgress.fromMap(Map<String, dynamic> map) {
    return BibleUserProgress(
      id: map['id'] as int?,
      userId: map['user_id'] as String? ?? '',
      book: map['book'] as String? ?? '',
      chapter: map['chapter'] as int? ?? 1,
      verse: map['verse'] as int?,
      version: map['version'] as String? ?? '',
      progressType: map['progress_type'] as String? ?? '',
      progressData: map['progress_data'] != null
          ? (map['progress_data'] is Map<String, dynamic>
              ? map['progress_data'] as Map<String, dynamic>
              : (map['progress_data'] is Map
                  ? Map<String, dynamic>.from(map['progress_data'] as Map)
                  : null))
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'version': version,
      'progress_type': progressType,
      'progress_data': progressData,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'BibleUserProgress(userId: $userId, $book $chapter:$verse, type: $progressType)';
  }
}