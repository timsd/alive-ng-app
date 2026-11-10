import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/meeting_links_config.dart';
import '../../constants/chapters.dart';
import '../../models/chat_models.dart';
import '../../models/meeting_models.dart';
import '../../providers/appwrite_auth_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../services/chat_service.dart';
import '../../services/platform/app_store_helper.dart';
import '../../services/platform/media_permission_adapter.dart';
import '../../services/ports/meeting_gateway.dart';
import '../../services/role_access_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/error_handler.dart';
import '../../utils/toast_utils.dart';
import '../admin/leader_meeting_transcription_screen.dart';
import 'components/meeting_breakout_banner.dart';
import 'components/meeting_breakout_sheet.dart';
import 'components/meeting_chat_sheet.dart';
import 'components/meeting_control_bar.dart';
import 'components/meeting_more_actions_sheet.dart';
import 'components/meeting_participant_actions_sheet.dart';
import 'components/meeting_participants_list.dart';
import 'components/meeting_prejoin_lobby.dart';
import 'components/meeting_projector_view.dart';

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
  String _selectedTargetChapter = ChapterConstants.availableChapters.first;
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
    // Resolve default notification target chapter from user's assigned chapter if present
    final profile = ref.read(currentUserProfileProvider).value;
    final userChapter = profile?.chapterId?.trim() ?? profile?.localChapter?.trim();
    if (userChapter != null &&
        userChapter.isNotEmpty &&
        ChapterConstants.availableChapters.contains(userChapter)) {
      _selectedTargetChapter = userChapter;
    }
    _roomController = TextEditingController(text: _initialRoomName());
    _loadAvailableChannels();
    // Ensure meeting overlay is dismissed when opening full meeting screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isMeetingMinimizedProvider.notifier).state = false;
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
        final currentUid = ref.read(currentUserProvider)?.uid ?? '';
        final targetId = msg.targetUserId;
        final isPublic = targetId == null || targetId.isEmpty || targetId == 'everyone';
        final isForMe = targetId == currentUid || msg.senderId == currentUid;

        if (isPublic || isForMe) {
          if (!_inMeetingChatMessages.any((m) => m.id == msg.id)) {
            setState(() {
              _inMeetingChatMessages.add(msg);
              if (!_isChatSheetOpen) {
                _unreadChatCount++;
              }
            });
            _scrollChatToBottom();
          }
        }
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

  void _minimizeMeeting() {
    ref.read(isMeetingMinimizedProvider.notifier).state = true;
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _joinMeeting(MeetingGateway gateway) async {
    if (_isJoining) return;

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

    setState(() => _isJoining = true);

    try {
      // Auto-prompt microphone & camera upfront so join completes on first click
      try {
        await MediaPermissionService.requestMediaPermissions()
            .timeout(const Duration(seconds: 25));
      } catch (_) {}

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
    if (AppStoreHelper.isMobileOnlyNotice(message)) {
      ToastUtils.showMobilePrompt(message);
    } else {
      ToastUtils.showInfo(message);
    }
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

  void _sendInMeetingChatMessage(
    MeetingGateway gateway,
    String text,
    ParticipantInfo? recipient,
  ) {
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

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

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
      'text': trimmed,
      'timestamp': now.toIso8601String(),
      'targetUserId': recipient?.identity,
      'targetUserName': recipient?.name,
    };

    gateway.sendDataChannelMessage(packet);

    setState(() {
      _inMeetingChatMessages.add(InMeetingChatMessage(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: avatar,
        text: trimmed,
        timestamp: now,
        isLocal: true,
        targetUserId: recipient?.identity,
        targetUserName: recipient?.name,
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

  void _showInMeetingChatSheet(
    BuildContext context,
    MeetingGateway gateway, {
    ParticipantInfo? initialRecipient,
  }) {
    setState(() {
      _isChatSheetOpen = true;
      _unreadChatCount = 0;
    });

    final user = ref.read(currentUserProvider);
    final isLeader = RoleAccessService.instance.canStartConferencing() ||
        widget.isModerator ||
        _isLocalHost ||
        _isLocalCoHost;
    final session = gateway.currentSession;

    MeetingChatSheet.show(
      context: context,
      gateway: gateway,
      messages: _inMeetingChatMessages,
      chatController: _inMeetingChatController,
      scrollController: _chatScrollController,
      isChatLockedByHost: _isChatLockedByHost,
      isLeader: isLeader,
      currentUserId: user?.uid ?? '',
      participants: session.participants,
      initialRecipient: initialRecipient,
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
      onSendMessage: (text, recipient) =>
          _sendInMeetingChatMessage(gateway, text, recipient),
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
          _minimizeMeeting();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MeetingProjectorView(
            session: session,
            gateway: gateway,
            isLeader: isLeader,
            canShareScreen: canShareScreen,
            roomTitle: _roomController.text.isNotEmpty
                ? _roomController.text
                : (widget.meetingType?.displayName ?? 'ALIVE Sanctuary Stage'),
            onExitProjector: () => setState(() => _isProjectorMode = false),
            onOpenBreakoutRooms: () =>
                _showBreakoutRoomsSheet(context, session, gateway, isLeader),
            onLeaveMeeting: () => _handleHostExit(gateway),
            onParticipantTap: (p) =>
                _showParticipantActions(context, p, gateway, isLeader),
            showMessage: _showMessage,
          ),
        ),
      );
    }

    return PopScope(
      canPop: !connected,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (connected) {
          _minimizeMeeting();
          return;
        }
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
          onBackPressed: connected ? _minimizeMeeting : null,
          showDonationButton: false,
          actions: [
            if (connected)
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                tooltip: 'Minimize to Floating Overlay',
                onPressed: _minimizeMeeting,
              ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share Meeting Link',
              onPressed: _shareMeetingLink,
            ),
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
        bottomNavigationBar: connected
            ? MeetingControlBar(
                session: session,
                gateway: gateway,
                isLeader: isLeader,
                canShareScreen: canShareScreen,
                isAudioMuted: isAudioMuted,
                isVideoMuted: isVideoMuted,
                unreadChatCount: _unreadChatCount,
                onToggleAudio: () async {
                  if (!isLeader && session.isRoomAudioLocked && isAudioMuted) {
                    _showMessage('The host has locked microphones. Raise your hand to request to speak.');
                    return;
                  }
                  try {
                    await gateway.toggleAudio();
                  } catch (e) {
                    _showMessage(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                onToggleVideo: () async {
                  try {
                    await gateway.toggleVideo();
                  } catch (e) {
                    _showMessage(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                onToggleScreenShare: () async {
                  try {
                    await gateway.toggleScreenShare();
                    _showMessage(session.isScreenShareEnabled
                        ? 'Screen sharing stopped.'
                        : 'Screen sharing started.');
                  } catch (e) {
                    final errStr = ErrorHandler.getUserFriendlyMessage(e);
                    if (AppStoreHelper.isMobileOnlyNotice(errStr) ||
                        AppStoreHelper.isMobileOnlyNotice(e)) {
                      ToastUtils.showInfo(
                        'Screen sharing on mobile requires the ALIVE app. Opening Google Play Store...',
                      );
                      AppStoreHelper.redirectToPlayStore();
                    } else {
                      ToastUtils.showError(e);
                    }
                  }
                },
                onOpenChat: () => _showInMeetingChatSheet(context, gateway),
                onToggleHand: () async {
                  final newRaised = !session.isHandRaised;
                  await gateway.raiseHand(raised: newRaised);
                  _showMessage(newRaised ? 'Hand raised' : 'Hand lowered');
                },
                onOpenMore: () => _showMeetingMoreSheet(context, session, gateway, isLeader),
                onLeaveOrEnd: () => _handleHostExit(gateway),
              )
            : null,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!connected)
                MeetingPrejoinLobby(
                  roomController: _roomController,
                  isLeader: isLeader,
                  isJoining: _isJoining,
                  requireHostApproval: _requireHostApproval,
                  onToggleRequireHostApproval: (val) => setState(() => _requireHostApproval = val),
                  notifyMembers: _notifyMembers,
                  onToggleNotifyMembers: (val) => setState(() => _notifyMembers = val),
                  targetAudience: _targetAudience,
                  onAudienceChanged: (val) => setState(() => _targetAudience = val),
                  audienceItems: _buildTargetAudienceItems(),
                  selectedTargetChapter: _selectedTargetChapter,
                  onChapterChanged: (val) => setState(() => _selectedTargetChapter = val),
                  isLoadingChannels: _isLoadingChannels,
                  onRefreshChannels: _loadAvailableChannels,
                  onJoin: () => _joinMeeting(gateway),
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
                  MeetingBreakoutBanner(
                    session: session,
                    gateway: gateway,
                    isLeader: isLeader,
                    onOpenBreakoutRooms: () =>
                        _showBreakoutRoomsSheet(context, session, gateway, isLeader),
                    onAskHostHelp: () async {
                      await gateway.requestHostHelpInBreakout();
                      _showMessage('Host has been invited to assist your room.');
                    },
                    onReturnToMainRoom: () async {
                      await gateway.returnToMainRoom();
                      _showMessage('Returned to Main Room');
                    },
                    formatRemaining: _formatBreakoutRemaining,
                  ),

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

                // Stage Header Card: Meeting Room Title & Presence
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1B2432)
                        : const Color(0xFFF3EBE0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD49B28).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          session.isInBreakoutRoom
                              ? '${session.activeBreakoutRoomName}'
                              : (widget.meetingType?.displayName ?? _roomController.text.trim()),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${session.participants.length} connected',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                MeetingParticipantsList(
                  session: session,
                  gateway: gateway,
                  isLeader: isLeader,
                  onParticipantTap: (p) =>
                      _showParticipantActions(context, p, gateway, isLeader),
                  formatParticipantName: _formatParticipantName,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMeetingMoreSheet(
    BuildContext context,
    MeetingSession session,
    MeetingGateway gateway,
    bool isLeader,
  ) {
    MeetingMoreActionsSheet.show(
      context: context,
      session: session,
      gateway: gateway,
      isLeader: isLeader,
      isBroadcasting: _isBroadcasting,
      onOpenBreakoutRooms: () =>
          _showBreakoutRoomsSheet(context, session, gateway, isLeader),
      onOpenProjector: () => setState(() => _isProjectorMode = true),
      onOpenScribe: () {
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
      onShareLink: _shareMeetingLink,
      onReturnToMainRoom: () async {
        await gateway.returnToMainRoom();
        _showMessage('Returned to Main Plenary Room');
      },
      onMuteAll: () async {
        await gateway.muteAll();
        _showMessage('Broadcast command sent: All participants muted.');
      },
      onToggleMicLock: (newLock) async {
        await gateway.setRoomAudioLock(newLock);
        _showMessage(newLock
            ? 'Host Hard Lockout activated: Participants cannot unmute.'
            : 'Host Hard Lockout released: Participants can now unmute.');
      },
      onToggleWaitingRoom: (newWaiting) async {
        await gateway.setWaitingRoom(newWaiting);
        _showMessage(newWaiting
            ? 'Waiting Room activated: New participants must be admitted.'
            : 'Waiting Room disabled: Participants can now join directly.');
      },
      onToggleBroadcast: () {
        if (_isBroadcasting) {
          _stopBroadcast(gateway);
        } else {
          _startBroadcast(gateway);
        }
      },
      onEndMeetingForAll: () => _confirmEndMeetingForAll(gateway),
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
      onStartDirectChat: (target) {
        _showInMeetingChatSheet(context, gateway, initialRecipient: target);
      },
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



  Future<bool> _handleHostExit(MeetingGateway gateway) async {
    final session = ref.read(meetingSessionStreamProvider).value;
    final isConnected = session?.isConnected ?? false;
    final isLeader = RoleAccessService.instance.canStartConferencing() ||
        widget.isModerator;

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
