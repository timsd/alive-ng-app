import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/custom_app_bar.dart';
import '../../providers/language_provider.dart';
import '../../models/app_models.dart';
import '../../widgets/daily_verse_card.dart';
import '../../services/daily_verse_repository.dart';
import '../../services/daily_verse_generation_service.dart';
import '../../services/bible_source.dart';
import '../../utils/text_formatter.dart';
import '../../utils/responsive_utils.dart';
import '../../constants/app_constants.dart';

// Provider for daily verse
final dailyVerseProvider = FutureProvider<DailyVerse?>((ref) async {
  DailyVerse fallbackVerse() {
    final now = DateTime.now();
    final epochDays = now.toUtc().difference(DateTime.utc(1970, 1, 1)).inDays;
    final verses = BibleSource.instance.dailyCorpus;
    final index = verses.isEmpty ? 0 : epochDays % verses.length;
    final v = verses.isEmpty ? null : verses[index];
    return DailyVerse(
      id: 'local-fallback',
      verse: v?.text['KJV'] ?? 'Trust in the Lord with all your heart.',
      reference: v?.reference ?? 'Proverbs 3:5',
      translation: 'KJV',
      date: now,
      reflection: null,
      createdAt: DateTime.now(),
    );
  }

  try {
    final repo = DailyVerseRepository.instance;
    final verseGenerator = DailyVerseGenerationService.instance;

    DailyVerse? dailyVerse = await repo.getDailyVerse(DateTime.now());
    if (dailyVerse == null) {
      debugPrint('No daily verse found, generating new one...');
      dailyVerse = await verseGenerator.generateDailyVerseForToday();
    }

    if (dailyVerse == null) {
      return fallbackVerse();
    }

    return dailyVerse;
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
      route: AppConstants.enhancedHealthRoute,
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

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen> {
  static const _requiredDuration = Duration(minutes: 5);

  final Map<String, DateTime> _taskStartTimes = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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
                      TextFormatter.formatActivityType('daily_activities'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    SizedBox(
                        height: ResponsiveUtils.getResponsiveValue(
                            context: context,
                            mobile: 6,
                            tablet: 8,
                            desktop: 10)),
                    Text(
                      _getDateString(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondary.withValues(alpha: 0.9),
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
              // Duolingo-style Streak & Gamification Banner
              Container(
                margin: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🔥', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '3 Day Devotional Streak!',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.orange, size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Complete activities daily to level up your spiritual habit. Automated tracking ensures real execution.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

  const DailyTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.trackingStarted,
    required this.remaining,
    required this.onStart,
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
                      task.title,
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
                      task.description,
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
