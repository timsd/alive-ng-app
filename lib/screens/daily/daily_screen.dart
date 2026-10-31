import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/custom_app_bar.dart';
import '../../providers/language_provider.dart';
import '../../models/app_models.dart';
import '../../widgets/daily_verse_card.dart';
import '../../services/daily_verse_generation_service.dart';
import '../../services/bible_source.dart';
import '../../constants/daily_verses_translations.dart';
import '../../utils/text_formatter.dart';
import '../../utils/responsive_utils.dart';
import '../../constants/app_constants.dart';

// Localized verse helper
String? _getTranslatedVerseText(String reference, String langCode) {
  if (langCode == 'en') return null;
  if (dailyVerseTranslations.containsKey(reference)) {
    final t = dailyVerseTranslations[reference]?[langCode];
    if (t != null && t.trim().isNotEmpty) return t;
  }
  final cleanRef = reference.trim().toLowerCase();
  for (final entry in dailyVerseTranslations.entries) {
    if (entry.key.trim().toLowerCase() == cleanRef) {
      final t = entry.value[langCode];
      if (t != null && t.trim().isNotEmpty) return t;
    }
  }
  final localVersion = {'yo': 'BM', 'ha': 'HAU', 'ig': 'IGBOB'}[langCode] ?? 'KJV';
  final corpus = BibleSource.instance.dailyCorpus;
  final matching = corpus.where((cv) => cv.reference.trim().toLowerCase() == cleanRef).firstOrNull;
  final matchText = matching?.text[localVersion] ?? matching?.text[langCode];
  if (matchText != null && matchText.trim().isNotEmpty) return matchText;

  final translatedKeys = dailyVerseTranslations.keys.toList();
  if (translatedKeys.isNotEmpty) {
    final now = DateTime.now();
    final epochDays = now.toUtc().difference(DateTime.utc(1970, 1, 1)).inDays;
    final fallbackRef = translatedKeys[epochDays % translatedKeys.length];
    return dailyVerseTranslations[fallbackRef]?[langCode];
  }
  return null;
}

String _getLocalizedReflection(String langCode) {
  switch (langCode) {
    case 'yo':
      return 'Kí ọ̀rọ̀ Ọlọ́run jẹ́ ìmọ́lẹ̀ sí ipa-ọ̀nà rẹ lónìí. Gbẹ́kẹ̀lé Olúwa pẹ̀lú gbogbo àyà rẹ, kí o sì rìn nínú àlàáfíà àti ìfẹ́ Rẹ̀.';
    case 'ha':
      return 'Bari maganar Allah ta zama haske ga tafarkinka a yau. Ka dogara ga Ubangiji da dukan zuciyarka kuma ka yi tafiya cikin salama da ƙaunarsa.';
    case 'ig':
      return 'Ka okwu Chineke bụrụ ìhè n\'ụzọ gị taa. Tụkwasị Onye-nwe obi gị niile, ma jee ije n\'udo na ịhụnanya Ya.';
    case 'en':
    default:
      return 'Let God\'s word guide your steps and illuminate your path today. Trust in the Lord with all your heart, walking in His grace and perfect peace.';
  }
}

