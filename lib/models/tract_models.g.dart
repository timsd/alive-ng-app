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
      pdfUrl: json['pdfUrl'] as String,
      localPdfPath: json['localPdfPath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDownloaded: json['isDownloaded'] as bool,
      order: (json['order'] as num).toInt(),
      language: json['language'] as String,
    );

Map<String, dynamic> _$TractToJson(Tract instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'pdfUrl': instance.pdfUrl,
      'localPdfPath': instance.localPdfPath,
      'imageUrl': instance.imageUrl,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isDownloaded': instance.isDownloaded,
      'order': instance.order,
      'language': instance.language,
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
      userId: json['userId'] as String,
      tractId: json['tractId'] as String,
      currentQuestionIndex: (json['currentQuestionIndex'] as num).toInt(),
      currentAnswers: Map<String, String>.from(json['currentAnswers'] as Map),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      isCompleted: json['isCompleted'] as bool,
      progressPercentage: (json['progressPercentage'] as num).toDouble(),
    );

Map<String, dynamic> _$TractProgressToJson(TractProgress instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'tractId': instance.tractId,
      'currentQuestionIndex': instance.currentQuestionIndex,
      'currentAnswers': instance.currentAnswers,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'isCompleted': instance.isCompleted,
      'progressPercentage': instance.progressPercentage,
    };

TractStatistics _$TractStatisticsFromJson(Map<String, dynamic> json) =>
    TractStatistics(
      tractId: json['tractId'] as String,
      totalCompletions: (json['totalCompletions'] as num).toInt(),
      averageScore: (json['averageScore'] as num).toDouble(),
      totalDownloads: (json['totalDownloads'] as num).toInt(),
      lastCompleted: DateTime.parse(json['lastCompleted'] as String),
      questionStats: Map<String, int>.from(json['questionStats'] as Map),
    );

Map<String, dynamic> _$TractStatisticsToJson(TractStatistics instance) =>
    <String, dynamic>{
      'tractId': instance.tractId,
      'totalCompletions': instance.totalCompletions,
      'averageScore': instance.averageScore,
      'totalDownloads': instance.totalDownloads,
      'lastCompleted': instance.lastCompleted.toIso8601String(),
      'questionStats': instance.questionStats,
    };
