import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';

// Provider for health tracking data
final healthTrackingProvider =
    FutureProvider<List<HealthTracking>>((ref) async {
  final supabase = ref.read(supabaseServiceProvider);
  final user = ref.read(currentUserProvider);

  if (user == null) return [];

  final response = await supabase.client
      .from('health_tracking')
      .select()
      .eq('user_id', user.id);
  return response.map((json) => HealthTracking.fromJson(json)).toList();
});

// Provider for today's health activities
final todayHealthActivitiesProvider =
    StateProvider<List<HealthActivity>>((ref) {
  return [
    HealthActivity(
      id: 'nutrition',
      name: 'Nutrition',
      description: 'Eat healthy, balanced meals',
      icon: Icons.restaurant,
      color: Colors.green,
      completed: false,
      target: 3,
      current: 0,
      unit: 'meals',
    ),
    HealthActivity(
      id: 'exercise',
      name: 'Exercise',
      description: 'Stay active with physical activity',
      icon: Icons.fitness_center,
      color: Colors.blue,
      completed: false,
      target: 30,
      current: 0,
      unit: 'minutes',
    ),
    HealthActivity(
      id: 'water',
      name: 'Water',
      description: 'Stay hydrated throughout the day',
      icon: Icons.water_drop,
      color: Colors.cyan,
      completed: false,
      target: 8,
      current: 0,
      unit: 'glasses',
    ),
    HealthActivity(
      id: 'sunlight',
      name: 'Sunlight',
      description: 'Get natural sunlight exposure',
      icon: Icons.wb_sunny,
      color: Colors.orange,
      completed: false,
      target: 15,
      current: 0,
      unit: 'minutes',
    ),
    HealthActivity(
      id: 'temperance',
      name: 'Temperance',
      description: 'Practice moderation in all things',
      icon: Icons.balance,
      color: Colors.purple,
      completed: false,
      target: 1,
      current: 0,
      unit: 'day',
    ),
    HealthActivity(
      id: 'fresh_air',
      name: 'Fresh Air',
      description: 'Breathe clean, fresh air',
      icon: Icons.air,
      color: Colors.teal,
      completed: false,
      target: 20,
      current: 0,
      unit: 'minutes',
    ),
  ];
});

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final todayActivities = ref.watch(todayHealthActivitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('health')),
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthTrackingProvider);
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
                decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('natural_remedies'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translate('gods_natural_healing'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Today's Progress Overview
              _buildProgressOverview(context, translate, todayActivities),

              const SizedBox(height: 24),

              // Health Activities
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  translate('todays_activities'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 16),

              _buildHealthActivities(context, translate, todayActivities, ref),

              const SizedBox(height: 24),

              // Health Tips
              _buildHealthTips(context, translate),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverview(BuildContext context,
      String Function(String) translate, List<HealthActivity> activities) {
    final completedActivities = activities.where((a) => a.completed).length;
    final totalActivities = activities.length;
    final progressPercentage =
        totalActivities > 0 ? (completedActivities / totalActivities) : 0.0;

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
          Row(
            children: [
              Icon(
                Icons.health_and_safety,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                translate('todays_wellness'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedActivities / $totalActivities ${translate('activities_completed')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircularProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.green.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthActivities(
      BuildContext context,
      String Function(String) translate,
      List<HealthActivity> activities,
      WidgetRef ref) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return HealthActivityCard(
          activity: activity,
          onUpdate: (updatedActivity) {
            final updatedActivities = [...activities];
            updatedActivities[index] = updatedActivity;
            ref.read(todayHealthActivitiesProvider.notifier).state =
                updatedActivities;
          },
        );
      },
    );
  }

  Widget _buildHealthTips(
      BuildContext context, String Function(String) translate) {
    final tips = [
      HealthTip(
        title: translate('nutrition_tip'),
        description:
            'Eat a variety of colorful fruits and vegetables to get essential nutrients.',
        icon: Icons.restaurant,
        color: Colors.green,
      ),
      HealthTip(
        title: translate('exercise_tip'),
        description:
            'Even 10 minutes of walking can boost your mood and energy levels.',
        icon: Icons.fitness_center,
        color: Colors.blue,
      ),
      HealthTip(
        title: translate('water_tip'),
        description:
            'Start your day with a glass of water to kickstart your metabolism.',
        icon: Icons.water_drop,
        color: Colors.cyan,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            translate('health_tips'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tip = tips[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tip.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                tip.icon,
                                color: tip.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Text(
                            tip.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HealthActivity {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool completed;
  final int target;
  final int current;
  final String unit;

  const HealthActivity({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.completed,
    required this.target,
    required this.current,
    required this.unit,
  });

  HealthActivity copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    bool? completed,
    int? target,
    int? current,
    String? unit,
  }) {
    return HealthActivity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      completed: completed ?? this.completed,
      target: target ?? this.target,
      current: current ?? this.current,
      unit: unit ?? this.unit,
    );
  }
}

class HealthTip {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const HealthTip({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class HealthActivityCard extends StatelessWidget {
  final HealthActivity activity;
  final Function(HealthActivity) onUpdate;

  const HealthActivityCard({
    super.key,
    required this.activity,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final progressPercentage = activity.target > 0
        ? (activity.current / activity.target).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: activity.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    activity.icon,
                    color: activity.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
                if (activity.completed)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${activity.current} / ${activity.target} ${activity.unit}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            '${(progressPercentage * 100).round()}%',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: activity.color,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progressPercentage,
                        backgroundColor: activity.color.withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(activity.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    IconButton(
                      onPressed: activity.current > 0
                          ? () {
                              final newCurrent = activity.current - 1;
                              onUpdate(activity.copyWith(
                                current: newCurrent,
                                completed: newCurrent >= activity.target,
                              ));
                            }
                          : null,
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: activity.color.withValues(alpha: 0.1),
                        foregroundColor: activity.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final newCurrent = activity.current + 1;
                        onUpdate(activity.copyWith(
                          current: newCurrent,
                          completed: newCurrent >= activity.target,
                        ));
                      },
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: activity.color.withValues(alpha: 0.1),
                        foregroundColor: activity.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
