import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../models/kids_missions.dart';
class KidsMissionScreen extends ConsumerWidget {
  const KidsMissionScreen({super.key});

  Stream<List<Mission>> _getMissionsStream() {
    return FirebaseFirestore.instance.collection('kids_missions').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Defaults to support legacy compatibility
        data['completed'] = data['completed'] ?? false;
        data['points'] = data['points'] ?? 10;
        data['category'] = data['category'] ?? 'learning';
        data['difficulty'] = data['difficulty'] ?? 'easy';
        data['duration'] = data['duration'] ?? 15;
        data['verificationMethod'] = data['verificationMethod'] ?? 'honor_system';
        data['content'] = data['content'] ?? data['instructions'] ?? '';

        try {
          return Mission.fromJson(data);
        } catch (e) {
          return null;
        }
      }).whereType<Mission>().toList();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kids Mission',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 16, tablet: 20, desktop: 24)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 179 / 255.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.child_care,
                    size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 56, tablet: 64, desktop: 72),
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
                  Text(
                    'Kids Mission Adventures',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
                  Text(
                    'Exciting missions and activities for young disciples',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 230 / 255.0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28)),

            // Mission Categories
            Text(
              'Mission Categories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
              mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20),
              childAspectRatio: 1.2,
              children: [
                _buildMissionCard(
                  context,
                  'Memory Verses',
                  Icons.psychology,
                  Theme.of(context).colorScheme.tertiary,
                  'Learn and memorize Bible verses',
                ),
                _buildMissionCard(
                  context,
                  'Prayer Time',
                  Icons.favorite,
                  Theme.of(context).colorScheme.error,
                  'Guided prayer activities',
                ),
                _buildMissionCard(
                  context,
                  'Service Projects',
                  Icons.volunteer_activism,
                  Theme.of(context).colorScheme.secondary,
                  'Help others in your community',
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28)),

            Text(
              'Available Missions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            
            StreamBuilder<List<Mission>>(
              stream: _getMissionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                
                if (snapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Failed to load missions: ${snapshot.error}')));
                }

                final missions = snapshot.data ?? [];
                
                if (missions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Column(
                        children: [
                          Icon(Icons.assignment_turned_in, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No active missions found.', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: missions.length,
                  itemBuilder: (context, index) {
                    return _buildMissionListItem(context, missions[index]);
                  },
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String description,
  ) {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () {
          _navigateToMissionCategory(context, title);
        },
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 26 / 255.0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 28, tablet: 32, desktop: 36),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionListItem(BuildContext context, Mission mission) {
    final categoryIcons = {
      MissionCategory.evangelism: Icons.campaign,
      MissionCategory.service: Icons.volunteer_activism,
      MissionCategory.learning: Icons.psychology,
      MissionCategory.prayer: Icons.favorite,
    };
    final categoryColors = {
      MissionCategory.evangelism: Theme.of(context).colorScheme.primary,
      MissionCategory.service: Theme.of(context).colorScheme.secondary,
      MissionCategory.learning: Theme.of(context).colorScheme.tertiary,
      MissionCategory.prayer: Theme.of(context).colorScheme.error,
    };

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (categoryColors[mission.category] ?? Theme.of(context).primaryColor).withValues(alpha: 0.15),
          child: Icon(
            categoryIcons[mission.category] ?? Icons.star,
            color: categoryColors[mission.category] ?? Theme.of(context).primaryColor,
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
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
            Text(
              mission.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

  void _navigateToMissionCategory(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$category Missions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Explore missions in the $category category.'),
            const SizedBox(height: 16),
            Text('This will show specific missions and activities related to $category.'),
          ],
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
                  content: Text('Opening $category missions...'),
                ),
              );
            },
            child: const Text('Explore'),
          ),
        ],
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
                     child: Image.network(mission.mediaUrl!, height: 150, width: double.infinity, fit: BoxFit.cover,
                       errorBuilder: (context, error, stackTrace) => Container(
                         height: 150, color: Colors.grey[300], child: const Icon(Icons.broken_image, color: Colors.grey),
                       ),
                     ),
                   ),
                 ),
              Text(
                'Activity Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(mission.description),
              const SizedBox(height: 16),
              Text(
                'Instructions:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(mission.instructions.isNotEmpty ? mission.instructions.join('\n') : '1. Read the activity description\n2. Gather required materials\n3. Follow the step-by-step guide\n4. Share your results with friends'),
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
}