// Provider for daily verse
final dailyVerseProvider = FutureProvider<DailyVerse?>((ref) async {
  final locale = ref.watch(localeProvider);
  final langCode = locale.languageCode;

  DailyVerse fallbackVerse() {
    final now = DateTime.now();
    final epochDays = now.toUtc().difference(DateTime.utc(1970, 1, 1)).inDays;
    final localVersion = {'yo': 'BM', 'ha': 'HAU', 'ig': 'IGBOB'}[langCode] ?? 'KJV';

    if (langCode != 'en') {
      final translatedKeys = dailyVerseTranslations.keys.toList();
      final refKey = translatedKeys[epochDays % translatedKeys.length];
      final text = dailyVerseTranslations[refKey]?[langCode] ?? 'Gbẹ́kẹ̀lé Olúwa pẹ̀lú gbogbo àyà rẹ.';
      return DailyVerse(
        id: 'local-fallback-$langCode',
        verse: text,
        reference: refKey,
        translation: localVersion,
        date: now,
        reflection: _getLocalizedReflection(langCode),
        createdAt: DateTime.now(),
      );
    }

    final verses = BibleSource.instance.dailyCorpus;
    final index = verses.isEmpty ? 0 : epochDays % verses.length;
    final v = verses.isEmpty ? null : verses[index];
    final text = v?.text['KJV'] ?? v?.text.values.firstOrNull ?? 'Trust in the Lord with all your heart.';
    return DailyVerse(
      id: 'local-fallback-$langCode',
      verse: text,
      reference: v?.reference ?? 'Proverbs 3:5',
      translation: 'KJV',
      date: now,
      reflection: _getLocalizedReflection(langCode),
      createdAt: DateTime.now(),
    );
  }

  try {
    final verseGenerator = DailyVerseGenerationService.instance;
    final dailyVerse = await verseGenerator.generateDailyVerseForToday(languageCode: langCode);
    if (dailyVerse != null) {
      if (langCode != 'en') {
        final localVersion = {'yo': 'BM', 'ha': 'HAU', 'ig': 'IGBOB'}[langCode] ?? 'KJV';
        final translatedText = _getTranslatedVerseText(dailyVerse.reference, langCode);
        if (translatedText != null && translatedText.trim().isNotEmpty) {
          return DailyVerse(
            id: dailyVerse.id,
            verse: translatedText,
            reference: dailyVerse.reference,
            translation: localVersion,
            date: dailyVerse.date,
            reflection: _getLocalizedReflection(langCode),
            createdAt: dailyVerse.createdAt,
          );
        }
      }
      return dailyVerse;
    }
    return fallbackVerse();
  } catch (e) {
    debugPrint('Error fetching/generating daily verse: $e');
    return fallbackVerse();
  }
});

// Provider for daily tasks
final dailyTasksProvider = StateProvider<List<DailyTask>>((ref) {
  return [
    const DailyTask(
      id: '1',
      title: 'Morning Prayer',
      description: 'Start your day with prayer and meditation',
      icon: Icons.favorite,
      completed: false,
      category: 'Prayer',
      route: AppConstants.prayerWallRoute,
    ),
    const DailyTask(
      id: '2',
      title: 'Bible Reading',
      description: 'Read today\'s scripture passage',
      icon: Icons.menu_book,
      completed: false,
      category: 'Study',
      route: AppConstants.bibleRoute,
    ),
    const DailyTask(
      id: '3',
      title: 'Health Check',
      description: 'Track your wellness activities',
      icon: Icons.health_and_safety,
      completed: false,
      category: 'Health',
      route: AppConstants.healthRoute,
    ),
    const DailyTask(
      id: '4',
      title: 'Evening Reflection',
      description: 'Reflect on God\'s blessings today',
      icon: Icons.self_improvement,
      completed: false,
      category: 'Reflection',
      route: AppConstants.testimoniesRoute,
    ),
  ];
});

String _getLocalizedTaskTitle(String id, String defaultTitle, String langCode) {
  switch (langCode) {
    case 'yo':
      switch (id) {
        case '1': return 'Àdúrà Àárọ̀';
        case '2': return 'Kíkà Bíbélì';
        case '3': return 'Ìtọ́jú Ìlera';
        case '4': return 'Àṣàrò Ìrọ̀lẹ́';
      }
      break;
    case 'ha':
      switch (id) {
        case '1': return 'Addu\'ar Safe';
        case '2': return 'Karanta Littafi Mai Tsarki';
        case '3': return 'Kula da Lafiya';
        case '4': return 'Tunani na Yamma';
      }
      break;
    case 'ig':
      switch (id) {
        case '1': return 'Ekpere Ụtụtụ';
        case '2': return 'Ọgụgụ Baịbụl';
        case '3': return 'Nlekọta Ahụike';
        case '4': return 'Ntụgharị Uche Anyasị';
      }
      break;
  }
  return defaultTitle;
}

