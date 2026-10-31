import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../services/appwrite_facade.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../models/kids_missions.dart';
import '../../utils/error_handler.dart';
import '../../utils/mission_scoring.dart';
import '../../services/kids_mission_progress_service.dart';

class KidsMissionScreen extends ConsumerStatefulWidget {
  const KidsMissionScreen({super.key});

  @override
  ConsumerState<KidsMissionScreen> createState() => _KidsMissionScreenState();
}

class _KidsMissionScreenState extends ConsumerState<KidsMissionScreen> {
  String? _selectedCategory;
  final KidsMissionProgressService _progress = KidsMissionProgressService();

  @override
  void initState() {
    super.initState();
    _progress.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Stream<List<Mission>> _getMissionsStream() {
    return Stream.fromFuture(TablesDB(appwriteClient).listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.kidsMissionsCollectionId,
      queries: [Query.equal('is_active', true), Query.limit(100)],
    ).then((snapshot) {
      final list = snapshot.rows
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
      return list.isNotEmpty ? list : _sampleMissionsFallback();
    }).catchError((_) => _sampleMissionsFallback()));
  }

  static List<Mission> _sampleMissionsFallback() {
    return [
      Mission(
        id: 'sample-1',
        title: 'Share a Bible Story',
        description: 'Tell a favorite Bible story to a friend or family member',
        location: 'Home/School',
        difficulty: MissionDifficulty.easy,
        duration: '15 minutes',
        points: 10,
        category: MissionCategory.sharing,
        completed: false,
        instructions: const [
          'Choose one of your favorite Bible stories',
          'Find someone who would like to hear it',
          'Tell the story in your own words',
          'Explain what lesson you learned from it',
        ],
        verificationMethod: VerificationMethod.story,
      ),
      Mission(
        id: 'sample-2',
        title: 'Help Someone in Need',
        description: 'Find someone who needs help and offer assistance with a kind heart',
        location: 'Community',
        difficulty: MissionDifficulty.easy,
        duration: '30 minutes',
        points: 15,
        category: MissionCategory.service,
        completed: false,
        instructions: const [
          'Look around for someone who might need help',
          'Offer your assistance kindly',
          'Help them with what they need',
          'Don\'t expect anything in return',
        ],
        verificationMethod: VerificationMethod.photo,
      ),
      Mission(
        id: 'sample-3',
        title: 'Memorize the Beatitudes',
        description: 'Learn and recite the Beatitudes from Matthew 5:3-12',
        location: 'Anywhere',
        difficulty: MissionDifficulty.medium,
        duration: '1 hour',
        points: 20,
        category: MissionCategory.learning,
        completed: false,
        instructions: const [
          'Read Matthew 5:3-12 several times',
          'Break it into smaller sections',
          'Practice reciting each section',
          'Recite the complete passage from memory',
        ],
        verificationMethod: VerificationMethod.quiz,
      ),
      Mission(
        id: 'sample-4',
        title: 'Prayer Walk',
        description: 'Take a quiet walk and pray for people and places you see',
        location: 'Neighborhood',
        difficulty: MissionDifficulty.easy,
        duration: '20 minutes',
        points: 10,
        category: MissionCategory.prayer,
        completed: false,
        instructions: const [
          'Walk with a parent or guardian',
          'Silently pray for the homes and neighbors you pass',
          'Thank God for your neighborhood',
        ],
        verificationMethod: VerificationMethod.story,
      ),
      Mission(
        id: 'sample-5',
        title: 'Invite a Friend to Sabbath School',
        description: 'Invite a classmate or friend to attend Sabbath School or church',
        location: 'School/Community',
        difficulty: MissionDifficulty.medium,
        duration: '30 minutes',
        points: 25,
        category: MissionCategory.evangelism,
        completed: false,
        instructions: const [
          'Pray for courage and love',
          'Warmly invite your friend to join this weekend',
          'Share what you love about Bible study',
        ],
        verificationMethod: VerificationMethod.witness,
      ),
    ];
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
      'expectedResponse': data['expected_response'] as String?,
      'expectedResponseMode': data['expected_response_mode'] as String?,
      'prerequisiteMissionIds': _stringList(data['prerequisite_mission_ids']),
      'isLocked': data['is_locked'] ?? false,
      'unlockedBy': data['unlocked_by'],
      'mediaUrl': data['media_url'],
    };
  }

  /// Appwrite stores list fields as JSON-encoded strings (e.g. '["a","b"]').
  ///
  /// This used to return such a string as a single element, so the whole
  /// array rendered as one step with visible brackets -- the `["...","..."]`
  /// children saw in the activity list. Decode it, and still tolerate a real
  /// list (from local/fallback data) or a plain string.
  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is! String) return const [];
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        // Not valid JSON -- fall through and keep the raw value.
      }
    }
    return [trimmed];
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
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.onSurface)
                      : theme.colorScheme.onSurface,
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

  Widget _buildMissionListItem(
    BuildContext context,
    Mission mission, {
    required int number,
  }) {
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
        // The activity number is what children refer to ("activity 3"), so it
        // is the leading element. A plain numeral reads faster than an icon.
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (categoryColors[mission.category] ??
                    Theme.of(context).primaryColor)
                .withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: categoryColors[mission.category] ??
                  Theme.of(context).primaryColor,
            ),
          ),
        ),
        title: Text(
          mission.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            decoration: (mission.completed || _progress.isCompleted(mission.id))
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${mission.category.displayName} • ${mission.difficulty.displayName} • ${mission.points} pts',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
                        .withValues(alpha: 0.88),
                  ),
            ),
          ],
        ),
        trailing: (mission.completed || _progress.isCompleted(mission.id))
            ? Icon(Icons.check_circle, color: Colors.green.shade600)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        isThreeLine: true,
        onTap: () => _navigateToActivityDetails(context, mission),
      ),
    );
  }

  List<Widget> _buildItemizedSteps(
    BuildContext context,
    Mission mission,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final List<String> steps = mission.instructions.isNotEmpty
        ? mission.instructions
        : const [
            'Read and reflect on the mission objective',
            'Gather any materials or prepare your thoughts',
            'Perform the mission activity with dedication',
            'Submit your response to earn points and complete',
          ];

    return steps.asMap().entries.map((entry) {
      final stepNumber = entry.key + 1;
      final stepText = entry.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                // No "Step N" caption: the numbered circle beside it already
                // shows the step, so the label repeated the number twice on
                // every row.
                stepText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _navigateToActivityDetails(BuildContext context, Mission mission) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            mission.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mission.mediaUrl != null && mission.mediaUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          mission.mediaUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 150,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: Icon(Icons.broken_image,
                                color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 4),
                            Text(
                              '${mission.points} points',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mission.difficulty.displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mission.duration,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Activity Overview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mission.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered_rounded,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Sequential Steps',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._buildItemizedSteps(context, mission, colorScheme, theme),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                // Close the details dialog, then open the activity sheet once
                // the dismiss has actually completed. Calling both in the same
                // frame left the sheet mounted behind the dialog's scrim, which
                // rendered as a second, translucent modal sitting to the side.
                Navigator.of(context).pop();
                Future.delayed(
                  const Duration(milliseconds: 250),
                  () => _openMissionFlow(mission),
                );
              },
              child: Text(
                _progress.isCompleted(mission.id)
                    ? 'Completed ✓'
                    : 'Start Activity',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The real mission activity flow — verification + scoring + reward.
  void _openMissionFlow(Mission mission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MissionActivitySheet(
        mission: mission,
        alreadyCompleted: _progress.isCompleted(mission.id),
        onCompleted: () {
          if (mounted) setState(() {}); // refresh list badges/points
        },
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
                      child: Text(
                        'Learn, play, and share God\'s love every day!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.95)
                              : theme.colorScheme.onPrimaryContainer,
                        ),
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
                      return _buildMissionListItem(
            context,
            filteredMissions[index],
            // Numbered by position in the full roster, not the filtered
            // view, so a filter never renumbers the activities.
            number: allMissions.indexOf(filteredMissions[index]) + 1,
          );
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


/// Full-screen activity sheet: verifies and scores the child's response
/// according to the mission's verification method, then awards points.
class _MissionActivitySheet extends StatefulWidget {
  final Mission mission;
  final bool alreadyCompleted;
  final VoidCallback onCompleted;

  const _MissionActivitySheet({
    required this.mission,
    required this.alreadyCompleted,
    required this.onCompleted,
  });

  @override
  State<_MissionActivitySheet> createState() => _MissionActivitySheetState();
}

class _MissionActivitySheetState extends State<_MissionActivitySheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _answerController = TextEditingController();
  final KidsMissionProgressService _progress = KidsMissionProgressService();

  bool _listening = false;
  bool _speechAvailable = false;
  String _transcript = '';
  int? _score;
  bool _completed = false;

  Mission get _mission => widget.mission;
  /// Whether the child speaks the answer aloud.
  ///
  /// `witness` is deliberately excluded. A witness activity is confirmed by
  /// another person, so asking the child to recite the prompt was both
  /// semantically wrong and, since the prompt is not a passage, unscoreable.
  bool get _isRecitation =>
      _mission.verificationMethod == VerificationMethod.story &&
      _isScorable;
  bool get _isQuiz => _mission.verificationMethod == VerificationMethod.quiz;
  bool get _isPhoto => _mission.verificationMethod == VerificationMethod.photo;

    /// The passage / expected answer the response is scored against.
  ///
  /// This used to fall back to [Mission.description], which is the task label
  /// shown on screen ("Learn and recite the Beatitudes from Matthew 5:3-12")
  /// rather than anything the child can say. A perfect recitation therefore
  /// scored near zero, while reciting the label aloud scored full marks.
  ///
  /// Only `expectedResponse` -- the passage stored with the mission -- is
  /// scoreable. Activities that are not word-for-word checkable (the child's
  /// own story, a prayer, a witness) leave it null and are not scored at all;
  /// see `_isScorable`.
  String? get _expectedText {
    final passage = _mission.expectedResponse?.trim();
    if (passage == null || passage.isEmpty) return null;
    return passage;
  }

  /// Whether this activity can be graded automatically at all.
  ///
  /// Requires a passage to compare against. A mission verified by photo or
  /// witness is confirmed by a person, so there is nothing to score, and
  /// scoring its instruction text would only manufacture a wrong answer.
  bool get _isScorable =>
      _expectedText != null &&
      _mission.verificationMethod != VerificationMethod.photo &&
      _mission.verificationMethod != VerificationMethod.witness;

  @override
  void initState() {
    super.initState();
    _completed = widget.alreadyCompleted;
    _initSpeech();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (!_isRecitation) return;
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              mounted &&
              _listening) {
            setState(() => _listening = false);
            _scoreRecitation();
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechAvailable = false;
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      _scoreRecitation();
      return;
    }
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Microphone is not available. Please allow mic permission and try again.'),
        ));
        return;
      }
    }
    setState(() {
      _transcript = '';
      _score = null;
      _listening = true;
    });
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'en_US',
        cancelOnError: true,
        partialResults: false, // avoids duplicated transcripts
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
          _scoreRecitation();
        }
      },
    );
  }

  void _scoreRecitation() {
    if (_transcript.trim().isEmpty) return;
    final expected = _expectedText;
    if (expected == null) return;
    final score = MissionScoring.scoreRecitation(expected, _transcript);
    setState(() => _score = score);
    if (score >= MissionScoring.recitationPassThreshold) {
      _awardPoints(score);
    } else {
      _progress.recordAttempt(_mission.id, score);
    }
  }

  void _submitQuizAnswer() {
    final expected = _expectedText;
    if (expected == null) return;
    final score = MissionScoring.scoreAnswer(expected, _answerController.text);
    setState(() => _score = score);
    if (score >= MissionScoring.quizPassThreshold) {
      _awardPoints(score);
    } else {
      _progress.recordAttempt(_mission.id, score);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;
    // Photo missions are parent-verified; capture counts as completion.
    await _awardPoints(100);
  }

  Future<void> _awardPoints(int score) async {
    final awarded = await _progress.completeMission(
        _mission.id, _mission.points,
        score: score);
    if (!mounted) return;
    setState(() => _completed = true);
    widget.onCompleted();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(awarded
            ? 'Mission complete! +${_mission.points} points 🎉'
            : 'Mission already completed — great job!'),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.88;

    return SafeArea(
      top: true,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: maxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _mission.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.star, size: 16),
                        label: Text('${_mission.points} points'),
                      ),
                      Chip(
                          label: Text(
                              _mission.verificationMethod.displayName)),
                      Chip(label: Text(_mission.duration)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _mission.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered_rounded,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Sequential Steps',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_mission.instructions.isNotEmpty
                          ? _mission.instructions
                          : const [
                              'Read and reflect on the mission objective',
                              'Gather any materials or prepare your thoughts',
                              'Perform the mission activity with dedication',
                              'Submit your response to earn points and complete',
                            ])
                      .asMap()
                      .entries
                      .map((entry) {
                    final num = entry.key + 1;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 8, top: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$num',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  if (_completed)
                    _buildCompletedCard(theme)
                  else if (_isRecitation)
                    _buildRecitationCard(theme)
                  else if (_isQuiz)
                    _buildQuizCard(theme)
                  else if (_isPhoto)
                    _buildPhotoCard(theme)
                  else
                    _buildSelfReportCard(theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildCompletedCard(ThemeData theme) {
    final best = _progress.bestScore(_mission.id);
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.green.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 44),
            const SizedBox(height: 8),
            Text('Mission completed!',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (best > 0) ...[
              const SizedBox(height: 4),
              Text('Best score: $best%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 4),
            Text('You earned ${_mission.points} points.',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildRecitationCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Say it out loud',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Tap the mic and recite the passage in your own words. Aim for at '
          'least ${MissionScoring.recitationPassThreshold}% of the key words.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? Colors.red : colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? Colors.red : colorScheme.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: _listening ? 24 : 10,
                        spreadRadius: _listening ? 6 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _listening ? Icons.stop : Icons.mic,
                    color: colorScheme.onPrimary,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _listening ? 'Listening… tap to stop' : 'Tap to start reciting',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (_transcript.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('What we heard:', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_transcript,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ),
        ],
        if (_score != null) ...[
          const SizedBox(height: 16),
          _buildScoreCard(theme, _score!),
        ],
      ],
    );
  }

  Widget _buildQuizCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your answer',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Write your answer. You need at least '
          '${MissionScoring.quizPassThreshold}% to pass.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Type your answer here…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Submit Answer'),
            onPressed: _submitQuizAnswer,
          ),
        ),
        if (_score != null) ...[
          const SizedBox(height: 16),
          _buildScoreCard(theme, _score!),
        ],
      ],
    );
  }

  Widget _buildPhotoCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Show us a photo',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Take a photo of you doing this mission with a grown-up nearby. '
          'A parent or leader can verify it later.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            onPressed: _pickPhoto,
          ),
        ),
      ],
    );
  }

  Widget _buildSelfReportCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Did you complete it?',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Be honest! God loves a truthful heart. Confirm below once you '
          'have done this mission.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.emoji_events),
            label: const Text('Yes, I did it!'),
            onPressed: () => _awardPoints(100),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard(ThemeData theme, int score) {
    final passed = score >= (_isQuiz
        ? MissionScoring.quizPassThreshold
        : MissionScoring.recitationPassThreshold);
    return Card(
      color: passed
          ? Colors.green.withValues(alpha: 0.12)
          : Colors.orange.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: passed ? Colors.green : Colors.orange),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$score%',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: passed
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                )),
            const SizedBox(height: 4),
            Text(MissionScoring.feedbackFor(score),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
            if (!passed && _isRecitation) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                onPressed: () {
                  setState(() {
                    _transcript = '';
                    _score = null;
                  });
                  _toggleListening();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}