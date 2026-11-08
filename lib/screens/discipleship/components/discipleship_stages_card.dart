import 'package:flutter/material.dart';
import '../../../models/discipleship_models.dart';
import '../../../utils/responsive_utils.dart';
import 'discipleship_helpers.dart';

/// The Discipleship Stages & Overview summary card widget.
class DiscipleshipOverviewTab extends StatelessWidget {
  final DiscipleshipStatistics statistics;

  const DiscipleshipOverviewTab({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: DiscipleshipStatCard(
                  title: 'Total Contacts',
                  value: statistics.totalContacts.toString(),
                  icon: Icons.people,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
              ),
              Expanded(
                child: DiscipleshipStatCard(
                  title: 'Active Contacts',
                  value: statistics.activeContacts.toString(),
                  icon: Icons.person_add,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DiscipleshipStatCard(
                  title: 'Baptisms',
                  value: statistics.totalBaptisms.toString(),
                  icon: Icons.water_drop,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
              ),
              Expanded(
                child: DiscipleshipStatCard(
                  title: 'Study Sessions',
                  value: statistics.totalStudySessions.toString(),
                  icon: Icons.book,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 24.0,
              tablet: 28.0,
              desktop: 32.0,
            ),
          ),

          // Level Distribution Card
          Card(
            child: Padding(
              padding: context.responsivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discipleship Levels & Stages',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 16.0,
                      tablet: 20.0,
                      desktop: 24.0,
                    ),
                  ),
                  ..._buildLevelDistribution(context),
                ],
              ),
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            ),
          ),

          // Recent Activity Card
          Card(
            child: Padding(
              padding: context.responsivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity (Last 30 Days)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 16.0,
                      tablet: 20.0,
                      desktop: 24.0,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              statistics.recentInteractions.toString(),
                              style: TextStyle(
                                fontSize: context.responsiveFontSize(24),
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text('Interactions'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              statistics.recentStudySessions.toString(),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.tertiary,
                                  ),
                            ),
                            Text('Study Sessions', style: Theme.of(context).textTheme.labelMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLevelDistribution(BuildContext context) {
    final levelDistribution = statistics.levelDistribution;

    return DiscipleshipLevel.values.map((level) {
      final count = levelDistribution[level.name] ?? 0;
      final percentage = statistics.totalContacts > 0
          ? (count / statistics.totalContacts * 100).round()
          : 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(DiscipleshipHelpers.getLevelDisplayName(level)),
            ),
            Expanded(
              flex: 2,
              child: LinearProgressIndicator(
                value: statistics.totalContacts > 0 ? count / statistics.totalContacts : 0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(DiscipleshipHelpers.getLevelColor(level)),
              ),
            ),
            SizedBox(
              width: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
            Text(
              '$count ($percentage%)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      );
    }).toList();
  }
}

/// A standard card showing a primary discipleship metric with an icon and label.
class DiscipleshipStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DiscipleshipStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          children: [
            Icon(icon, size: context.responsiveIconSize(32), color: color),
            SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact stat tile for contact detail sheets.
class DiscipleshipMiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DiscipleshipMiniStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
