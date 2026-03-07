class Podcast {
  final String id;
  final String title;
  final String description;
  final PodcastCategory category;
  final String host;
  final int episodes;
  final double rating;
  final bool isSubscribed;
  final List<String> tags;
  final String? coverImage;
  final String? audioUrl;

  const Podcast({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.host,
    required this.episodes,
    required this.rating,
    required this.isSubscribed,
    required this.tags,
    this.coverImage,
    this.audioUrl,
  });

  factory Podcast.fromJson(Map<String, dynamic> json) {
    return Podcast(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: PodcastCategory.values.firstWhere(
        (e) => e.name == json['category'],
      ),
      host: json['host'] as String,
      episodes: json['episodes'] as int,
      rating: (json['rating'] as num).toDouble(),
      isSubscribed: json['isSubscribed'] as bool,
      tags: List<String>.from(json['tags'] as List),
      coverImage: json['coverImage'] as String?,
      audioUrl: json['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'host': host,
      'episodes': episodes,
      'rating': rating,
      'isSubscribed': isSubscribed,
      'tags': tags,
      'coverImage': coverImage,
      'audioUrl': audioUrl,
    };
  }

  Podcast copyWith({
    String? id,
    String? title,
    String? description,
    PodcastCategory? category,
    String? host,
    int? episodes,
    double? rating,
    bool? isSubscribed,
    List<String>? tags,
    String? coverImage,
    String? audioUrl,
  }) {
    return Podcast(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      host: host ?? this.host,
      episodes: episodes ?? this.episodes,
      rating: rating ?? this.rating,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      tags: tags ?? this.tags,
      coverImage: coverImage ?? this.coverImage,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}

class PodcastEpisode {
  final String id;
  final String title;
  final String podcastId;
  final String podcastTitle;
  final String description;
  final String duration;
  final String audioUrl;
  final DateTime publishDate;
  final bool isDownloaded;
  final String? localPath;

  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.podcastId,
    required this.podcastTitle,
    required this.description,
    required this.duration,
    required this.audioUrl,
    required this.publishDate,
    required this.isDownloaded,
    this.localPath,
  });

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) {
    return PodcastEpisode(
      id: json['id'] as String,
      title: json['title'] as String,
      podcastId: json['podcastId'] as String,
      podcastTitle: json['podcastTitle'] as String,
      description: json['description'] as String,
      duration: json['duration'] as String,
      audioUrl: json['audioUrl'] as String,
      publishDate: DateTime.parse(json['publishDate'] as String),
      isDownloaded: json['isDownloaded'] as bool,
      localPath: json['localPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'podcastId': podcastId,
      'podcastTitle': podcastTitle,
      'description': description,
      'duration': duration,
      'audioUrl': audioUrl,
      'publishDate': publishDate.toIso8601String(),
      'isDownloaded': isDownloaded,
      'localPath': localPath,
    };
  }
}

enum PodcastCategory {
  mec('MEC'),
  retreat('Retreat'),
  devotional('Devotional'),
  bibleStudy('Bible Study'),
  youth('Youth'),
  health('Health'),
  missions('Missions'),
  sabbathSchool('Sabbath School'),
  christianLiving('Christian Living'),
  prophecy('Prophecy');

  const PodcastCategory(this.displayName);
  final String displayName;
}

final List<Podcast> podcasts = [
  // MEC Category
  const Podcast(
    id: 'mec_01',
    title: 'MEC Leadership Training',
    description: 'Training sessions for MEC leaders and coordinators.',
    category: PodcastCategory.mec,
    host: 'ALIVE NG Leadership Team',
    episodes: 12,
    rating: 4.8,
    isSubscribed: false,
    tags: ['leadership', 'training', 'mec', 'coordination'],
  ),
  const Podcast(
    id: 'mec_02',
    title: 'MEC Bible Study Series',
    description: 'Deep Bible study sessions designed for MEC groups.',
    category: PodcastCategory.mec,
    host: 'Pastor Emmanuel Adebayo',
    episodes: 24,
    rating: 4.9,
    isSubscribed: false,
    tags: ['bible study', 'mec', 'group study', 'scripture'],
  ),
  const Podcast(
    id: 'mec_03',
    title: 'MEC Evangelism Strategies',
    description: 'Practical evangelism methods and testimonies from MEC groups.',
    category: PodcastCategory.mec,
    host: 'Elder Sarah Okafor',
    episodes: 18,
    rating: 4.7,
    isSubscribed: false,
    tags: ['evangelism', 'outreach', 'mec', 'witnessing'],
  ),

  // Retreat Category
  const Podcast(
    id: 'retreat_01',
    title: 'Youth Retreat Messages',
    description: 'Inspiring messages from ALIVE NG youth retreats.',
    category: PodcastCategory.retreat,
    host: 'Pastor David Ogundimu',
    episodes: 15,
    rating: 4.8,
    isSubscribed: false,
    tags: ['youth', 'retreat', 'inspiration', 'spiritual growth'],
  ),
  const Podcast(
    id: 'retreat_02',
    title: 'Family Retreat Devotions',
    description: 'Family-focused devotional messages from annual retreats.',
    category: PodcastCategory.retreat,
    host: 'Elder Grace Adeyemi',
    episodes: 20,
    rating: 4.9,
    isSubscribed: false,
    tags: ['family', 'retreat', 'devotion', 'relationships'],
  ),
  const Podcast(
    id: 'retreat_03',
    title: 'Leadership Retreat Sessions',
    description: 'Leadership development sessions from ALIVE NG retreats.',
    category: PodcastCategory.retreat,
    host: 'Pastor John Olumide',
    episodes: 10,
    rating: 4.6,
    isSubscribed: false,
    tags: ['leadership', 'retreat', 'development', 'ministry'],
  ),

  // Additional Categories for Future Expansion
  const Podcast(
    id: 'devotional_01',
    title: 'Daily Bread Devotions',
    description: 'Daily inspirational messages for spiritual growth.',
    category: PodcastCategory.devotional,
    host: 'Pastor Mary Adebisi',
    episodes: 365,
    rating: 4.8,
    isSubscribed: false,
    tags: ['daily', 'devotion', 'inspiration', 'spiritual growth'],
  ),
  const Podcast(
    id: 'bible_study_01',
    title: 'Book by Book Bible Study',
    description: 'Systematic study through each book of the Bible.',
    category: PodcastCategory.bibleStudy,
    host: 'Dr. Samuel Adeyinka',
    episodes: 66,
    rating: 4.9,
    isSubscribed: false,
    tags: ['bible study', 'systematic', 'books', 'theology'],
  ),
];

// Sample episodes for demonstration
final List<PodcastEpisode> sampleEpisodes = [
  PodcastEpisode(
    id: 'mec_01_ep_01',
    title: 'Introduction to MEC Leadership',
    podcastId: 'mec_01',
    podcastTitle: 'MEC Leadership Training',
    description: 'Understanding the role and responsibilities of MEC leaders.',
    duration: '25:30',
    audioUrl: '', // Will be populated from Firebase Storage
    publishDate: DateTime(2024, 1, 15),
    isDownloaded: false,
  ),
  PodcastEpisode(
    id: 'retreat_01_ep_01',
    title: 'Walking with God in Your Youth',
    podcastId: 'retreat_01',
    podcastTitle: 'Youth Retreat Messages',
    description: 'How young people can maintain a close relationship with God.',
    duration: '32:15',
    audioUrl: '', // Will be populated from Firebase Storage
    publishDate: DateTime(2024, 2, 1),
    isDownloaded: false,
  ),
];