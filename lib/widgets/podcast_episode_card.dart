import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class PodcastEpisodeCard extends StatelessWidget {
  final String title;
  final String podcastTitle;
  final String duration;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  const PodcastEpisodeCard({
    super.key,
    required this.title,
    required this.podcastTitle,
    required this.duration,
    this.onPlay,
    this.onDownload,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context, 12),
      ),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveValue<double>(
            context: context,
            mobile: 56,
            tablet: 67,
            desktop: 78,
          ),
          height: ResponsiveUtils.getResponsiveValue<double>(
            context: context,
            mobile: 56,
            tablet: 67,
            desktop: 78,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveSpacing(context, 8),
            ),
          ),
          child: Icon(
            Icons.headphones,
            color: Theme.of(context).primaryColor,
            size: ResponsiveUtils.getResponsiveIconSize(context, 24),
          ),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$podcastTitle • $duration',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 4)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: onPlay,
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: onDownload,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: onShare,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}