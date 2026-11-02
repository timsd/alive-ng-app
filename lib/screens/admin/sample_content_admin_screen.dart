import 'package:flutter/material.dart';
import 'video_content_admin_screen.dart';

/// Legacy sample content route adapter: forwards directly to the production
/// [VideoContentAdminScreen], which is now the single source of truth for
/// library video content, while podcast content is managed in Tract & Podcast Admin.
class SampleContentAdminScreen extends StatelessWidget {
  const SampleContentAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VideoContentAdminScreen();
  }
}