String _getLocalizedTaskDescription(String id, String defaultDesc, String langCode) {
  switch (langCode) {
    case 'yo':
      switch (id) {
        case '1': return 'Bẹ̀rẹ̀ ọjọ́ rẹ pẹ̀lú àdúrà àti àṣàrò';
        case '2': return 'Ka ẹsẹ Bíbélì tí òní';
        case '3': return 'Ṣe àyẹ̀wò àwọn ìgbésẹ̀ ìlera rẹ';
        case '4': return 'Ronú lórí àwọn ìbùkún Ọlọ́run lónìí';
      }
      break;
    case 'ha':
      switch (id) {
        case '1': return 'Fara ranarka da addu\'a da bimbini';
        case '2': return 'Karanta ayar yau';
        case '3': return 'Bibiyar ayyukan lafiyarka';
        case '4': return 'Yi tunani a kan albarkar Allah a yau';
      }
      break;
    case 'ig':
      switch (id) {
        case '1': return 'Bido ụbọchị gị site n\'ekpere na ịtụgharị uche';
        case '2': return 'Gụọ amaokwu Baịbụl nke taa';
        case '3': return 'Sochie mmemme ahụike gị';
        case '4': return 'Tụgharịa uche n\'ngọzi Chineke taa';
      }
      break;
  }
  return defaultDesc;
}

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  static const _requiredDuration = Duration(minutes: 5);

  final Map<String, DateTime> _taskStartTimes = {};
  Timer? _timer;
  int _currentStreak = 1;

  @override
  void initState() {
    super.initState();
    _loadStreak();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _autoCompleteElapsedTasks();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    final dailyVerseAsync = ref.watch(dailyVerseProvider);
    final dailyTasks = ref.watch(dailyTasksProvider);

    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: true,
        title: translate('daily'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyVerseProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                        ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28)),
                    bottomRight: Radius.circular(
                        ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 20,
                            tablet: 24,
                            desktop: 28)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDateString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondary
                                .withValues(alpha: 0.95),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),
              dailyVerseAsync.when(
                data: (verse) => DailyVerseCard(
                  verse: verse,
                  isLoading: false,
                ),
                loading: () => const DailyVerseCard(
                  verse: null,
                  isLoading: true,
                ),
                error: (error, stack) => const DailyVerseCard(
                  verse: null,
                  isLoading: false,
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),
              // Spiritual Habit & Consistency Card
              Container(
                margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5B94D).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bookmark_added_rounded,
                        color: Color(0xFFD4A017),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_currentStreak Day Devotional Journey',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _currentStreak > 1
                                ? 'You have dedicated $_currentStreak consecutive days to scripture and reflection.'
                                : 'Complete your daily devotional tasks to build a steadfast habit in the Word.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 16, tablet: 20, desktop: 24)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                child: Text(
                  TextFormatter.formatActivityType('daily_tasks'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              _buildDailyTasks(context, translate, dailyTasks, ref),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),
              _buildProgressSummary(context, translate, dailyTasks),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _buildDailyTasks(BuildContext context,
      String Function(String) translate, List<DailyTask> tasks, WidgetRef ref) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 16, tablet: 20, desktop: 24)),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final startAt = _taskStartTimes[task.id];
        final remaining = startAt == null
            ? _requiredDuration
            : _requiredDuration - DateTime.now().difference(startAt);

        return DailyTaskCard(
          task: task,
          trackingStarted: startAt != null,
          remaining: remaining,
          onToggle: (completed) {
            final updatedTasks = [...tasks];
            updatedTasks[index] = task.copyWith(completed: completed);
            ref.read(dailyTasksProvider.notifier).state = updatedTasks;
            if (completed) {
              _taskStartTimes.remove(task.id);
            }
          },
          onStart: () => _startTask(context, ref, tasks, index),
          languageCode: ref.watch(localeProvider).languageCode,
        );
      },
    );
  }

  Widget _buildProgressSummary(BuildContext context,
      String Function(String) translate, List<DailyTask> tasks) {
    final completedTasks = tasks.where((task) => task.completed).length;
    final totalTasks = tasks.length;
    final progressPercentage =
        totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 16, tablet: 20, desktop: 24)),
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: ResponsiveUtils.getResponsiveValue(
                context: context, mobile: 6, tablet: 8, desktop: 10),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TextFormatter.formatTimeText('today_progress'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 12, tablet: 16, desktop: 20)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedTasks / $totalTasks ${TextFormatter.formatActivityType('tasks_completed')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 6,
                            tablet: 8,
                            desktop: 10)),
                    LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              Text(
                '${(progressPercentage * 100).round()}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startTask(BuildContext context, WidgetRef ref, List<DailyTask> tasks, int index) {
    final task = tasks[index];
    if (task.completed) return;

    _taskStartTimes.putIfAbsent(task.id, () => DateTime.now());
    setState(() {});

    context.go(task.route);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking started for ${task.title}. Complete 5 minutes to auto-mark done.'),
      ),
    );
  }

  Future<void> _loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDateStr = prefs.getString('daily_last_active_date');
      final savedStreak = prefs.getInt('daily_streak_count') ?? 1;

      if (lastDateStr != null) {
        final lastDate = DateTime.tryParse(lastDateStr);
        if (lastDate != null) {
          final now = DateTime.now();
          final diff = DateTime(now.year, now.month, now.day)
              .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
              .inDays;
          if (diff <= 1) {
            _currentStreak = savedStreak;
          } else {
            _currentStreak = 1;
            await prefs.setInt('daily_streak_count', 1);
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _recordStreakActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastDateStr = prefs.getString('daily_last_active_date');

      if (lastDateStr != todayStr) {
        int newStreak = _currentStreak;
        if (lastDateStr != null) {
          final lastDate = DateTime.tryParse(lastDateStr);
          if (lastDate != null) {
            final diff = DateTime(now.year, now.month, now.day)
                .difference(
                    DateTime(lastDate.year, lastDate.month, lastDate.day))
                .inDays;
            newStreak = (diff == 1) ? (_currentStreak + 1) : 1;
          }
        } else {
          newStreak = 1;
        }
        _currentStreak = newStreak;
        await prefs.setInt('daily_streak_count', newStreak);
        await prefs.setString('daily_last_active_date', todayStr);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _autoCompleteElapsedTasks() {
    final tasks = ref.read(dailyTasksProvider);
    if (_taskStartTimes.isEmpty || tasks.isEmpty) return;

    bool changed = false;
    final updated = [...tasks];
    final now = DateTime.now();

    for (var i = 0; i < updated.length; i++) {
      final task = updated[i];
      if (task.completed) continue;
      final start = _taskStartTimes[task.id];
      if (start == null) continue;

      if (now.difference(start) >= _requiredDuration) {
        updated[i] = task.copyWith(completed: true);
        _taskStartTimes.remove(task.id);
        changed = true;
        _recordStreakActivity();
      }
    }

    if (changed) {
      ref.read(dailyTasksProvider.notifier).state = updated;
    }
  }
}

class DailyTask {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool completed;
  final String category;
  final String route;

  const DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.completed,
    required this.category,
    required this.route,
  });

  DailyTask copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    bool? completed,
    String? category,
    String? route,
  }) {
    return DailyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      completed: completed ?? this.completed,
      category: category ?? this.category,
      route: route ?? this.route,
    );
  }
}

