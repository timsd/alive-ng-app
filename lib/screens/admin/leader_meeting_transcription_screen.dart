import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/meeting_models.dart';
import '../../providers/meeting_provider.dart';
import '../../services/alive_scribe_service.dart';
import '../../services/appwrite_meeting_file_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'meeting_file_sharing_screen.dart';

// Backwards compatibility classes for synthesizer and references
enum TranscriptEntryType {
  general,
  decision,
  actionItem,
  motion,
}

class MeetingAttendee {
  final String id;
  final String name;
  final String role;
  final Color color;

  const MeetingAttendee({
    required this.id,
    required this.name,
    required this.role,
    required this.color,
  });
}

class MeetingTranscriptEntry {
  final String id;
  String speakerName;
  String speakerRole;
  Color speakerColor;
  String content;
  final DateTime timestamp;
  TranscriptEntryType type;

  MeetingTranscriptEntry({
    required this.id,
    required this.speakerName,
    required this.speakerRole,
    required this.speakerColor,
    required this.content,
    required this.timestamp,
    this.type = TranscriptEntryType.general,
  });
}

class MeetingActionItem {
  final String id;
  String task;
  String assignee;
  DateTime? dueDate;
  bool isCompleted;

  MeetingActionItem({
    required this.id,
    required this.task,
    required this.assignee,
    this.dueDate,
    this.isCompleted = false,
  });
}

/// Zero-touch, high-accuracy meeting transcription & intelligence dashboard.
/// Powered by distributed client-side speech recognition, LiveKit data channels,
/// and two-pass deterministic extraction with traceable citations.
class LeaderMeetingTranscriptionScreen extends ConsumerStatefulWidget {
  final String? initialMeetingTitle;
  final String? initialMeetingType;
  final String? initialRoomName;

  const LeaderMeetingTranscriptionScreen({
    super.key,
    this.initialMeetingTitle,
    this.initialMeetingType,
    this.initialRoomName,
  });

  @override
  ConsumerState<LeaderMeetingTranscriptionScreen> createState() =>
      _LeaderMeetingTranscriptionScreenState();
}

