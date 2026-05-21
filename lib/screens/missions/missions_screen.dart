// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../providers/language_provider.dart';
import '../../models/app_models.dart';
import '../../widgets/bible_reference_widget.dart';
import '../../widgets/star_animation_widget.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../services/role_access_service.dart';

// Provider for missions data
final missionsProvider = FutureProvider<List<Mission>>((ref) async {
  final databases = Databases(appwriteClient);
  final snapshot = await databases.listDocuments(
    databaseId: AppwriteBackendConfig.databaseId,
    collectionId: AppwriteBackendConfig.missionsCollectionId,
    queries: [
      Query.equal('is_active', true),
      Query.orderDesc('start_date'),
      Query.limit(100),
    ],
  );

  return snapshot.documents
      .map(_mapMissionDocument)
      .map(Mission.fromJson)
      .toList();
});

Map<String, dynamic> _mapMissionDocument(appwrite_models.Document doc) {
  final data = Map<String, dynamic>.from(doc.data);
  final now = DateTime.now().toIso8601String();

  return {
    'id': doc.$id,
    'title': data['title'] ?? 'Mission',
    'description': data['description'] ?? '',
    'location': data['location'] ?? '',
    'category': data['category'] ?? 'community',
    'difficulty': data['difficulty'],
    'duration': _toInt(data['duration']),
    'points': _toInt(data['points']),
    'status': data['status'],
    'instructions': _stringList(data['instructions']),
    'verification_method': data['verification_method'],
    'start_date': _dateString(data['start_date']) ?? now,
    'end_date': _dateString(data['end_date']),
    'participants_count': _toInt(data['participants_count']) ?? 0,
    'max_participants': _toInt(data['max_participants']) ?? 0,
    'current_participants': _stringList(data['current_participants']),
    'image_url': data['image_url'],
    'requirements': _stringList(data['requirements']),
    'contact_info': data['contact_info'] ?? '',
    'is_active': data['is_active'] ?? true,
    'created_at': _dateString(data['created_at']),
    'updated_at': _dateString(data['updated_at']),
  };
}

