import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';

class KidsMissionScreen extends ConsumerWidget {
  const KidsMissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Will be used for localization in future implementation
    // final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kids Mission',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 179 / 255.0), // 0.7 opacity = 179 alpha
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.child_care,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kids Mission Adventures',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exciting missions and activities for young disciples',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 230 / 255.0), // 0.9 opacity = 230 alpha
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mission Categories
            Text(
              'Mission Categories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildMissionCard(
                  context,
                  'Bible Stories',
                  Icons.book,
                  Colors.blue,
                  'Interactive Bible stories for kids',
                ),
                _buildMissionCard(
                  context,
                  'Memory Verses',
                  Icons.psychology,
                  Colors.green,
                  'Learn and memorize Bible verses',
                ),
                _buildMissionCard(
                  context,
                  'Prayer Time',
                  Icons.favorite,
                  Colors.red,
                  'Guided prayer activities',
                ),
                _buildMissionCard(
                  context,
                  'Service Projects',
                  Icons.volunteer_activism,
                  Colors.orange,
                  'Help others in your community',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Activities
            Text(
              'Recent Activities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return _buildActivityCard(context, index);
              },
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
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _navigateToMissionCategory(context, title);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 26 / 255.0), // 0.1 opacity = 26 alpha
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
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

  Widget _buildActivityCard(BuildContext context, int index) {
    final activities = [
      {
        'title': 'David and Goliath',
        'type': 'Bible Story',
        'progress': 0.8,
        'icon': Icons.shield,
      },
      {
        'title': 'Psalm 23:1',
        'type': 'Memory Verse',
        'progress': 1.0,
        'icon': Icons.psychology,
      },
      {
        'title': 'Help a Neighbor',
        'type': 'Service Project',
        'progress': 0.6,
        'icon': Icons.volunteer_activism,
      },
    ];

    final activity = activities[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 26 / 255.0), // 0.1 opacity = 26 alpha
          child: Icon(
            activity['icon'] as IconData,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          activity['title'] as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity['type'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: activity['progress'] as double,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () {
          _navigateToActivityDetails(context, activity['title'] as String, activity['description'] as String);
        },
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

  void _navigateToActivityDetails(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Details',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Read the activity description\n2. Gather required materials\n3. Follow the step-by-step guide\n4. Share your results with friends'),
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
                  content: Text('Starting activity: $title'),
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



