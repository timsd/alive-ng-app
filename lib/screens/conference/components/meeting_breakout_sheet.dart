import 'package:flutter/material.dart';

import '../../../models/meeting_models.dart';
import '../../../services/ports/meeting_gateway.dart';

/// Bottom sheet widget for viewing, managing, creating, and joining Breakout Rooms.
class MeetingBreakoutSheet extends StatefulWidget {
  final MeetingGateway gateway;
  final bool isLeader;
  final String currentUserId;
  final void Function(String message) showMessage;

  const MeetingBreakoutSheet({
    super.key,
    required this.gateway,
    required this.isLeader,
    required this.currentUserId,
    required this.showMessage,
  });

  static Future<void> show({
    required BuildContext context,
    required MeetingGateway gateway,
    required bool isLeader,
    required String currentUserId,
    required void Function(String message) showMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MeetingBreakoutSheet(
        gateway: gateway,
        isLeader: isLeader,
        currentUserId: currentUserId,
        showMessage: showMessage,
      ),
    );
  }

  @override
  State<MeetingBreakoutSheet> createState() => _MeetingBreakoutSheetState();
}

class _MeetingBreakoutSheetState extends State<MeetingBreakoutSheet> {
  final List<String> _defaultRoomTopics = <String>[
    'Prayer & Intercession',
    'Evangelism & Outreach',
    'Bible Study & Doctrine',
    'Youth & Campus Mission',
    'Medical & Health Ministry',
    'Family & Fellowship',
    'Chapter Strategy',
    'Media & Publications',
  ];

