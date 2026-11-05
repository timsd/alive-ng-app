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
        // Ensure standard default lessons (like Lesson 1) are present even for existing local storage
        for (final defaultLesson in _defaultLessons.reversed) {
          if (!_lessons.any((l) => l.id == defaultLesson.id)) {
            _lessons.insert(0, defaultLesson);
          }
        }
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
      id: 'lesson_something_we_can_trust',
      title: 'Lesson 1: Something We Can Trust',
      description: 'What The Bible Says Series - Lesson 1. An interactive study on the truth, inspiration, and evidence of God\'s Word.',
      category: 'What the Bible Says',
      level: 'Beginner',
      duration: '20 min',
      tractId: 'test_tract_lesson_1',
      content: '''# Lesson 1: Something We Can Trust

## 1. What does the Bible claim about itself?
"All scripture is given by inspiration of God." (2 Timothy 3:16)
"Prophecy came not in old time by the will of man: but holy men of God spake as they were moved by the Holy Ghost." (2 Peter 1:21)
"The scripture cannot be broken." (John 10:35)

## 2. How did Jesus demonstrate His confidence in Scripture?
Jesus quoted Scripture when meeting the temptations of Satan: "It is written, Man shall not live by bread alone." (Matthew 4:4, 7, 10). He also stated that God's Word is truth (John 17:17).

## 3. Fulfilled Prophecies
Bible predictions confirm inspiration as they come to pass:
* Four world empires: Babylon, Medo-Persia, Greece, and Rome (Daniel 2, 7, 8)
* Cyrus named 150 years beforehand (Isaiah 45:1-3)
* Babylon destroyed, never inhabited again (Isaiah 13:19, 20)

## 4. Scientific Accuracy
* Earth hung upon nothing: Job 26:7
* Earth is a sphere: Isaiah 40:22
* Atomic power holding together: Colossians 1:17

## 5. Transformed Lives
"Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, all things are become new." (2 Corinthians 5:17)

## 6. Messianic Prophecies
More than 125 Old Testament prophecies were fulfilled in Jesus Christ (Luke 24:27; Acts 18:28).

## 7. Advantage of Accepting God's Word
"I understand more than the ancients, because I keep thy precepts." (Psalms 119:100)

## 8. Universal Appeal
The Bible answers life's three most puzzling questions: Where did I come from? Why am I here? What does the future hold for me? (Psalms 119:105; Galatians 3:26; John 14:1-3)''',
      isFavorite: true,
      progress: 0.0,
      isCompleted: false,
      isActive: true,
    ),
  ];
}
