import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../widgets/daily_verse_card.dart';

// Provider for daily verse
final dailyVerseProvider = FutureProvider<BibleVerse?>((ref) async {
  // TODO: Implement actual API call to get daily verse
  await Future.delayed(const Duration(seconds: 1));
  return BibleVerse(
    reference: 'Jeremiah 29:11',
    kjv:
        'For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end.',
    nkjv:
        'For I know the thoughts that I think toward you, says the Lord, thoughts of peace and not of evil, to give you a future and a hope.',
    niv:
        'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, to give you hope and a future.',
  );
});

// Provider for daily tasks
final dailyTasksProvider = StateProvider<List<DailyTask>>((ref) {
  return [
    DailyTask(
      id: '1',
      title: 'Morning Prayer',
      description: 'Start your day with prayer and meditation',
      icon: Icons.favorite,
      completed: false,
      category: 'Prayer',
    ),
    DailyTask(
      id: '2',
      title: 'Bible Reading',
      description: 'Read today\'s scripture passage',
      icon: Icons.menu_book,
      completed: false,
      category: 'Study',
    ),
    DailyTask(
      id: '3',
      title: 'Health Check',
      description: 'Track your wellness activities',
      icon: Icons.health_and_safety,
      completed: false,
      category: 'Health',
    ),
    DailyTask(
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
      appBar: AppBar(
        title: Text(translate('daily')),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('daily_activities'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDateString(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Daily Verse Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: dailyVerseAsync.when(
                  data: (verse) => DailyVerseCard(
                    verse: verse,
                    isLoading: false,
                  ),
                  loading: () => const DailyVerseCard(
                    verse: null,
                    isLoading: true,
                  ),
                  error: (error, stack) => DailyVerseCard(
                    verse: null,
                    isLoading: false,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Daily Tasks Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  translate('daily_tasks'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 16),

              _buildDailyTasks(context, translate, dailyTasks, ref),

              const SizedBox(height: 24),

              // Progress Summary
              _buildProgressSummary(context, translate, dailyTasks),

              const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('today_progress'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedTasks / $totalTasks ${translate('tasks_completed')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
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
              const SizedBox(width: 16),
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: task.completed ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => onToggle(!task.completed),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  task.icon,
                  color: task.completed
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
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
