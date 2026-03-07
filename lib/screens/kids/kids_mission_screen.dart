import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';

class KidsMissionScreen extends ConsumerWidget {
  const KidsMissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Will be used for localization in future implementation
    // final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: const CustomAppBar(
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
                    Theme.of(context).primaryColor.withValues(alpha: 179 / 255.0), // 0.7 opacity = 179 alpha
                  ],
                ),
                borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.child_care,
                    size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 56, tablet: 64, desktop: 72),
                    color: Colors.white,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
                  Text(
                    'Kids Mission Adventures',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6, tablet: 8, desktop: 10)),
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
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20, tablet: 24, desktop: 28)),

            // Recent Activities
            Text(
              'Recent Activities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12, tablet: 16, desktop: 20)),
            
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
        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
      ),
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
                  color: color.withValues(alpha: 26 / 255.0), // 0.1 opacity = 26 alpha
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

  Widget _buildActivityCard(BuildContext context, int index) {
    final activities = [
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
      {
        'title': 'Morning Prayer',
        'type': 'Prayer Time',
        'progress': 0.9,
        'icon': Icons.favorite,
      },
    ];

    final activity = activities[index];
    
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10, tablet: 12, desktop: 14)),
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
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3, tablet: 4, desktop: 5)),
            LinearProgressIndicator(
              value: activity['progress'] as double,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
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
            const Text(
              'Activity Details',
              style: TextStyle(fontWeight: FontWeight.bold),
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



