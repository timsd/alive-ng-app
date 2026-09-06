import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/project_model.dart';
import 'project_fund_update.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onDonate});
  final Project project;
  final VoidCallback onDonate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = project.currency.trim().isEmpty ? 'NGN' : project.currency;
    final money =
        NumberFormat.compactCurrency(name: currency, symbol: '$currency ');
    final statusColor = switch (project.status.toLowerCase()) {
      'active' => colors.tertiary,
      'planning' => colors.secondary,
      'completed' => colors.primary,
      _ => colors.outline,
    };

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (project.imageUrl?.isNotEmpty == true)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                project.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Icon(Icons.image_not_supported_outlined,
                      color: colors.onSurfaceVariant),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(project.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (project.status.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(project.status,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: statusColor)),
                ],
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(project.description, style: theme.textTheme.bodyMedium),
                ],
                if (project.targetAmount > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (project.raisedAmount / project.targetAmount)
                        .clamp(0.0, 1.0),
                    semanticsLabel: 'Project funding progress',
                    minHeight: 6,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${money.format(project.raisedAmount)} raised of ${money.format(project.targetAmount)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
                ProjectFundUpdate(project: project),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onDonate,
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Donate'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
