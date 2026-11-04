import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InteractiveLessonItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;
  final String duration;
  final String content;
  final String? tractId;
  final bool isFavorite;
  final double progress;
  final bool isCompleted;
  final bool isActive;

  const InteractiveLessonItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.duration,
    required this.content,
    this.tractId,
    this.isFavorite = false,
    this.progress = 0.0,
    this.isCompleted = false,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'level': level,
        'duration': duration,
        'content': content,
        'tractId': tractId,
        'isFavorite': isFavorite,
        'progress': progress,
        'isCompleted': isCompleted,
        'isActive': isActive,
      };

  factory InteractiveLessonItem.fromJson(Map<String, dynamic> json) =>
      InteractiveLessonItem(
        id: json['id'] as String? ?? 'lesson_${DateTime.now().millisecondsSinceEpoch}',
        title: json['title'] as String? ?? 'Untitled Lesson',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Bible Study',
        level: json['level'] as String? ?? 'Beginner',
        duration: json['duration'] as String? ?? '30 min',
        content: json['content'] as String? ?? '',
        tractId: json['tractId'] as String?,
        isFavorite: json['isFavorite'] as bool? ?? false,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        isCompleted: json['isCompleted'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
      );

  InteractiveLessonItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? level,
    String? duration,
    String? content,
    String? tractId,
    bool? isFavorite,
    double? progress,
    bool? isCompleted,
    bool? isActive,
  }) {
    return InteractiveLessonItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      level: level ?? this.level,
      duration: duration ?? this.duration,
      content: content ?? this.content,
      tractId: tractId ?? this.tractId,
      isFavorite: isFavorite ?? this.isFavorite,
      progress: progress ?? this.progress,
      isCompleted: isCompleted ?? this.isCompleted,
      isActive: isActive ?? this.isActive,
    );
  }
}

class InteractiveLessonsService extends ChangeNotifier {
  static final InteractiveLessonsService _instance =
      InteractiveLessonsService._internal();
  factory InteractiveLessonsService() => _instance;
  static InteractiveLessonsService get instance => _instance;

  InteractiveLessonsService._internal() {
    _loadLessons();
  }

  static const String _storageKey = 'interactive_lessons_list';
  static const String _progressPrefix = 'lesson_progress_';

  List<InteractiveLessonItem> _lessons = [];
  bool _isLoaded = false;

  List<InteractiveLessonItem> get lessons => List.unmodifiable(_lessons);
  List<InteractiveLessonItem> get activeLessons =>
      _lessons.where((l) => l.isActive).toList();
  bool get isLoaded => _isLoaded;

  Future<void> _loadLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJsonList = prefs.getStringList(_storageKey);

      if (savedJsonList != null && savedJsonList.isNotEmpty) {
        _lessons = savedJsonList
            .map((s) => InteractiveLessonItem.fromJson(jsonDecode(s)))
            .toList();
      } else {
        _lessons = List.from(_defaultLessons);
        await _persistLessons();
      }

