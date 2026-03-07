// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bible_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BibleBook _$BibleBookFromJson(Map<String, dynamic> json) => BibleBook(
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String,
      chapters: (json['chapters'] as num).toInt(),
      testament: json['testament'] as String,
      order: (json['order'] as num).toInt(),
      translations: (json['translations'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$BibleBookToJson(BibleBook instance) => <String, dynamic>{
      'name': instance.name,
      'abbreviation': instance.abbreviation,
      'chapters': instance.chapters,
      'testament': instance.testament,
      'order': instance.order,
      'translations': instance.translations,
    };

BibleVerse _$BibleVerseFromJson(Map<String, dynamic> json) => BibleVerse(
      number: (json['number'] as num).toInt(),
      text: json['text'] as String,
      footnotes: (json['footnotes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      crossReferences: (json['crossReferences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$BibleVerseToJson(BibleVerse instance) =>
    <String, dynamic>{
      'number': instance.number,
      'text': instance.text,
      'footnotes': instance.footnotes,
      'crossReferences': instance.crossReferences,
    };

BibleChapter _$BibleChapterFromJson(Map<String, dynamic> json) => BibleChapter(
      book: json['book'] as String,
      chapter: (json['chapter'] as num).toInt(),
      version: json['version'] as String,
      language: json['language'] as String,
      verses: (json['verses'] as List<dynamic>)
          .map((e) => BibleVerse.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      lastUpdated: json['lastUpdated'] == null
          ? null
          : DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$BibleChapterToJson(BibleChapter instance) =>
    <String, dynamic>{
      'book': instance.book,
      'chapter': instance.chapter,
      'version': instance.version,
      'language': instance.language,
      'verses': instance.verses,
      'metadata': instance.metadata,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };

BibleSearchResult _$BibleSearchResultFromJson(Map<String, dynamic> json) =>
    BibleSearchResult(
      book: json['book'] as String,
      chapter: (json['chapter'] as num).toInt(),
      verse: (json['verse'] as num).toInt(),
      text: json['text'] as String,
      version: json['version'] as String,
      language: json['language'] as String,
      reference: json['reference'] as String,
      relevanceScore: (json['relevanceScore'] as num?)?.toDouble(),
      highlightedTerms: (json['highlightedTerms'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$BibleSearchResultToJson(BibleSearchResult instance) =>
    <String, dynamic>{
      'book': instance.book,
      'chapter': instance.chapter,
      'verse': instance.verse,
      'text': instance.text,
      'version': instance.version,
      'language': instance.language,
      'reference': instance.reference,
      'relevanceScore': instance.relevanceScore,
      'highlightedTerms': instance.highlightedTerms,
    };

BibleVersion _$BibleVersionFromJson(Map<String, dynamic> json) => BibleVersion(
      code: json['code'] as String,
      name: json['name'] as String,
      language: json['language'] as String,
      languageCode: json['languageCode'] as String,
      description: json['description'] as String,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      downloadedAt: json['downloadedAt'] == null
          ? null
          : DateTime.parse(json['downloadedAt'] as String),
      totalSize: (json['totalSize'] as num?)?.toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$BibleVersionToJson(BibleVersion instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'language': instance.language,
      'languageCode': instance.languageCode,
      'description': instance.description,
      'isDownloaded': instance.isDownloaded,
      'downloadedAt': instance.downloadedAt?.toIso8601String(),
      'totalSize': instance.totalSize,
      'metadata': instance.metadata,
    };

BibleReadingPlan _$BibleReadingPlanFromJson(Map<String, dynamic> json) =>
    BibleReadingPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      totalDays: (json['totalDays'] as num).toInt(),
      days: (json['days'] as List<dynamic>)
          .map((e) => BibleReadingDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      completedDate: json['completedDate'] == null
          ? null
          : DateTime.parse(json['completedDate'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$BibleReadingPlanToJson(BibleReadingPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'totalDays': instance.totalDays,
      'days': instance.days,
      'startDate': instance.startDate?.toIso8601String(),
      'completedDate': instance.completedDate?.toIso8601String(),
      'metadata': instance.metadata,
    };

BibleReadingDay _$BibleReadingDayFromJson(Map<String, dynamic> json) =>
    BibleReadingDay(
      day: (json['day'] as num).toInt(),
      readings:
          (json['readings'] as List<dynamic>).map((e) => e as String).toList(),
      theme: json['theme'] as String?,
      reflection: json['reflection'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );

Map<String, dynamic> _$BibleReadingDayToJson(BibleReadingDay instance) =>
    <String, dynamic>{
      'day': instance.day,
      'readings': instance.readings,
      'theme': instance.theme,
      'reflection': instance.reflection,
      'isCompleted': instance.isCompleted,
      'completedAt': instance.completedAt?.toIso8601String(),
    };
