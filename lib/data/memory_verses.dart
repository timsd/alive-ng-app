class MemoryVerse {
  final String id;
  final String reference;
  final String text;
  final VerseCategory category;
  final VerseDifficulty difficulty;
  final int points;

  const MemoryVerse({
    required this.id,
    required this.reference,
    required this.text,
    required this.category,
    required this.difficulty,
    required this.points,
  });

  factory MemoryVerse.fromJson(Map<String, dynamic> json) {
    return MemoryVerse(
      id: json['id'] as String,
      reference: json['reference'] as String,
      text: json['text'] as String,
      category: VerseCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      difficulty: VerseDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
      ),
      points: json['points'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'text': text,
      'category': category.name,
      'difficulty': difficulty.name,
      'points': points,
    };
  }

  MemoryVerse copyWith({
    String? id,
    String? reference,
    String? text,
    VerseCategory? category,
    VerseDifficulty? difficulty,
    int? points,
  }) {
    return MemoryVerse(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      text: text ?? this.text,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      points: points ?? this.points,
    );
  }
}

enum VerseCategory {
  faith('Faith'),
  love('Love'),
  hope('Hope'),
  salvation('Salvation'),
  prayer('Prayer'),
  obedience('Obedience');

  const VerseCategory(this.displayName);
  final String displayName;
}

enum VerseDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const VerseDifficulty(this.displayName);
  final String displayName;
}

final List<MemoryVerse> memoryVerses = [
  const MemoryVerse(
    id: "1",
    reference: "John 3:16",
    text:
        "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
    category: VerseCategory.salvation,
    difficulty: VerseDifficulty.easy,
    points: 10,
  ),
  const MemoryVerse(
    id: "2",
    reference: "Philippians 4:13",
    text: "I can do all this through him who gives me strength.",
    category: VerseCategory.faith,
    difficulty: VerseDifficulty.easy,
    points: 10,
  ),
  const MemoryVerse(
    id: "3",
    reference: "Psalm 23:1",
    text: "The Lord is my shepherd, I lack nothing.",
    category: VerseCategory.faith,
    difficulty: VerseDifficulty.easy,
    points: 10,
  ),
  const MemoryVerse(
    id: "4",
    reference: "Romans 8:28",
    text:
        "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
    category: VerseCategory.faith,
    difficulty: VerseDifficulty.medium,
    points: 15,
  ),
  const MemoryVerse(
    id: "5",
    reference: "1 John 4:19",
    text: "We love because he first loved us.",
    category: VerseCategory.love,
    difficulty: VerseDifficulty.easy,
    points: 10,
  ),
  const MemoryVerse(
    id: "6",
    reference: "Jeremiah 29:11",
    text:
        "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, to give you hope and a future.",
    category: VerseCategory.hope,
    difficulty: VerseDifficulty.medium,
    points: 15,
  ),
  const MemoryVerse(
    id: "7",
    reference: "Matthew 6:33",
    text:
        "But seek first his kingdom and his righteousness, and all these things will be given to you as well.",
    category: VerseCategory.obedience,
    difficulty: VerseDifficulty.medium,
    points: 15,
  ),
  const MemoryVerse(
    id: "8",
    reference: "1 Thessalonians 5:17",
    text: "Pray continually.",
    category: VerseCategory.prayer,
    difficulty: VerseDifficulty.easy,
    points: 10,
  ),
  const MemoryVerse(
    id: "9",
    reference: "Ephesians 2:8-9",
    text:
        "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.",
    category: VerseCategory.salvation,
    difficulty: VerseDifficulty.hard,
    points: 20,
  ),
  const MemoryVerse(
    id: "10",
    reference: "Proverbs 3:5-6",
    text:
        "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
    category: VerseCategory.faith,
    difficulty: VerseDifficulty.hard,
    points: 20,
  ),
];
