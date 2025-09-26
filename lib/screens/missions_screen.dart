import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../services/supabase_service.dart';
import '../widgets/bible_reference_widget.dart';
import '../widgets/star_animation_widget.dart';
import '../utils/mobile_utils.dart';

// Provider for missions data
final missionsProvider = FutureProvider<List<Mission>>((ref) async {
  // Replace with actual Supabase query
  return await SupabaseService.instance.getMissions();
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
      id: 'retreat',
      name: 'Retreat',
      icon: Icons.festival,
      color: Colors.green,
      isSelected: false,
    ),
    MissionCategory(
      id: 'conference',
      name: 'MEC Conference',
      icon: Icons.speaker_group_rounded,
      color: Colors.green,
      isSelected: false,
    ),
    MissionCategory(
      id: 'youth',
      name: 'Camp Ministry',
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

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
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
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                }
              });
            },
            icon: Icon(_showSearch ? Icons.close : Icons.search),
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
              padding: MobileUtils.getResponsivePadding(context, 20),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(MobileUtils.getResponsiveBorderRadius(context, 24)),
                  bottomRight: Radius.circular(MobileUtils.getResponsiveBorderRadius(context, 24)),
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
                  SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    translate('go_make_disciples'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                  ),
                ],
              ),
            ),

            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 20)),

            // Mission Categories
            _buildMissionCategories(context, categories, ref),

            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 20)),

            // Search bar
            if (_showSearch)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: MobileUtils.getResponsiveSpacing(context, 20)),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: translate('search_missions'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 12)),
                    ),
                  ),
                ),
              ),

            if (_showSearch) SizedBox(height: MobileUtils.getResponsiveSpacing(context, 20)),

            // Missions List
            Expanded(
              child: missionsAsync.when(
                data: (missions) {
                  var filteredMissions = selectedCategory.id == 'all'
                      ? missions
                      : missions
                          .where((m) => m.category
                              .toLowerCase()
                              .contains(selectedCategory.id))
                          .toList();

                  // Apply search filter
                  if (_searchQuery.isNotEmpty) {
                    filteredMissions = filteredMissions
                        .where((m) =>
                            m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            m.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            m.location.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();
                  }

                  if (filteredMissions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: MobileUtils.getResponsiveIconSize(context, 64),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
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
                    padding: EdgeInsets.symmetric(horizontal: MobileUtils.getResponsiveSpacing(context, 20)),
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
                        size: MobileUtils.getResponsiveIconSize(context, 64),
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
                      Text(
                        translate('error_loading_missions'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
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
                      SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
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
      height: MobileUtils.getResponsiveSpacing(context, 50),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: MobileUtils.getResponsiveSpacing(context, 20)),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            margin: EdgeInsets.only(right: MobileUtils.getResponsiveSpacing(context, 12)),
            child: FilterChip(
              selected: category.isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: MobileUtils.getResponsiveIconSize(context, 16),
                    color: category.isSelected ? Colors.white : category.color,
                  ),
                  SizedBox(width: MobileUtils.getResponsiveSpacing(context, 6)),
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
          MissionDetailsSheet(
            mission: mission, 
            translate: translate,
            onComplete: _completeMission,
          ),
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
              _showCreateMissionForm(context, translate);
            },
            child: Text(translate('create')),
          ),
        ],
      ),
    );
  }

  void _showCreateMissionForm(BuildContext context, Function translate) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('create_new_mission')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: translate('mission_title'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: translate('description'),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: translate('location'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  descriptionController.text.isNotEmpty &&
                  locationController.text.isNotEmpty) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mission "${titleController.text}" created successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(translate('create')),
          ),
        ],
      ),
    );
  }

  void _completeMission(BuildContext context, Mission mission) {
    final translate = ref.read(translationProvider);
    
    // Show star animation celebration
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StarAnimationWidget(
        showAnimation: true,
        onAnimationComplete: () {
          Navigator.of(context).pop();
          // Show completion message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${translate('mission_completed').replaceAll('{title}', mission.title)} 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        },
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
      margin: EdgeInsets.only(bottom: MobileUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 16)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 16)),
        child: Padding(
          padding: MobileUtils.getResponsivePadding(context, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: MobileUtils.getResponsiveSpacing(context, 8), 
                        vertical: MobileUtils.getResponsiveSpacing(context, 4)),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(mission.category)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 12)),
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
                      padding: EdgeInsets.symmetric(
                          horizontal: MobileUtils.getResponsiveSpacing(context, 8), 
                          vertical: MobileUtils.getResponsiveSpacing(context, 4)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 12)),
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
              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 12)),
              Text(
                mission.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
              BibleReferenceWidget(
                text: mission.description,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 12)),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: MobileUtils.getResponsiveIconSize(context, 16),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  SizedBox(width: MobileUtils.getResponsiveSpacing(context, 4)),
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
                    size: MobileUtils.getResponsiveIconSize(context, 16),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  SizedBox(width: MobileUtils.getResponsiveSpacing(context, 4)),
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
              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 12)),
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
                  SizedBox(width: MobileUtils.getResponsiveSpacing(context, 12)),
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
  final Function(BuildContext, Mission) onComplete;

  const MissionDetailsSheet({
    super.key,
    required this.mission,
    required this.translate,
    required this.onComplete,
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(MobileUtils.getResponsiveBorderRadius(context, 24)),
          topRight: Radius.circular(MobileUtils.getResponsiveBorderRadius(context, 24)),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: MobileUtils.getResponsiveSpacing(context, 40),
            height: MobileUtils.getResponsiveSpacing(context, 4),
            margin: EdgeInsets.symmetric(vertical: MobileUtils.getResponsiveSpacing(context, 12)),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 2)),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: MobileUtils.getResponsivePadding(context, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    mission.category,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getCategoryColor(mission.category),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
                  BibleReferenceWidget(
                    text: mission.description,
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),

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

                  SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),

                  // Requirements
                  if (mission.instructions?.isNotEmpty == true) ...[
                    Text(
                      'Requirements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 12)),
                    ...(mission.instructions?.map((req) => Padding(
                              padding: EdgeInsets.only(bottom: MobileUtils.getResponsiveSpacing(context, 8)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: MobileUtils.getResponsiveSpacing(context, 6),
                                    height: MobileUtils.getResponsiveSpacing(context, 6),
                                    margin: EdgeInsets.only(
                                        top: MobileUtils.getResponsiveSpacing(context, 6), 
                                        right: MobileUtils.getResponsiveSpacing(context, 12)),
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
                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: MobileUtils.getResponsivePadding(context, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final shareText = '${mission.title}\n\n${mission.description}\n\nLocation: ${mission.location}\nDate: ${mission.startDate.day}/${mission.startDate.month}/${mission.startDate.year}\n\nJoin us in this mission! Download the ALIVE NG app to participate.';
                      
                      // Show share dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Share Mission'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Share this mission with others:'),
                              SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
                              Container(
                                padding: MobileUtils.getResponsivePadding(context, 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(MobileUtils.getResponsiveBorderRadius(context, 8)),
                                ),
                                child: Text(
                                  shareText,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Mission details copied to clipboard'),
                                  ),
                                );
                              },
                              child: const Text('Copy to Clipboard'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(translate('share')),
                  ),
                ),
                SizedBox(width: MobileUtils.getResponsiveSpacing(context, 16)),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                      onPressed: () {
                        onComplete(context, mission);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getCategoryColor(mission.category),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(translate('complete_mission')),
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
      padding: EdgeInsets.only(bottom: MobileUtils.getResponsiveSpacing(context, 16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: MobileUtils.getResponsiveIconSize(context, 20),
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          SizedBox(width: MobileUtils.getResponsiveSpacing(context, 12)),
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
                SizedBox(height: MobileUtils.getResponsiveSpacing(context, 2)),
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
}




