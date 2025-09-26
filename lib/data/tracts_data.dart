class Tract {
  final String id;
  final String title;
  final String author;
  final TractCategory category;
  final String description;
  final int pages;
  final String? downloadUrl;
  final String? coverImage;
  final bool featured;
  final List<String> tags;

  const Tract({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    required this.pages,
    this.downloadUrl,
    this.coverImage,
    required this.featured,
    required this.tags,
  });

  factory Tract.fromJson(Map<String, dynamic> json) {
    return Tract(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      category: TractCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      description: json['description'] as String,
      pages: json['pages'] as int,
      downloadUrl: json['downloadUrl'] as String?,
      coverImage: json['coverImage'] as String?,
      featured: json['featured'] as bool,
      tags: List<String>.from(json['tags'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'category': category.name,
      'description': description,
      'pages': pages,
      'downloadUrl': downloadUrl,
      'coverImage': coverImage,
      'featured': featured,
      'tags': tags,
    };
  }

  Tract copyWith({
    String? id,
    String? title,
    String? author,
    TractCategory? category,
    String? description,
    int? pages,
    String? downloadUrl,
    String? coverImage,
    bool? featured,
    List<String>? tags,
  }) {
    return Tract(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      description: description ?? this.description,
      pages: pages ?? this.pages,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      coverImage: coverImage ?? this.coverImage,
      featured: featured ?? this.featured,
      tags: tags ?? this.tags,
    );
  }
}

enum TractCategory {
  evangelism('Evangelism'),
  doctrine('Doctrine'),
  health('Health'),
  prophecy('Prophecy'),
  lifestyle('Lifestyle'),
  children('Children');

  const TractCategory(this.displayName);
  final String displayName;
}

final List<Tract> tracts = [
  const Tract(
    id: '1',
    title: 'Steps to Christ',
    author: 'Ellen G. White',
    category: TractCategory.evangelism,
    description:
        'A beautiful guide to finding Jesus and living the Christian life. Perfect for sharing with friends and family.',
    pages: 96,
    featured: true,
    tags: ['salvation', 'christian living', 'evangelism'],
  ),
  const Tract(
    id: '2',
    title: 'The Great Controversy',
    author: 'Ellen G. White',
    category: TractCategory.prophecy,
    description:
        'The ultimate struggle between good and evil from the destruction of Jerusalem to the new earth.',
    pages: 678,
    featured: true,
    tags: ['prophecy', 'end times', 'history'],
  ),
  const Tract(
    id: '3',
    title: 'The Desire of Ages',
    author: 'Ellen G. White',
    category: TractCategory.doctrine,
    description:
        'The life and ministry of Jesus Christ - His love, sacrifice, and teachings.',
    pages: 835,
    featured: false,
    tags: ['Jesus', 'gospel', 'biography'],
  ),
  const Tract(
    id: '4',
    title: 'Ministry of Healing',
    author: 'Ellen G. White',
    category: TractCategory.health,
    description:
        'Principles of natural health and spiritual healing from the pen of inspiration.',
    pages: 541,
    featured: false,
    tags: ['health', 'healing', 'natural remedies'],
  ),
  const Tract(
    id: '5',
    title: 'What Does the Bible Say About...?',
    author: 'Various Authors',
    category: TractCategory.evangelism,
    description:
        'Quick biblical answers to common questions about Christianity and Adventist beliefs.',
    pages: 32,
    featured: true,
    tags: ['bible study', 'questions', 'doctrine'],
  ),
  const Tract(
    id: '6',
    title: 'The Sabbath: Rest for the Weary',
    author: 'Nigerian Union Conference',
    category: TractCategory.doctrine,
    description:
        'Understanding God\'s gift of the Sabbath and its relevance for modern Nigeria.',
    pages: 24,
    featured: false,
    tags: ['sabbath', 'rest', 'commandments'],
  ),
  const Tract(
    id: '7',
    title: 'Eight Natural Doctors',
    author: 'Nigerian Health Ministries',
    category: TractCategory.health,
    description:
        'Discover God\'s natural remedies: nutrition, exercise, water, sunlight, temperance, air, rest, trust.',
    pages: 48,
    featured: true,
    tags: ['natural health', 'prevention', 'lifestyle'],
  ),
  const Tract(
    id: '8',
    title: 'Bible Stories for Nigerian Children',
    author: 'West African Division',
    category: TractCategory.children,
    description:
        'Exciting Bible stories with African illustrations and cultural relevance for children.',
    pages: 64,
    featured: false,
    tags: ['children', 'stories', 'african culture'],
  ),
  const Tract(
    id: '9',
    title: 'The Three Angels\' Messages',
    author: 'General Conference',
    category: TractCategory.prophecy,
    description:
        'Understanding Revelation 14 and the final message of hope to the world.',
    pages: 40,
    featured: false,
    tags: ['prophecy', 'revelation', 'end times'],
  ),
  const Tract(
    id: '10',
    title: 'Faith and Finance',
    author: 'Stewardship Ministries',
    category: TractCategory.lifestyle,
    description:
        'Biblical principles for managing money and resources in the Nigerian economy.',
    pages: 36,
    featured: false,
    tags: ['stewardship', 'finances', 'tithing'],
  ),
];




