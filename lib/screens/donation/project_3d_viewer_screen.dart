import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../widgets/custom_app_bar.dart';
import '../../widgets/video_embed_view.dart';

/// In-app 3D project viewer screen so `/alive_ng_3d_viewer.html` and
/// `/project-3d-viewer` always render cleanly inside Flutter Web/PWA and mobile
/// instead of hitting GoRouter's Page Not Found screen.
class Project3DViewerScreen extends StatefulWidget {
  final String viewerUrl;

  const Project3DViewerScreen({
    super.key,
    this.viewerUrl = 'alive_ng_3d_viewer.html',
  });

  @override
  State<Project3DViewerScreen> createState() => _Project3DViewerScreenState();
}

class _Project3DViewerScreenState extends State<Project3DViewerScreen> {
  WebViewController? _webViewController;

  String get _resolvedUrl {
    final trimmed = widget.viewerUrl.trim();
    final target = trimmed.isEmpty ? 'alive_ng_3d_viewer.html' : trimmed;
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    final cleanPath = target.startsWith('/') ? target.substring(1) : target;
    if (kIsWeb && Uri.base.scheme.startsWith('http')) {
      return '${Uri.base.origin}/$cleanPath';
    }
    return 'https://app.alivenigeria.org/$cleanPath';
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0F172A))
        ..loadRequest(Uri.parse(_resolvedUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    return Scaffold(
      appBar: const CustomAppBar(
        title: '3D Project Viewer',
        showBackButton: true,
      ),
      body: kIsWeb
          ? buildVideoEmbed(
              videoId: 'project-3d-${url.hashCode}',
              embedUrl: url,
            )
          : (_webViewController != null
              ? WebViewWidget(controller: _webViewController!)
              : const Center(child: CircularProgressIndicator())),
    );
  }
}
