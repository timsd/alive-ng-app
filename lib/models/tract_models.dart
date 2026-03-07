import 'package:json_annotation/json_annotation.dart';

part 'tract_models.g.dart';

@JsonSerializable()
class Tract {
  final String id;
  final String title;
  final String description;
  final String category;
  final String pdfUrl;
  final String? localPdfPath;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDownloaded;
  final int order;
  final String language;

  const Tract({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.pdfUrl,
    this.localPdfPath,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.isDownloaded,
    required this.order,
    required this.language,
  });

  factory Tract.fromJson(Map<String, dynamic> json) => _$TractFromJson(json);
  Map<String, dynamic> toJson() => _$TractToJson(this);

  Tract copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? pdfUrl,
    String? localPdfPath,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDownloaded,
    int? order,
    String? language,
  }) {
    return Tract(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      localPdfPath: localPdfPath ?? this.localPdfPath,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      order: order ?? this.order,
      language: language ?? this.language,
    );
  }
}

@JsonSerializable()
class TractContent {
  final String id;
  final String tractId;
  final String content;
  final List<TractQuestion> questions;
  final Map<String, dynamic>? metadata;

  const TractContent({
    required this.id,
    required this.tractId,
    required this.content,
    required this.questions,
    this.metadata,
  });

  factory TractContent.fromJson(Map<String, dynamic> json) => _$TractContentFromJson(json);
  Map<String, dynamic> toJson() => _$TractContentToJson(this);
}

@JsonSerializable()
class TractQuestion {
  final String id;
  final String question;
  final String type; // 'text', 'multiple_choice', 'true_false', 'essay'
  final List<String>? options; // For multiple choice questions
  final String? correctAnswer;
  final int order;

  const TractQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    this.correctAnswer,
    required this.order,
  });

  factory TractQuestion.fromJson(Map<String, dynamic> json) => _$TractQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$TractQuestionToJson(this);
}

@JsonSerializable()
class UserTractAnswer {
  final String id;
  final String userId;
  final String tractId;
  final Map<String, String> answers; // questionId -> answer
  final DateTime completedAt;
  final bool isCompleted;
  final int score;

  const UserTractAnswer({
    required this.id,
    required this.userId,
    required this.tractId,
    required this.answers,
    required this.completedAt,
    required this.isCompleted,
    required this.score,
  });

  factory UserTractAnswer.fromJson(Map<String, dynamic> json) => _$UserTractAnswerFromJson(json);
  Map<String, dynamic> toJson() => _$UserTractAnswerToJson(this);
}

@JsonSerializable()
class TractCategory {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int order;
  final bool isActive;

  const TractCategory({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.order,
    required this.isActive,
  });

  factory TractCategory.fromJson(Map<String, dynamic> json) => _$TractCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$TractCategoryToJson(this);
}

@JsonSerializable()
class TractProgress {
  final String userId;
  final String tractId;
  final int currentQuestionIndex;
  final Map<String, String> currentAnswers;
  final DateTime lastUpdated;
  final bool isCompleted;
  final double progressPercentage;

  const TractProgress({
    required this.userId,
    required this.tractId,
    required this.currentQuestionIndex,
    required this.currentAnswers,
    required this.lastUpdated,
    required this.isCompleted,
    required this.progressPercentage,
  });

  factory TractProgress.fromJson(Map<String, dynamic> json) => _$TractProgressFromJson(json);
  Map<String, dynamic> toJson() => _$TractProgressToJson(this);
}

@JsonSerializable()
class TractStatistics {
  final String tractId;
  final int totalCompletions;
  final double averageScore;
  final int totalDownloads;
  final DateTime lastCompleted;
  final Map<String, int> questionStats; // questionId -> correct answers count

  const TractStatistics({
    required this.tractId,
    required this.totalCompletions,
    required this.averageScore,
    required this.totalDownloads,
    required this.lastCompleted,
    required this.questionStats,
  });

  factory TractStatistics.fromJson(Map<String, dynamic> json) => _$TractStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$TractStatisticsToJson(this);
}