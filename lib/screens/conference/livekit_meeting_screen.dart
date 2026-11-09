import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/meeting_links_config.dart';
import '../../constants/chapters.dart';
import '../../models/chat_models.dart';
import '../../models/meeting_models.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../services/chat_service.dart';
import '../../services/platform/media_permission_adapter.dart';
import '../../services/ports/meeting_gateway.dart';
import '../../services/role_access_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/error_handler.dart';
import '../admin/leader_meeting_transcription_screen.dart';
import 'components/meeting_breakout_sheet.dart';
import 'components/meeting_chat_sheet.dart';
import 'components/meeting_participant_actions_sheet.dart';
import 'components/meeting_stage_view.dart';

class LiveKitMeetingScreen extends ConsumerStatefulWidget {
  final MeetingType? meetingType;
  final String? customRoomName;
  final bool isModerator;

  const LiveKitMeetingScreen({
    super.key,
    this.meetingType,
    this.customRoomName,
    this.isModerator = false,
  });

  @override
  ConsumerState<LiveKitMeetingScreen> createState() =>
      _LiveKitMeetingScreenState();
}

class _LiveKitMeetingScreenState extends ConsumerState<LiveKitMeetingScreen> {
  late final TextEditingController _roomController;
  final ChatService _chatService = ChatService();
  List<ChatChannel> _availableChannels = [];
  bool _isLoadingChannels = false;
  bool _isJoining = false;
  bool _isBroadcasting = false;
  bool _notifyMembers = true;
  String _targetAudience = 'general';
  String _selectedTargetChapter = 'Ibadan';
  bool _requireHostApproval = false;
  bool _isLocalHost = false;
  bool _isLocalCoHost = false;
  bool _isLocalScreenSharePermitted = false;
  bool _isProjectorMode = false;
  String? _activeEgressId;
  StreamSubscription<String>? _moderationSub;
  StreamSubscription<Map<String, dynamic>>? _dataChannelSub;
  Timer? _breakoutUiTicker;

