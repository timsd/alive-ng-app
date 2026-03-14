// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tract_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tract _$TractFromJson(Map<String, dynamic> json) => Tract(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      pdfUrl: json['pdfUrl'] as String?,
      localPdfPath: json['localPdfPath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
      language: json['language'] as String? ?? 'en',
      author: json['author'] as String?,
      pages: (json['pages'] as num?)?.toInt(),
      featured: json['featured'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      coverImage: json['coverImage'] as String?,
      coverImages: (json['coverImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TractToJson(Tract instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'pdfUrl': instance.pdfUrl,
      'localPdfPath': instance.localPdfPath,
      'imageUrl': instance.imageUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isDownloaded': instance.isDownloaded,
      'order': instance.order,
      'language': instance.language,
      'author': instance.author,
      'pages': instance.pages,
      'featured': instance.featured,
      'tags': instance.tags,
      'coverImage': instance.coverImage,
      'coverImages': instance.coverImages,
    };

TractContent _$TractContentFromJson(Map<String, dynamic> json) => TractContent(
      id: json['id'] as String,
      tractId: json['tractId'] as String,
      content: json['content'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map((e) => TractQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$TractContentToJson(TractContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tractId': instance.tractId,
      'content': instance.content,
      'questions': instance.questions,
      'metadata': instance.metadata,
    };

TractQuestion _$TractQuestionFromJson(Map<String, dynamic> json) =>
    TractQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      type: json['type'] as String,
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      correctAnswer: json['correctAnswer'] as String?,
      order: (json['order'] as num).toInt(),
    );

Map<String, dynamic> _$TractQuestionToJson(TractQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'type': instance.type,
      'options': instance.options,
      'correctAnswer': instance.correctAnswer,
      'order': instance.order,
    };

UserTractAnswer _$UserTractAnswerFromJson(Map<String, dynamic> json) =>
    UserTractAnswer(
      id: json['id'] as String,
      userId: json['userId'] as String,
      tractId: json['tractId'] as String,
      answers: Map<String, String>.from(json['answers'] as Map),
      completedAt: DateTime.parse(json['completedAt'] as String),
      isCompleted: json['isCompleted'] as bool,
      score: (json['score'] as num).toInt(),
    );

Map<String, dynamic> _$UserTractAnswerToJson(UserTractAnswer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'tractId': instance.tractId,
      'answers': instance.answers,
      'completedAt': instance.completedAt.toIso8601String(),
      'isCompleted': instance.isCompleted,
      'score': instance.score,
    };

TractCategory _$TractCategoryFromJson(Map<String, dynamic> json) =>
    TractCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      order: (json['order'] as num).toInt(),
      isActive: json['isActive'] as bool,
    );

Map<String, dynamic> _$TractCategoryToJson(TractCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'order': instance.order,
      'isActive': instance.isActive,
    };

TractProgress _$TractProgressFromJson(Map<String, dynamic> json) =>
    TractProgress(
      id: json['id'] as String,
      userId: json['userId'] as String,
      tractId: json['tractId'] as String,
      currentPage: (json['currentPage'] as num).toInt(),
      isCompleted: json['isCompleted'] as bool,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$TractProgressToJson(TractProgress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'tractId': instance.tractId,
      'currentPage': instance.currentPage,
      'isCompleted': instance.isCompleted,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };

TractStatistics _$TractStatisticsFromJson(Map<String, dynamic> json) =>
    TractStatistics(
      totalTracts: (json['totalTracts'] as num).toInt(),
      totalDownloads: (json['totalDownloads'] as num).toInt(),
      activeReaders: (json['activeReaders'] as num).toInt(),
      categoryDistribution:
          Map<String, int>.from(json['categoryDistribution'] as Map),
    );

Map<String, dynamic> _$TractStatisticsToJson(TractStatistics instance) =>
    <String, dynamic>{
      'totalTracts': instance.totalTracts,
      'totalDownloads': instance.totalDownloads,
      'activeReaders': instance.activeReaders,
      'categoryDistribution': instance.categoryDistribution,
    };
