import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../utils/layout_fix_utils.dart';
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
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context, 16),
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveSpacing(context, 12),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveSpacing(context, 12),
        ),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: LayoutFixUtils.safeRow(
            children: [
              // Cover image
              CustomImage(
                imageUrl: podcast.coverImage,
                width: ResponsiveUtils.getResponsiveValue<double>(
                  context: context,
                  mobile: 80,
                  tablet: 96,
                  desktop: 112,
                ),
                height: ResponsiveUtils.getResponsiveValue<double>(
                  context: context,
                  mobile: 80,
                  tablet: 96,
                  desktop: 112,
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveSpacing(context, 8),
                ),
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                placeholder: Icon(
                  Icons.headset,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 40),
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcast.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                    Text(
                      'by ${podcast.host}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                    Text(
                      podcast.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                    LayoutFixUtils.safeRow(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                          color: Colors.grey[600],
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(context, 4),
                        ),
                        LayoutFixUtils.safeText(
                          '${podcast.episodes} episodes',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize:
                                    ResponsiveUtils.getResponsiveFontSize(context, 12),
                              ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(context, 12),
                        ),
                        Icon(
                          Icons.star,
                          size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                          color: Colors.amber[700],
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(context, 4),
                        ),
                        LayoutFixUtils.safeText(
                          podcast.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize:
                                    ResponsiveUtils.getResponsiveFontSize(context, 12),
                              ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(context, 12),
                        ),
                        Icon(
                          podcast.isSubscribed ? Icons.favorite : Icons.favorite_border,
                          size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                          color: podcast.isSubscribed
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(context, 4),
                        ),
                        LayoutFixUtils.safeText(
                          podcast.isSubscribed ? 'Subscribed' : 'Subscribe',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 10),
                                color: podcast.isSubscribed
                                    ? Theme.of(context).primaryColor
                                    : null,
                              ),
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