List<String> _stringList(dynamic value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _dateString(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toIso8601String();
  final raw = value.toString();
  return DateTime.tryParse(raw)?.toIso8601String() ?? raw;
}

// Provider for mission categories
final missionCategoriesProvider = StateProvider<List<MissionCategory>>((ref) {
  return [
    const MissionCategory(
      id: 'all',
      name: 'All Missions',
      icon: Icons.public,
      color: null, // Use primary color by default
      isSelected: true,
    ),
    const MissionCategory(
      id: 'community',
      name: 'Community Service',
      icon: Icons.volunteer_activism,
      color: Colors.green, // Fixed categories with specific meaningful colors
      isSelected: false,
    ),
    const MissionCategory(
      id: 'retreat',
      name: 'Retreat',
      icon: Icons.festival,
      color: Colors.green,
      isSelected: false,
    ),
    const MissionCategory(
      id: 'conference',
      name: 'MEC Conference',
      icon: Icons.speaker_group_rounded,
      color: Colors.green,
      isSelected: false,
    ),
    const MissionCategory(
      id: 'youth',
      name: 'Camp Ministry',
      icon: Icons.groups,
      color: Colors.orange,
      isSelected: false,
    ),
    const MissionCategory(
      id: 'international',
      name: 'International',
      icon: Icons.flight_takeoff,
      color: Colors.purple,
      isSelected: false,
    ),
    const MissionCategory(
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
      appBar: CustomAppBar(
        title: translate('missions'),
        showBackButton: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                }
              });
            },
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
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(
                      ResponsiveUtils.getResponsiveBorderRadiusValue(
                          context, 24)),
                  bottomRight: Radius.circular(
                      ResponsiveUtils.getResponsiveBorderRadiusValue(
                          context, 24)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('great_commission'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    translate('go_make_disciples'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.9),
                        ),
                  ),
                ],
              ),
            ),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),

            // Mission Categories
            _buildMissionCategories(context, categories, ref),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),

            // Search bar
            if (_showSearch)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        ResponsiveUtils.getResponsiveSpacing(context, 20)),
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
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadiusValue(
                              context, 12)),
                    ),
                  ),
                ),
              ),

            if (_showSearch)
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 20)),

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
                            m.title
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            m.description
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            m.location
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                        .toList();
                  }

                  if (filteredMissions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: ResponsiveUtils.getResponsiveIconSize(
                                context, 64),
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                          SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                  context, 16)),
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
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveUtils.getResponsiveSpacing(context, 20)),
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
                        size:
                            ResponsiveUtils.getResponsiveIconSize(context, 64),
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 16)),
                      Text(
                        translate('error_loading_missions'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(
                          height:
                              ResponsiveUtils.getResponsiveSpacing(context, 8)),
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
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 16)),
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
      floatingActionButton: RoleAccessService.instance.canCreateMissions()
          ? FloatingActionButton(
              onPressed: () {
                _showCreateMissionDialog(context, translate);
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.add,
                  color: Theme.of(context).colorScheme.onPrimary),
            )
          : null,
    );
  }

  Widget _buildMissionCategories(
      BuildContext context, List<MissionCategory> categories, WidgetRef ref) {
    return SizedBox(
      height: ResponsiveUtils.getResponsiveSpacing(context, 50),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveSpacing(context, 20)),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            margin: EdgeInsets.only(
                right: ResponsiveUtils.getResponsiveSpacing(context, 12)),
            child: FilterChip(
              selected: category.isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category.icon,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: category.isSelected ? Colors.white : (category.color ?? Theme.of(context).colorScheme.primary),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 6)),
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
              selectedColor: category.color ?? Theme.of(context).colorScheme.primary,
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
      builder: (context) => MissionDetailsSheet(
        mission: mission,
        translate: translate,
        onComplete: _completeMission,
      ),
    );
  }

  void _showCreateMissionDialog(
      BuildContext context, String Function(String) translate) {
    // Check permissions before showing dialog
    if (!RoleAccessService.instance.canCreateMissions()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'You do not have permission to create missions. Only executives can create content.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

  Future<void> _showCreateMissionForm(
    BuildContext context,
    Function translate,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    await showDialog(
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
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: translate('description'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: translate('location'),
                  border: const OutlineInputBorder(),
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
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              final location = locationController.text.trim();

              if (title.isEmpty || description.isEmpty || location.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final now = DateTime.now();
                await Databases(appwriteClient).createDocument(
                  databaseId: AppwriteBackendConfig.databaseId,
                  collectionId: AppwriteBackendConfig.missionsCollectionId,
                  documentId: ID.unique(),
                  data: {
                    'title': title,
                    'description': description,
                    'location': location,
                    'category': 'community',
                    'difficulty': 'easy',
                    'duration': 60,
                    'points': 10,
                    'status': 'active',
                    'instructions': <String>[],
                    'verification_method': 'manual',
                    'start_date': now.toIso8601String(),
                    'participants_count': 0,
                    'max_participants': 0,
                    'current_participants': <String>[],
                    'requirements': <String>[],
                    'contact_info': '',
                    'is_active': true,
                    'created_at': now.toIso8601String(),
                    'updated_at': now.toIso8601String(),
                  },
                );

                if (!context.mounted) return;
                Navigator.of(context).pop();
                ref.invalidate(missionsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mission "$title" created successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on AppwriteException catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.message ?? 'Unable to create mission'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: Text(translate('create')),
          ),
        ],
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
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
              content: Text(
                  '${translate('mission_completed').replaceAll('{title}', mission.title)} 🎉'),
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
  final Color? color;
  final bool isSelected;

  const MissionCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
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
    final currentCount =
        mission.currentParticipants?.length ?? mission.participantsCount;
    final max = mission.maxParticipants;
    final spotsLeft = (max - currentCount).clamp(0, max);

    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 16)),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveUtils.getResponsiveSpacing(context, 8),
                        vertical:
                            ResponsiveUtils.getResponsiveSpacing(context, 4)),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(context, mission.category)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadiusValue(
                              context, 12)),
                    ),
                    child: Text(
                      mission.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getCategoryColor(context, mission.category),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const Spacer(),
                  if (daysUntilStart > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              ResponsiveUtils.getResponsiveSpacing(context, 8),
                          vertical:
                              ResponsiveUtils.getResponsiveSpacing(context, 4)),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadiusValue(
                                context, 12)),
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
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              Text(
                mission.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              BibleReferenceWidget(
                text: mission.description,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
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
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    '$currentCount/$max',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (max > 0 ? (currentCount / max).clamp(0, 1) : 0.0)
                          .toDouble(),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getCategoryColor(context, mission.category),
                      ),
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                  Text(
                    '$spotsLeft spots left',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getCategoryColor(context, mission.category),
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

  Color _getCategoryColor(BuildContext context, String category) {
    switch (category.toLowerCase()) {
      case 'community service':
      case 'retreat':
      case 'mec conference':
        return Colors.green;
      case 'camp ministry':
      case 'youth ministry':
        return Colors.orange;
      case 'international':
        return Colors.purple;
      case 'evangelism':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
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

  Color _getCategoryColor(BuildContext context, String category) {
    switch (category.toLowerCase()) {
      case 'community service':
      case 'retreat':
      case 'mec conference':
        return Colors.green;
      case 'camp ministry':
      case 'youth ministry':
        return Colors.orange;
      case 'international':
        return Colors.purple;
      case 'evangelism':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ResponsiveUtils.getResponsiveValue<double>(
        context: context,
        mobile: MediaQuery.of(context).size.height * 0.8,
        tablet: MediaQuery.of(context).size.height * 0.75,
        desktop: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 24)),
          topRight: Radius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 24)),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: ResponsiveUtils.getResponsiveSpacing(context, 40),
            height: ResponsiveUtils.getResponsiveSpacing(context, 4),
            margin: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveSpacing(context, 12)),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadiusValue(context, 2)),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    mission.category,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getCategoryColor(context, mission.category),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  BibleReferenceWidget(
                    text: mission.description,
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 24)),

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

                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 24)),

                  // Requirements
                  if (mission.instructions?.isNotEmpty == true) ...[
                    Text(
                      'Requirements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 12)),
                    ...?mission.instructions?.map(
                      (req) => Padding(
                        padding: EdgeInsets.only(
                          bottom: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: ResponsiveUtils.getResponsiveSpacing(
                                  context, 6),
                              height: ResponsiveUtils.getResponsiveSpacing(
                                  context, 6),
                              margin: EdgeInsets.only(
                                top: ResponsiveUtils.getResponsiveSpacing(
                                    context, 6),
                                right: ResponsiveUtils.getResponsiveSpacing(
                                    context, 12),
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(context, mission.category),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                req,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 24)),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            width: double.infinity,
            padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
            margin: EdgeInsets.only(
                bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(
                    ResponsiveUtils.getResponsiveBorderRadiusValue(
                        context, 24)),
                bottomRight: Radius.circular(
                    ResponsiveUtils.getResponsiveBorderRadiusValue(
                        context, 24)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('discover_missions'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Text(
                  translate('join_community_missions'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final shareText =
                          '${mission.title}\n\n${mission.description}\n\nLocation: ${mission.location}\nDate: ${mission.startDate.day}/${mission.startDate.month}/${mission.startDate.year}\n\nJoin us in this mission! Download the ALIVE NG app to participate.';

                      // Show share dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Share Mission'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Share this mission with others:'),
                              SizedBox(
                                  height: ResponsiveUtils.getResponsiveSpacing(
                                      context, 16)),
                              Container(
                                padding: ResponsiveUtils
                                    .getResponsivePaddingWithBase(context, 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                      ResponsiveUtils
                                          .getResponsiveBorderRadiusValue(
                                              context, 8)),
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
                                    content: Text(
                                        'Mission details copied to clipboard'),
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
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      onComplete(context, mission);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getCategoryColor(context, mission.category),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
      padding: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: ResponsiveUtils.getResponsiveIconSize(context, 20),
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
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
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 2)),
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
