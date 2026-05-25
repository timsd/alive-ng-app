import 'package:json_annotation/json_annotation.dart';

part 'tract_models.g.dart';

@JsonSerializable()
class Tract {
  final String id;
  final String title;
  final String description;

  /// Remote category string, also maps to [TractCategory.name].
  final String category;
  // ---- Remote/Appwrite fields ----
  final String? pdfUrl;
  final String? localPdfPath;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDownloaded;
  final int order;
  final String language;
  // ---- Rich metadata (used by UI and admin screen) ----
  final String? author;
  final int? pages;
  final bool featured;
  final List<String> tags;
  final String? coverImage;
  final List<String> coverImages;

  /// Alias for pdfUrl, kept for backward compat
  String? get downloadUrl => pdfUrl;

  const Tract({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.pdfUrl,
    this.localPdfPath,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.isDownloaded = false,
    this.order = 0,
    this.language = 'en',
    this.author,
    this.pages,
    this.featured = false,
    this.tags = const [],
    this.coverImage,
    this.coverImages = const [],
  });

  factory Tract.fromJson(Map<String, dynamic> json) => _$TractFromJson(json);
  Map<String, dynamic> toJson() => _$TractToJson(this);

  /// Build from an Appwrite or legacy document with flexible field names.
  factory Tract.fromDocument(Map<String, dynamic> data, String docId) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return Tract(
      id: docId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'evangelism',
      pdfUrl: data['pdfUrl'] as String? ?? data['pdf_url'] as String?,
      localPdfPath:
          data['localPdfPath'] as String? ?? data['local_pdf_path'] as String?,
      imageUrl: data['imageUrl'] as String? ??
          data['image_url'] as String? ??
          data['coverImage'] as String?,
      createdAt: parseDate(data['createdAt'] ?? data['created_at']),
      updatedAt: parseDate(data['updatedAt'] ?? data['updated_at']),
      isDownloaded: data['isDownloaded'] as bool? ??
          data['is_downloaded'] as bool? ??
          false,
      order: data['order'] as int? ?? 0,
      language: data['language'] as String? ?? 'en',
      author: data['author'] as String?,
      pages: data['pages'] as int?,
      featured: data['featured'] as bool? ?? false,
      tags: data['tags'] != null ? List<String>.from(data['tags'] as List) : [],
      coverImage:
          data['coverImage'] as String? ?? data['cover_image'] as String?,
      coverImages: _stringList(data['coverImages'] ?? data['cover_images']),
    );
  }

  @Deprecated('Use Tract.fromDocument for Appwrite and legacy documents.')
  factory Tract.fromFirestore(Map<String, dynamic> data, String docId) =>
      Tract.fromDocument(data, docId);

  static List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

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
    String? author,
    int? pages,
    bool? featured,
    List<String>? tags,
    String? coverImage,
    List<String>? coverImages,
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
      author: author ?? this.author,
      pages: pages ?? this.pages,
      featured: featured ?? this.featured,
      tags: tags ?? this.tags,
      coverImage: coverImage ?? this.coverImage,
      coverImages: coverImages ?? this.coverImages,
    );
  }

  /// Primary cover image to display
  String? get primaryCover {
    if (coverImage != null && coverImage!.isNotEmpty) return coverImage;
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    if (coverImages.isNotEmpty) return coverImages.first;
    return null;
  }

  /// All available cover images
  List<String> get allCovers {
    final all = <String>[];
    if (coverImage != null && coverImage!.isNotEmpty) all.add(coverImage!);
    if (imageUrl != null && imageUrl!.isNotEmpty && !all.contains(imageUrl)) {
      all.add(imageUrl!);
    }
    for (final img in coverImages) {
      if (!all.contains(img)) all.add(img);
    }
    return all;
  }
}

/// Helper to convert category string to display name
extension TractCategoryDisplay on String {
  String get tractDisplayName {
    switch (toLowerCase()) {
      case 'evangelism':
        return 'Evangelism';
      case 'doctrine':
        return 'Doctrine';
      case 'health':
        return 'Health';
      case 'prophecy':
        return 'Prophecy';
      case 'lifestyle':
        return 'Lifestyle';
      case 'children':
        return 'Children';
      case 'biblesays':
        return 'What the Bible Says';
      default:
        if (isEmpty) return 'General';
        return this[0].toUpperCase() + substring(1);
    }
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

  factory TractContent.fromJson(Map<String, dynamic> json) =>
      _$TractContentFromJson(json);
  Map<String, dynamic> toJson() => _$TractContentToJson(this);
}

@JsonSerializable()
class TractQuestion {
  final String id;
  final String question;
  final String type;
  final List<String>? options;
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

  factory TractQuestion.fromJson(Map<String, dynamic> json) =>
      _$TractQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$TractQuestionToJson(this);
}

@JsonSerializable()
class UserTractAnswer {
  final String id;
  final String userId;
  final String tractId;
  final Map<String, String> answers;
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

  factory UserTractAnswer.fromJson(Map<String, dynamic> json) =>
      _$UserTractAnswerFromJson(json);
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

  factory TractCategory.fromJson(Map<String, dynamic> json) =>
      _$TractCategoryFromJson(json);
  Map<String, dynamic> toJson() => _$TractCategoryToJson(this);

  String get displayName => name;
}

@JsonSerializable()
class TractProgress {
  final String id;
  final String userId;
  final String tractId;
  final int currentPage;
  final bool isCompleted;
  final DateTime lastUpdated;

  const TractProgress({
    required this.id,
    required this.userId,
    required this.tractId,
    required this.currentPage,
    required this.isCompleted,
    required this.lastUpdated,
  });

  factory TractProgress.fromJson(Map<String, dynamic> json) =>
      _$TractProgressFromJson(json);
  Map<String, dynamic> toJson() => _$TractProgressToJson(this);
}

@JsonSerializable()
class TractStatistics {
  final int totalTracts;
  final int totalDownloads;
  final int activeReaders;
  final Map<String, int> categoryDistribution;

  const TractStatistics({
    required this.totalTracts,
    required this.totalDownloads,
    required this.activeReaders,
    required this.categoryDistribution,
  });

  factory TractStatistics.fromJson(Map<String, dynamic> json) =>
      _$TractStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$TractStatisticsToJson(this);
}