  // In-Meeting Real-time Chat
  final List<InMeetingChatMessage> _inMeetingChatMessages = [];
  int _unreadChatCount = 0;
  bool _isChatSheetOpen = false;
  bool _isChatLockedByHost = false;
  final TextEditingController _inMeetingChatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: _initialRoomName());
    _loadAvailableChannels();
    // Auto-prompt media permissions upfront (Google Meet flow)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MediaPermissionService.requestMediaPermissions();
    });

    _breakoutUiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = ref.read(meetingGatewayProvider).currentSession;
      if (session.isBreakoutActive && session.breakoutEndsAt != null) {
        setState(() {});
      }
    });

    final gateway = ref.read(meetingGatewayProvider);

    _dataChannelSub = gateway.dataChannelMessagesStream.listen((data) {
      if (!mounted) return;
      if (data['action'] == 'in_meeting_chat') {
        final msg = InMeetingChatMessage.fromJson(data, isLocal: false);
        setState(() {
          _inMeetingChatMessages.add(msg);
          if (!_isChatSheetOpen) {
            _unreadChatCount++;
          }
        });
        _scrollChatToBottom();
      } else if (data['action'] == 'in_meeting_chat_lock') {
        final isLocked = data['isLocked'] == true;
        setState(() {
          _isChatLockedByHost = isLocked;
        });
        _showMessage(isLocked
            ? 'Meeting chat has been locked by the host.'
            : 'Meeting chat has been unlocked by the host.');
      } else if (data['action'] == 'in_meeting_chat_clear') {
        setState(() {
          _inMeetingChatMessages.clear();
          _unreadChatCount = 0;
        });
        _showMessage('Meeting chat transcript cleared by host.');
      }
    });
    _moderationSub = gateway.moderationPromptsStream.listen((event) {
      if (!mounted) return;
      if (event == 'ask_unmute') {
        _showUnmuteRequestDialog(gateway);
      } else if (event == 'ask_video') {
        _showVideoRequestDialog(gateway);
      } else if (event == 'muted_by_host') {
        _showMessage('The host has muted your microphone.');
      } else if (event == 'video_stopped_by_host') {
        _showMessage('The host has stopped your video.');
      } else if (event == 'granted_host') {
        setState(() {
          _isLocalHost = true;
          _isLocalCoHost = false;
        });
        _showMessage('You are now the Host of this meeting.');
      } else if (event == 'transferred_host') {
        setState(() {
          _isLocalHost = false;
          _isLocalCoHost = true;
        });
        _showMessage('Host role transferred. You are now a Co-Host.');
      } else if (event == 'granted_cohost') {
        setState(() => _isLocalCoHost = true);
        _showMessage('You are now a co-host of this meeting.');
      } else if (event == 'revoked_cohost') {
        setState(() => _isLocalCoHost = false);
        _showMessage('Your co-host permissions were revoked by the host.');
      } else if (event == 'granted_screenshare') {
        setState(() => _isLocalScreenSharePermitted = true);
        _showMessage('The host has granted you permission to share your screen.');
      } else if (event == 'revoked_screenshare') {
        setState(() => _isLocalScreenSharePermitted = false);
        _showMessage('The host has revoked your screen share permission.');
      } else if (event == 'removed_by_host') {
        setState(() {
          _isLocalCoHost = false;
          _isLocalScreenSharePermitted = false;
          _isProjectorMode = false;
        });
        _showMessage('You have been removed from the meeting by the host.');
      } else if (event == 'ended_by_host') {
        setState(() {
          _isLocalCoHost = false;
          _isLocalScreenSharePermitted = false;
          _isProjectorMode = false;
        });
        _showMessage('The meeting has been ended for all by the host.');
      } else if (event == 'admitted_by_host') {
        _showMessage('You have been admitted to the meeting room.');
      } else if (event == 'declined_by_host') {
        _showDeclinedDialog();
      } else if (event == 'breakout_started') {
        _showMessage('Breakout rooms are now open! Tap "Breakout Rooms" to join.');
      } else if (event.startsWith('breakout_assigned:')) {
        final raw = event.substring('breakout_assigned:'.length);
        final parts = raw.split('|');
        final roomId = parts.isNotEmpty ? parts[0] : '';
        final roomName = parts.length > 1 ? parts[1] : 'Breakout Room';
        _showBreakoutAssignmentDialog(gateway, roomId, roomName);
      } else if (event == 'breakout_closed') {
        _showMessage('Breakout rooms closed by host. Returning to Main Room...');
      } else if (event.startsWith('breakout_broadcast:')) {
        final msg = event.substring('breakout_broadcast:'.length);
        _showMessage('Host Announcement: $msg');
      } else if (event.startsWith('breakout_help:')) {
        final raw = event.substring('breakout_help:'.length);
        final parts = raw.split('|');
        final roomId = parts.isNotEmpty ? parts[0] : '';
        final roomName = parts.length > 1 ? parts[1] : 'Breakout Room';
        final requester = parts.length > 2 ? parts[2] : 'Participant';
        _showBreakoutHelpRequestDialog(gateway, roomId, roomName, requester);
      }
    });
  }

  String _initialRoomName() {
    if (widget.customRoomName != null) return widget.customRoomName!;
    if (widget.meetingType != null) {
      return widget.meetingType!.displayName;
    }
    return 'ALIVE Meeting';
  }

  String _getRoomSlug() {
    if (widget.meetingType != null) {
      return AliveMeetConfig.roomFor(widget.meetingType!);
    }
    final text = _roomController.text.trim();
    if (text.isEmpty) return 'alive-meet';
    return text.replaceAll(' ', '-').toLowerCase();
  }

  Future<void> _joinMeeting(MeetingGateway gateway) async {
    final roomName = _roomController.text.trim();
    if (roomName.isEmpty) {
      _showMessage('Enter a room name before joining.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showMessage('Please sign in before joining a meeting.');
      return;
    }

    // Google Meet flow: Auto-prompt microphone & camera upfront
    await MediaPermissionService.requestMediaPermissions();

    setState(() => _isJoining = true);
    try {
      final isAdmin = RoleAccessService.instance.canAccessAdmin() || widget.isModerator;
      final roomSlug = _getRoomSlug();
      final roomTitle = widget.meetingType?.displayName ?? roomName;

      final currentAvatar = ref.read(currentUserAvatarUrlProvider);

      await gateway.executionAndJoin(
        roomName: roomSlug,
        userId: user.uid,
        userName: user.displayNameOrFallback,
        meetingType: widget.meetingType?.name ?? 'general',
        notifyMembers: isAdmin && _notifyMembers,
        meetingTitle: roomTitle,
        targetAudience: _targetAudience,
        targetChapter: _targetAudience == 'chapter' ? _selectedTargetChapter : null,
        isWaitingRoomEnabled: _requireHostApproval,
        avatarUrl: currentAvatar,
      );

      // User gesture: Unlock audio playback & speaker routing immediately on entry
      try {
        await gateway.unlockAudio();
      } catch (_) {}
    } catch (e) {
      final errStr = e.toString();
      debugPrint('[LiveKitMeetingScreen] Join error: $e');

      // Extract user-friendly error message
      String errorMessage =
          'ALIVE Meet could not be joined. Please check your connection and try again.';
      if (errStr.contains('certificate') ||
          errStr.contains('SSL') ||
          errStr.contains('TLS')) {
        errorMessage =
            'SSL certificate error. The LiveKit server certificate may be self-signed or expired.';
      } else if (errStr.contains('timeout')) {
        errorMessage =
            'Connection timed out. Please check your internet connection.';
      } else if (errStr.contains('Token not found')) {
        errorMessage =
            'Failed to generate meeting token. Please try again later.';
      } else if (errStr.contains('No element') ||
          errStr.contains('Bad state')) {
        errorMessage =
            'ALIVE Meet connection interrupted. Please check your network and try again.';
      } else if (errStr.contains('permission') ||
          errStr.contains('NotAllowedError') ||
          errStr.contains('device') ||
          errStr.contains('NotFound') ||
          errStr.contains('not detected')) {
        errorMessage =
            'Microphone or camera not detected. Joining in listen-only mode.';
      } else if (e is Exception) {
        final cleanMsg = errStr.replaceAll('Exception: ', '').trim();
        if (cleanMsg.isNotEmpty && cleanMsg.length < 120) {
          errorMessage = cleanMsg;
        }
      }
      _showMessage(errorMessage);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showDeclinedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Admission Declined'),
          ],
        ),
        content: const Text(
          'The meeting host did not admit you to this meeting session. If you believe this is a mistake, please reach out to your leader or coordinator.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).maybePop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadAvailableChannels() async {
    try {
      if (mounted) setState(() => _isLoadingChannels = true);
      final channels = await _chatService.getActiveChannels();
      if (mounted) {
        setState(() {
          _availableChannels = channels;
          _isLoadingChannels = false;
        });
      }
    } catch (e) {
      debugPrint('Load channels for meeting notification note: $e');
      if (mounted) setState(() => _isLoadingChannels = false);
    }
  }

  void _shareMeetingLink() {
    final roomSlug = _getRoomSlug();
    final roomTitle = widget.meetingType?.displayName ?? _roomController.text.trim();
    final meetingUrl = 'https://app.alivenigeria.org/meet?room=${Uri.encodeComponent(roomSlug)}';
    final shareText =
        'You are invited to join the ALIVE meeting: "$roomTitle"\n\nJoin directly here:\n$meetingUrl';

    Clipboard.setData(ClipboardData(text: meetingUrl));
    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'ALIVE Meeting Invitation: $roomTitle',
      ),
    );
    _showMessage('Meeting invitation link copied to clipboard!');
  }

  void _sendInMeetingChatMessage(MeetingGateway gateway) {
    if (_isChatLockedByHost) {
      final isLeader = RoleAccessService.instance.canStartConferencing() ||
          widget.isModerator ||
          _isLocalHost ||
          _isLocalCoHost;
      if (!isLeader) {
        _showMessage('Meeting chat is locked by the host.');
        return;
      }
    }

    final text = _inMeetingChatController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final avatar = ref.read(currentUserAvatarUrlProvider);
    final senderId = user?.uid ?? 'anonymous';
    final senderName = user?.displayNameOrFallback ?? 'Attendee';
    final now = DateTime.now();
    final messageId = 'msg_${now.millisecondsSinceEpoch}_${UniqueKey().toString()}';

    final packet = {
      'action': 'in_meeting_chat',
      'id': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': avatar,
      'text': text,
      'timestamp': now.toIso8601String(),
    };

    gateway.sendDataChannelMessage(packet);

    setState(() {
      _inMeetingChatMessages.add(InMeetingChatMessage(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: avatar,
        text: text,
        timestamp: now,
        isLocal: true,
      ));
    });

    _inMeetingChatController.clear();
    _scrollChatToBottom();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showInMeetingChatSheet(BuildContext context, MeetingGateway gateway) {
    setState(() {
      _isChatSheetOpen = true;
      _unreadChatCount = 0;
    });

    final user = ref.read(currentUserProvider);
    final isLeader = RoleAccessService.instance.canStartConferencing() ||
        widget.isModerator ||
        _isLocalHost ||
        _isLocalCoHost;

    MeetingChatSheet.show(
      context: context,
      gateway: gateway,
      messages: _inMeetingChatMessages,
      chatController: _inMeetingChatController,
      scrollController: _chatScrollController,
      isChatLockedByHost: _isChatLockedByHost,
      isLeader: isLeader,
      currentUserId: user?.uid ?? '',
      onToggleLock: (newLock) {
        gateway.sendDataChannelMessage({
          'action': 'in_meeting_chat_lock',
          'isLocked': newLock,
        });
        setState(() => _isChatLockedByHost = newLock);
        _showMessage(newLock ? 'Chat locked for participants' : 'Chat unlocked');
      },
      onClearChat: () {
        gateway.sendDataChannelMessage({
          'action': 'in_meeting_chat_clear',
        });
        setState(() {
          _inMeetingChatMessages.clear();
          _unreadChatCount = 0;
        });
        _showMessage('Chat transcript cleared');
      },
      onSendMessage: () => _sendInMeetingChatMessage(gateway),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isChatSheetOpen = false);
      }
    });
  }

  List<DropdownMenuItem<String>> _buildTargetAudienceItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: 'general',
        child: Text('General (All Members)'),
      ),
      const DropdownMenuItem(
        value: 'chapter',
        child: Text('Selected Chapter Members Only'),
      ),
      const DropdownMenuItem(
        value: 'singles',
        child: Text('Singles Fellowship Platform Only'),
      ),
      const DropdownMenuItem(
        value: 'married',
        child: Text('Couples & Married Fellowship Only'),
      ),
      const DropdownMenuItem(
        value: 'bod_only',
        child: Text('Board of Directors (BOD) Only'),
      ),
      const DropdownMenuItem(
        value: 'board',
        child: Text('Board of Directors (BOD) & Trustees'),
      ),
      const DropdownMenuItem(
        value: 'directors',
        child: Text('Directors Only'),
      ),
      const DropdownMenuItem(
        value: 'leadership',
        child: Text('Coordinators & Leaders Only'),
      ),
    ];

    // Auto-add dynamic custom & newly created channels
    final customChannels = _availableChannels.where((c) {
      if (c.type == ChannelType.direct) return false;
      if (c.id == 'channel_general' ||
          c.id == 'channel_singles' ||
          c.id == 'channel_married' ||
          c.id == 'channel_bod') {
        return false;
      }
      return true;
    }).toList();

    for (final ch in customChannels) {
      if (!items.any((it) => it.value == ch.id)) {
        items.add(
          DropdownMenuItem<String>(
            value: ch.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag_rounded, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Channel: ${ch.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    }

    return items;
  }

  String _formatBreakoutRemaining(DateTime? endsAt) {
    if (endsAt == null) return '';
    final diff = endsAt.difference(DateTime.now().toUtc());
    if (diff.isNegative || diff.inSeconds <= 0) return '00:00';
    final mins = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (diff.inHours > 0) {
      return '${diff.inHours}:$mins:$secs';
    }
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final gateway = ref.watch(meetingGatewayProvider);
    final sessionAsync = ref.watch(meetingSessionStreamProvider);
    final MeetingSession session =
        sessionAsync.value ?? gateway.currentSession;
    final connected = session.isConnected;
    final isAudioMuted = session.isAudioMuted;
    final isVideoMuted = session.isVideoMuted;

    final isLeader = RoleAccessService.instance.canStartConferencing() ||
        widget.isModerator ||
        _isLocalHost ||
        _isLocalCoHost;
    final canShareScreen = isLeader ||
        _isLocalCoHost ||
        _isLocalScreenSharePermitted ||
        session.isScreenSharePermitted;

    if (connected && _isProjectorMode) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await _handleHostExit(gateway);
          if (shouldPop && context.mounted) {
            Navigator.of(context).maybePop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildProjectorView(context, session, gateway, isLeader, canShareScreen),
        ),
      );
    }

    return PopScope(
      canPop: !connected,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleHostExit(gateway);
        if (shouldPop && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: session.isInBreakoutRoom
              ? (session.activeBreakoutRoomName ?? 'Breakout Room')
              : (widget.meetingType?.displayName ?? 'ALIVE Meet'),
          showBackButton: true,
          showDonationButton: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share Meeting Link',
              onPressed: _shareMeetingLink,
            ),
            if (connected) ...[
              IconButton(
                icon: Badge(
                  isLabelVisible: _unreadChatCount > 0,
                  label: Text('$_unreadChatCount'),
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                tooltip: 'In-Meeting Chat',
                onPressed: () => _showInMeetingChatSheet(context, gateway),
              ),
            ],
            if (connected && (isLeader || session.isBreakoutActive)) ...[
              IconButton(
                icon: Badge(
                  isLabelVisible: session.isBreakoutActive,
                  label: Text('${session.breakoutRooms.length}'),
                  child: const Icon(Icons.workspaces_rounded),
                ),
                tooltip: 'Breakout Rooms',
                onPressed: () =>
                    _showBreakoutRoomsSheet(context, session, gateway, isLeader),
              ),
            ],
            if (connected) ...[
              IconButton(
                icon: const Icon(Icons.tv_rounded),
                tooltip: 'Projector / Stage Display',
                onPressed: () => setState(() => _isProjectorMode = true),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.note_alt_outlined),
              tooltip: 'Scribe & Notes',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeaderMeetingTranscriptionScreen(
                      initialMeetingTitle:
                          widget.meetingType?.displayName ?? _roomController.text,
                      initialRoomName: _roomController.text.trim(),
                      initialMeetingType: widget.meetingType?.displayName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: 'Meeting Room',
                  border: const OutlineInputBorder(),
                  helperText: !isLeader
                      ? 'Members can join designated rooms. Starting new rooms is reserved for leaders.'
                      : null,
                ),
                readOnly: !isLeader,
              ),
              if (isLeader && !connected) ...[
                const SizedBox(height: 8),
                // Waiting Room Policy toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.meeting_room_outlined),
                  title: const Text('Require Host Approval (Waiting Room)'),
                  subtitle: const Text('Participants wait in virtual lobby until admitted by host/leader'),
                  value: _requireHostApproval,
                  onChanged: (val) => setState(() => _requireHostApproval = val),
                ),
                const SizedBox(height: 4),
                // Targeted Push Notification toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notify members via push notification'),
                  subtitle: const Text('Sends a background push notification when meeting starts'),
                  value: _notifyMembers,
                  onChanged: (val) => setState(() => _notifyMembers = val),
                ),
                if (_notifyMembers) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final audienceItems = _buildTargetAudienceItems();
                      final effectiveAudience =
                          audienceItems.any((i) => i.value == _targetAudience)
                              ? _targetAudience
                              : 'general';

                      return DropdownButtonFormField<String>(
                        value: effectiveAudience,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Notification Target Audience',
                          prefixIcon: const Icon(Icons.group_outlined),
                          suffixIcon: IconButton(
                            icon: _isLoadingChannels
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            tooltip: 'Refresh Channels',
                            onPressed: _isLoadingChannels
                                ? null
                                : _loadAvailableChannels,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: audienceItems,
                        onChanged: (val) {
                          if (val != null) setState(() => _targetAudience = val);
                        },
                      );
                    },
                  ),
                  if (_targetAudience == 'chapter') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedTargetChapter,
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
                        if (val != null) setState(() => _selectedTargetChapter = val);
                      },
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isJoining || connected
                    ? null
                    : () => _joinMeeting(gateway),
                icon: _isJoining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_call),
                label: Text(_isJoining
                    ? 'Joining...'
                    : connected
                        ? (session.isInBreakoutRoom
                            ? 'Connected • ${session.activeBreakoutRoomName}'
                            : 'Connected')
                        : (isLeader ? 'Start / Join ALIVE Meet' : 'Join ALIVE Meet')),
              ),
              // Connection status banner
              if (session.status == RoomStatus.connecting ||
                  session.status == RoomStatus.reconnecting) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session.status == RoomStatus.reconnecting
                              ? 'Reconnecting to meeting...'
                              : 'Connecting to meeting...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Notice / Error banner
              if (session.error != null && !connected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: session.error!.toLowerCase().contains('listen-only') ||
                            session.error!.toLowerCase().contains('device not detected')
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: session.error!.toLowerCase().contains('listen-only') ||
                              session.error!.toLowerCase().contains('device not detected')
                          ? Colors.amber.shade700.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        session.error!.toLowerCase().contains('listen-only') ||
                                session.error!.toLowerCase().contains('device not detected')
                            ? Icons.info_outline_rounded
                            : Icons.error_outline,
                        color: session.error!.toLowerCase().contains('listen-only') ||
                                session.error!.toLowerCase().contains('device not detected')
                            ? Colors.amber.shade800
                            : Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          session.error!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: session.error!.toLowerCase().contains('listen-only') ||
                                            session.error!.toLowerCase().contains('device not detected')
                                        ? (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.amber.shade200
                                            : Colors.amber.shade900)
                                        : Theme.of(context).colorScheme.error,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (connected && !session.isAdmitted && session.isWaitingRoomEnabled && !isLeader) ...[
                // Gated Waiting Room UI for unadmitted participants
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD49B28).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD49B28).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            size: 48,
                            color: Color(0xFFD49B28),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Waiting for Host Approval',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The meeting leader has been notified that you are in the lobby. You will be admitted automatically once approved.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: gateway.leaveMeeting,
                          icon: const Icon(Icons.call_end),
                          label: const Text('Leave Waiting Room'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (connected) ...[
                // Active Breakout Room Status Banner
                if (session.isBreakoutActive || session.isInBreakoutRoom)
                  _buildBreakoutBanner(context, session, gateway, isLeader),

                // Host Waiting Room Admission Requests Banner
                if (isLeader && session.waitingKnocks.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.door_sliding_outlined, size: 20, color: Color(0xFFD49B28)),
                            const SizedBox(width: 8),
                            Text(
                              'Waiting Room (${session.waitingKnocks.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                for (final knock in List<Map<String, String>>.from(session.waitingKnocks)) {
                                  final id = knock['id'];
                                  if (id != null) gateway.admitParticipant(id);
                                }
                              },
                              child: const Text('Admit All'),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        ...session.waitingKnocks.map((knock) {
                          final kId = knock['id'] ?? '';
                          final kName = knock['name'] ?? 'Participant';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(
                                    kName.isNotEmpty ? kName.substring(0, 1).toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    kName,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () => gateway.admitParticipant(kId),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.green.shade700,
                                  ),
                                  child: const Text('Admit'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => gateway.declineParticipant(kId),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                // Audio Lock notice banner
                if (session.isRoomAudioLocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isLeader
                                ? 'Room Audio Locked: Standard participants cannot unmute themselves.'
                                : 'Microphones are locked by the host. Raise your hand to request to speak.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        if (!isLeader && session.isRoomAudioLocked && isAudioMuted) {
                          _showMessage('The host has locked microphones. Raise your hand to ask to speak.');
                          return;
                        }
                        try {
                          await gateway.toggleAudio();
                        } catch (e) {
                          _showMessage(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                      icon: Icon(isAudioMuted ? Icons.mic_off : Icons.mic),
                      label: Text(
                        !isLeader && session.isRoomAudioLocked && isAudioMuted
                            ? 'Muted (Locked)'
                            : (isAudioMuted ? 'Unmute' : 'Mute'),
                      ),
                      style: !isLeader && session.isRoomAudioLocked && isAudioMuted
                          ? FilledButton.styleFrom(
                              backgroundColor: Colors.grey.shade700,
                            )
                          : null,
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await gateway.toggleVideo();
                        } catch (e) {
                          _showMessage(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                      icon: Icon(isVideoMuted ? Icons.videocam_off : Icons.videocam),
                      label: Text(isVideoMuted ? 'Camera On' : 'Camera Off'),
                    ),
                    // Screen Share button for Host and Co-Host
                    if (canShareScreen)
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await gateway.toggleScreenShare();
                            _showMessage(session.isScreenShareEnabled
                                ? 'Screen sharing stopped.'
                                : 'Screen sharing started.');
                          } catch (e) {
                            _showMessage(ErrorHandler.getUserFriendlyMessage(e));
                          }
                        },
                        icon: Icon(session.isScreenShareEnabled
                            ? Icons.stop_screen_share_rounded
                            : Icons.screen_share_rounded),
                        label: Text(session.isScreenShareEnabled
                            ? 'Stop Screen'
                            : 'Share Screen'),
                        style: session.isScreenShareEnabled
                            ? FilledButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                              )
                            : null,
                      ),
                    // Breakout Rooms button
                    if (isLeader || session.isBreakoutActive)
                      FilledButton.tonalIcon(
                        onPressed: () => _showBreakoutRoomsSheet(
                          context,
                          session,
                          gateway,
                          isLeader,
                        ),
                        icon: const Icon(Icons.workspaces_rounded),
                        label: Text(
                          session.isBreakoutActive
                              ? 'Breakout Rooms (${session.breakoutRooms.length})'
                              : 'Breakout Rooms',
                        ),
                      ),
                    if (session.isInBreakoutRoom)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await gateway.returnToMainRoom();
                          _showMessage('Returned to Main Plenary Room');
                        },
                        icon: const Icon(Icons.keyboard_return_rounded),
                        label: const Text('Main Room'),
                      ),
                    // In-Meeting Chat button
                    FilledButton.tonalIcon(
                      onPressed: () => _showInMeetingChatSheet(context, gateway),
                      icon: Badge(
                        isLabelVisible: _unreadChatCount > 0,
                        label: Text('$_unreadChatCount'),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      label: Text(_unreadChatCount > 0 ? 'Chat ($_unreadChatCount)' : 'Chat'),
                    ),
                    // Share Meeting Link button
                    OutlinedButton.icon(
                      onPressed: _shareMeetingLink,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Link'),
                    ),
                    // Projector / Display View button
                    FilledButton.tonalIcon(
                      onPressed: () => setState(() => _isProjectorMode = true),
                      icon: const Icon(Icons.tv_rounded),
                      label: const Text('Projector Display'),
                    ),
                    // Raise Hand button for all attendees
                    OutlinedButton.icon(
                      onPressed: () async {
                        final newRaised = !session.isHandRaised;
                        await gateway.raiseHand(raised: newRaised);
                        _showMessage(newRaised ? 'Hand raised' : 'Hand lowered');
                      },
                      icon: Icon(
                        session.isHandRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
                        color: session.isHandRaised ? const Color(0xFFD49B28) : null,
                      ),
                      label: Text(session.isHandRaised ? 'Lower Hand' : 'Raise Hand'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _handleHostExit(gateway),
                      icon: const Icon(Icons.call_end),
                      label: const Text('Leave'),
                    ),
                    // End Meeting for All button (leaders/hosts only)
                    if (isLeader)
                      FilledButton.icon(
                        onPressed: () => _confirmEndMeetingForAll(gateway),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('End Meeting for All'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    // Go Live button — streams to YouTube via LiveKit egress
                    if (isLeader)
                      FilledButton.icon(
                        onPressed: _isBroadcasting
                            ? () => _stopBroadcast(gateway)
                            : () => _startBroadcast(gateway),
                        icon: Icon(_isBroadcasting ? Icons.stop : Icons.live_tv),
                        label: Text(_isBroadcasting ? 'Stop Live' : 'Go Live'),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _isBroadcasting ? Colors.red : null,
                        ),
                      ),
                  ],
                ),

                // Host / Moderator Controls Area
                if (isLeader) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1B2432)
                          : const Color(0xFFF3EBE0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD49B28).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFFD49B28)),
                            SizedBox(width: 6),
                            Text(
                              'Host Moderation Controls',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD49B28),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            // "Mute All" button
                            ElevatedButton.icon(
                              onPressed: () async {
                                await gateway.muteAll();
                                _showMessage('Broadcast command sent: All participants muted.');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade800,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.volume_off_rounded, size: 16),
                              label: const Text('Mute All'),
                            ),
                            // Hard Lockout toggle ("Disallow Participants to Unmute")
                            OutlinedButton.icon(
                              onPressed: () async {
                                final newLock = !session.isRoomAudioLocked;
                                await gateway.setRoomAudioLock(newLock);
                                _showMessage(newLock
                                    ? 'Host Hard Lockout activated: Participants cannot unmute.'
                                    : 'Host Hard Lockout released: Participants can now unmute.');
                              },
                              icon: Icon(
                                session.isRoomAudioLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                size: 16,
                              ),
                              label: Text(session.isRoomAudioLocked ? 'Unlock Mics' : 'Lock Mics'),
                            ),
                            // Waiting Room / Gated meeting toggle
                            OutlinedButton.icon(
                              onPressed: () async {
                                final newWaiting = !session.isWaitingRoomEnabled;
                                await gateway.setWaitingRoom(newWaiting);
                                _showMessage(newWaiting
                                    ? 'Waiting Room activated: New participants must be admitted.'
                                    : 'Waiting Room disabled: Participants can now join directly.');
                              },
                              icon: Icon(
                                session.isWaitingRoomEnabled ? Icons.door_sliding : Icons.meeting_room_outlined,
                                size: 16,
                              ),
                              label: Text(session.isWaitingRoomEnabled ? 'Waiting Room: ON' : 'Waiting Room: OFF'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: session.isWaitingRoomEnabled ? const Color(0xFFD49B28) : null,
                              ),
                            ),
                            // Breakout Rooms Manager button in Host Controls
                            OutlinedButton.icon(
                              onPressed: () => _showBreakoutRoomsSheet(
                                context,
                                session,
                                gateway,
                                isLeader,
                              ),
                              icon: const Icon(Icons.workspaces_rounded, size: 16),
                              label: Text(
                                session.isBreakoutActive
                                    ? 'Manage Breakout Rooms (${session.breakoutRooms.length})'
                                    : 'Create Breakout Rooms',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: session.isBreakoutActive
                                    ? Colors.teal
                                    : const Color(0xFFD49B28),
                              ),
                            ),
                            // End Meeting for All in Host Controls
                            ElevatedButton.icon(
                              onPressed: () => _confirmEndMeetingForAll(gateway),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade900,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                              label: const Text('End Meeting for All'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                if (session.participants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    session.isInBreakoutRoom
                        ? '${session.activeBreakoutRoomName} Participants (${session.participants.length}):'
                        : 'Participants (${session.participants.length}):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: session.participants.length,
                      itemBuilder: (context, index) {
                        final participant = session.participants[index];
                        final displayName = _formatParticipantName(participant);
                        return ListTile(
                          onTap: () => _showParticipantActions(
                            context,
                            participant,
                            gateway,
                            isLeader,
                          ),
                          leading: CircleAvatar(
                            backgroundImage: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                                ? NetworkImage(participant.avatarUrl!)
                                : null,
                            child: (participant.avatarUrl != null && participant.avatarUrl!.isNotEmpty)
                                ? null
                                : Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'M',
                                  ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  participant.isLocal
                                      ? '$displayName (You)'
                                      : displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (gateway.isParticipantHost(participant.identity)) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD49B28).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD49B28), width: 0.8),
                                  ),
                                  child: const Text(
                                    'HOST',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD49B28),
                                    ),
                                  ),
                                ),
                              ] else if (gateway.isParticipantCoHost(participant.identity)) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.teal, width: 0.8),
                                  ),
                                  child: const Text(
                                    'CO-HOST',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            isLeader
                                ? 'Tap to manage (mute, video, host, co-host)'
                                : (participant.isLocal ? 'Tap for your audio/video controls' : ''),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (participant.isHandRaised) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD49B28).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFD49B28), width: 1),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.pan_tool_rounded, size: 13, color: Color(0xFFD49B28)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Hand Raised',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD49B28)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Icon(
                                participant.isAudioMuted
                                    ? Icons.mic_off
                                    : Icons.mic,
                                size: 18,
                                color: participant.isAudioMuted
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                participant.isVideoMuted
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                size: 18,
                                color: participant.isVideoMuted
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakoutBanner(
    BuildContext context,
    MeetingSession session,
    MeetingGateway gateway,
    bool isLeader,
  ) {
    final remaining = _formatBreakoutRemaining(session.breakoutEndsAt);
    final inSubRoom = session.isInBreakoutRoom;
    final broadcastMsg = session.breakoutBroadcastMessage;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade600.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspaces_rounded,
                size: 18,
                color: Colors.teal.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inSubRoom
                      ? 'Breakout Room: ${session.activeBreakoutRoomName}'
                      : 'Breakout Sessions Active (${session.breakoutRooms.length} Rooms)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (remaining.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        remaining,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (broadcastMsg != null && broadcastMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD49B28).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, size: 16, color: Color(0xFFD49B28)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Host Broadcast: $broadcastMsg',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    _showBreakoutRoomsSheet(context, session, gateway, isLeader),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(inSubRoom ? 'Switch / View Rooms' : 'View / Join Rooms'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (inSubRoom && !isLeader)
                OutlinedButton.icon(
                  onPressed: () async {
                    await gateway.requestHostHelpInBreakout();
                    _showMessage('Host has been invited to assist your room.');
                  },
                  icon: const Icon(Icons.support_agent_rounded, size: 16),
                  label: const Text('Ask Host for Help'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (inSubRoom)
                OutlinedButton.icon(
                  onPressed: () async {
                    await gateway.returnToMainRoom();
                    _showMessage('Returned to Main Room');
                  },
                  icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                  label: const Text('Return to Main Room'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBreakoutAssignmentDialog(
    MeetingGateway gateway,
    String roomId,
    String roomName,
  ) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspaces_rounded, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Breakout Room Assigned')),
          ],
        ),
        content: Text(
          'The host has assigned you to "$roomName". Would you like to join your breakout group now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final room = gateway.currentSession.breakoutRooms.firstWhere(
                (r) => r.id == roomId,
                orElse: () => BreakoutRoom(id: roomId, name: roomName),
              );
              await gateway.joinBreakoutRoom(room);
            },
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Join Room'),
          ),
        ],
      ),
    );
  }

  void _showBreakoutHelpRequestDialog(
    MeetingGateway gateway,
    String roomId,
    String roomName,
    String requester,
  ) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: Color(0xFFD49B28)),
            SizedBox(width: 8),
            Expanded(child: Text('Breakout Help Requested')),
          ],
        ),
        content: Text(
          '$requester in "$roomName" is requesting the host to join their breakout room.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          if (roomId.isNotEmpty)
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final room = gateway.currentSession.breakoutRooms.firstWhere(
                  (r) => r.id == roomId,
                  orElse: () => BreakoutRoom(id: roomId, name: roomName),
                );
                await gateway.joinBreakoutRoom(room);
              },
              icon: const Icon(Icons.login_rounded, size: 18),
              label: Text('Join $roomName'),
            ),
        ],
      ),
    );
  }

  void _showBreakoutRoomsSheet(
    BuildContext context,
    MeetingSession initialSession,
    MeetingGateway gateway,
    bool isLeader,
  ) {
    final localId = initialSession.localParticipant?.identity ??
        ref.read(currentUserProvider)?.uid ??
        '';

    MeetingBreakoutSheet.show(
      context: context,
      gateway: gateway,
      isLeader: isLeader,
      currentUserId: localId,
      showMessage: _showMessage,
    );
  }

  void _showParticipantActions(
    BuildContext context,
    ParticipantInfo participant,
    MeetingGateway gateway,
    bool isLeaderOrHost,
  ) {
    MeetingParticipantActionsSheet.show(
      context: context,
      participant: participant,
      gateway: gateway,
      isLeaderOrHost: isLeaderOrHost,
      showMessage: _showMessage,
    );
  }

  void _showUnmuteRequestDialog(MeetingGateway gateway) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.green),
            SizedBox(width: 8),
            Text('The Host Asked You to Speak'),
          ],
        ),
        content: const Text('The host has invited you to unmute your microphone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay Muted'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await gateway.toggleAudio();
              } catch (e) {
                _showMessage(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Unmute Microphone'),
          ),
        ],
      ),
    );
  }

  void _showVideoRequestDialog(MeetingGateway gateway) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.videocam, color: Colors.green),
            SizedBox(width: 8),
            Text('The Host Asked You to Start Video'),
          ],
        ),
        content: const Text('The host has requested that you turn on your camera.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Camera Off'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await gateway.toggleVideo();
              } catch (e) {
                _showMessage(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Start Video'),
          ),
        ],
      ),
    );
  }

  String _formatParticipantName(ParticipantInfo p) {
    final raw = p.name.trim();
    if (raw.isEmpty || raw == p.identity || (raw.length > 20 && !raw.contains(' '))) {
      return p.isLocal ? 'You' : 'ALIVE Member';
    }
    return raw;
  }

  Widget _buildProjectorView(
    BuildContext context,
    MeetingSession session,
    MeetingGateway gateway,
    bool isLeader,
    bool canShareScreen,
  ) {
    final activePresenter = session.activeScreenShareName;
    final isPresenting = session.isScreenShareEnabled || activePresenter != null;

    return SafeArea(
      child: Stack(
        children: [
          // Main Stage Canvas
          Column(
            children: [
              // Projector Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF111418),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Exit Projector Display',
                      onPressed: () => setState(() => _isProjectorMode = false),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.isInBreakoutRoom
                            ? Colors.teal.shade800
                            : Colors.red.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            session.isInBreakoutRoom
                                ? Icons.workspaces_rounded
                                : Icons.fiber_manual_record,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            session.isInBreakoutRoom ? 'BREAKOUT' : 'LIVE STAGE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.isInBreakoutRoom
                                ? (session.activeBreakoutRoomName ?? 'Breakout Room')
                                : (_roomController.text.isNotEmpty
                                    ? _roomController.text
                                    : (widget.meetingType?.displayName ?? 'ALIVE Sanctuary Stage')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isPresenting
                                ? 'Screen Share: ${activePresenter ?? "You are presenting"}'
                                : 'Attendees: ${session.participants.length} connected',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isLeader || session.isBreakoutActive)
                      IconButton(
                        icon: const Icon(Icons.workspaces_rounded, color: Colors.white),
                        tooltip: 'Breakout Rooms',
                        onPressed: () => _showBreakoutRoomsSheet(
                          context,
                          session,
                          gateway,
                          isLeader,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white),
                      tooltip: 'Exit Projector Display',
                      onPressed: () => setState(() => _isProjectorMode = false),
                    ),
                  ],
                ),
              ),

              // Central Stage Area (Optimized for Sanctuary / Conference Projectors)
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFF0A0D11),
                  child: Center(
                    child: isPresenting
                        ? _buildScreenShareStage(session, gateway)
                        : _buildVideoGridStage(session, gateway),
                  ),
                ),
              ),

              // Floating Controls Bar at Bottom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF111418),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () async {
                        try {
                          await gateway.toggleAudio();
                        } catch (e) {
                          _showMessage(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                      icon: Icon(session.isAudioMuted ? Icons.mic_off : Icons.mic),
                      style: IconButton.styleFrom(
                        backgroundColor: session.isAudioMuted
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                        foregroundColor: session.isAudioMuted ? Colors.red : Colors.green,
                      ),
                      tooltip: session.isAudioMuted ? 'Unmute' : 'Mute',
                    ),
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: () async {
                        try {
                          await gateway.toggleVideo();
                        } catch (e) {
                          _showMessage(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                      icon: Icon(session.isVideoMuted ? Icons.videocam_off : Icons.videocam),
                      style: IconButton.styleFrom(
                        backgroundColor: session.isVideoMuted
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.blue.withValues(alpha: 0.3),
                        foregroundColor: session.isVideoMuted ? Colors.red : Colors.blue,
                      ),
                      tooltip: session.isVideoMuted ? 'Camera On' : 'Camera Off',
                    ),
                    if (canShareScreen) ...[
                      const SizedBox(width: 14),
                      IconButton.filledTonal(
                        onPressed: () async {
                          try {
                            await gateway.toggleScreenShare();
                            _showMessage(session.isScreenShareEnabled
                                ? 'Screen sharing stopped.'
                                : 'Screen sharing started.');
                          } catch (e) {
                            _showMessage(ErrorHandler.getUserFriendlyMessage(e));
                          }
                        },
                        icon: Icon(session.isScreenShareEnabled
                            ? Icons.stop_screen_share_rounded
                            : Icons.screen_share_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: session.isScreenShareEnabled ? Colors.teal.shade700 : Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: session.isScreenShareEnabled ? 'Stop Sharing' : 'Share Screen',
                      ),
                    ],
                    if (isLeader || session.isBreakoutActive) ...[
                      const SizedBox(width: 14),
                      IconButton.filledTonal(
                        onPressed: () => _showBreakoutRoomsSheet(
                          context,
                          session,
                          gateway,
                          isLeader,
                        ),
                        icon: const Icon(Icons.workspaces_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: session.isBreakoutActive
                              ? Colors.teal.shade700
                              : Colors.white12,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Breakout Rooms',
                      ),
                    ],
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: () => setState(() => _isProjectorMode = false),
                      icon: const Icon(Icons.view_compact_rounded),
                      style: IconButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                      tooltip: 'Standard Meeting View',
                    ),
                    const SizedBox(width: 14),
                    IconButton.filledTonal(
                      onPressed: () => _handleHostExit(gateway),
                      icon: const Icon(Icons.call_end),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
                      tooltip: 'Leave Meeting',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _handleHostExit(MeetingGateway gateway) async {
    final session = ref.read(meetingSessionStreamProvider).value;
    final isConnected = session?.isConnected ?? false;
    final isLeader = RoleAccessService.instance.canStartConferencing() ||
        widget.isModerator ||
        (session?.isHost ?? false) ||
        (session?.isCoHost ?? false);

    if (!isConnected) {
      return true;
    }

    if (!isLeader) {
      await gateway.leaveMeeting();
      return true;
    }

    // If host is the only person remaining in the room, leave cleanly and end the session
    if ((session?.participants.length ?? 0) <= 1) {
      if (_isProjectorMode) {
        setState(() => _isProjectorMode = false);
      }
      await gateway.endMeetingForAll();
      _showMessage('Meeting ended.');
      return true;
    }

    // Host / Leader: Show Zoom / Google Meet standard choice dialog
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.call_end_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Leave or End Meeting?'),
          ],
        ),
        content: const Text(
          'As the meeting host, would you like to end the meeting for all attendees, or leave and keep the session active for others?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('leave'),
            child: const Text('Leave Meeting'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop('end_all'),
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('End Meeting for All'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
          ),
        ],
      ),
    );

    if (action == 'end_all') {
      if (_isProjectorMode) {
        setState(() => _isProjectorMode = false);
      }
      await gateway.endMeetingForAll();
      _showMessage('Meeting ended for all participants.');
      return true;
    } else if (action == 'leave') {
      if (_isProjectorMode) {
        setState(() => _isProjectorMode = false);
      }
      await gateway.leaveMeeting();
      return true;
    }

    return false; // User cancelled
  }

  void _confirmEndMeetingForAll(MeetingGateway gateway) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.stop_circle_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('End Meeting for All?'),
          ],
        ),
        content: const Text(
          'This will disconnect all attendees and close the meeting room immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await gateway.endMeetingForAll();
              _showMessage('Meeting ended for all participants.');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('End Meeting for All'),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenShareStage(MeetingSession session, MeetingGateway gateway) {
    return MeetingScreenShareStage(session: session, gateway: gateway);
  }

  Widget _buildVideoGridStage(MeetingSession session, MeetingGateway gateway) {
    final isLeader = RoleAccessService.instance.canStartConferencing() ||
        widget.isModerator ||
        session.isHost ||
        session.isCoHost;
    return MeetingVideoGridStage(
      session: session,
      gateway: gateway,
      isLeader: isLeader,
      onParticipantTap: (p) => _showParticipantActions(
        context,
        p,
        gateway,
        isLeader,
      ),
    );
  }

  Future<void> _startBroadcast(MeetingGateway gateway) async {
    final meetingType = widget.meetingType?.name ?? 'general';
    try {
      final egressId = await gateway.startBroadcast(meetingType: meetingType);
      if (!mounted) return;
      setState(() {
        _isBroadcasting = true;
        _activeEgressId = egressId;
      });
      _showMessage('Live stream started');
    } catch (e) {
      final friendly = ErrorHandler.getUserFriendlyMessage(
        e,
        'Live broadcast could not be started. Please check streaming settings or contact support.',
      );
      _showMessage(friendly);
    }
  }

  Future<void> _stopBroadcast(MeetingGateway gateway) async {
    if (_activeEgressId == null) return;
    try {
      await gateway.stopBroadcast(egressId: _activeEgressId!);
      if (!mounted) return;
      setState(() {
        _isBroadcasting = false;
        _activeEgressId = null;
      });
      _showMessage('Live stream stopped');
    } catch (e) {
      final friendly = ErrorHandler.getUserFriendlyMessage(
        e,
        'Live stream could not be stopped. Please try again.',
      );
      _showMessage(friendly);
    }
  }

  @override
  void dispose() {
    _breakoutUiTicker?.cancel();
    _moderationSub?.cancel();
    _dataChannelSub?.cancel();
    _inMeetingChatController.dispose();
    _chatScrollController.dispose();
    _roomController.dispose();
    super.dispose();
  }
}
