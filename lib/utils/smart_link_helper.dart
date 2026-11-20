import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/scripture_rich_text.dart';

import 'toast_utils.dart';

/// Utilities for detecting URLs in feed content, generating smart CTA labels,
/// and launching external URLs or internal app routes.
class SmartLinkHelper {
  SmartLinkHelper._();

  static final RegExp _urlRegex = RegExp(
    r'(?:https?:\/\/|www\.)[^\s<>\]\)]+',
    caseSensitive: false,
  );

  /// Extracts unique, normalized URLs from free-form [text].
  static List<String> extractUrls(String text) {
    if (text.trim().isEmpty) return const [];
    final seen = <String>{};
    final urls = <String>[];

    for (final match in _urlRegex.allMatches(text)) {
      final cleaned = _stripTrailingPunctuation(match.group(0) ?? '');
      if (cleaned.isEmpty) continue;
      final normalized = normalizeUrl(cleaned);
      if (seen.add(normalized)) {
        urls.add(normalized);
      }
    }
    return urls;
  }

  /// Normalizes a raw URL (prepends `https://` for `www.` links).
  static String normalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty || trimmed.startsWith('/')) return trimmed;
    if (trimmed.toLowerCase().startsWith('www.')) {
      return 'https://$trimmed';
    }
    if (!trimmed.contains('://') && trimmed.contains('.')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  static String _stripTrailingPunctuation(String url) {
    var result = url.trim();
    while (result.isNotEmpty &&
        '.,;:!?)]\'"'.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// Returns [customLabel] if non-empty, or infers a smart CTA button label
  /// from [url] and optional surrounding [contextText].
  static String inferSmartCtaLabel(
    String url, {
    String? customLabel,
    String? contextText,
  }) {
    final custom = customLabel?.trim() ?? '';
    if (custom.isNotEmpty) return custom;

    final normalized = normalizeUrl(url);
    final lowerUrl = normalized.toLowerCase();
    final lowerContext = (contextText ?? '').toLowerCase();

    // Internal app routes
    if (normalized.startsWith('/')) {
      if (lowerUrl.contains('donat')) return 'Donate Now';
      if (lowerUrl.contains('event')) return 'View Event';
      if (lowerUrl.contains('podcast')) return 'Listen Now';
      if (lowerUrl.contains('bible')) return 'Open Bible';
      if (lowerUrl.contains('tract')) return 'Read Tracts';
      if (lowerUrl.contains('meeting') || lowerUrl.contains('conference')) {
        return 'Join Meeting';
      }
      return 'Open Page';
    }

    // Video / live meetings
    if (lowerUrl.contains('zoom.us') ||
        lowerUrl.contains('meet.google.com') ||
        lowerUrl.contains('teams.microsoft.com') ||
        lowerUrl.contains('meet.jit.si')) {
      return 'Join Meeting';
    }

    // Video platforms
    if (lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('vimeo.com')) {
      return 'Watch Video';
    }

    // Forms & registrations
    if (lowerUrl.contains('forms.gle') ||
        lowerUrl.contains('docs.google.com/forms') ||
        lowerUrl.contains('typeform.com') ||
        lowerUrl.contains('tally.so') ||
        lowerUrl.contains('register') ||
        lowerUrl.contains('signup') ||
        lowerUrl.contains('rsvp') ||
        lowerContext.contains('register') ||
        lowerContext.contains('sign up') ||
        lowerContext.contains('rsvp')) {
      return 'Register Now';
    }

    // Donations & giving
    if (lowerUrl.contains('paystack.com') ||
        lowerUrl.contains('flutterwave.com') ||
        lowerUrl.contains('gofundme.com') ||
        lowerUrl.contains('donate') ||
        lowerContext.contains('donate') ||
        lowerContext.contains('giving')) {
      return 'Donate Now';
    }

    // Community / chat links
    if (lowerUrl.contains('whatsapp.com') || lowerUrl.contains('wa.me')) {
      return 'Join WhatsApp';
    }
    if (lowerUrl.contains('t.me') || lowerUrl.contains('telegram.me')) {
      return 'Join Telegram';
    }

    // Documents & downloads
    if (lowerUrl.endsWith('.pdf') ||
        lowerUrl.contains('docs.google.com') ||
        lowerUrl.contains('drive.google.com') ||
        lowerUrl.contains('dropbox.com')) {
      return 'View Document';
    }

    // App stores
    if (lowerUrl.contains('play.google.com') ||
        lowerUrl.contains('apps.apple.com')) {
      return 'Get App';
    }

    // Social posts
    if (lowerUrl.contains('instagram.com') ||
        lowerUrl.contains('facebook.com') ||
        lowerUrl.contains('fb.com') ||
        lowerUrl.contains('x.com') ||
        lowerUrl.contains('twitter.com')) {
      return 'View Post';
    }

    final uri = Uri.tryParse(normalized);
    final host = (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
    if (host.isNotEmpty) {
      return 'Visit $host';
    }
    return 'Open Link';
  }

  /// Picks a contextual icon for a smart CTA button.
  static IconData inferSmartCtaIcon(String url, {String? contextText}) {
    final label = inferSmartCtaLabel(url, contextText: contextText);
    switch (label) {
      case 'Join Meeting':
        return Icons.videocam_outlined;
      case 'Watch Video':
        return Icons.play_circle_outline;
      case 'Register Now':
        return Icons.how_to_reg_outlined;
      case 'Donate Now':
        return Icons.volunteer_activism_outlined;
      case 'Join WhatsApp':
      case 'Join Telegram':
        return Icons.forum_outlined;
      case 'View Document':
        return Icons.description_outlined;
      case 'Get App':
        return Icons.get_app_outlined;
      default:
        return Icons.open_in_new_rounded;
    }
  }

  /// Extracts an internal GoRouter route (e.g. `/podcasts?episodeId=...`) if
  /// [rawUrl] points to an in-app route or an `app.alivenigeria.org` deep link.
  static String? extractInternalRoute(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('/')) {
      if (trimmed.endsWith('.html') && trimmed != '/alive_ng_3d_viewer.html') {
        return null;
      }
      if (trimmed.startsWith('/downloads/')) return null;
      return trimmed;
    }

    final normalized = normalizeUrl(trimmed);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority) return null;

    final host = uri.host.toLowerCase();
    final isAppHost = host == 'app.alivenigeria.org' ||
        (Uri.base.hasAuthority &&
            Uri.base.host.isNotEmpty &&
            host == Uri.base.host.toLowerCase());
    if (!isAppHost) return null;

    if (uri.fragment.startsWith('/')) {
      return uri.fragment;
    }

    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/' && !uri.hasQuery) return null;
    if (path.endsWith('.html') && path != '/alive_ng_3d_viewer.html') {
      return null;
    }
    if (path.startsWith('/downloads/')) return null;

    return uri.hasQuery ? '$path?${uri.query}' : path;
  }

  /// Opens an internal route via GoRouter or an external URL via `url_launcher`.
  static Future<void> openSmartLink(
    BuildContext context,
    String rawUrl,
  ) async {
    final target = normalizeUrl(rawUrl);
    if (target.isEmpty) return;

    final internalRoute = extractInternalRoute(target);
    if (internalRoute != null && internalRoute.isNotEmpty) {
      try {
        GoRouter.of(context).push(internalRoute);
      } catch (_) {
        if (context.mounted) {
          context.go(internalRoute);
        }
      }
      return;
    }

    final uri = Uri.tryParse(target);
    if (uri == null) {
      ToastUtils.showError('Invalid link: $target');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        ToastUtils.showError('Could not open link');
      }
    } catch (_) {
      ToastUtils.showError('Could not open link');
    }
  }

  /// Renders [text] with any embedded URLs styled as clickable links and any
  /// Bible references clickable to open [BibleReferenceModalSheet].
  static Widget buildLinkifiedText(
    BuildContext context,
    String text, {
    TextStyle? style,
  }) {
    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return ScriptureRichText(text, style: style);
    }

    final linkColor = Theme.of(context).colorScheme.primary;
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.addAll(
          ScriptureTextParser.buildSpans(
            context,
            text.substring(cursor, match.start),
            baseStyle: style,
          ),
        );
      }
      final rawMatch = match.group(0) ?? '';
      final cleaned = _stripTrailingPunctuation(rawMatch);
      final trailing = rawMatch.substring(cleaned.length);

      if (cleaned.isNotEmpty) {
        spans.add(
          TextSpan(
            text: cleaned,
            style: TextStyle(
              color: linkColor,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => openSmartLink(context, cleaned),
          ),
        );
      }
      if (trailing.isNotEmpty) {
        spans.add(TextSpan(text: trailing));
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.addAll(
        ScriptureTextParser.buildSpans(
          context,
          text.substring(cursor),
          baseStyle: style,
        ),
      );
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
    );
  }
}
