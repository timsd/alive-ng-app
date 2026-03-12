class BibleStory {
  final String id;
  final String title;
  final String subtitle;
  final AgeGroup ageGroup;
  final int duration; // in minutes
  final String description;
  final String? content; // The actual extracted story text
  final String moralLesson;
  final String bibleReference;
  final String? audioUrl;
  final String? illustrationUrl;
  final String? mediaUrl; // Optional video or supplementary media
  final bool completed;
  final bool favorite;
  final StoryCategory category;
  final List<String> tags;

  const BibleStory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ageGroup,
    required this.duration,
    required this.description,
    this.content,
    required this.moralLesson,
    required this.bibleReference,
    this.audioUrl,
    this.illustrationUrl,
    this.mediaUrl,
    required this.completed,
    required this.favorite,
    required this.category,
    required this.tags,
  });

  factory BibleStory.fromJson(Map<String, dynamic> json) {
    return BibleStory(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      ageGroup: AgeGroup.values.firstWhere(
        (e) => e.name == json['ageGroup'].toString().replaceAll('-', '_'),
      ),
      duration: json['duration'] as int,
      description: json['description'] as String,
      content: json['content'] as String?,
      moralLesson: json['moralLesson'] as String,
      bibleReference: json['bibleReference'] as String,
      audioUrl: json['audioUrl'] as String?,
      illustrationUrl: json['illustrationUrl'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      completed: json['completed'] as bool,
      favorite: json['favorite'] as bool,
      category: StoryCategory.values.firstWhere(
        (e) => e.name == json['category'].toString().replaceAll('-', '_'),
      ),
      tags: List<String>.from(json['tags'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'ageGroup': ageGroup.name.replaceAll('_', '-'),
      'duration': duration,
      'description': description,
      if (content != null) 'content': content,
      'moralLesson': moralLesson,
      'bibleReference': bibleReference,
      'audioUrl': audioUrl,
      'illustrationUrl': illustrationUrl,
      'mediaUrl': mediaUrl,
      'completed': completed,
      'favorite': favorite,
      'category': category.name.replaceAll('_', '-'),
      'tags': tags,
    };
  }

  BibleStory copyWith({
    String? id,
    String? title,
    String? subtitle,
    AgeGroup? ageGroup,
    int? duration,
    String? description,
    String? content,
    String? moralLesson,
    String? bibleReference,
    String? audioUrl,
    String? illustrationUrl,
    String? mediaUrl,
    bool? completed,
    bool? favorite,
    StoryCategory? category,
    List<String>? tags,
  }) {
    return BibleStory(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      ageGroup: ageGroup ?? this.ageGroup,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      content: content ?? this.content,
      moralLesson: moralLesson ?? this.moralLesson,
      bibleReference: bibleReference ?? this.bibleReference,
      audioUrl: audioUrl ?? this.audioUrl,
      illustrationUrl: illustrationUrl ?? this.illustrationUrl,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      completed: completed ?? this.completed,
      favorite: favorite ?? this.favorite,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
}

enum AgeGroup {
  age_3_6('3-6'),
  age_7_10('7-10'),
  age_11_14('11-14');

  const AgeGroup(this.displayName);
  final String displayName;
}

enum StoryCategory {
  oldTestament('Old Testament'),
  newTestament('New Testament'),
  parables('Parables'),
  miracles('Miracles'),
  sdaDoctrines('SDA Doctrines'),
  sdaValues('SDA Values');

  const StoryCategory(this.displayName);
  final String displayName;
}
