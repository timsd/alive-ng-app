class Tract {
  final String id;
  final String title;
  final String author;
  final TractCategory category;
  final String description;
  final int pages;
  final String? downloadUrl;
  final String? coverImage;
  final List<String> coverImages; // Multiple cover images for lessons in a series
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
    this.coverImages = const [], // Default to empty list
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
      coverImages: json['coverImages'] != null 
          ? List<String>.from(json['coverImages'] as List)
          : [],
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
      'coverImages': coverImages,
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
    List<String>? coverImages,
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
      coverImages: coverImages ?? this.coverImages,
      featured: featured ?? this.featured,
      tags: tags ?? this.tags,
    );
  }

  // Get primary cover image (explicit coverImage, else first from coverImages, else series image)
  String get primaryCover {
    if (coverImage != null && coverImage!.isNotEmpty) return coverImage!;
    if (coverImages.isNotEmpty) return coverImages.first;
    return category.seriesImage;
  }

  // Get all available covers (combines coverImage + coverImages + series fallback)
  List<String> get allCovers {
    final List<String> all = [];
    if (coverImage != null && coverImage!.isNotEmpty) all.add(coverImage!);
    all.addAll(coverImages);
    if (!all.contains(category.seriesImage)) {
      all.add(category.seriesImage);
    }
    return all;
  }
}

enum TractCategory {
  evangelism('Evangelism'),
  doctrine('Doctrine'),
  health('Health'),
  prophecy('Prophecy'),
  lifestyle('Lifestyle'),
  children('Children'),
  bibleSays('What the Bible Says');

  const TractCategory(this.displayName);
  final String displayName;
  
  // Series avatar images for each category
  String get seriesImage {
    switch (this) {
      case TractCategory.evangelism:
        return 'assets/images/series/evangelism_series.svg';
      case TractCategory.doctrine:
        return 'assets/images/series/doctrine_series.svg';
      case TractCategory.health:
        return 'assets/images/series/health_series.svg';
      case TractCategory.prophecy:
        return 'assets/images/series/prophecy_series.svg';
      case TractCategory.lifestyle:
        return 'assets/images/series/lifestyle_series.svg';
      case TractCategory.children:
        return 'assets/images/series/children_series.svg';
      case TractCategory.bibleSays:
        return 'assets/images/series/bible_says_series.svg';
    }
  }
}

final List<Tract> tracts = [
  // What the Bible Says Series - Lessons 1-11
  const Tract(
    id: 'wbs_01',
    title: 'What the Bible Says - Lesson 1: The Bible',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Understanding the Bible as God\'s Word and its importance in our daily lives.',
    pages: 8,
    featured: true,
    tags: ['bible study', 'scripture', 'word of god'],
  ),
  const Tract(
    id: 'wbs_02',
    title: 'What the Bible Says - Lesson 2: God',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Discovering who God is according to the Bible and His character.',
    pages: 8,
    featured: true,
    tags: ['god', 'character', 'attributes'],
  ),
  const Tract(
    id: 'wbs_03',
    title: 'What the Bible Says - Lesson 3: Jesus Christ',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Learning about Jesus Christ, His divinity, and His role as our Savior.',
    pages: 8,
    featured: true,
    tags: ['jesus', 'savior', 'divinity'],
  ),
  const Tract(
    id: 'wbs_04',
    title: 'What the Bible Says - Lesson 4: The Holy Spirit',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Understanding the Holy Spirit\'s role in our lives and spiritual growth.',
    pages: 8,
    featured: true,
    tags: ['holy spirit', 'spiritual growth', 'trinity'],
  ),
  const Tract(
    id: 'wbs_05',
    title: 'What the Bible Says - Lesson 5: Salvation',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Exploring God\'s plan of salvation and how we can be saved.',
    pages: 8,
    featured: true,
    tags: ['salvation', 'grace', 'redemption'],
  ),
  const Tract(
    id: 'wbs_06',
    title: 'What the Bible Says - Lesson 6: The Law of God',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Understanding God\'s law, the Ten Commandments, and their relevance today.',
    pages: 8,
    featured: true,
    tags: ['ten commandments', 'law', 'obedience'],
  ),
  const Tract(
    id: 'wbs_07',
    title: 'What the Bible Says - Lesson 7: The Sabbath',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Discovering the biblical Sabbath and its importance for Christians.',
    pages: 8,
    featured: true,
    tags: ['sabbath', 'rest', 'worship'],
  ),
  const Tract(
    id: 'wbs_08',
    title: 'What the Bible Says - Lesson 8: Death and the Afterlife',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Understanding what the Bible teaches about death and eternal life.',
    pages: 8,
    featured: true,
    tags: ['death', 'afterlife', 'resurrection'],
  ),
  const Tract(
    id: 'wbs_09',
    title: 'What the Bible Says - Lesson 9: The Second Coming',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Learning about Jesus\' promised return and signs of His coming.',
    pages: 8,
    featured: true,
    tags: ['second coming', 'prophecy', 'hope'],
  ),
  const Tract(
    id: 'wbs_10',
    title: 'What the Bible Says - Lesson 10: The Church',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Understanding the biblical concept of the church and Christian fellowship.',
    pages: 8,
    featured: true,
    tags: ['church', 'fellowship', 'community'],
  ),
  const Tract(
    id: 'wbs_11',
    title: 'What the Bible Says - Lesson 11: Christian Living',
    author: 'ALIVE NG, ALIVE by the Truth',
    category: TractCategory.bibleSays,
    description:
        'Practical guidance for living as a Christian in today\'s world.',
    pages: 8,
    featured: true,
    tags: ['christian living', 'discipleship', 'practical faith'],
  ),
];




