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