class DailyTaskCard extends StatelessWidget {
  final DailyTask task;
  final bool trackingStarted;
  final Duration remaining;
  final Function(bool) onToggle;
  final VoidCallback onStart;
  final String languageCode;

  const DailyTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.trackingStarted,
    required this.remaining,
    required this.onStart,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final timeLeft = remaining.isNegative ? Duration.zero : remaining;
    final timeText =
        '${timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0')}:${timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0')}';

    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 10, tablet: 12, desktop: 14)),
      elevation: task.completed ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20)),
      ),
      child: InkWell(
        onTap: task.completed ? null : onStart,
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 12, tablet: 16, desktop: 20)),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 12, tablet: 16, desktop: 20)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 6, tablet: 8, desktop: 10)),
                decoration: BoxDecoration(
                  color: task.completed
                      ? Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.2)
                      : Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveValue(
                          context: context, mobile: 6, tablet: 8, desktop: 10)),
                ),
                child: Icon(
                  task.icon,
                  color: task.completed
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28),
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 12, tablet: 16, desktop: 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getLocalizedTaskTitle(task.id, task.title, languageCode),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.completed
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6)
                                : null,
                          ),
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 3.0,
                      tablet: 4.0,
                      desktop: 5.0,
                    )),
                    Text(
                      _getLocalizedTaskDescription(task.id, task.description, languageCode),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: task.completed
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                          ),
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 3.0,
                      tablet: 4.0,
                      desktop: 5.0,
                    )),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 6,
                              tablet: 8,
                              desktop: 10),
                          vertical: ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 1,
                              tablet: 2,
                              desktop: 3)),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 10,
                                tablet: 12,
                                desktop: 14)),
                      ),
                      child: Text(
                        task.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    if (!task.completed && trackingStarted) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Tracking... $timeText left',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: task.completed
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please open and complete this activity to automatically verify progress!',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        onStart();
                      },
                child: Checkbox(
                  value: task.completed,
                  onChanged: task.completed
                      ? null
                      : (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please open and complete this activity to automatically verify progress!',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          onStart();
                        },
                  activeColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
