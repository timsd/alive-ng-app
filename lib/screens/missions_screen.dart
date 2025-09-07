import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../widgets/bible_reference_widget.dart';

// Provider for missions data
final missionsProvider = FutureProvider<List<Mission>>((ref) async {
  final supabase = ref.read(supabaseServiceProvider);

  // TODO: Replace with actual Supabase query
  // For now, return mock data
  await Future.delayed(const Duration(milliseconds: 500));

  return [
    Mission(
      id: '1',
      title: 'Local Community Outreach',
      description:
          'Share God\'s love with your local community through acts of service and kindness.',
      location: 'Your Local Area',
      startDate: DateTime.now().add(const Duration(days: 7)),
      endDate: DateTime.now().add(const Duration(days: 14)),
      participantsCount: 25,
      maxParticipants: 50,
      category: 'Community Service',
      imageUrl: '',
      requirements: ['Heart for service', 'Available weekends'],
      contactInfo: 'missions@church.org',
      isActive: true,
    ),
    Mission(
      id: '2',
      title: 'Youth Ministry Support',
      description:
          'Help mentor and guide young people in their spiritual journey.',
      location: 'Church Youth Center',
      startDate: DateTime.now().add(const Duration(days: 3)),
      endDate: DateTime.now().add(const Duration(days: 90)),
      participantsCount: 12,
      maxParticipants: 20,
      category: 'Youth Ministry',
      imageUrl: '',
      requirements: ['Experience with youth', 'Background check'],
      contactInfo: 'youth@church.org',
      isActive: true,
    ),
    Mission(
      id: '3',
      title: 'International Mission Trip',
      description:
          'Join us for a life-changing mission trip to serve communities in need.',
      location: 'Kenya, Africa',
      startDate: DateTime.now().add(const Duration(days: 60)),
      endDate: DateTime.now().add(const Duration(days: 74)),
      participantsCount: 8,
      maxParticipants: 15,
      category: 'International',
      imageUrl: '',
      requirements: [
        'Passport required',
        'Medical clearance',
        'Fundraising commitment'
      ],
      contactInfo: 'international@church.org',
      isActive: true,
    ),
  ];
});

// Provider for mission categories
final missionCategoriesProvider = StateProvider<List<MissionCategory>>((ref) {
  return [
    MissionCategory(
      id: 'all',
      name: 'All Missions',
      icon: Icons.public,
      color: Colors.blue,
      isSelected: true,
    ),
    MissionCategory(
      id: 'community',
      name: 'Community Service',
      icon: Icons.volunteer_activism,
      color: Colors.green,
      isSelected: false,
    ),
    MissionCategory(
      id: 'youth',
      name: 'Youth Ministry',
      icon: Icons.groups,
      color: Colors.orange,
      isSelected: false,
    ),
    MissionCategory(
      id: 'international',
      name: 'International',
      icon: Icons.flight_takeoff,
      color: Colors.purple,
      isSelected: false,
    ),
    MissionCategory(
      id: 'evangelism',
      name: 'Evangelism',
      icon: Icons.campaign,
      color: Colors.red,
      isSelected: false,
    ),
  ];
});

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final missionsAsync = ref.watch(missionsProvider);
    final categories = ref.watch(missionCategoriesProvider);
    final selectedCategory = categories.firstWhere((c) => c.isSelected);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('missions')),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Implement search functionality
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(missionsProvider);
        },
        child: Column(
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('great_commission'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translate('go_make_disciples'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Mission Categories
            _buildMissionCategories(context, categories, ref),

            const SizedBox(height: 20),

            // Missions List
            Expanded(
              child: missionsAsync.when(
                data: (missions) {
                  final filteredMissions = selectedCategory.id == 'all'
                      ? missions
                      : missions
                          .where((m) => m.category
                              .toLowerCase()
                              .contains(selectedCategory.id))
                          .toList();

                  if (filteredMissions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            translate('no_missions_found'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredMissions.length,
                    itemBuilder: (context, index) {
                      final mission = filteredMissions[index];
                      return MissionCard(
                        mission: mission,
                        onTap: () =>
                            _showMissionDetails(context, mission, translate),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        translate('error_loading_missions'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(missionsProvider),
                        child: Text(translate('retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement create mission functionality
          _showCreateMissionDialog(context, translate);
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMissionCategories(
      BuildContext context, List<MissionCategory> categories, WidgetRef ref) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: category.isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: 16,
                    color: category.isSelected ? Colors.white : category.color,
                  ),
                  const SizedBox(width: 6),
                  Text(category.name),
                ],
              ),
              onSelected: (selected) {
                if (selected) {
                  final updatedCategories = categories
                      .map((c) => MissionCategory(
                            id: c.id,
                            name: c.name,
                            icon: c.icon,
                            color: c.color,
                            isSelected: c.id == category.id,
                          ))
                      .toList();
                  ref.read(missionCategoriesProvider.notifier).state =
                      updatedCategories;
                }
              },
              selectedColor: category.color,
              checkmarkColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  void _showMissionDetails(BuildContext context, Mission mission,
      String Function(String) translate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          MissionDetailsSheet(mission: mission, translate: translate),
    );
  }

  void _showCreateMissionDialog(
      BuildContext context, String Function(String) translate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('create_mission')),
        content: Text(translate('create_mission_description')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to create mission screen
            },
            child: Text(translate('create')),
          ),
        ],
      ),
    );
  }
}

class MissionCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;

  const MissionCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
  });
}

class MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;

  const MissionCard({
    super.key,
    required this.mission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntilStart =
        mission.createdAt?.difference(DateTime.now()).inDays ?? 0;
    final spotsLeft =
        10; // Default value since these properties don't exist in Mission model

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(mission.category)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      mission.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getCategoryColor(mission.category),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const Spacer(),
                  if (daysUntilStart > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$daysUntilStart days',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                mission.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              BibleReferenceWidget(
                text: mission.description,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mission.location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ),
                  Icon(
                    Icons.people,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '5/10', // Default values since properties don't exist
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.5, // Default value since properties don't exist
                      backgroundColor: Colors.grey.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getCategoryColor(mission.category),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$spotsLeft spots left',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getCategoryColor(mission.category),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'community service':
        return Colors.green;
      case 'youth ministry':
        return Colors.orange;
      case 'international':
        return Colors.purple;
      case 'evangelism':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class MissionDetailsSheet extends StatelessWidget {
  final Mission mission;
  final String Function(String) translate;

  const MissionDetailsSheet({
    super.key,
    required this.mission,
    required this.translate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mission.category,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getCategoryColor(mission.category),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 16),
                  BibleReferenceWidget(
                    text: mission.description,
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Mission Details
                  _buildDetailRow(
                      context, Icons.location_on, 'Location', mission.location),
                  _buildDetailRow(context, Icons.calendar_today, 'Created',
                      '${mission.createdAt?.day}/${mission.createdAt?.month}/${mission.createdAt?.year}'),
                  _buildDetailRow(context, Icons.access_time, 'Duration',
                      '${mission.duration} minutes'),
                  _buildDetailRow(context, Icons.star, 'Points',
                      '${mission.points} points'),
                  _buildDetailRow(context, Icons.verified, 'Verification',
                      mission.verificationMethod ?? 'Not specified'),

                  const SizedBox(height: 24),

                  // Requirements
                  if (mission.instructions?.isNotEmpty == true) ...[
                    Text(
                      'Requirements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...(mission.instructions?.map((req) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(
                                        top: 6, right: 12),
                                    decoration: BoxDecoration(
                                      color:
                                          _getCategoryColor(mission.category),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      req,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            )) ??
                        []),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement share functionality
                    },
                    child: Text(translate('share')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement join mission functionality
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getCategoryColor(mission.category),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(translate('join_mission')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'community service':
        return Colors.green;
      case 'youth ministry':
        return Colors.orange;
      case 'international':
        return Colors.purple;
      case 'evangelism':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
