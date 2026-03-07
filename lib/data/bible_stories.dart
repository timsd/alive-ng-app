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
  oldTestament('Old Testament'),
  newTestament('New Testament'),
  parables('Parables'),
  miracles('Miracles'),
  sdaDoctrines('SDA Doctrines'),
  sdaValues('SDA Values');

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
    category: StoryCategory.oldTestament,
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
    category: StoryCategory.oldTestament,
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
    category: StoryCategory.newTestament,
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
    category: StoryCategory.oldTestament,
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
    category: StoryCategory.oldTestament,
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
    category: StoryCategory.oldTestament,
    tags: ['creation', 'sabbath', 'rest', 'nature', 'beautiful'],
  ),
  // SDA-aligned stories and values
  const BibleStory(
    id: '11',
    title: 'Sabbath – A Day of Rest',
    subtitle: 'God’s Special Weekly Gift',
    ageGroup: AgeGroup.age_7_10,
    duration: 12,
    description:
        'Explore why God made the Sabbath day holy and how resting helps us remember Him.',
    moralLesson:
        'God invites us to rest with Him every Sabbath and draw closer to Him and family.',
    bibleReference: 'Exodus 20:8-11; Genesis 2:1-3',
    completed: false,
    favorite: true,
    category: StoryCategory.sdaDoctrines,
    tags: ['sabbath', 'rest', 'worship', 'family', 'creation'],
  ),
  const BibleStory(
    id: '12',
    title: 'Jesus Is Coming Again',
    subtitle: 'Hope in the Second Coming',
    ageGroup: AgeGroup.age_11_14,
    duration: 10,
    description:
        'Learn the promises Jesus gave about His return and how we can live ready every day.',
    moralLesson:
        'We live with hope and kindness, knowing Jesus will return to take us home.',
    bibleReference: 'John 14:1-3; 1 Thessalonians 4:16-17',
    completed: false,
    favorite: false,
    category: StoryCategory.sdaDoctrines,
    tags: ['second coming', 'hope', 'promise', 'heaven', 'readiness'],
  ),
  const BibleStory(
    id: '13',
    title: 'Healthy Choices Like Daniel',
    subtitle: 'Honoring God With Our Bodies',
    ageGroup: AgeGroup.age_7_10,
    duration: 9,
    description:
        'See how Daniel chose healthy foods and trusted God, becoming strong and wise.',
    moralLesson:
        'We honor God by making healthy choices that help our bodies and minds.',
    bibleReference: 'Daniel 1:8-20',
    completed: false,
    favorite: false,
    category: StoryCategory.sdaValues,
    tags: ['health', 'vegetables', 'courage', 'wisdom', 'faith'],
  ),
  const BibleStory(
    id: '14',
    title: 'Caring for God’s World',
    subtitle: 'Stewardship of Creation',
    ageGroup: AgeGroup.age_3_6,
    duration: 7,
    description:
        'Discover how God asked us to care for the earth, animals, and our community.',
    moralLesson:
        'Being good stewards means caring for nature and helping people around us.',
    bibleReference: 'Genesis 1:26-28; 2:15',
    completed: false,
    favorite: false,
    category: StoryCategory.sdaValues,
    tags: ['stewardship', 'creation care', 'animals', 'garden', 'kindness'],
  ),
  const BibleStory(
    id: '15',
    title: 'The Armor of God',
    subtitle: 'Standing Strong for Truth',
    ageGroup: AgeGroup.age_11_14,
    duration: 11,
    description:
        'Learn about the spiritual armor God gives us to stand for truth and love.',
    moralLesson:
        'God equips us with faith, truth, and love to face life’s challenges.',
    bibleReference: 'Ephesians 6:10-18',
    completed: false,
    favorite: true,
    category: StoryCategory.sdaDoctrines,
    tags: ['faith', 'truth', 'righteousness', 'salvation', 'prayer'],
  ),
  const BibleStory(
    id: '16',
    title: 'Jesus and Lazarus',
    subtitle: 'Life Through Jesus',
    ageGroup: AgeGroup.age_7_10,
    duration: 10,
    description:
        'See Jesus’ power over death when He calls Lazarus from the tomb.',
    moralLesson:
        'Jesus is the source of life, and we can trust Him with our future.',
    bibleReference: 'John 11:1-44',
    completed: false,
    favorite: false,
    category: StoryCategory.sdaDoctrines,
    tags: ['life', 'resurrection', 'trust', 'family', 'miracle'],
  ),
];




