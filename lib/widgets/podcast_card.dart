import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../models/podcast_models.dart';
import 'custom_image.dart';

class PodcastCard extends StatelessWidget {
  final Podcast podcast;
  final VoidCallback? onTap;

  const PodcastCard({
    super.key,
    required this.podcast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageSize = ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      mobile: 84,
      tablet: 96,
      desktop: 112,
    );

    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context, 14),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomImage(
                  imageUrl: podcast.coverImage,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  placeholder: Icon(
                    Icons.headset,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 36),
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info Column - Fills 100% of the remaining horizontal width
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title cuts across the card with ellipsis for overflow protection
                    Text(
                      podcast.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 15),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'by ${podcast.host}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      podcast.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 13),
                        color: colorScheme.onSurface.withValues(alpha: 0.8),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Metadata row: episodes, rating, subscription
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${podcast.episodes} eps',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 11.5),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              podcast.rating.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 11.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              podcast.isSubscribed
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: podcast.isSubscribed
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              podcast.isSubscribed ? 'Subscribed' : 'Subscribe',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 11),
                                fontWeight: FontWeight.w600,
                                color: podcast.isSubscribed ? colorScheme.primary : null,
                              ),
                            ),
                          ],
                        ),
                      ],
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