class _LeaderMeetingTranscriptionScreenState
    extends ConsumerState<LeaderMeetingTranscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _transcriptScrollController = ScrollController();
  final TextEditingController _meetingTitleController = TextEditingController();

  AliveScribeService? _scribeService;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _decisionsSub;
  StreamSubscription? _actionItemsSub;
  StreamSubscription? _roomStatusSub;

  List<ScribeTranscriptPacket> _transcript = [];
  List<ScribeDecision> _decisions = [];
  List<ScribeActionItem> _actionItems = [];

  late String _meetingType;
  final DateTime _meetingStartTime = DateTime.now();
  String? _connectedRoomName;

  bool _isSavingToFileArea = false;
  Timer? _durationTimer;
  Duration _sessionDuration = Duration.zero;

  static const List<Color> _avatarColors = [
    Color(0xFF1B365D), // Host Navy
    Color(0xFF00897B), // Teal
    Color(0xFFE65100), // Amber
    Color(0xFF6A1B9A), // Purple
    Color(0xFFC2185B), // Pink
    Color(0xFF2E7D32), // Forest Green
    Color(0xFF0277BD), // Blue
    Color(0xFFD84315), // Deep Orange
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _meetingTitleController.text = widget.initialMeetingTitle ??
        'Council Meeting - ${DateFormat('MMMM d, yyyy').format(DateTime.now())}';
    _meetingType = widget.initialMeetingType ?? 'Council';
    _connectedRoomName = widget.initialRoomName;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _sessionDuration = DateTime.now().difference(_meetingStartTime);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAliveScribe();
    });
  }

  void _initAliveScribe() {
    final gateway = ref.read(meetingGatewayProvider);
    final user = AuthService.instance.currentUser;
    final userId = user?.uid ?? 'leader_${DateTime.now().millisecondsSinceEpoch}';
    final userName = user?.displayName ?? 'Host Leader';

    _scribeService = AliveScribeService(
      gateway: gateway,
      localUserId: userId,
      localUserName: userName,
      localUserRole: 'Council Member',
    );

    _transcriptSub = _scribeService!.transcriptStream.listen((list) {
      if (mounted) {
        setState(() {
          _transcript = list;
        });
        _scrollToBottom();
      }
    });

    _decisionsSub = _scribeService!.decisionsStream.listen((list) {
      if (mounted) {
        setState(() {
          _decisions = list;
        });
      }
    });

    _actionItemsSub = _scribeService!.actionItemsStream.listen((list) {
      if (mounted) {
        setState(() {
          _actionItems = list;
        });
      }
    });

    // Auto-listen only when an active meeting is connected
    _roomStatusSub = gateway.roomStatus.listen((status) {
      if (!mounted) return;
      if (status == RoomStatus.connected) {
        if (_scribeService != null && !_scribeService!.isListening) {
          _scribeService!.startListening().then((_) {
            if (mounted) setState(() {});
          });
        }
      } else if (status == RoomStatus.disconnected) {
        if (_scribeService != null && _scribeService!.isListening) {
          _scribeService!.stopListening().then((_) {
            if (mounted) setState(() {});
          });
        }
      }
    });

    // If meeting is already actively connected when Scribe screen is opened, start listening;
    // otherwise remain in Standby mode until a meeting connects.
    if (gateway.isConnected) {
      _scribeService!.startListening().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          _transcriptScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getSpeakerColor(String speakerName) {
    final hash = speakerName.hashCode.abs();
    return _avatarColors[hash % _avatarColors.length];
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMicrophone() async {
    if (_scribeService == null) return;
    if (_scribeService!.isListening) {
      await _scribeService!.stopListening();
    } else {
      await _scribeService!.startListening();
    }
    if (mounted) setState(() {});
  }

  // ──────────────────────────────────────────────────────────
  //  Action 1: Save to Meeting Files (Appwrite Bucket)
  // ──────────────────────────────────────────────────────────
  Future<void> _saveToMeetingFiles() async {
    if (_transcript.isEmpty && _decisions.isEmpty && _actionItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save empty minutes. Waiting for discussion...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Color(0xFF1B365D)),
            SizedBox(width: 8),
            Text('Save to Meeting Files'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ALIVE Scribe will compile the executive overview, timestamped resolutions, assigned action items table, and full cleaned transcript into a markdown file and store it in the Meeting Files repository.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Title: ${_meetingTitleController.text.trim()}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Transcripts: ${_transcript.length} turns'),
                  Text('• Resolutions: ${_decisions.length}'),
                  Text('• Action Items: ${_actionItems.length}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Save Minutes'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSavingToFileArea = true);

    try {
      final markdown = _scribeService?.generateMarkdownMinutes(
            meetingTitle: _meetingTitleController.text.trim(),
            meetingType: _meetingType,
          ) ??
          '';

      final bytes = Uint8List.fromList(utf8.encode(markdown));
      final dateClean = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final sanitizedTitle = _meetingTitleController.text
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'Minutes_${sanitizedTitle}_$dateClean.md';

      final user = AuthService.instance.currentUser;
      final uploaderId = user?.uid ?? 'alive-scribe';
      final uploaderName = user?.displayName ?? 'ALIVE Scribe';

      await AppwriteMeetingFileService.instance.uploadMeetingFileBytes(
        bytes,
        fileName: fileName,
        description:
            'Synthesized council minutes, resolutions & clean transcript for "${_meetingTitleController.text.trim()}".',
        uploaderId: uploaderId,
        uploadedBy: uploaderName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$fileName" to Meeting Files!'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View Files',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MeetingFileSharingScreen(),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note saving file: $e'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingToFileArea = false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Action 2: Copy / Share Minutes
  // ──────────────────────────────────────────────────────────
  Future<void> _copyOrShareMinutes() async {
    final markdown = _scribeService?.generateMarkdownMinutes(
          meetingTitle: _meetingTitleController.text.trim(),
          meetingType: _meetingType,
        ) ??
        '';

    if (markdown.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcript or minutes available to share yet.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share Minutes',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF1B365D)),
                title: const Text('Copy to Clipboard'),
                subtitle: const Text('Markdown format with overview, decisions & table'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: markdown));
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Minutes copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Color(0xFF00897B)),
                title: const Text('Share via App / Email'),
                subtitle: const Text('Send verified minutes through system share'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await SharePlus.instance.share(
                    ShareParams(
                      text: markdown,
                      subject: '${_meetingTitleController.text.trim()} - Minutes',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _transcriptSub?.cancel();
    _decisionsSub?.cancel();
    _actionItemsSub?.cancel();
    _roomStatusSub?.cancel();
    _scribeService?.dispose();
    _tabController.dispose();
    _transcriptScrollController.dispose();
    _meetingTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sessionAsync = ref.watch(meetingSessionStreamProvider);
    final session = sessionAsync.value;

    final isLiveKitConnected = session != null &&
        session.status == RoomStatus.connected &&
        session.roomName.isNotEmpty;
    final roomName = isLiveKitConnected
        ? session.roomName
        : (_connectedRoomName ?? 'Standalone Scribe');

    final remoteAttendees = session?.participants ?? [];
    final totalAttendeesCount =
        remoteAttendees.isNotEmpty ? remoteAttendees.length : (_scribeService?.attendees.length ?? 1);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'ALIVE Scribe',
        showBackButton: true,
        actions: [
          // Local Microphone Listening Indicator / Toggle
          IconButton(
            icon: Icon(
              _scribeService?.isListening == true
                  ? Icons.mic_rounded
                  : Icons.mic_off_rounded,
              color: _scribeService?.isListening == true
                  ? Colors.greenAccent
                  : Colors.grey,
            ),
            tooltip: _scribeService?.isListening == true
                ? 'Scribe Listening (Tap to Mute)'
                : 'Scribe Mic Muted (Tap to Listen)',
            onPressed: _toggleMicrophone,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Copy or Share Minutes',
            onPressed: _copyOrShareMinutes,
          ),
          IconButton(
            icon: _isSavingToFileArea
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            tooltip: 'Save to Meeting Files',
            onPressed: _isSavingToFileArea ? null : _saveToMeetingFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // ──────────────────────────────────────────────────────────
          //  Zero-Touch Header: Connection Status & Active Attendees
          // ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D2A) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF233549) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Connection Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLiveKitConnected
                            ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                            : const Color(0xFF64748B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLiveKitConnected
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLiveKitConnected
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLiveKitConnected ? 'LiveKit: $roomName' : roomName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isLiveKitConnected
                                  ? (isDark ? Colors.greenAccent : const Color(0xFF15803D))
                                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Duration Counter
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_sessionDuration),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Active Attendees Row
                Row(
                  children: [
                    Text(
                      'Attendees ($totalAttendeesCount):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (remoteAttendees.isNotEmpty)
                              ...remoteAttendees.map((p) {
                                final color = _getSpeakerColor(p.name);
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: p.isSpeaking ? Colors.green : color.withValues(alpha: 0.3),
                                      width: p.isSpeaking ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 6,
                                        backgroundColor: color,
                                        child: Text(
                                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                          style: const TextStyle(fontSize: 8, color: Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: p.isSpeaking ? FontWeight.bold : FontWeight.w500,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      if (p.isSpeaking) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.volume_up, size: 12, color: Colors.green),
                                      ],
                                    ],
                                  ),
                                );
                              })
                            else
                              ...(_scribeService?.attendees ?? {'Host'}).map((name) {
                                final color = _getSpeakerColor(name);
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ──────────────────────────────────────────────────────────
          //  Tabs: Live Transcript & Live Council Intelligence
          // ──────────────────────────────────────────────────────────
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.outline,
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.subtitles_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Live Transcript (${_transcript.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text('Intelligence (${_decisions.length + _actionItems.length})'),
                  ],
                ),
              ),
            ],
          ),

          // ──────────────────────────────────────────────────────────
          //  Tab Content
          // ──────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Live Transcript View
                _buildLiveTranscriptTab(isDark),

                // 2. Extracted Decisions & Action Items View
                _buildIntelligenceTab(isDark),
              ],
            ),
          ),

          // ──────────────────────────────────────────────────────────
          //  Zero-Touch Bottom Bar: Only Essential Actions
          // ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D2A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyOrShareMinutes,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Minutes'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSavingToFileArea ? null : _saveToMeetingFiles,
                    icon: _isSavingToFileArea
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Save to Files'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Tab 1: Multi-Speaker Cleaned Transcript List
  // ──────────────────────────────────────────────────────────
  Widget _buildLiveTranscriptTab(bool isDark) {
    if (_transcript.isEmpty) {
      final isListening = _scribeService?.isListening == true;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isListening ? Icons.record_voice_over_rounded : Icons.mic_none_rounded,
                size: 52,
                color: isListening
                    ? const Color(0xFF16A34A)
                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Text(
                isListening
                    ? 'ALIVE Scribe is actively listening.'
                    : 'ALIVE Scribe is in Standby.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isListening
                    ? 'When attendees speak, their speech is cleaned of filler words ("um", "you know") and streamed here in real time with 100% speaker attribution.'
                    : 'Listening begins automatically when your meeting connects. You can also tap the microphone icon above to start manual dictation at any time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _transcriptScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _transcript.length,
      itemBuilder: (context, index) {
        final packet = _transcript[index];
        final color = _getSpeakerColor(packet.speakerName);
        final timeStr = DateFormat('HH:mm').format(packet.timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Text(
                  packet.speakerName.isNotEmpty ? packet.speakerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            packet.speakerName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              packet.speakerRole,
                              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        packet.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Tab 2: Real-Time Extracted Resolutions & Action Items
  // ──────────────────────────────────────────────────────────
  Widget _buildIntelligenceTab(bool isDark) {
    if (_decisions.isEmpty && _actionItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 52,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              Text(
                'No decisions or action items yet.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'As participants state agreements ("we agreed to...", "it is resolved that...") or commitments ("I will...", "Bro. Samuel to follow up..."), ALIVE Scribe will extract them here with exact verbatim citations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Council Resolutions Card
          if (_decisions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Council Resolutions (${_decisions.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._decisions.map((dec) => _buildDecisionCard(dec, isDark)),
            const SizedBox(height: 20),
          ],

          // 2. Assigned Action Items Card
          if (_actionItems.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Assigned Action Items (${_actionItems.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._actionItems.map((act) => _buildActionItemCard(act, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildDecisionCard(ScribeDecision dec, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142419) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A27) : const Color(0xFFDCFCE7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dec.category.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
              ),
              const Spacer(),
              Text(
                '[${dec.timestampFormatted}]',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF86EFAC).withValues(alpha: 0.8) : const Color(0xFF166534).withValues(alpha: 0.8),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dec.decision,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: isDark ? const Color(0xFFF0FDF4) : const Color(0xFF14532D),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Citation: "${dec.verbatimQuote}" — ${dec.speakerName}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemCard(ScribeActionItem act, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17223B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF22355A) : const Color(0xFFDBEAFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 12, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      act.assignee,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              if (act.targetDueDate != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    act.targetDueDate!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '[${act.timestampFormatted}]',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF93C5FD).withValues(alpha: 0.8) : const Color(0xFF1E40AF).withValues(alpha: 0.8),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            act.task,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Citation: "${act.verbatimQuote}" — ${act.speakerName}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
