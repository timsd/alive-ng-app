import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import '../../widgets/custom_app_bar.dart';
import '../../config/meeting_links_config.dart';
import 'livekit_meeting_screen.dart';

class ConferencePlatformScreen extends StatelessWidget {
  const ConferencePlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const roomName = AliveMeetConfig.communityRoom;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'ALIVE Meet',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'ALIVE Meet room',
                hintText: roomName,
                border: OutlineInputBorder(),
                enabled: false,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call),
              label: const Text('Continue to ALIVE Meet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LiveKitMeetingScreen(
                      customRoomName: roomName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(Icons.edit_note, color: theme.colorScheme.primary),
              label: const Text('Open Scribe & Meeting Notes'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                context.push(AppConstants.scribeRoute);
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ALIVE Scribe captures speech-to-text meeting minutes, action items, and executive summaries. It operates both during live calls and as a standalone scribe.',
                        style: TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
