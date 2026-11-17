import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/billboard_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/video_embed_view.dart';

/// Reusable Program & Project Billboard / Showcase screen.
///
/// Serves `/billboard`, `/showcase`, `/project-3d-viewer`, and
/// `/alive_ng_3d_viewer.html`, rendering admin-configured flyers, videos,
/// registration forms, or interactive 3D HTML scenes.
class Project3DViewerScreen extends StatefulWidget {
  final String viewerUrl;

  const Project3DViewerScreen({
    super.key,
    this.viewerUrl = '',
  });

  @override
  State<Project3DViewerScreen> createState() => _Project3DViewerScreenState();
}

class _Project3DViewerScreenState extends State<Project3DViewerScreen> {
  BillboardConfig _config = const BillboardConfig();
  bool _loading = true;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _initBillboard();
  }

  Future<void> _initBillboard() async {
    final explicit = widget.viewerUrl.trim();
    final fetched = await BillboardService.instance.fetchConfig();
    BillboardConfig active = fetched;

    if (explicit.isNotEmpty &&
        explicit != 'alive_ng_3d_viewer.html' &&
        explicit != fetched.mediaUrl) {
      active = BillboardConfig(
        isEnabled: true,
        contentType: _inferType(explicit),
        title: 'Featured Showcase',
        mediaUrl: explicit,
      );
    }

    if (!mounted) return;
    _config = active;

    if (!kIsWeb && active.contentType != 'flyer') {
      final targetUrl = _resolveWebOrEmbedUrl(active);
      final headers = active.contentType == 'video'
          ? const {'Referer': 'https://app.alivenigeria.org/'}
          : const <String, String>{};
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0F172A))
        ..loadRequest(Uri.parse(targetUrl), headers: headers);
    }

    setState(() => _loading = false);
  }

  String _inferType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'video';
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp')) {
      return 'flyer';
    }
    if (lower.contains('forms.gle') || lower.contains('docs.google.com/forms')) {
      return 'form';
    }
    return '3d_html';
  }

  String? _extractYouTubeId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com')) {
      if (uri.pathSegments.contains('embed') && uri.pathSegments.length >= 2) {
        return uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
      }
      if (uri.pathSegments.contains('shorts') && uri.pathSegments.length >= 2) {
        return uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
      }
      return uri.queryParameters['v'];
    }
    return null;
  }

  String _resolveWebOrEmbedUrl(BillboardConfig cfg) {
    final target = cfg.mediaUrl.trim().isEmpty
        ? 'alive_ng_3d_viewer.html'
        : cfg.mediaUrl.trim();
    if (cfg.contentType == 'video') {
      final ytId = _extractYouTubeId(target);
      if (ytId != null && ytId.isNotEmpty) {
        final origin = (kIsWeb && Uri.base.scheme.startsWith('http'))
            ? Uri.encodeComponent(Uri.base.origin)
            : 'https%3A%2F%2Fapp.alivenigeria.org';
        return 'https://www.youtube.com/embed/$ytId?autoplay=1&playsinline=1&rel=0&enablejsapi=1&origin=$origin';
      }
    }
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    final cleanPath = target.startsWith('/') ? target.substring(1) : target;
    if (kIsWeb && Uri.base.scheme.startsWith('http')) {
      return '${Uri.base.origin}/$cleanPath';
    }
    return 'https://app.alivenigeria.org/$cleanPath';
  }

  Future<void> _openExternal(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    final resolved = (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
        ? trimmed
        : 'https://app.alivenigeria.org/${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
    final uri = Uri.tryParse(resolved);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _resolveWebOrEmbedUrl(_config);
    final hasCta = _config.ctaUrl.trim().isNotEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        title: _loading ? 'Showcase Billboard' : _config.title,
        showBackButton: true,
        actions: [
          if (!_loading && _config.mediaUrl.trim().isNotEmpty)
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => _openExternal(
                hasCta ? _config.ctaUrl : _config.mediaUrl,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _config.contentType == 'flyer'
              ? Column(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: CustomImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    if (_config.subtitle.trim().isNotEmpty || hasCta)
                      SafeArea(
                        top: false,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border(
                              top: BorderSide(color: theme.dividerColor),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_config.subtitle.trim().isNotEmpty) ...[
                                Text(
                                  _config.subtitle,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (hasCta) const SizedBox(height: 12),
                              ],
                              if (hasCta)
                                FilledButton.icon(
                                  onPressed: () => _openExternal(_config.ctaUrl),
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    _config.ctaLabel.isEmpty
                                        ? 'Register / Open'
                                        : _config.ctaLabel,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  children: [
                    if (_config.subtitle.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        child: Text(
                          _config.subtitle,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    Expanded(
                      child: kIsWeb
                          ? buildVideoEmbed(
                              videoId: 'billboard-${url.hashCode}',
                              embedUrl: url,
                            )
                          : (_webViewController != null
                              ? WebViewWidget(controller: _webViewController!)
                              : const Center(
                                  child: CircularProgressIndicator())),
                    ),
                    if (hasCta)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openExternal(_config.ctaUrl),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(
                                _config.ctaLabel.isEmpty
                                    ? 'Open Link'
                                    : _config.ctaLabel,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
