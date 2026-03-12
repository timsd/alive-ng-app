class Mission {
  final String id;
  final String title;
  final String description;
  final String location;
  final MissionDifficulty difficulty;
  final String duration; // e.g., "30 minutes", "1 hour"
  final int points;
  final MissionCategory category;
  final bool completed;
  final List<String> instructions;
  final VerificationMethod verificationMethod;
  final List<String> prerequisiteMissionIds; // Missions that must be completed first
  final bool isLocked; // Whether this mission is currently locked
  final String? unlockedBy; // ID of the mission that unlocked this one
  final String? mediaUrl; // Optional image or video for the mission

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.difficulty,
    required this.duration,
    required this.points,
    required this.category,
    required this.completed,
    required this.instructions,
    required this.verificationMethod,
    this.prerequisiteMissionIds = const [],
    this.isLocked = false,
    this.unlockedBy,
    this.mediaUrl,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      difficulty: MissionDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      duration: json['duration'] as String,
      points: json['points'] as int,
      category: MissionCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      completed: json['completed'] as bool,
      instructions: List<String>.from(json['instructions'] as List),
      verificationMethod: VerificationMethod.values.firstWhere(
        (e) => e.name == json['verificationMethod'],
      ),
      prerequisiteMissionIds: json['prerequisiteMissionIds'] != null
          ? List<String>.from(json['prerequisiteMissionIds'] as List)
          : const [],
      isLocked: json['isLocked'] as bool? ?? false,
      unlockedBy: json['unlockedBy'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'difficulty': difficulty.name,
      'duration': duration,
      'points': points,
      'category': category.name,
      'completed': completed,
      'instructions': instructions,
      'verificationMethod': verificationMethod.name,
      'prerequisiteMissionIds': prerequisiteMissionIds,
      'isLocked': isLocked,
      'unlockedBy': unlockedBy,
      'mediaUrl': mediaUrl,
    };
  }

  Mission copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    MissionDifficulty? difficulty,
    String? duration,
    int? points,
    MissionCategory? category,
    bool? completed,
    List<String>? instructions,
    VerificationMethod? verificationMethod,
    List<String>? prerequisiteMissionIds,
    bool? isLocked,
    String? unlockedBy,
    String? mediaUrl,
  }) {
    return Mission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      difficulty: difficulty ?? this.difficulty,
      duration: duration ?? this.duration,
      points: points ?? this.points,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      instructions: instructions ?? this.instructions,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      prerequisiteMissionIds: prerequisiteMissionIds ?? this.prerequisiteMissionIds,
      isLocked: isLocked ?? this.isLocked,
      unlockedBy: unlockedBy ?? this.unlockedBy,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }
}

enum MissionDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const MissionDifficulty(this.displayName);
  final String displayName;
}

enum MissionCategory {
  evangelism('Evangelism'),
  service('Service'),
  learning('Learning'),
  sharing('Sharing'),
  prayer('Prayer');

  const MissionCategory(this.displayName);
  final String displayName;
}

enum VerificationMethod {
  photo('Photo'),
  story('Story'),
  quiz('Quiz'),
  witness('Witness');

  const VerificationMethod(this.displayName);
  final String displayName;
}
