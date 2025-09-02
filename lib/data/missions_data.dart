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

final List<Mission> kidsMissions = [
  const Mission(
    id: "1",
    title: "Share a Bible Story",
    description: "Tell a favorite Bible story to a friend or family member",
    location: "Home/School",
    difficulty: MissionDifficulty.easy,
    duration: "15 minutes",
    points: 10,
    category: MissionCategory.sharing,
    completed: false,
    instructions: [
      "Choose one of your favorite Bible stories",
      "Find someone who would like to hear it",
      "Tell the story in your own words",
      "Explain what lesson you learned from it"
    ],
    verificationMethod: VerificationMethod.story,
  ),
  const Mission(
    id: "2",
    title: "Help Someone in Need",
    description: "Find someone who needs help and offer assistance",
    location: "Community",
    difficulty: MissionDifficulty.easy,
    duration: "30 minutes",
    points: 15,
    category: MissionCategory.service,
    completed: false,
    instructions: [
      "Look around for someone who might need help",
      "Offer your assistance kindly",
      "Help them with what they need",
      "Don't expect anything in return"
    ],
    verificationMethod: VerificationMethod.photo,
  ),
  const Mission(
    id: "3",
    title: "Memorize the Beatitudes",
    description: "Learn and recite the Beatitudes from Matthew 5:3-12",
    location: "Anywhere",
    difficulty: MissionDifficulty.medium,
    duration: "1 hour",
    points: 20,
    category: MissionCategory.learning,
    completed: false,
    instructions: [
      "Read Matthew 5:3-12 several times",
      "Break it into smaller sections",
      "Practice reciting each section",
      "Recite the complete passage from memory"
    ],
    verificationMethod: VerificationMethod.quiz,
  ),
  const Mission(
    id: "4",
    title: "Prayer Walk",
    description: "Take a walk and pray for people and places you see",
    location: "Neighborhood",
    difficulty: MissionDifficulty.easy,
    duration: "20 minutes",
    points: 10,
    category: MissionCategory.prayer,
    completed: false,
    instructions: [
      "Take a walk in your neighborhood or area",
      "Pray silently for each person you see",
      "Pray for the homes and families you pass",
      "Ask God to bless your community"
    ],
    verificationMethod: VerificationMethod.story,
  ),
  const Mission(
    id: "5",
    title: "Make a Get-Well Card",
    description: "Create and deliver a get-well card to someone who is sick",
    location: "Home/Hospital/Church",
    difficulty: MissionDifficulty.easy,
    duration: "45 minutes",
    points: 15,
    category: MissionCategory.service,
    completed: false,
    instructions: [
      "Think of someone you know who is unwell",
      "Make a colorful, encouraging card",
      "Write a Bible verse and personal message",
      "Deliver it with a smile and pray with them if possible"
    ],
    verificationMethod: VerificationMethod.photo,
  ),
  const Mission(
    id: "6",
    title: "Invite a Friend to Church",
    description: "Invite a friend who doesn't attend church to come with you",
    location: "School/Community",
    difficulty: MissionDifficulty.medium,
    duration: "1 week",
    points: 25,
    category: MissionCategory.evangelism,
    completed: false,
    instructions: [
      "Think of a friend who doesn't attend church regularly",
      "Tell them about fun activities at your church",
      "Invite them to a special program or regular service",
      "Offer to sit with them and help them feel welcome"
    ],
    verificationMethod: VerificationMethod.witness,
  ),
  const Mission(
    id: "7",
    title: "Collect Items for the Needy",
    description: "Gather clothes, food, or supplies to donate to those in need",
    location: "Community",
    difficulty: MissionDifficulty.medium,
    duration: "2 hours",
    points: 20,
    category: MissionCategory.service,
    completed: false,
    instructions: [
      "Ask your family for items they can donate",
      "Organize the items neatly",
      "Find a local charity or church that accepts donations",
      "Deliver the items and see how your help makes a difference"
    ],
    verificationMethod: VerificationMethod.photo,
  ),
  const Mission(
    id: "8",
    title: "Learn the Books of the Bible",
    description: "Memorize all 66 books of the Bible in order",
    location: "Anywhere",
    difficulty: MissionDifficulty.hard,
    duration: "2 weeks",
    points: 30,
    category: MissionCategory.learning,
    completed: false,
    instructions: [
      "Start with the Old Testament books (39 books)",
      "Learn them in groups of 5-10",
      "Practice daily until you can recite them",
      "Then learn the New Testament books (27 books)",
      "Practice reciting all 66 books in order"
    ],
    verificationMethod: VerificationMethod.quiz,
  ),
  const Mission(
    id: "9",
    title: "Neighborhood Cleanup",
    description: "Organize or join a neighborhood cleanup activity",
    location: "Neighborhood",
    difficulty: MissionDifficulty.medium,
    duration: "1.5 hours",
    points: 20,
    category: MissionCategory.service,
    completed: false,
    instructions: [
      "Get permission from parents/guardians",
      "Gather gloves and garbage bags",
      "Pick up litter in your neighborhood or a local park",
      "Properly dispose of all collected trash"
    ],
    verificationMethod: VerificationMethod.photo,
  ),
  const Mission(
    id: "10",
    title: "Teach a Bible Song",
    description: "Teach a Bible song or hymn to younger children",
    location: "Church/Home",
    difficulty: MissionDifficulty.easy,
    duration: "30 minutes",
    points: 15,
    category: MissionCategory.sharing,
    completed: false,
    instructions: [
      "Choose a simple, memorable Bible song",
      "Practice singing it until you know it well",
      "Find younger children who would like to learn",
      "Teach them the words and tune patiently"
    ],
    verificationMethod: VerificationMethod.story,
  ),
];
