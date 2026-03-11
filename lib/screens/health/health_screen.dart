import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';

import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/app_models.dart';
import '../../utils/text_formatter.dart';
import '../../utils/layout_fix_utils.dart';
import '../../utils/responsive_utils.dart';

// Provider for health tracking data
final healthTrackingProvider =
    FutureProvider<List<HealthTracking>>((ref) async {
  final firebase = ref.read(firebaseDatabaseServiceProvider);
  final user = ref.read(currentUserProvider);

  if (user == null) return [];

  // Fetch health activities from Firebase
  final snapshot = await firebase.firestore
      .collection('health_activities')
      .where('user_id', isEqualTo: user.uid)
      .get();

  return snapshot.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id;
    return HealthTracking.fromJson(data);
  }).toList();
});

// Provider for today's health activities
final todayHealthActivitiesProvider =
    StateProvider<List<HealthActivity>>((ref) {
  return [
    const HealthActivity(
      id: 'nutrition',
      name: 'Nutrition',
      description: 'Eat healthy, balanced meals',
      icon: Icons.restaurant,
      color: Color(0xFF4CAF50), // Green
      completed: false,
      target: 3,
      current: 0,
      unit: 'meals',
    ),
    const HealthActivity(
      id: 'exercise',
      name: 'Exercise',
      description: 'Stay active with physical activity',
      icon: Icons.fitness_center,
      color: Color(0xFF2196F3), // Blue
      completed: false,
      target: 30,
      current: 0,
      unit: 'minutes',
    ),
    const HealthActivity(
      id: 'water',
      name: 'Water',
      description: 'Stay hydrated throughout the day',
      icon: Icons.water_drop,
      color: Color(0xFF00BCD4), // Cyan
      completed: false,
      target: 8,
      current: 0,
      unit: 'glasses',
    ),
    const HealthActivity(
      id: 'sunlight',
      name: 'Sunlight',
      description: 'Get natural sunlight exposure',
      icon: Icons.wb_sunny,
      color: Color(0xFFFF9800), // Orange
      completed: false,
      target: 15,
      current: 0,
      unit: 'minutes',
    ),
    const HealthActivity(
      id: 'temperance',
      name: 'Temperance',
      description: 'Practice moderation in all things',
      icon: Icons.balance,
      color: Color(0xFF9C27B0), // Purple
      completed: false,
      target: 1,
      current: 0,
      unit: 'day',
    ),
    const HealthActivity(
      id: 'fresh_air',
      name: 'Fresh Air',
      description: 'Breathe clean, fresh air',
      icon: Icons.air,
      color: Color(0xFF009688), // Teal
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
      appBar: CustomAppBar(
        title: translate('health'),
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthTrackingProvider);
        },
        child: LayoutFixUtils.safeColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: ResponsiveUtils.getResponsivePadding(context),
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
                    TextFormatter.formatHealthCategory('natural_remedies'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 24),
                        ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    TextFormatter.formatHealthCategory('gods_natural_healing'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 16),
                        ),
                  ),
                ],
              ),
            ),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

            // Today's Progress Overview
            _buildProgressOverview(context, translate, todayActivities),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

            // Health Activities
            Padding(
              padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
              child: Text(
                TextFormatter.formatTimeText('todays_activities'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 20),
                    ),
              ),
            ),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

            _buildHealthActivities(context, translate, todayActivities, ref),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),

            // Health Tips
            _buildHealthTips(context, translate),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
          ],
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
      margin: ResponsiveUtils.getResponsiveHorizontalPadding(context),
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
                size: ResponsiveUtils.getResponsiveIconSize(context, 24),
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                TextFormatter.formatHealthCategory('todays_wellness'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 16),
                    ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedActivities / $totalActivities ${TextFormatter.formatHealthCategory('activities_completed')}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 14),
                          ),
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ],
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              SizedBox(
                width: ResponsiveUtils.getResponsiveIconSize(context, 40),
                height: ResponsiveUtils.getResponsiveIconSize(context, 40),
                child: CircularProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.green.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
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
      padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
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
        title: TextFormatter.formatText('nutrition_tip'),
        description:
            'Eat a variety of colorful fruits and vegetables to get essential nutrients.',
        icon: Icons.restaurant,
        color: Colors.green,
      ),
      HealthTip(
        title: TextFormatter.formatText('exercise_tip'),
        description:
            'Even 10 minutes of walking can boost your mood and energy levels.',
        icon: Icons.fitness_center,
        color: Colors.blue,
      ),
      HealthTip(
        title: TextFormatter.formatText('water_tip'),
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
          padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
          child: Text(
            TextFormatter.formatText('health_tips'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
                ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        SizedBox(
          height: ResponsiveUtils.getResponsiveValue<double>(
            context: context,
            mobile: 160,
            tablet: 160 * 1.2,
            desktop: 160 * 1.4,
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tip = tips[index];
              return Container(
                width: ResponsiveUtils.getResponsiveValue<double>(
                  context: context,
                  mobile: 280,
                  tablet: 280 * 1.2,
                  desktop: 280 * 1.4,
                ),
                margin: EdgeInsets.only(
                    right: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(
                                  ResponsiveUtils.getResponsiveSpacing(
                                      context, 8)),
                              decoration: BoxDecoration(
                                color: tip.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                tip.icon,
                                color: tip.color,
                                size: ResponsiveUtils.getResponsiveIconSize(
                                    context, 20),
                              ),
                            ),
                            SizedBox(
                                width: ResponsiveUtils.getResponsiveSpacing(
                                    context, 12)),
                            Expanded(
                              child: Text(
                                tip.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          ResponsiveUtils.getResponsiveFontSize(
                                              context, 16),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: ResponsiveUtils.getResponsiveSpacing(
                                context, 12)),
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
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                          context, 14),
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
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                      ResponsiveUtils.getResponsiveSpacing(context, 12)),
                  decoration: BoxDecoration(
                    color: activity.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    activity.icon,
                    color: activity.color,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 24),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 16),
                            ),
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 4)),
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
                    padding: EdgeInsets.all(
                        ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.green,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    ),
                  ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
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
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                          context, 14),
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
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                          context, 14),
                                ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 8)),
                      LinearProgressIndicator(
                        value: progressPercentage,
                        backgroundColor: activity.color.withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(activity.color),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Row(
                  children: [
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveIconSize(context, 40),
                      height:
                          ResponsiveUtils.getResponsiveIconSize(context, 40),
                      child: IconButton(
                        onPressed: activity.current > 0
                            ? () {
                                final newCurrent = activity.current - 1;
                                onUpdate(activity.copyWith(
                                  current: newCurrent,
                                  completed: newCurrent >= activity.target,
                                ));
                              }
                            : null,
                        icon: Icon(
                          Icons.remove,
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 20),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              activity.color.withValues(alpha: 0.1),
                          foregroundColor: activity.color,
                        ),
                      ),
                    ),
                    SizedBox(
                        width:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveIconSize(context, 40),
                      height:
                          ResponsiveUtils.getResponsiveIconSize(context, 40),
                      child: IconButton(
                        onPressed: () {
                          final newCurrent = activity.current + 1;
                          onUpdate(activity.copyWith(
                            current: newCurrent,
                            completed: newCurrent >= activity.target,
                          ));
                        },
                        icon: Icon(
                          Icons.add,
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 20),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              activity.color.withValues(alpha: 0.1),
                          foregroundColor: activity.color,
                        ),
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
