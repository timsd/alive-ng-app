// Enums for study guides
enum StudyGuideType {
  prophecy,
  doctrine,
  lifestyle,
  evangelism,
  baptism,
  discipleship
}

enum StudyDifficulty { beginner, intermediate, advanced }

enum QuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  essay,
  bibleVerse,
  reflection
}

enum StudyStatus { notStarted, inProgress, completed, reviewed }

enum StudySessionStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  rescheduled
}

// Main study guide model
class StudyGuide {
  final String id;
  final String title;
  final String description;
  final StudyGuideType type;
  final StudyDifficulty difficulty;
  final int estimatedDurationMinutes;
  final List<String> objectives;
  final List<String> prerequisites;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyGuide({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required this.objectives,
    this.prerequisites = const [],
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyGuide.fromJson(Map<String, dynamic> json) {
    return StudyGuide(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: StudyGuideType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => StudyGuideType.doctrine,
      ),
      difficulty: StudyDifficulty.values.firstWhere(
        (difficulty) => difficulty.name == json['difficulty'],
        orElse: () => StudyDifficulty.beginner,
      ),
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
      objectives: List<String>.from(json['objectives'] ?? []),
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'difficulty': difficulty.name,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'objectives': objectives,
      'prerequisites': prerequisites,
      'image_url': imageUrl,
      'is_active': isActive,
      'sort_order': sortOrder,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StudyGuide copyWith({
    String? id,
    String? title,
    String? description,
    StudyGuideType? type,
    StudyDifficulty? difficulty,
    int? estimatedDurationMinutes,
    List<String>? objectives,
    List<String>? prerequisites,
    String? imageUrl,
    bool? isActive,
    int? sortOrder,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyGuide(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      objectives: objectives ?? this.objectives,
      prerequisites: prerequisites ?? this.prerequisites,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Study lesson model
class StudyLesson {
  final String id;
  final String studyGuideId;
  final String title;
  final String content;
  final List<String> keyVerses;
  final List<String> supportingVerses;
  final String? summary;
  final String? practicalApplication;
  final int lessonNumber;
  final int estimatedDurationMinutes;
  final Map<String, dynamic> resources;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyLesson({
    required this.id,
    required this.studyGuideId,
    required this.title,
    required this.content,
    required this.keyVerses,
    this.supportingVerses = const [],
    this.summary,
    this.practicalApplication,
    required this.lessonNumber,
    required this.estimatedDurationMinutes,
    this.resources = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyLesson.fromJson(Map<String, dynamic> json) {
    return StudyLesson(
      id: json['id'] as String,
      studyGuideId: json['study_guide_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      keyVerses: List<String>.from(json['key_verses'] ?? []),
      supportingVerses: List<String>.from(json['supporting_verses'] ?? []),
      summary: json['summary'] as String?,
      practicalApplication: json['practical_application'] as String?,
      lessonNumber: json['lesson_number'] as int,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
      resources: Map<String, dynamic>.from(json['resources'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_guide_id': studyGuideId,
      'title': title,
      'content': content,
      'key_verses': keyVerses,
      'supporting_verses': supportingVerses,
      'summary': summary,
      'practical_application': practicalApplication,
      'lesson_number': lessonNumber,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'resources': resources,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Study question model
class StudyQuestion {
  final String id;
  final String lessonId;
  final String question;
  final QuestionType type;
  final List<String> options; // For multiple choice
  final String? correctAnswer;
  final String? explanation;
  final List<String> bibleReferences;
  final int questionNumber;
  final bool isRequired;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const StudyQuestion({
    required this.id,
    required this.lessonId,
    required this.question,
    required this.type,
    this.options = const [],
    this.correctAnswer,
    this.explanation,
    this.bibleReferences = const [],
    required this.questionNumber,
    this.isRequired = true,
    this.metadata = const {},
    required this.createdAt,
  });

  factory StudyQuestion.fromJson(Map<String, dynamic> json) {
    return StudyQuestion(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      question: json['question'] as String,
      type: QuestionType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => QuestionType.shortAnswer,
      ),
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correct_answer'] as String?,
      explanation: json['explanation'] as String?,
      bibleReferences: List<String>.from(json['bible_references'] ?? []),
      questionNumber: json['question_number'] as int,
      isRequired: json['is_required'] as bool? ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'question': question,
      'type': type.name,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'bible_references': bibleReferences,
      'question_number': questionNumber,
      'is_required': isRequired,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// User study progress model
class UserStudyProgress {
  final String id;
  final String userId;
  final String studyGuideId;
  final StudyStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int currentLessonNumber;
  final double progressPercentage;
  final int totalTimeSpentMinutes;
  final Map<String, dynamic> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserStudyProgress({
    required this.id,
    required this.userId,
    required this.studyGuideId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.currentLessonNumber = 1,
    this.progressPercentage = 0.0,
    this.totalTimeSpentMinutes = 0,
    this.notes = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserStudyProgress.fromJson(Map<String, dynamic> json) {
    return UserStudyProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      studyGuideId: json['study_guide_id'] as String,
      status: StudyStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => StudyStatus.notStarted,
      ),
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      currentLessonNumber: json['current_lesson_number'] as int? ?? 1,
      progressPercentage:
          (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      totalTimeSpentMinutes: json['total_time_spent_minutes'] as int? ?? 0,
      notes: Map<String, dynamic>.from(json['notes'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'study_guide_id': studyGuideId,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'current_lesson_number': currentLessonNumber,
      'progress_percentage': progressPercentage,
      'total_time_spent_minutes': totalTimeSpentMinutes,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserStudyProgress copyWith({
    String? id,
    String? userId,
    String? studyGuideId,
    StudyStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? currentLessonNumber,
    double? progressPercentage,
    int? totalTimeSpentMinutes,
    Map<String, dynamic>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserStudyProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      studyGuideId: studyGuideId ?? this.studyGuideId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      currentLessonNumber: currentLessonNumber ?? this.currentLessonNumber,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      totalTimeSpentMinutes:
          totalTimeSpentMinutes ?? this.totalTimeSpentMinutes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// User lesson progress model
class UserLessonProgress {
  final String id;
  final String userId;
  final String lessonId;
  final StudyStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int timeSpentMinutes;
  final Map<String, String> answers; // questionId -> answer
  final double? score;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserLessonProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.timeSpentMinutes = 0,
    this.answers = const {},
    this.score,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserLessonProgress.fromJson(Map<String, dynamic> json) {
    return UserLessonProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      status: StudyStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => StudyStatus.notStarted,
      ),
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      timeSpentMinutes: json['time_spent_minutes'] as int? ?? 0,
      answers: Map<String, String>.from(json['answers'] ?? {}),
      score: (json['score'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'lesson_id': lessonId,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'time_spent_minutes': timeSpentMinutes,
      'answers': answers,
      'score': score,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Study session model for scheduled/guided sessions
class StudySession {
  final String id;
  final String studyGuideId;
  final String? lessonId;
  final String facilitatorId;
  final List<String> participantIds;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final StudySessionStatus status;
  final String? meetingLink;
  final String? location;
  final Map<String, dynamic> resources;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudySession({
    required this.id,
    required this.studyGuideId,
    this.lessonId,
    required this.facilitatorId,
    required this.participantIds,
    required this.title,
    this.description,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.status,
    this.meetingLink,
    this.location,
    this.resources = const {},
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      studyGuideId: json['study_guide_id'] as String,
      lessonId: json['lesson_id'] as String?,
      facilitatorId: json['facilitator_id'] as String,
      participantIds: List<String>.from(json['participant_ids'] ?? []),
      title: json['title'] as String,
      description: json['description'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: json['duration_minutes'] as int,
      status: StudySessionStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => StudySessionStatus.scheduled,
      ),
      meetingLink: json['meeting_link'] as String?,
      location: json['location'] as String?,
      resources: Map<String, dynamic>.from(json['resources'] ?? {}),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'study_guide_id': studyGuideId,
      'lesson_id': lessonId,
      'facilitator_id': facilitatorId,
      'participant_ids': participantIds,
      'title': title,
      'description': description,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'status': status.name,
      'meeting_link': meetingLink,
      'location': location,
      'resources': resources,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Constants for study guides
class StudyGuideConstants {
  // Storacles of Prophecy-style study guides
  static const List<Map<String, dynamic>> defaultStudyGuides = [
    {
      'title': 'The Bible - God\'s Guidebook',
      'type': 'doctrine',
      'difficulty': 'beginner',
      'description':
          'Understanding the Bible as God\'s inspired word and guide for life.',
      'objectives': [
        'Understand the inspiration of Scripture',
        'Learn how to study the Bible effectively',
        'Discover the Bible\'s central theme',
      ],
      'keyVerses': ['2 Timothy 3:16-17', '2 Peter 1:20-21', 'Isaiah 28:10'],
    },
    {
      'title': 'God\'s Love for You',
      'type': 'evangelism',
      'difficulty': 'beginner',
      'description': 'Discovering God\'s amazing love and plan for your life.',
      'objectives': [
        'Experience God\'s unconditional love',
        'Understand the plan of salvation',
        'Accept Jesus as personal Savior',
      ],
      'keyVerses': ['John 3:16', 'Romans 5:8', '1 John 4:9-10'],
    },
    {
      'title': 'The Second Coming of Jesus',
      'type': 'prophecy',
      'difficulty': 'intermediate',
      'description': 'Understanding the signs and promise of Christ\'s return.',
      'objectives': [
        'Recognize the signs of Christ\'s coming',
        'Understand the manner of His return',
        'Prepare for His coming',
      ],
      'keyVerses': ['John 14:1-3', 'Matthew 24:30', '1 Thessalonians 4:16-17'],
    },
    {
      'title': 'Death and the Resurrection',
      'type': 'doctrine',
      'difficulty': 'intermediate',
      'description':
          'Biblical understanding of death and the hope of resurrection.',
      'objectives': [
        'Understand the state of the dead',
        'Learn about the resurrection hope',
        'Find comfort in God\'s promises',
      ],
      'keyVerses': [
        'Ecclesiastes 9:5-6',
        '1 Thessalonians 4:13-18',
        '1 Corinthians 15:51-55'
      ],
    },
    {
      'title': 'The Sabbath - God\'s Gift of Rest',
      'type': 'lifestyle',
      'difficulty': 'intermediate',
      'description':
          'Discovering the blessing and importance of the Sabbath day.',
      'objectives': [
        'Understand the origin of the Sabbath',
        'Learn how to keep the Sabbath holy',
        'Experience Sabbath blessings',
      ],
      'keyVerses': ['Genesis 2:2-3', 'Exodus 20:8-11', 'Isaiah 58:13-14'],
    },
    {
      'title': 'Baptism - Following Jesus\' Example',
      'type': 'baptism',
      'difficulty': 'beginner',
      'description': 'Understanding the meaning and importance of baptism.',
      'objectives': [
        'Understand the symbolism of baptism',
        'Learn the biblical method of baptism',
        'Prepare for baptism',
      ],
      'keyVerses': ['Matthew 3:13-17', 'Romans 6:3-6', 'Acts 8:36-39'],
    },
    {
      'title': 'The Law of God',
      'type': 'doctrine',
      'difficulty': 'intermediate',
      'description':
          'Understanding God\'s law as an expression of His character.',
      'objectives': [
        'Understand the purpose of God\'s law',
        'Learn the Ten Commandments',
        'See Christ in the law',
      ],
      'keyVerses': ['Exodus 20:3-17', 'Matthew 5:17-18', 'Romans 3:31'],
    },
    {
      'title': 'Health and Temperance',
      'type': 'lifestyle',
      'difficulty': 'beginner',
      'description': 'God\'s plan for physical and mental health.',
      'objectives': [
        'Understand the body as God\'s temple',
        'Learn principles of healthful living',
        'Practice temperance in all things',
      ],
      'keyVerses': [
        '1 Corinthians 6:19-20',
        '1 Corinthians 10:31',
        'Daniel 1:8'
      ],
    },
  ];

  static const Map<StudyGuideType, String> typeDescriptions = {
    StudyGuideType.prophecy:
        'Studies focusing on biblical prophecies and their fulfillment',
    StudyGuideType.doctrine: 'Core biblical teachings and beliefs',
    StudyGuideType.lifestyle:
        'Practical Christian living and health principles',
    StudyGuideType.evangelism: 'Studies designed for sharing the gospel',
    StudyGuideType.baptism: 'Preparation for baptism and church membership',
    StudyGuideType.discipleship: 'Growing as a disciple and making disciples',
  };

  static const Map<StudyDifficulty, String> difficultyDescriptions = {
    StudyDifficulty.beginner: 'Suitable for new believers and seekers',
    StudyDifficulty.intermediate: 'For those with basic Bible knowledge',
    StudyDifficulty.advanced: 'In-depth study for mature believers',
  };

  static const Map<QuestionType, String> questionTypeDescriptions = {
    QuestionType.multipleChoice: 'Choose the best answer from given options',
    QuestionType.trueFalse: 'Determine if the statement is true or false',
    QuestionType.shortAnswer: 'Provide a brief written response',
    QuestionType.essay: 'Write a detailed response',
    QuestionType.bibleVerse: 'Find and write out the Bible verse',
    QuestionType.reflection: 'Personal reflection and application',
  };

  static const List<String> bibleBooks = [
    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
    'Joshua',
    'Judges',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Kings',
    '2 Kings',
    '1 Chronicles',
    '2 Chronicles',
    'Ezra',
    'Nehemiah',
    'Esther',
    'Job',
    'Psalms',
    'Proverbs',
    'Ecclesiastes',
    'Song of Solomon',
    'Isaiah',
    'Jeremiah',
    'Lamentations',
    'Ezekiel',
    'Daniel',
    'Hosea',
    'Joel',
    'Amos',
    'Obadiah',
    'Jonah',
    'Micah',
    'Nahum',
    'Habakkuk',
    'Zephaniah',
    'Haggai',
    'Zechariah',
    'Malachi',
    'Matthew',
    'Mark',
    'Luke',
    'John',
    'Acts',
    'Romans',
    '1 Corinthians',
    '2 Corinthians',
    'Galatians',
    'Ephesians',
    'Philippians',
    'Colossians',
    '1 Thessalonians',
    '2 Thessalonians',
    '1 Timothy',
    '2 Timothy',
    'Titus',
    'Philemon',
    'Hebrews',
    'James',
    '1 Peter',
    '2 Peter',
    '1 John',
    '2 John',
    '3 John',
    'Jude',
    'Revelation',
  ];

  static const Map<String, String> inspirationalQuotes = {
    'study':
        'Study to show yourself approved to God, a worker who does not need to be ashamed, rightly dividing the word of truth. - 2 Timothy 2:15',
    'growth':
        'But grow in the grace and knowledge of our Lord and Savior Jesus Christ. - 2 Peter 3:18',
    'wisdom':
        'If any of you lacks wisdom, let him ask of God, who gives to all liberally and without reproach, and it will be given to him. - James 1:5',
    'understanding':
        'The entrance of Your words gives light; it gives understanding to the simple. - Psalm 119:130',
    'guidance':
        'Your word is a lamp to my feet and a light to my path. - Psalm 119:105',
  };
}
