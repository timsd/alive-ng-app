class BibleStory {
  final String id;
  final String title;
  final String subtitle;
  final AgeGroup ageGroup;
  final int duration; // in minutes
  final String description;
  final String moralLesson;
  final String bibleReference;
  final String? audioUrl;
  final String? illustrationUrl;
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
    required this.moralLesson,
    required this.bibleReference,
    this.audioUrl,
    this.illustrationUrl,
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
      moralLesson: json['moralLesson'] as String,
      bibleReference: json['bibleReference'] as String,
      audioUrl: json['audioUrl'] as String?,
      illustrationUrl: json['illustrationUrl'] as String?,
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
      'moralLesson': moralLesson,
      'bibleReference': bibleReference,
      'audioUrl': audioUrl,
      'illustrationUrl': illustrationUrl,
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
    String? moralLesson,
    String? bibleReference,
    String? audioUrl,
    String? illustrationUrl,
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
      moralLesson: moralLesson ?? this.moralLesson,
      bibleReference: bibleReference ?? this.bibleReference,
      audioUrl: audioUrl ?? this.audioUrl,
      illustrationUrl: illustrationUrl ?? this.illustrationUrl,
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
  old_testament('Old Testament'),
  new_testament('New Testament'),
  parables('Parables'),
  miracles('Miracles');

  const StoryCategory(this.displayName);
  final String displayName;
}

final List<BibleStory> bibleStories = [
  const BibleStory(
    id: '1',
    title: 'Noah\'s Big Boat',
    subtitle: 'God Protects His People',
    ageGroup: AgeGroup.age_3_6,
    duration: 8,
    description:
        'Follow Noah as he builds the great ark and saves all the animals from the flood.',
    moralLesson:
        'God always keeps His promises and protects those who obey Him.',
    bibleReference: 'Genesis 6-9',
    completed: false,
    favorite: false,
    category: StoryCategory.old_testament,
    tags: ['obedience', 'animals', 'protection', 'rainbow'],
  ),
  const BibleStory(
    id: '2',
    title: 'David and the Giant',
    subtitle: 'Faith Conquers Fear',
    ageGroup: AgeGroup.age_7_10,
    duration: 12,
    description:
        'See how young David defeats the mighty giant Goliath with just a stone and his faith in God.',
    moralLesson:
        'With God\'s help, even children can do great things when they trust Him.',
    bibleReference: '1 Samuel 17',
    completed: true,
    favorite: true,
    category: StoryCategory.old_testament,
    tags: ['courage', 'faith', 'shepherd', 'victory'],
  ),
  const BibleStory(
    id: '3',
    title: 'Baby Jesus is Born',
    subtitle: 'The Greatest Gift Ever',
    ageGroup: AgeGroup.age_3_6,
    duration: 10,
    description:
        'Journey to Bethlehem and witness the birth of Jesus, God\'s special gift to the world.',
    moralLesson: 'God loves us so much that He sent Jesus to be our Savior.',
    bibleReference: 'Luke 2:1-20',
    completed: false,
    favorite: true,
    category: StoryCategory.new_testament,
    tags: ['Christmas', 'Bethlehem', 'angels', 'shepherds', 'love'],
  ),
  const BibleStory(
    id: '4',
    title: 'Jesus Feeds 5,000 People',
    subtitle: 'Sharing Makes Miracles',
    ageGroup: AgeGroup.age_7_10,
    duration: 9,
    description:
        'Watch Jesus turn a boy\'s small lunch into a feast that feeds thousands of hungry people.',
    moralLesson:
        'God can use our small gifts to do big things when we share with others.',
    bibleReference: 'Matthew 14:13-21',
    completed: false,
    favorite: false,
    category: StoryCategory.miracles,
    tags: ['sharing', 'multiplication', 'compassion', 'disciples'],
  ),
  const BibleStory(
    id: '5',
    title: 'Daniel in the Lions\' Den',
    subtitle: 'Prayer Protects Us',
    ageGroup: AgeGroup.age_7_10,
    duration: 14,
    description:
        'See how Daniel\'s faithfulness and prayer time saves him from hungry lions.',
    moralLesson:
        'When we pray and trust God, He protects us even in scary times.',
    bibleReference: 'Daniel 6',
    completed: false,
    favorite: false,
    category: StoryCategory.old_testament,
    tags: ['prayer', 'protection', 'faithfulness', 'courage'],
  ),
  const BibleStory(
    id: '6',
    title: 'The Good Samaritan',
    subtitle: 'Love Your Neighbor',
    ageGroup: AgeGroup.age_11_14,
    duration: 7,
    description:
        'Learn about kindness and helping others through Jesus\' parable of the Good Samaritan.',
    moralLesson:
        'We should help anyone in need, even if they are different from us.',
    bibleReference: 'Luke 10:25-37',
    completed: false,
    favorite: false,
    category: StoryCategory.parables,
    tags: ['kindness', 'helping', 'love', 'neighbor', 'mercy'],
  ),
  const BibleStory(
    id: '7',
    title: 'Moses and the Red Sea',
    subtitle: 'God Makes a Way',
    ageGroup: AgeGroup.age_7_10,
    duration: 16,
    description:
        'Experience the amazing moment when God parts the Red Sea to save His people from Egypt.',
    moralLesson:
        'God always makes a way for His people, even when it seems impossible.',
    bibleReference: 'Exodus 14',
    completed: false,
    favorite: false,
    category: StoryCategory.old_testament,
    tags: ['miracle', 'deliverance', 'sea', 'Egypt', 'freedom'],
  ),
  const BibleStory(
    id: '8',
    title: 'Jesus Walks on Water',
    subtitle: 'Trust in the Storm',
    ageGroup: AgeGroup.age_11_14,
    duration: 11,
    description:
        'Join the disciples as they see Jesus walking on the stormy sea and learn about trusting God.',
    moralLesson:
        'Jesus is with us in every storm and helps us when we call on Him.',
    bibleReference: 'Matthew 14:22-33',
    completed: false,
    favorite: false,
    category: StoryCategory.miracles,
    tags: ['trust', 'storm', 'water', 'faith', 'Peter'],
  ),
  const BibleStory(
    id: '9',
    title: 'The Lost Sheep',
    subtitle: 'God Never Gives Up on Us',
    ageGroup: AgeGroup.age_3_6,
    duration: 6,
    description:
        'Follow the shepherd as he searches for his one lost sheep in this beautiful parable.',
    moralLesson:
        'God loves each of us so much that He never stops looking for us when we\'re lost.',
    bibleReference: 'Luke 15:3-7',
    completed: false,
    favorite: false,
    category: StoryCategory.parables,
    tags: ['love', 'searching', 'shepherd', 'lost', 'found'],
  ),
  const BibleStory(
    id: '10',
    title: 'Creation Week',
    subtitle: 'God Makes Everything Beautiful',
    ageGroup: AgeGroup.age_3_6,
    duration: 18,
    description:
        'Discover how God created the world in six days and rested on the Sabbath.',
    moralLesson:
        'God created everything beautiful, including us, and gave us the Sabbath to rest.',
    bibleReference: 'Genesis 1-2',
    completed: false,
    favorite: true,
    category: StoryCategory.old_testament,
    tags: ['creation', 'sabbath', 'rest', 'nature', 'beautiful'],
  ),
];
