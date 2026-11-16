import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/appwrite_backend_config.dart';
import '../../config/meeting_links_config.dart';
import '../../constants/app_constants.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../services/role_access_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'livekit_meeting_screen.dart';

class _OngoingRoomInfo {
  final String roomName;
  final String displayName;
  final MeetingType meetingType;
  final int numParticipants;

  const _OngoingRoomInfo({
    required this.roomName,
    required this.displayName,
    required this.meetingType,
    required this.numParticipants,
  });
}

class ConferencePlatformScreen extends ConsumerStatefulWidget {
  const ConferencePlatformScreen({super.key});

  @override
  ConsumerState<ConferencePlatformScreen> createState() =>
      _ConferencePlatformScreenState();
}

class _RoomCandidate {
  final String roomName;
  final String displayName;
  final MeetingType meetingType;

  const _RoomCandidate({
    required this.roomName,
    required this.displayName,
    required this.meetingType,
  });
}

class _ConferencePlatformScreenState
    extends ConsumerState<ConferencePlatformScreen>
    with WidgetsBindingObserver {
  bool _isLoadingRooms = true;
  List<_OngoingRoomInfo> _ongoingRooms = const [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOngoingRooms();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchOngoingRooms(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchOngoingRooms(silent: true);
    }
  }

  MeetingType _parseMeetingType(String raw, String roomName) {
    switch (raw.toLowerCase()) {
      case 'board':
        return MeetingType.board;
      case 'leadership':
        return MeetingType.leadership;
      case 'prayer':
        return MeetingType.prayer;
      case 'quick':
        return MeetingType.quick;
      default:
        if (roomName == AliveMeetConfig.boardRoom ||
            roomName.startsWith('board-meeting-')) {
          return MeetingType.board;
        }
        if (roomName == AliveMeetConfig.leadershipRoom) {
          return MeetingType.leadership;
        }
        if (roomName == AliveMeetConfig.prayerRoom) {
          return MeetingType.prayer;
        }
        if (roomName == AliveMeetConfig.quickRoom) {
          return MeetingType.quick;
        }
        return MeetingType.general;
    }
  }

  String _friendlyRoomTitle(String roomName) {
    if (roomName == AliveMeetConfig.communityRoom) {
      return 'General Meeting Room';
    }
    if (roomName == AliveMeetConfig.prayerRoom) {
      return 'Prayer Room Meeting';
    }
    if (roomName == AliveMeetConfig.quickRoom) {
      return 'Quick Meeting Room';
    }
    if (roomName == AliveMeetConfig.leadershipRoom) {
      return 'Leadership Meeting';
    }
    if (roomName == AliveMeetConfig.boardRoom ||
        roomName.startsWith('board-meeting-')) {
      return 'Board of Directors Meeting';
    }
    return roomName
        .replaceFirst(RegExp(r'^alive-meet-'), '')
        .replaceAll(RegExp(r'[-_]+'), ' ');
  }

  Future<void> _fetchOngoingRooms({bool silent = false}) async {
    if (mounted && !silent) {
      setState(() => _isLoadingRooms = true);
    }

    final List<_OngoingRoomInfo> found = [];

    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? '';
      if (userId.isNotEmpty) {
        final functions = Functions(appwriteClient);
        final execution = await functions.createExecution(
          functionId: AppwriteBackendConfig.createLiveKitTokenFunctionId,
          body: jsonEncode({
            'action': 'listRooms',
            'identity': userId,
          }),
          xasync: false,
          method: appwrite_enums.ExecutionMethod.pOST,
        );

        final raw = execution.responseBody;
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded['rooms'] is List) {
            for (final item in decoded['rooms'] as List) {
              if (item is Map) {
                final rName = (item['roomName'] ?? '').toString().trim();
                if (rName.isEmpty) continue;
                final dName = (item['displayName'] ?? '').toString().trim();
                final mType = _parseMeetingType(
                  (item['meetingType'] ?? '').toString(),
                  rName,
                );
                final count =
                    int.tryParse('${item['numParticipants'] ?? 1}') ?? 1;
                found.add(
                  _OngoingRoomInfo(
                    roomName: rName,
                    displayName:
                        dName.isNotEmpty ? dName : _friendlyRoomTitle(rName),
                    meetingType: mType,
                    numParticipants: count,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    // Also include the locally connected session if not already in the list
    try {
      final localSession = ref.read(meetingGatewayProvider).currentSession;
      if (localSession.isConnected && localSession.roomName.isNotEmpty) {
        final rName = localSession.roomName;
        if (!found.any((r) => r.roomName == rName)) {
          found.insert(
            0,
            _OngoingRoomInfo(
              roomName: rName,
              displayName: _friendlyRoomTitle(rName),
              meetingType: _parseMeetingType('', rName),
              numParticipants: localSession.participants.isNotEmpty
                  ? localSession.participants.length
                  : 1,
            ),
          );
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _ongoingRooms = found;
        _isLoadingRooms = false;
      });
    }
  }

  Future<void> _openRoom(
    String roomName,
    MeetingType meetingType, {
    bool autoJoin = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveKitMeetingScreen(
          customRoomName: roomName,
          meetingType: meetingType,
          autoJoin: autoJoin,
        ),
      ),
    );
    if (mounted) {
      await _fetchOngoingRooms(silent: true);
    }
  }

  _RoomCandidate? _nextAvailableRoom() {
    final activeNames = _ongoingRooms.map((r) => r.roomName).toSet();
    final hasOngoingBoard = activeNames.any(
      (n) => n == AliveMeetConfig.boardRoom || n.startsWith('board-meeting-'),
    );
    final roleAccess = RoleAccessService.instance;
    final canLeader = roleAccess.canAccessLeadership();
    final canBoard = roleAccess.canAccessBoardDocuments();

    final candidates = <_RoomCandidate>[
      const _RoomCandidate(
        roomName: AliveMeetConfig.communityRoom,
        displayName: 'General Meeting Room',
        meetingType: MeetingType.general,
      ),
      const _RoomCandidate(
        roomName: AliveMeetConfig.prayerRoom,
        displayName: 'Prayer Room Meeting',
        meetingType: MeetingType.prayer,
      ),
      const _RoomCandidate(
        roomName: AliveMeetConfig.quickRoom,
        displayName: 'Quick Meeting Room',
        meetingType: MeetingType.quick,
      ),
      if (canLeader)
        const _RoomCandidate(
          roomName: AliveMeetConfig.leadershipRoom,
          displayName: 'Leadership Meeting Room',
          meetingType: MeetingType.leadership,
        ),
      if (canBoard)
        const _RoomCandidate(
          roomName: AliveMeetConfig.boardRoom,
          displayName: 'Board Meeting Room',
          meetingType: MeetingType.board,
        ),
    ];

    for (final c in candidates) {
      if (c.meetingType == MeetingType.board) {
        if (!hasOngoingBoard) return c;
      } else if (!activeNames.contains(c.roomName)) {
        return c;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final nextRoom = _nextAvailableRoom();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'ALIVE Meet',
        showBackButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOngoingRooms,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ongoing Meetings Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _ongoingRooms.isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : cs.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ongoing Meetings',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_isLoadingRooms)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Text(
                              '${_ongoingRooms.length} active',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_ongoingRooms.isEmpty && !_isLoadingRooms)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Text(
                            'No ongoing meetings right now. You can continue to the General Meeting Room below.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      else
                        ..._ongoingRooms.map((room) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.videocam_rounded,
                                      size: 20,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          room.displayName,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${room.numParticipants} ${room.numParticipants == 1 ? 'participant' : 'participants'} • ${room.roomName}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => _openRoom(
                                      room.roomName,
                                      room.meetingType,
                                      autoJoin: true,
                                    ),
                                    icon: const Icon(
                                      Icons.login_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Join'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // General Meeting Room Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.video_camera_front_rounded,
                              color: cs.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nextRoom?.displayName ?? 'Meeting Rooms Busy',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nextRoom != null
                                      ? (_ongoingRooms.isEmpty
                                          ? 'Connect with brethren, chapters, and fellowship rooms.'
                                          : 'Next available room selected automatically to avoid room collision.')
                                      : 'All available rooms are currently active. Join an ongoing meeting above or wait for a room to end.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.video_call_rounded),
                        label: Text(
                          nextRoom != null
                              ? 'Continue to ${nextRoom.displayName}'
                              : 'All Eligible Rooms Busy',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: nextRoom != null
                            ? () => _openRoom(
                                  nextRoom.roomName,
                                  nextRoom.meetingType,
                                )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: Icon(Icons.draw_rounded, color: cs.primary),
                        label: const Text(
                          'Open Scribe & Meeting Notes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: cs.outlineVariant),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          context.push(AppConstants.scribeRoute);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
