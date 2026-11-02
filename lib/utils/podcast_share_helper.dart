import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Centralized podcast sharing utility.
/// Generates deep links that open directly to specific episodes in the ALIVE Nigeria app,
/// copies the shareable URL to clipboard, and triggers native/web share sheet.
class PodcastShareHelper {
  static const String webBaseUrl = 'https://app.alivenigeria.org';

  /// Generates a direct web/app link to the podcast episode.
  static String buildEpisodeShareUrl({
    required String episodeId,
    String? podcastId,
  }) {
    if (episodeId.isEmpty) {
      return '$webBaseUrl/#/podcasts';
    }
    final encodedId = Uri.encodeComponent(episodeId);
    if (podcastId != null && podcastId.isNotEmpty) {
      return '$webBaseUrl/#/podcasts?episodeId=$encodedId&podcastId=${Uri.encodeComponent(podcastId)}';
    }
    return '$webBaseUrl/#/podcasts?episodeId=$encodedId';
  }

  /// Shares a podcast episode across social platforms, messaging apps, and clipboard.
  static Future<void> shareEpisode(
    BuildContext context, {
    required Map<String, dynamic> episode,
    String? podcastTitle,
  }) async {
    final title = (episode['title'] ?? 'ALIVE Nigeria Podcast').toString().trim();
    final show = (podcastTitle ??
            episode['podcastTitle'] ??
            episode['podcast_title'] ??
            'ALIVE Nigeria')
        .toString()
        .trim();
    final host =
        (episode['host'] ?? episode['author'] ?? episode['speaker'] ?? '').toString().trim();
    final episodeId = (episode['id'] ?? episode[r'$id'] ?? '').toString().trim();
    final podcastId = (episode['podcastId'] ?? episode['podcast_id'] ?? '').toString().trim();

    final shareUrl = buildEpisodeShareUrl(episodeId: episodeId, podcastId: podcastId);

    final buffer = StringBuffer();
    buffer.writeln('🎙️ "$title"');
    if (host.isNotEmpty) {
      buffer.writeln('Speaker: $host');
    }
    if (show.isNotEmpty && show != title) {
      buffer.writeln('Show: $show');
    }
    buffer.writeln();
    buffer.writeln('Listen now on ALIVE Nigeria:');
    buffer.writeln(shareUrl);

    final shareMessage = buffer.toString();

    // 1. Copy link to clipboard immediately so desktop & web users always have it
    try {
      await Clipboard.setData(ClipboardData(text: shareUrl));
    } catch (_) {}

    // 2. Trigger native or browser share dialog
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareMessage,
          subject: '$title - ALIVE Nigeria Podcast',
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast link copied to clipboard!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Podcast link copied to clipboard!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

