import 'package:flutter/material.dart';

import '../../widgets/custom_app_bar.dart';
import 'livekit_meeting_screen.dart';

class ConferencePlatformScreen extends StatelessWidget {
  const ConferencePlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roomController = TextEditingController();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'LiveKit Conference',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Room name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call),
              label: const Text('Continue to LiveKit'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LiveKitMeetingScreen(
                      customRoomName: roomController.text.trim().isEmpty
                          ? null
                          : roomController.text.trim(),
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
