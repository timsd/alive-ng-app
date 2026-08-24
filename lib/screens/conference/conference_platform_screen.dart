import 'package:flutter/material.dart';

import '../../widgets/custom_app_bar.dart';
import '../../config/meeting_links_config.dart';
import 'livekit_meeting_screen.dart';

class ConferencePlatformScreen extends StatelessWidget {
  const ConferencePlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const roomName = AliveMeetConfig.communityRoom;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'ALIVE Meet',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LiveKitMeetingScreen(
                      customRoomName: roomName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