      // Sync member progress stored locally
      for (int i = 0; i < _lessons.length; i++) {
        final prog = prefs.getDouble('$_progressPrefix${_lessons[i].id}');
        if (prog != null) {
          _lessons[i] = _lessons[i].copyWith(
            progress: prog,
            isCompleted: prog >= 1.0,
          );
        }
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load interactive lessons: $e');
      _lessons = List.from(_defaultLessons);
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persistLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _lessons.map((l) => jsonEncode(l.toJson())).toList();
      await prefs.setStringList(_storageKey, list);
    } catch (e) {
      debugPrint('Failed to persist lessons: $e');
    }
  }

  Future<void> saveLesson(InteractiveLessonItem lesson) async {
    final idx = _lessons.indexWhere((l) => l.id == lesson.id);
    if (idx != -1) {
      _lessons[idx] = lesson;
    } else {
      _lessons.insert(0, lesson);
    }
    await _persistLessons();
    notifyListeners();
  }

  Future<void> deleteLesson(String lessonId) async {
    _lessons.removeWhere((l) => l.id == lessonId);
    await _persistLessons();
    notifyListeners();
  }

  Future<void> toggleFavorite(String lessonId) async {
    final idx = _lessons.indexWhere((l) => l.id == lessonId);
    if (idx != -1) {
      final cur = _lessons[idx];
      _lessons[idx] = cur.copyWith(isFavorite: !cur.isFavorite);
      await _persistLessons();
      notifyListeners();
    }
  }

  Future<void> updateLessonProgress(String lessonId, double progress) async {
    final clamped = progress.clamp(0.0, 1.0);
    final idx = _lessons.indexWhere((l) => l.id == lessonId);
    if (idx != -1) {
      _lessons[idx] = _lessons[idx].copyWith(
        progress: clamped,
        isCompleted: clamped >= 1.0,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_progressPrefix$lessonId', clamped);
      await _persistLessons();
      notifyListeners();
    }
  }

  // Pre-populated Curated Production Lessons
  static final List<InteractiveLessonItem> _defaultLessons = [
    const InteractiveLessonItem(
      id: 'lesson_great_controversy',
      title: 'The Great Controversy',
      description: 'Understanding the cosmic conflict between Christ and Satan, and the ultimate triumph of God\'s love and justice.',
      category: 'Bible Study',
      level: 'Intermediate',
      duration: '45 min',
      tractId: 'tract_great_controversy',
      content: '''# The Great Controversy

## 1. The Origin of Evil
Before the entrance of evil there was peace and joy throughout the universe. All was in perfect harmony with the Creator's will. Love to God was supreme, love for one another impartial.

> "How art thou fallen from heaven, O Lucifer, son of the morning! how art thou cut down to the ground, which didst weaken the nations!" — Isaiah 14:12

## 2. The Conflict on Earth
Sin entered our world through deception in Eden. But God immediately revealed His eternal plan of redemption through Jesus Christ (Genesis 3:15).

## 3. The Final Triumph
At the cross, Satan's character was unmasked before the unfallen universe. Christ declared, "It is finished!" Victory is assured for every believer who overcomes by the blood of the Lamb.''',
      isFavorite: true,
      progress: 0.0,
      isCompleted: false,
      isActive: true,
    ),
    const InteractiveLessonItem(
      id: 'lesson_daniel_revelation',
      title: 'Daniel and Revelation',
      description: 'Exploring apocalyptic prophecies, the 2300-day sanctuary timeline, and the Three Angels\' Messages for our time.',
      category: 'Prophecy',
      level: 'Advanced',
      duration: '60 min',
      tractId: 'tract_daniel_prophecy',
      content: '''# Daniel and Revelation: Prophetic Foundations

## 1. The Multi-Metal Statue (Daniel 2)
God outlines the sequence of world empires from Babylon, Medo-Persia, Greece, and Rome, down to the divided nations of Europe—culminating in the everlasting Kingdom of God.

## 2. The 2300-Day Prophecy (Daniel 8:14)
"Unto two thousand and three hundred days; then shall the sanctuary be cleansed." This historic prophecy points directly to the Investigative Judgment beginning in 1844.

## 3. The Three Angels' Messages (Revelation 14:6–12)
1. **First Angel:** The Everlasting Gospel, the hour of His judgment is come, worship the Creator.
2. **Second Angel:** Babylon is fallen.
3. **Third Angel:** Warning against the mark of the beast, and upholding the commandments of God and the faith of Jesus.''',
      isFavorite: false,
      progress: 0.0,
      isCompleted: false,
      isActive: true,
    ),
    const InteractiveLessonItem(
      id: 'lesson_steps_to_christ',
      title: 'Steps to Christ',
      description: 'A transformative study on repentance, surrender, the test of discipleship, and growing up in Christ.',
      category: 'Bible Study',
      level: 'Beginner',
      duration: '30 min',
      tractId: 'tract_steps_to_christ',
      content: '''# Steps to Christ

## 1. God's Love for Man
Nature and revelation alike testify of God's love. Our heavenly Father is the source of life, of wisdom, and of joy.

## 2. The Sinner's Need of Christ
Man was originally endowed with noble powers and a well-balanced mind. Through disobedience, his powers became perverted. Christ alone can renew the heart.

## 3. Repentance and Confession
Repentance includes sorrow for sin and a turning away from it. True confession is always specific and acknowledges the sins committed.

## 4. Growing in Grace
A life in Christ is a life of restfulness. There may be no ecstasy of feeling, but there should be an abiding, peaceful trust.''',
      isFavorite: true,
      progress: 0.0,
      isCompleted: false,
      isActive: true,
    ),
    const InteractiveLessonItem(
      id: 'lesson_biblical_health',
      title: 'Biblical Health & Wholeness',
      description: 'Principles of God\'s health blueprint: nutrition, natural therapeutic remedies, and health as the right arm of the Gospel.',
      category: 'Health',
      level: 'Beginner',
      duration: '40 min',
      content: '''# Biblical Health & Wholeness

## 1. The Body as God's Temple
"What? know ye not that your body is the temple of the Holy Ghost which is in you, which ye have of God, and ye are not your own?" (1 Corinthians 6:19)

## 2. The NEWSTART Principles
* **N**utrition — Clean, plant-based whole foods
* **E**xercise — Daily purposeful movement
* **W**ater — Abundant internal hydration & hydrotherapy
* **S**unlight — Natural vitamin D & immune uplift
* **T**emperance — Self-control in all good things, avoiding harmful substances
* **A**ir — Fresh outdoor oxygenation
* **R**est — Quality sleep and the Sabbath rest
* **T**rust in Divine Power — Peace through complete faith in God''',
      isFavorite: false,
      progress: 0.0,
      isCompleted: false,
      isActive: true,
    ),
    const InteractiveLessonItem(
      id: 'lesson_personal_evangelism',
      title: 'Personal Evangelism & Discipleship',
      description: 'Equipping lay missionaries to share Scripture effectively across Nigerian campuses, rural towns, and marketplaces.',
      category: 'Missions',
      level: 'Intermediate',
      duration: '35 min',
      content: '''# Personal Evangelism & Discipleship

## 1. Christ's Method Alone
"Christ's method alone will give true success in reaching the people. The Saviour mingled with men as one who desired their good. He showed His sympathy for them, ministered to their needs, and won their confidence. Then He bade them, 'Follow Me.'" — Ministry of Healing, p. 143.

## 2. Practical Door-to-Door & Campus Outreach
* Lead with a listening ear and prayer.
* Meet felt needs through health advice, food, and emotional support.
* Share your personal testimony of what Christ has done in your life.
* Introduce inductive Bible study guides.''',
      isFavorite: true,
      progress: 0.0,
      isCompleted: false,
      isActive: true,
    ),
  ];
}
