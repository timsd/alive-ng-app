import 'package:flutter/material.dart';

import '../../../constants/chapters.dart';

/// Pre-join lobby form for configuring meeting room settings before joining.
class MeetingPrejoinLobby extends StatelessWidget {
  final TextEditingController roomController;
  final bool isLeader;
  final bool isJoining;
  final bool requireHostApproval;
  final ValueChanged<bool> onToggleRequireHostApproval;
  final bool notifyMembers;
  final ValueChanged<bool> onToggleNotifyMembers;
  final String targetAudience;
  final ValueChanged<String> onAudienceChanged;
  final List<DropdownMenuItem<String>> audienceItems;
  final String? selectedTargetChapter;
  final ValueChanged<String> onChapterChanged;
  final bool isLoadingChannels;
  final VoidCallback onRefreshChannels;
  final VoidCallback onJoin;

  const MeetingPrejoinLobby({
    super.key,
    required this.roomController,
    required this.isLeader,
    required this.isJoining,
    required this.requireHostApproval,
    required this.onToggleRequireHostApproval,
    required this.notifyMembers,
    required this.onToggleNotifyMembers,
    required this.targetAudience,
    required this.onAudienceChanged,
    required this.audienceItems,
    required this.selectedTargetChapter,
    required this.onChapterChanged,
    required this.isLoadingChannels,
    required this.onRefreshChannels,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAudience = audienceItems.any((i) => i.value == targetAudience)
        ? targetAudience
        : 'general';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: roomController,
          decoration: InputDecoration(
            labelText: 'Meeting Room',
            border: const OutlineInputBorder(),
            helperText: !isLeader
                ? 'Members can join designated rooms. Starting new rooms is reserved for leaders.'
                : null,
          ),
          readOnly: !isLeader,
        ),
        if (isLeader) ...[
          const SizedBox(height: 8),
          // Waiting Room Policy toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              requireHostApproval ? Icons.door_sliding : Icons.meeting_room_outlined,
              color: requireHostApproval ? const Color(0xFFD49B28) : null,
            ),
            title: const Text('Require Host Approval (Waiting Room)'),
            subtitle: const Text('Participants wait in virtual lobby until admitted by host/leader'),
            value: requireHostApproval,
            activeThumbColor: const Color(0xFFD49B28),
            onChanged: onToggleRequireHostApproval,
          ),
          const SizedBox(height: 4),
          // Targeted Push Notification toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notify members via push notification'),
            subtitle: const Text('Sends a background push notification when meeting starts'),
            value: notifyMembers,
            onChanged: onToggleNotifyMembers,
          ),
          if (notifyMembers) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: effectiveAudience,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Notification Target Audience',
                prefixIcon: const Icon(Icons.group_outlined),
                suffixIcon: IconButton(
                  icon: isLoadingChannels
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Refresh Channels',
                  onPressed: isLoadingChannels ? null : onRefreshChannels,
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: audienceItems,
              onChanged: (val) {
                if (val != null) onAudienceChanged(val);
              },
            ),
            if (targetAudience == 'chapter') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedTargetChapter,
                decoration: const InputDecoration(
                  labelText: 'Select Chapter to Notify',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: ChapterConstants.availableChapters.map((ch) {
                  return DropdownMenuItem(
                    value: ch,
                    child: Text(ch),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onChapterChanged(val);
                },
              ),
            ],
          ],
        ],
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: isJoining ? null : onJoin,
          icon: isJoining
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.video_call),
          label: Text(isJoining
              ? 'Joining...'
              : (isLeader ? 'Start / Join ALIVE Meet' : 'Join ALIVE Meet')),
        ),
      ],
    );
  }
}

