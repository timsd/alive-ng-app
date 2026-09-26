import 'dart:convert';

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

  /// The text a child's response is actually scored against.
  ///
  /// [description] is the task label shown on screen ("Learn and recite the
  /// Beatitudes from Matthew 5:3-12") and is NOT sayable. Scoring used it
  /// directly, so reciting the Beatitudes perfectly scored zero while saying
  /// the label aloud scored full marks. This holds the passage or reference
  /// instead. Null means the activity is not scored word-for-word.
  final String? expectedResponse;

  /// How the child's answer is checked, when there is an expected response.
  /// 'recite' for a passage, 'quiz' for a typed answer.
  final String? expectedResponseMode;

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
    this.expectedResponse,
    this.expectedResponseMode,
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
            instructions: _instructionsFromJson(json['instructions']),
      verificationMethod: VerificationMethod.values.firstWhere(
        (e) => e.name == json['verificationMethod'],
      ),
      prerequisiteMissionIds: json['prerequisiteMissionIds'] != null
          ? List<String>.from(json['prerequisiteMissionIds'] as List)
          : const [],
      isLocked: json['isLocked'] as bool? ?? false,
      unlockedBy: json['unlockedBy'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      expectedResponse: json['expectedResponse'] as String?,
      expectedResponseMode: json['expectedResponseMode'] as String?,
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
      'expectedResponse': expectedResponse,
      'expectedResponseMode': expectedResponseMode,
    };
    }

  /// Decodes the `instructions` field, which Appwrite stores as a JSON-encoded
  /// string (e.g. '["1","2"]'). Without this decode the entire
  /// array was rendered as a single step, which is why you saw the
  /// `[",", ...]` blob. This helper splits it back into a proper, ordered
  /// list of steps. It also tolerates an already-decoded list (from local
  /// sources) and degrades gracefully on anything unparseable.
  static List<String> _instructionsFromJson(dynamic raw) {
    if (raw == null) return const <String>[];
    if (raw is List) return List<String>.from(raw);
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <String>[];
      // The stored value is a JSON array string like ["a","b"].
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return List<String>.from(decoded).whereType<String>().toList();
        }
      } catch (_) {
        // Not valid JSON — fall through and keep the whole string.
      }
      return <String>[trimmed];
    }
    return const <String>[];
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
    String? expectedResponse,
    String? expectedResponseMode,
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
      expectedResponse: expectedResponse ?? this.expectedResponse,
      expectedResponseMode: expectedResponseMode ?? this.expectedResponseMode,
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
