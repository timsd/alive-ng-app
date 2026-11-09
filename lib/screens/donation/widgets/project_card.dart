import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/project_model.dart';
import '../../../services/exchange_rate_service.dart';
import 'project_fund_update.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onDonate,
    this.displayCurrency,
    this.exchangeRate,
  });

  final Project project;
  final VoidCallback onDonate;
  final String? displayCurrency;
  final double? exchangeRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rate = (exchangeRate != null && exchangeRate! > 0)
        ? exchangeRate!
        : ExchangeRateService.instance.lastKnownRate;
    final hasRate = rate > 0;

    final isUsdPrimary = displayCurrency?.toUpperCase() == 'USD';
    final ngnRaised = project.raisedAmount;
    final ngnTarget = project.targetAmount;
    final usdRaised = hasRate ? (ngnRaised / rate) : 0.0;
    final usdTarget = hasRate ? (ngnTarget / rate) : 0.0;

    final ngnMoney = NumberFormat.compactCurrency(name: 'NGN', symbol: '₦');
    final usdMoney = NumberFormat.compactCurrency(name: 'USD', symbol: '\$');

    final primaryText = isUsdPrimary
        ? '${usdMoney.format(usdRaised)} raised of ${usdMoney.format(usdTarget)}'
        : '${ngnMoney.format(ngnRaised)} raised of ${ngnMoney.format(ngnTarget)}';

    final secondaryText = isUsdPrimary
        ? '≈ ${ngnMoney.format(ngnRaised)} / ${ngnMoney.format(ngnTarget)} NGN'
        : (hasRate
            ? '≈ ${usdMoney.format(usdRaised)} / ${usdMoney.format(usdTarget)} USD'
            : null);

    final statusColor = switch (project.status.toLowerCase()) {
      'active' => colors.tertiary,
      'planning' => colors.secondary,
      'completed' => colors.primary,
      _ => colors.outline,
    };

    // Use dynamic CTA label if available, otherwise default to "Donate"
    final ctaLabel = project.ctaLabel.trim().isEmpty
        ? 'Donate'
        : project.ctaLabel;

    // Interactive 3D project viewer (served with the web build). Donors can
    // explore the real project in detail before giving.
    var viewerUrl = project.viewerUrl.trim();
    if (viewerUrl.isEmpty && project.id == 'impact_hub_center') {
      viewerUrl = 'alive_ng_3d_viewer.html';
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (project.imageUrl?.isNotEmpty == true)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: project.imageUrl!.startsWith('assets/')
                  ? Image.asset(
                      project.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: colors.onSurfaceVariant),
                      ),
                    )
                  : Image.network(
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(
                        primaryText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (secondaryText != null)
                        Text(
                          secondaryText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
                ProjectFundUpdate(project: project),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onDonate,
                  icon: const Icon(Icons.volunteer_activism),
                  label: Text(ctaLabel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                ),
                if (viewerUrl.isNotEmpty && kIsWeb) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await launchUrl(
                          Uri.parse(viewerUrl),
                          webOnlyWindowName: '_blank',
                        );
                      } catch (_) {
                        // Viewer unavailable; fail silently.
                      }
                    },
                    icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                    label: const Text('Explore the project in 3D'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
