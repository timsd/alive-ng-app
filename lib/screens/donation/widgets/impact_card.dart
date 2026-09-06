import 'package:flutter/material.dart';
import '../../../models/donation_presentation_models.dart';
import '../../../utils/responsive_utils.dart';

class ImpactCard extends StatelessWidget {
  const ImpactCard(
      {super.key,
      required this.impact,
      required this.isSelected,
      required this.onTap});
  final DonationImpact impact;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.dividerColor.withValues(alpha: 0.2),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  impact.icon,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                ),
              ),
              SizedBox(
                  width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            impact.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle,
                              color: theme.colorScheme.primary, size: 20),
                      ],
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    Text(
                      impact.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isSelected
                          ? 'Selected for this Gift'
                          : 'Tap to direct your gift here',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