  int _roomCount = 2;
  int? _selectedDurationMins = 15;
  bool _allowSelfSelect = true;
  bool _autoAssign = true;
  late final List<TextEditingController> _nameControllers;
  final TextEditingController _broadcastController = TextEditingController();
  final Map<String, int> _manualAssignments = <String, int>{};

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(
      8,
      (i) => TextEditingController(
        text: 'Room ${i + 1}: ${_defaultRoomTopics[i % _defaultRoomTopics.length]}',
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    _broadcastController.dispose();
    super.dispose();
  }

  String _formatRemaining(DateTime? endsAt) {
    if (endsAt == null) return '';
    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return 'Time expired';
    final mins = diff.inMinutes;
    final secs = diff.inSeconds % 60;
    return '${mins}m ${secs.toString().padLeft(2, '0')}s remaining';
  }

  @override
  Widget build(BuildContext context) {
    final gateway = widget.gateway;
    final session = gateway.currentSession;
    final isActive = session.isBreakoutActive;
    final localId = session.localParticipant?.identity ?? widget.currentUserId;
    final theme = Theme.of(context);

    if (isActive) {
      final remaining = _formatRemaining(session.breakoutEndsAt);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: ListView(
              controller: scrollController,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspaces_rounded, color: Colors.teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Breakout Rooms (${session.breakoutRooms.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            session.isInBreakoutRoom
                                ? 'Currently in: ${session.activeBreakoutRoomName}'
                                : 'Currently in: Main Plenary Room',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (remaining.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: Text(remaining),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const Divider(height: 24),
                if (session.isInBreakoutRoom) ...[
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await gateway.returnToMainRoom();
                      widget.showMessage('Returned to Main Plenary Room');
                    },
                    icon: const Icon(Icons.keyboard_return_rounded),
                    label: const Text('Return to Main Plenary Room'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.isLeader) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _broadcastController,
                          decoration: const InputDecoration(
                            hintText: 'Broadcast announcement to all rooms...',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.campaign_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final msg = _broadcastController.text.trim();
                          if (msg.isEmpty) return;
                          _broadcastController.clear();
                          await gateway.broadcastToBreakoutRooms(msg);
                          widget.showMessage('Announcement broadcast to all breakout rooms.');
                          setState(() {});
                        },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                ...session.breakoutRooms.map((room) {
                  final isCurrent = session.activeBreakoutRoomId == room.id;
                  final isAssigned = room.assignedParticipantIds.contains(localId);
                  final canJoin = widget.isLeader || session.allowBreakoutSelfSelect || isAssigned;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCurrent
                            ? Colors.teal
                            : (isAssigned ? const Color(0xFFD49B28) : Colors.transparent),
                        width: isCurrent || isAssigned ? 1.5 : 0.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            room.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (isAssigned) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD49B28).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Assigned',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD49B28),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      room.assignedParticipantNames.isEmpty
                                          ? 'Open for participants to join'
                                          : 'Assigned (${room.assignedParticipantNames.length}): ${room.assignedParticipantNames.values.join(", ")}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isCurrent)
                                const Chip(
                                  label: Text('Joined'),
                                  visualDensity: VisualDensity.compact,
                                )
                              else if (canJoin)
                                FilledButton.tonal(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    await gateway.joinBreakoutRoom(room);
                                    widget.showMessage('Joined ${room.name}');
                                  },
                                  child: const Text('Join'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (widget.isLeader) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await gateway.closeBreakoutRooms();
                      widget.showMessage('Closed all breakout rooms and recalled participants.');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.meeting_room_rounded),
                    label: const Text('Close All Breakout Rooms'),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    // Host Creation View (when breakout rooms are not yet active)
    final remoteMembers = session.participants.where((p) => !p.isLocal).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspaces_rounded, color: Colors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Create Breakout Rooms',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Room count selector
              Row(
                children: [
                  const Text('Number of Rooms:'),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _roomCount,
                    items: List.generate(
                      7,
                      (i) => DropdownMenuItem(value: i + 2, child: Text('${i + 2} rooms')),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _roomCount = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Duration selector
              Row(
                children: [
                  const Text('Session Duration:'),
                  const SizedBox(width: 16),
                  DropdownButton<int?>(
                    value: _selectedDurationMins,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      DropdownMenuItem(value: 20, child: Text('20 minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes')),
                      DropdownMenuItem(value: 45, child: Text('45 minutes')),
                      DropdownMenuItem(value: 60, child: Text('60 minutes')),
                      DropdownMenuItem(value: null, child: Text('No timer (manual close)')),
                    ],
                    onChanged: (val) => setState(() => _selectedDurationMins = val),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow Participants to Choose Room'),
                subtitle: const Text('Attendees can switch freely between open breakout groups'),
                value: _allowSelfSelect,
                onChanged: (val) => setState(() => _allowSelfSelect = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatically Distribute Participants'),
                subtitle: const Text('Distribute attendees evenly into rooms upon launch'),
                value: _autoAssign,
                onChanged: (val) => setState(() => _autoAssign = val),
              ),
              const Divider(height: 24),
              Text(
                'Customize Room Names',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...List.generate(_roomCount, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _nameControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Room ${i + 1} Name',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }),
              if (!_autoAssign && remoteMembers.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Manual Participant Assignment',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...remoteMembers.map((member) {
                  final assignedIdx = _manualAssignments[member.identity] ?? 0;
                  return Row(
                    children: [
                      Expanded(child: Text(member.name)),
                      DropdownButton<int>(
                        value: assignedIdx < _roomCount ? assignedIdx : 0,
                        items: List.generate(
                          _roomCount,
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text('Room ${i + 1}'),
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _manualAssignments[member.identity] = val);
                          }
                        },
                      ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final rooms = <BreakoutRoom>[];
                  for (int i = 0; i < _roomCount; i++) {
                    final assignedIds = <String>[];
                    final assignedNames = <String, String>{};
                    if (_autoAssign) {
                      for (int j = 0; j < remoteMembers.length; j++) {
                        if (j % _roomCount == i) {
                          assignedIds.add(remoteMembers[j].identity);
                          assignedNames[remoteMembers[j].identity] = remoteMembers[j].name;
                        }
                      }
                    } else {
                      _manualAssignments.forEach((id, roomIdx) {
                        if (roomIdx == i) {
                          final mem = remoteMembers.firstWhere((p) => p.identity == id);
                          assignedIds.add(id);
                          assignedNames[id] = mem.name;
                        }
                      });
                    }

                    rooms.add(BreakoutRoom(
                      id: 'breakout_${i + 1}_${DateTime.now().millisecondsSinceEpoch}',
                      name: _nameControllers[i].text.trim().isNotEmpty
                          ? _nameControllers[i].text.trim()
                          : 'Room ${i + 1}',
                      assignedParticipantIds: assignedIds,
                      assignedParticipantNames: assignedNames,
                    ));
                  }

                  await gateway.startBreakoutRooms(
                    rooms: rooms,
                    durationMinutes: _selectedDurationMins,
                    allowSelfSelect: _allowSelfSelect,
                  );
                  widget.showMessage('Started ${_roomCount} breakout rooms.');
                },
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text('Open ${_roomCount} Breakout Rooms'),
              ),
            ],
          ),
        );
      },
    );
  }
}
