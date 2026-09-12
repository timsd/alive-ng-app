import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/appwrite_facade.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../models/kids_missions.dart';
import '../../utils/error_handler.dart';

class KidsMissionScreen extends ConsumerStatefulWidget {
  const KidsMissionScreen({super.key});

  @override
  ConsumerState<KidsMissionScreen> createState() => _KidsMissionScreenState();
}

class _KidsMissionScreenState extends ConsumerState<KidsMissionScreen> {
  String? _selectedCategory;

  Stream<List<Mission>> _getMissionsStream() {
    return Stream.fromFuture(TablesDB(appwriteClient).listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.kidsMissionsCollectionId,
      queries: [Query.equal('is_active', true), Query.limit(100)],
    ).then((snapshot) {
      return snapshot.rows
          .map((row) {
            final data = _mapMissionDocument(row);

            try {
              return Mission.fromJson(data);
            } catch (e) {
              return null;
            }
          })
          .whereType<Mission>()
          .toList();
    }));
  }

  Map<String, dynamic> _mapMissionDocument(dynamic row) {
    final data = Map<String, dynamic>.from(row.data);

    return {
      'id': row.$id,
      'title': data['title'] ?? 'Mission',
      'description': data['description'] ?? '',
      'location': data['location'] ?? 'Home',
      'difficulty': _missionDifficulty(data['difficulty']),
      'duration': data['duration']?.toString() ?? '15 minutes',
      'points': data['points'] ?? 10,
      'category': _missionCategory(data['category']),
      'completed': data['completed'] ?? false,
      'instructions': _stringList(data['instructions']),
      'verificationMethod': _verificationMethod(data['verification_method']),
      'prerequisiteMissionIds': _stringList(data['prerequisite_mission_ids']),
      'isLocked': data['is_locked'] ?? false,
      'unlockedBy': data['unlocked_by'],
      'mediaUrl': data['media_url'],
    };
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  String _missionDifficulty(dynamic value) {
    final normalized = value?.toString().toLowerCase() ?? '';
    if (normalized.contains('hard')) return 'hard';
    if (normalized.contains('medium')) return 'medium';
    return 'easy';
  }

  String _missionCategory(dynamic value) {
    final normalized = value?.toString().toLowerCase() ?? '';
    if (normalized.contains('evangel')) return 'evangelism';
    if (normalized.contains('service')) return 'service';
    if (normalized.contains('sharing')) return 'sharing';
    if (normalized.contains('prayer')) return 'prayer';
    return 'learning';
  }

  String _verificationMethod(dynamic value) {
    final normalized = value?.toString().toLowerCase() ?? '';
    if (normalized.contains('photo')) return 'photo';
    if (normalized.contains('story')) return 'story';
    if (normalized.contains('quiz')) return 'quiz';
    return 'witness';
  }

  Widget _buildStateCard(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 52, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCategory(
    BuildContext context,
    String shortLabel,
    String category,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedCategory == category) {
            _selectedCategory = null; // Toggle off to show all
          } else {
            _selectedCategory = category;
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainer,
          border: Border.all(
            color: isSelected
                ? color
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shortLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionListItem(BuildContext context, Mission mission) {
    final categoryIcons = {
      MissionCategory.evangelism: Icons.campaign,
      MissionCategory.service: Icons.volunteer_activism,
      MissionCategory.learning: Icons.psychology,
      MissionCategory.sharing: Icons.share,
      MissionCategory.prayer: Icons.favorite,
    };
    final categoryColors = {
      MissionCategory.evangelism: Theme.of(context).colorScheme.primary,
      MissionCategory.service: Theme.of(context).colorScheme.secondary,
      MissionCategory.learning: Theme.of(context).colorScheme.tertiary,
      MissionCategory.sharing: Colors.orange,
      MissionCategory.prayer: Theme.of(context).colorScheme.error,
    };

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 10, tablet: 12, desktop: 14)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (categoryColors[mission.category] ??
                  Theme.of(context).primaryColor)
              .withValues(alpha: 0.15),
          child: Icon(
            categoryIcons[mission.category] ?? Icons.star,
            color: categoryColors[mission.category] ??
                Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          mission.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: mission.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${mission.category.displayName} • ${mission.difficulty.displayName} • ${mission.points} pts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 3, tablet: 4, desktop: 5)),
            Text(
              mission.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
        trailing: mission.completed
            ? Icon(Icons.check_circle, color: Colors.green.shade600)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        isThreeLine: true,
        onTap: () => _navigateToActivityDetails(context, mission),
      ),
    );
  }

  void _navigateToActivityDetails(BuildContext context, Mission mission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mission.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mission.mediaUrl != null && mission.mediaUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      mission.mediaUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: Colors.grey[300],
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              Text(
                'Activity Details',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(mission.description),
              const SizedBox(height: 16),
              Text(
                'Instructions:',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(mission.instructions.isNotEmpty
                  ? mission.instructions.join('\n')
                  : '1. Read the activity description\n2. Gather required materials\n3. Follow the step-by-step guide\n4. Share your results with friends'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Starting activity: ${mission.title}'),
                ),
              );
            },
            child: const Text('Start Activity'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kids Mission',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 14, tablet: 18, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with high contrast in dark mode
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 16, tablet: 20, desktop: 24)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1E293B),
                            const Color(0xFF0F172A),
                          ]
                        : [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.secondaryContainer,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.child_care_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kids Mission Adventure',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Learn, play, and share God\'s love every day!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Categories in Quick-Action size
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedCategory != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedCategory = null),
                      child: const Text('Show All'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final items = [
                    _buildQuickActionCategory(
                      context,
                      'Evangelism',
                      'evangelism',
                      Icons.campaign_rounded,
                      Colors.blue,
                    ),
                    _buildQuickActionCategory(
                      context,
                      'Service',
                      'service',
                      Icons.volunteer_activism_rounded,
                      Colors.green,
                    ),
                    _buildQuickActionCategory(
                      context,
                      'Learning',
                      'learning',
                      Icons.psychology_rounded,
                      Colors.purple,
                    ),
                    _buildQuickActionCategory(
                      context,
                      'Prayer',
                      'prayer',
                      Icons.favorite_rounded,
                      Colors.redAccent,
                    ),
                  ];

                  if (constraints.maxWidth < 380) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 90,
                              child: item,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }

                  final itemWidth = (constraints.maxWidth - 36) / 4;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: items
                        .map((item) => SizedBox(width: itemWidth, child: item))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Missions List with Category Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory != null
                        ? '${_selectedCategory![0].toUpperCase()}${_selectedCategory!.substring(1)} Missions'
                        : 'Active Missions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Mission>>(
                stream: _getMissionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildStateCard(
                      context,
                      title: 'Unable to Load Missions',
                      message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
                      icon: Icons.error_outline_rounded,
                    );
                  }

                  final allMissions = snapshot.data ?? [];
                  final filteredMissions = _selectedCategory == null
                      ? allMissions
                      : allMissions
                          .where((m) => m.category.name.toLowerCase() == _selectedCategory)
                          .toList();

                  if (filteredMissions.isEmpty) {
                    return _buildStateCard(
                      context,
                      title: 'No Missions Found',
                      message: _selectedCategory != null
                          ? 'There are no active $_selectedCategory missions at the moment.'
                          : 'Check back soon for new mission challenges!',
                      icon: Icons.star_border_rounded,
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredMissions.length,
                    itemBuilder: (context, index) {
                      return _buildMissionListItem(context, filteredMissions[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
