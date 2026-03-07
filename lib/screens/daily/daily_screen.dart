import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';

import '../../providers/language_provider.dart';
import '../../models/app_models.dart';
import '../../widgets/daily_verse_card.dart';
import '../../services/daily_verse_repository.dart';
import '../../services/daily_verse_generation_service.dart';
import '../../services/bible_source.dart';
import '../../utils/text_formatter.dart';
import '../../utils/responsive_utils.dart';

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

    // Try to get today's verse from database
    DailyVerse? dailyVerse = await repo.getDailyVerse(DateTime.now());

    // If no verse exists for today, generate one
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
    ),
    const DailyTask(
      id: '2',
      title: 'Bible Reading',
      description: 'Read today\'s scripture passage',
      icon: Icons.menu_book,
      completed: false,
      category: 'Study',
    ),
    const DailyTask(
      id: '3',
      title: 'Health Check',
      description: 'Track your wellness activities',
      icon: Icons.health_and_safety,
      completed: false,
      category: 'Health',
    ),
    const DailyTask(
      id: '4',
      title: 'Evening Reflection',
      description: 'Reflect on God\'s blessings today',
      icon: Icons.self_improvement,
      completed: false,
      category: 'Reflection',
    ),
  ];
});

class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final dailyVerseAsync = ref.watch(dailyVerseProvider);
    final dailyTasks = ref.watch(dailyTasksProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('daily'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
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
              // Header section
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
                                color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),

              // Daily Verse Section
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveValue(
                        context: context, mobile: 16, tablet: 20, desktop: 24)),
                child: dailyVerseAsync.when(
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
              ),

              SizedBox(
                  height: ResponsiveUtils.getResponsiveValue(
                      context: context, mobile: 20, tablet: 24, desktop: 28)),

              // Daily Tasks Section
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

              // Progress Summary
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
        return DailyTaskCard(
          task: task,
          onToggle: (completed) {
            final updatedTasks = [...tasks];
            updatedTasks[index] = task.copyWith(completed: completed);
            ref.read(dailyTasksProvider.notifier).state = updatedTasks;
          },
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
            color: Colors.black.withValues(alpha: 0.1),
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
}

class DailyTask {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool completed;
  final String category;

  const DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.completed,
    required this.category,
  });

  DailyTask copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    bool? completed,
    String? category,
  }) {
    return DailyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      completed: completed ?? this.completed,
      category: category ?? this.category,
    );
  }
}

class DailyTaskCard extends StatelessWidget {
  final DailyTask task;
  final Function(bool) onToggle;

  const DailyTaskCard({
    super.key,
    required this.task,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: () => onToggle(!task.completed),
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
                  ],
                ),
              ),
              Checkbox(
                value: task.completed,
                onChanged: (value) => onToggle(value ?? false),
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
