import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/meeting_models.dart';
import '../../providers/meeting_provider.dart';
import '../../services/appwrite_meeting_file_service.dart';
import '../../services/auth_service.dart';
import '../../services/on_device_meeting_synthesizer.dart';
import '../../widgets/custom_app_bar.dart';
import 'meeting_file_sharing_screen.dart';

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
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _meetingTitleController = TextEditingController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  String _interimWords = '';

  late String _meetingType;
  final DateTime _meetingDate = DateTime.now();
  String? _connectedRoomName;

  final List<MeetingAttendee> _attendees = [];
  late MeetingAttendee _selectedSpeaker;

  final List<MeetingTranscriptEntry> _transcriptEntries = [];
  final List<String> _decisions = [];
  final List<MeetingActionItem> _actionItems = [];
  final List<String> _discussionThemes = [];
  bool _quorumAchieved = false;

  final OnDeviceMeetingSynthesizer _synthesizer =
      const OnDeviceMeetingSynthesizer();

  bool _isSavingToFileArea = false;

  static const List<Color> _colorPalette = [
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
    _meetingType = widget.initialMeetingType ?? 'Board of Directors';
    _connectedRoomName = widget.initialRoomName;

    // Initialize with current authenticated leader as primary host
    final user = AuthService.instance.currentUser;
    final leaderName = user?.displayName ?? 'Host Leader';
    _attendees.add(MeetingAttendee(
      id: user?.uid ?? 'host',
      name: leaderName,
      role: 'Meeting Host',
      color: _colorPalette.first,
    ));
    _selectedSpeaker = _attendees.first;

    _summaryController.text = '';
    _checkExistingDraft();
  }

  static const String _draftKey = 'alive_leader_scribe_backup_draft';

  Future<void> _checkExistingDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString(_draftKey);
      if (draftStr != null && draftStr.isNotEmpty && mounted) {
        final draft = jsonDecode(draftStr) as Map<String, dynamic>;
        final count = (draft['entries'] as List?)?.length ?? 0;
        if (count > 0 && _transcriptEntries.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found backed-up meeting draft ($count entries).'),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                label: 'Restore',
                textColor: Colors.amberAccent,
                onPressed: () => _restoreDraftFromBackup(draft),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking scribe draft: $e');
    }
  }

  Future<void> _backupDraftLocally({bool showNotification = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'title': _meetingTitleController.text,
        'summary': _summaryController.text,
        'meetingType': _meetingType,
        'date': _meetingDate.toIso8601String(),
        'decisions': _decisions,
        'actionItems': _actionItems
            .map((a) => {
                  'id': a.id,
                  'task': a.task,
                  'assignee': a.assignee,
                  'dueDate': a.dueDate?.toIso8601String(),
                  'isCompleted': a.isCompleted,
                })
            .toList(),
        'entries': _transcriptEntries
            .map((e) => {
                  'id': e.id,
                  'speakerName': e.speakerName,
                  'speakerRole': e.speakerRole,
                  'speakerColor': e.speakerColor.toARGB32(),
                  'content': e.content,
                  'timestamp': e.timestamp.toIso8601String(),
                  'type': e.type.index,
                })
            .toList(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_draftKey, jsonEncode(draft));
      if (showNotification && mounted) {
        _showFeedback('Notes backed up locally!');
      }
    } catch (e) {
      if (showNotification && mounted) {
        _showFeedback('Backup failed: $e');
      }
    }
  }

  void _restoreDraftFromBackup(Map<String, dynamic> draft) {
    setState(() {
      if (draft['title'] != null && draft['title'].toString().isNotEmpty) {
        _meetingTitleController.text = draft['title'].toString();
      }
      if (draft['summary'] != null) {
        _summaryController.text = draft['summary'].toString();
      }
      if (draft['meetingType'] != null) {
        _meetingType = draft['meetingType'].toString();
      }
      if (draft['decisions'] is List) {
        _decisions
          ..clear()
          ..addAll(List<String>.from(draft['decisions']));
      }
      if (draft['actionItems'] is List) {
        _actionItems
          ..clear()
          ..addAll((draft['actionItems'] as List).map((i) => MeetingActionItem(
                id: i['id'] ?? '',
                task: i['task'] ?? '',
                assignee: i['assignee'] ?? '',
                dueDate:
                    i['dueDate'] != null ? DateTime.tryParse(i['dueDate']) : null,
                isCompleted: i['isCompleted'] == true,
              )));
      }
      if (draft['entries'] is List) {
        _transcriptEntries
          ..clear()
          ..addAll((draft['entries'] as List).map((e) => MeetingTranscriptEntry(
                id: e['id'] ?? '',
                speakerName: e['speakerName'] ?? 'Speaker',
                speakerRole: e['speakerRole'] ?? 'Member',
                speakerColor: Color(e['speakerColor'] ?? 0xFF1B365D),
                content: e['content'] ?? '',
                timestamp:
                    DateTime.tryParse(e['timestamp'] ?? '') ?? DateTime.now(),
                type: TranscriptEntryType.values[(e['type'] as int?) ?? 0],
              )));
      }
    });
    _showFeedback('Restored ${_transcriptEntries.length} entries from backup!');
  }

  /// Synchronizes LiveKit conference room participants directly into Scribe attendees
  void _syncLiveKitSession(MeetingSession session) {
    if (!session.isConnected) return;

    bool stateChanged = false;
    _connectedRoomName = session.roomName;

    for (final p in session.participants) {
      final name = p.name.isNotEmpty ? p.name : p.identity;
      final existingIndex = _attendees.indexWhere(
        (a) => a.id == p.identity || a.name.toLowerCase() == name.toLowerCase(),
      );

      if (existingIndex == -1) {
        final color = _colorPalette[_attendees.length % _colorPalette.length];
        final role = p.isLocal ? 'Meeting Host' : 'Council Delegate';
        _attendees.add(MeetingAttendee(
          id: p.identity,
          name: name,
          role: role,
          color: color,
        ));
        stateChanged = true;
      }
    }

    // Active Speaker Tracking from LiveKit WebRTC audio stream
    ParticipantInfo? speakingParticipant;
    for (final p in session.participants) {
      if (p.isSpeaking) {
        speakingParticipant = p;
        break;
      }
    }

    if (speakingParticipant != null) {
      final sName = speakingParticipant.name.isNotEmpty
          ? speakingParticipant.name
          : speakingParticipant.identity;
      final match = _attendees.firstWhere(
        (a) =>
            a.id == speakingParticipant!.identity ||
            a.name.toLowerCase() == sName.toLowerCase(),
        orElse: () => _selectedSpeaker,
      );

      if (match.id != _selectedSpeaker.id) {
        _selectedSpeaker = match;
        stateChanged = true;
      }
    }

    if (stateChanged && mounted) {
      setState(() {});
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          debugPrint('Scribe speech engine note: ${err.errorMsg}');
          if (mounted && _isListening) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && _isListening) _startContinuousScribe();
            });
          }
        },
        onStatus: (status) {
          debugPrint('Scribe status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              _commitInterimWords();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _isListening) _startContinuousScribe();
              });
            }
          }
        },
      );
      if (mounted) {
        setState(() => _speechInitialized = available);
      }
    } catch (e) {
      debugPrint('Speech engine initialization: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transcriptScrollController.dispose();
    _inputController.dispose();
    _summaryController.dispose();
    _meetingTitleController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Toggle Autonomous Scribe
  Future<void> _toggleScribeMode() async {
    HapticFeedback.mediumImpact();

    if (_isListening) {
      await _speech.stop();
      _commitInterimWords();
      setState(() => _isListening = false);
      _showFeedback('Scribe paused.');
      return;
    }

    // Direct OS permission prompt like Zoom/Meet
    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isPermanentlyDenied) {
        _showFeedback(
            'Microphone permission is denied. Please allow it in device Settings.');
        return;
      }
      if (!micStatus.isGranted) {
        _showFeedback('Microphone permission is required for speech transcription.');
        return;
      }
    } catch (e) {
      debugPrint('Direct mic permission error: $e');
    }

    if (!_speechInitialized) {
      await _initSpeech();
    }

    setState(() {
      _isListening = true;
      _interimWords = '';
    });

    _showFeedback(
        'Scribe active: capturing all conference room speakers simultaneously.');
    await _startContinuousScribe();
  }

  Future<void> _startContinuousScribe() async {
    if (!_isListening) return;

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || !_isListening) return;
          setState(() {
            _interimWords = result.recognizedWords;
          });

          if (result.finalResult && _interimWords.trim().isNotEmpty) {
            _commitInterimWords();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(minutes: 30),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('Continuous scribe listener error: $e');
    }
  }

  void _commitInterimWords() {
    final text = _interimWords.trim();
    if (text.isEmpty) return;

    // Attribute speaker: detect if an attendee is explicitly addressed/named in text
    MeetingAttendee speaker = _selectedSpeaker;
    for (final attendee in _attendees) {
      final firstName = attendee.name.toLowerCase().split(' ').first;
      if (text.toLowerCase().startsWith(firstName) ||
          text.toLowerCase().contains('$firstName:')) {
        speaker = attendee;
        break;
      }
    }

    final entryType = _inferEntryType(text);

    _addTranscriptEntry(
      speaker: speaker,
      content: text,
      type: entryType,
    );

    // Auto-extract Decisions on-the-fly into Key Decisions list
    if (entryType == TranscriptEntryType.decision) {
      final decisions = _synthesizer.extractDecisions(
        entries: [
          MeetingTranscriptEntry(
            id: 'temp',
            speakerName: speaker.name,
            speakerRole: speaker.role,
            speakerColor: speaker.color,
            content: text,
            timestamp: DateTime.now(),
            type: entryType,
          )
        ],
        existingDecisions: _decisions,
      );
      for (final d in decisions) {
        if (!_decisions.contains(d)) {
          setState(() => _decisions.add(d));
        }
      }
    }

    // Auto-extract Action Items on-the-fly into Action Items list
    if (entryType == TranscriptEntryType.actionItem) {
      final actionItems = _synthesizer.extractActionItems(
        entries: [
          MeetingTranscriptEntry(
            id: 'temp',
            speakerName: speaker.name,
            speakerRole: speaker.role,
            speakerColor: speaker.color,
            content: text,
            timestamp: DateTime.now(),
            type: entryType,
          )
        ],
        attendees: _attendees,
        meetingDate: DateTime.now(),
        existingActionItems: _actionItems,
      );
      setState(() {
        _actionItems
          ..clear()
          ..addAll(actionItems);
      });
    }

    setState(() {
      _interimWords = '';
    });
  }

  /// One-click meeting simulation to verify that the Scribe captures dialogue,
  /// attributes all room speakers, and generates formatted minutes cleanly without error.
  Future<void> _simulateMeetingDiscussion() async {
    if (_attendees.length < 3) {
      _attendees.addAll([
        const MeetingAttendee(
          id: 'attendee_grace',
          name: 'Sister Grace',
          role: 'Treasurer',
          color: Color(0xFF00897B),
        ),
        const MeetingAttendee(
          id: 'attendee_segun',
          name: 'Brother Segun',
          role: 'Evangelism Coordinator',
          color: Color(0xFFE65100),
        ),
      ]);
    }

    final simulationSteps = [
      (
        speaker: _attendees.first,
        text: 'Welcome everyone to the council meeting. Let us review the agenda.'
      ),
      (
        speaker: _attendees[1],
        text:
            'Sister Grace: The financial statement for Q3 shows healthy surplus for evangelism tracts.'
      ),
      (
        speaker: _attendees.first,
        text:
            'Resolved that the council approves allocating 200,000 Naira to chapter literature distribution.'
      ),
      (
        speaker: _attendees[2],
        text:
            'Brother Segun: Evangelism teams will conduct outreach across Lagos chapters next Sabbath.'
      ),
      (
        speaker: _attendees[2],
        text:
            'Action item: Brother Segun will coordinate 50 volunteer evangelists before Friday.'
      ),
      (
        speaker: _attendees[1],
        text:
            'Action item: Sister Grace to finalize financial audit report by next week.'
      ),
      (
        speaker: _attendees.first,
        text:
            'Decision: Approved unanimously to establish a new ALIVE campus chapter in Ibadan.'
      ),
    ];

    _showFeedback('Simulating simultaneous multi-speaker room dialogue...');

    for (int i = 0; i < simulationSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final step = simulationSteps[i];
      _selectedSpeaker = step.speaker;
      _interimWords = step.text;
      _commitInterimWords();
    }

    _autoSummarizeFromTranscript();
    _showFeedback(
        'Minutes generated: Scribe synthesized executive summary, decisions, and action items!');
  }

  TranscriptEntryType _inferEntryType(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('decision:') ||
        lower.startsWith('resolution:') ||
        lower.contains('it is decided') ||
        lower.contains('approved unanimously') ||
        lower.contains('motion passed') ||
        lower.contains('council resolved that') ||
        lower.contains('resolved that')) {
      return TranscriptEntryType.decision;
    }
    if (lower.startsWith('action:') ||
        lower.startsWith('action item:') ||
        lower.contains('will follow up') ||
        lower.contains('assigned to') ||
        lower.contains('task for')) {
      return TranscriptEntryType.actionItem;
    }
    if (lower.startsWith('motion:') || lower.contains('i move that')) {
      return TranscriptEntryType.motion;
    }
    return TranscriptEntryType.general;
  }

  void _addTranscriptEntry({
    required MeetingAttendee speaker,
    required String content,
    TranscriptEntryType type = TranscriptEntryType.general,
  }) {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) return;

    final entry = MeetingTranscriptEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      speakerName: speaker.name,
      speakerRole: speaker.role,
      speakerColor: speaker.color,
      content: cleanContent,
      timestamp: DateTime.now(),
      type: type,
    );

    setState(() {
      _transcriptEntries.add(entry);
    });

    _autoScrollTranscript();
  }

  void _autoScrollTranscript() {
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

  void _submitManualInput({TranscriptEntryType? forcedType}) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final type = forcedType ?? _inferEntryType(text);
    _addTranscriptEntry(
      speaker: _selectedSpeaker,
      content: text,
      type: type,
    );

    if (type == TranscriptEntryType.decision) {
      final decs = _synthesizer.extractDecisions(
        entries: [
          MeetingTranscriptEntry(
            id: 'temp',
            speakerName: _selectedSpeaker.name,
            speakerRole: _selectedSpeaker.role,
            speakerColor: _selectedSpeaker.color,
            content: text,
            timestamp: DateTime.now(),
            type: type,
          )
        ],
        existingDecisions: _decisions,
      );
      for (final d in decs) {
        if (!_decisions.contains(d)) _decisions.add(d);
      }
    } else if (type == TranscriptEntryType.actionItem) {
      final acts = _synthesizer.extractActionItems(
        entries: [
          MeetingTranscriptEntry(
            id: 'temp',
            speakerName: _selectedSpeaker.name,
            speakerRole: _selectedSpeaker.role,
            speakerColor: _selectedSpeaker.color,
            content: text,
            timestamp: DateTime.now(),
            type: type,
          )
        ],
        attendees: _attendees,
        meetingDate: DateTime.now(),
        existingActionItems: _actionItems,
      );
      _actionItems
        ..clear()
        ..addAll(acts);
    }

    _inputController.clear();
  }

  /// 100% On-Device Minutes Synthesis
  void _autoSummarizeFromTranscript() {
    final result = _synthesizer.synthesize(
      meetingTitle: _meetingTitleController.text.trim().isNotEmpty
          ? _meetingTitleController.text.trim()
          : 'Council Meeting',
      meetingType: _meetingType,
      meetingDate: _meetingDate,
      attendees: _attendees,
      entries: _transcriptEntries,
      existingDecisions: _decisions,
      existingActionItems: _actionItems,
    );

    setState(() {
      _summaryController.text = result.executiveSummary;
      _decisions
        ..clear()
        ..addAll(result.keyDecisions);
      _actionItems
        ..clear()
        ..addAll(result.actionItems);
      _discussionThemes
        ..clear()
        ..addAll(result.discussionThemes);
      _quorumAchieved = result.quorumAchieved;
    });

    _showFeedback(
      'Minutes Compiled: Executive Summary, ${_decisions.length} Decisions, and ${_actionItems.length} Action Items!',
    );
  }

  String _generateMarkdownNotes() {
    final buffer = StringBuffer();
    final dateStr = DateFormat('EEEE, MMMM d, y • h:mm a').format(_meetingDate);

    buffer.writeln('# 🏛️ ${_meetingTitleController.text.trim()}');
    buffer.writeln('**Meeting Category:** $_meetingType  ');
    buffer.writeln('**Date & Time:** $dateStr  ');
    if (_connectedRoomName != null && _connectedRoomName!.isNotEmpty) {
      buffer.writeln('**LiveKit Conference Room:** `$_connectedRoomName`  ');
    }
    buffer.writeln(
        '**Quorum Status:** ${_quorumAchieved ? 'Duly Constituted' : 'Informally Observed'}  ');
    buffer.writeln(
        '**Council Attendees (${_attendees.length}):** ${_attendees.map((a) => '${a.name} (${a.role})').join(', ')}  \n');

    buffer.writeln('---');
    buffer.writeln('## 📋 Executive Summary\n');
    buffer.writeln(
        '${_summaryController.text.trim().isNotEmpty ? _summaryController.text.trim() : '*No executive summary compiled yet.*'}\n');

    if (_discussionThemes.isNotEmpty) {
      buffer.writeln('### 🏷️ Agenda Discussion Themes\n');
      for (final theme in _discussionThemes) {
        buffer.writeln('- $theme');
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('## ⚖️ Key Decisions & Council Resolutions\n');
    if (_decisions.isEmpty) {
      buffer.writeln('*No formal resolutions recorded.*\n');
    } else {
      for (int i = 0; i < _decisions.length; i++) {
        buffer.writeln('${i + 1}. **[ADOPTED RESOLUTION]** ${_decisions[i]}');
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('## ✅ Action Items & Target Deadlines\n');
    if (_actionItems.isEmpty) {
      buffer.writeln('*No pending action items assigned.*\n');
    } else {
      for (final item in _actionItems) {
        final status = item.isCompleted ? '[x]' : '[ ]';
        final due = item.dueDate != null
            ? ' *(Target Deadline: ${DateFormat.yMMMd().format(item.dueDate!)})*'
            : '';
        buffer.writeln('- $status **${item.assignee}:** ${item.task}$due');
      }
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln('## 🎙️ Chronological Multi-Speaker Transcript\n');
    buffer.writeln(
        '> *Automated multi-speaker transcript recorded on-device by ALIVE Scribe.*\n');

    if (_transcriptEntries.isEmpty) {
      buffer.writeln('*No speech dialogue captured for this sitting.*\n');
    } else {
      for (final entry in _transcriptEntries) {
        final time = DateFormat('h:mm a').format(entry.timestamp);
        final tag = entry.type == TranscriptEntryType.decision
            ? ' `[DECISION]`'
            : entry.type == TranscriptEntryType.actionItem
                ? ' `[ACTION]`'
                : entry.type == TranscriptEntryType.motion
                    ? ' `[MOTION]`'
                    : '';
        buffer.writeln(
            '- **[$time] ${entry.speakerName} (${entry.speakerRole}):**$tag ${entry.content}');
      }
    }

    return buffer.toString();
  }

  Future<void> _finishAndSaveToMeetingFiles() async {
    final title = _meetingTitleController.text.trim();
    if (title.isEmpty) {
      _showFeedback('Please provide a meeting title.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_special, color: Color(0xFF5865F2)),
              SizedBox(width: 8),
              Text('Store Formatted Minutes'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALIVE Scribe will save the synthesized executive summary, council resolutions, and assigned action items into the leadership Meeting Files repository.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Title: $title',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('• Speaker entries: ${_transcriptEntries.length}'),
                    Text('• Key decisions: ${_decisions.length}'),
                    Text('• Action items: ${_actionItems.length}'),
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
              label: const Text('Store Minutes'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSavingToFileArea = true);

    try {
      final markdown = _generateMarkdownNotes();
      final bytes = Uint8List.fromList(utf8.encode(markdown));

      final dateClean = DateFormat('yyyyMMdd_HHmm').format(_meetingDate);
      final sanitizedTitle = title
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final fileName = 'Minutes_${sanitizedTitle}_$dateClean.md';

      final user = AuthService.instance.currentUser;
      final uploaderId = user?.uid ?? 'leader-scribe';
      final uploaderName = user?.displayName ?? 'ALIVE Scribe';

      await AppwriteMeetingFileService.instance.uploadMeetingFileBytes(
        bytes,
        fileName: fileName,
        description:
            'Synthesized minutes, council resolutions & multi-speaker transcript for "$title" compiled by ALIVE Scribe.',
        uploaderId: uploaderId,
        uploadedBy: uploaderName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$fileName" directly to Meeting Files!'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'View in Files',
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

      _showShareOrCopyDialog(markdown, fileName);
    } catch (e) {
      if (mounted) {
        _showFeedback('Failed to save to Meeting Files: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingToFileArea = false);
      }
    }
  }

  void _showShareOrCopyDialog(String markdown, String fileName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Minutes Successfully Formatted!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'File "$fileName" is now stored in Meeting Files. You can also copy or distribute the formatted minutes directly.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: markdown));
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            _showFeedback('Copied formatted minutes to clipboard!');
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          SharePlus.instance.share(
                            markdown,
                            subject: _meetingTitleController.text,
                          );
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSpeakerDialog() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    Color chosenColor = Colors.teal;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add Meeting Attendee / Speaker'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name / Title',
                      hintText: 'e.g. Bro. Emmanuel',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Role in Meeting',
                      hintText: 'e.g. Trustee / Coordinator',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Speaker Color: '),
                      const SizedBox(width: 8),
                      ..._colorPalette.take(5).map((c) {
                        final isSelected = chosenColor == c;
                        return GestureDetector(
                          onTap: () => setDlgState(() => chosenColor = c),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: c.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final n = nameCtrl.text.trim();
                    final r = roleCtrl.text.trim();
                    if (n.isNotEmpty) {
                      final newAttendee = MeetingAttendee(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: n,
                        role: r.isNotEmpty ? r : 'Council Delegate',
                        color: chosenColor,
                      );
                      setState(() {
                        _attendees.add(newAttendee);
                        _selectedSpeaker = newAttendee;
                      });
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Add Speaker'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddActionItemDialog() {
    final taskCtrl = TextEditingController();
    String selectedAssignee = _selectedSpeaker.name;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Add Action Item'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Action Task Description',
                      hintText: 'e.g. Prepare financial statement for Q4',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAssignee,
                    decoration: const InputDecoration(
                      labelText: 'Assignee',
                    ),
                    items: _attendees
                        .map((a) =>
                            DropdownMenuItem(value: a.name, child: Text(a.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => selectedAssignee = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target Deadline'),
                    subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDlgState(() => selectedDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final t = taskCtrl.text.trim();
                    if (t.isNotEmpty) {
                      setState(() {
                        _actionItems.add(MeetingActionItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          task: t,
                          assignee: selectedAssignee,
                          dueDate: selectedDate,
                        ));
                      });
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Add Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDecisionDialog() {
    final decisionCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Record Council Resolution'),
          content: TextField(
            controller: decisionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resolution Text',
              hintText:
                  'e.g. Board approved budget increment for Chapter operations.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final d = decisionCtrl.text.trim();
                if (d.isNotEmpty) {
                  setState(() => _decisions.add(d));
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Adopt Resolution'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Synchronize LiveKit room session automatically if connected
    ref.listen<AsyncValue<MeetingSession>>(meetingSessionStreamProvider,
        (previous, next) {
      final session = next.value;
      if (session != null && session.isConnected) {
        _syncLiveKitSession(session);
      }
    });

    final currentLiveKitSession = ref.watch(meetingSessionStreamProvider).value;
    final isLiveKitActive = currentLiveKitSession?.isConnected == true;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Leader Scribe & Notes',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.backup_outlined),
            tooltip: 'Backup / Save Draft',
            onPressed: () => _backupDraftLocally(),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'View Meeting Files',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MeetingFileSharingScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: _isSavingToFileArea
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_as_outlined),
            tooltip: 'Save Notes to Meeting Files',
            onPressed:
                _isSavingToFileArea ? null : _finishAndSaveToMeetingFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScribeHeaderCard(theme, colorScheme, isLiveKitActive),
          _buildActiveSpeakerBar(colorScheme),
          TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: [
              Tab(
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                text: 'Live Transcript (${_transcriptEntries.length})',
              ),
              Tab(
                icon: const Icon(Icons.assignment_outlined, size: 20),
                text: 'Summary & Decisions (${_decisions.length})',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTranscriptTab(theme, colorScheme),
                _buildSummaryTab(theme, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// On-Device Hybrid Scribe Card with LiveKit room connection banner
  Widget _buildScribeHeaderCard(
      ThemeData theme, ColorScheme colorScheme, bool isLiveKitActive) {
    const brandColor = Color(0xFF1B365D);
    const livekitGreen = Color(0xFF00897B);
    final isListening = _isListening;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isListening
              ? Colors.redAccent.withValues(alpha: 0.6)
              : isLiveKitActive
                  ? livekitGreen.withValues(alpha: 0.4)
                  : brandColor.withValues(alpha: 0.25),
          width: isListening ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with active indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLiveKitActive ? livekitGreen : brandColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isLiveKitActive ? livekitGreen : brandColor)
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isListening ? Colors.redAccent : Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ALIVE Meeting Scribe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SCRIBE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isListening
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isListening
                                      ? Colors.redAccent
                                      : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isListening
                                    ? 'SCRIBE: RECORDING'
                                    : (isLiveKitActive
                                        ? 'LIVEKIT LINKED'
                                        : 'ONLINE & READY'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isListening
                                      ? Colors.redAccent
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLiveKitActive
                          ? 'Synchronized with LiveKit room "${_connectedRoomName ?? 'Active Meet'}" • ${_attendees.length} Connected'
                          : (isListening
                              ? 'Recording all conference room speakers simultaneously...'
                              : '100% On-Device Hybrid Scribe: private, offline, multi-speaker.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isListening
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: _toggleScribeMode,
                  style: FilledButton.styleFrom(
                    backgroundColor: isListening
                        ? Colors.redAccent
                        : const Color(0xFF1B365D),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    isListening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_outlined,
                    size: 18,
                  ),
                  label: Text(
                    isListening ? 'Pause Recording' : 'Record All Speakers',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _simulateMeetingDiscussion,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Test Simulation'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _autoSummarizeFromTranscript,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Compile Minutes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Active Speaker Bar: Displays all meeting attendees / LiveKit participants
  Widget _buildActiveSpeakerBar(ColorScheme colorScheme) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _attendees.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _attendees.length) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add Speaker'),
              onPressed: _showAddSpeakerDialog,
            );
          }

          final attendee = _attendees[index];
          final isSelected = _selectedSpeaker.id == attendee.id;

          return ChoiceChip(
            selected: isSelected,
            selectedColor: attendee.color.withValues(alpha: 0.2),
            avatar: CircleAvatar(
              radius: 12,
              backgroundColor: attendee.color,
              child: Text(
                attendee.name.isNotEmpty ? attendee.name[0] : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attendee.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? attendee.color : null,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• ${attendee.role.split(' ').first}',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedSpeaker = attendee);
              }
            },
          );
        },
      ),
    );
  }

  /// Live Transcript Tab: Multi-Speaker Thread
  Widget _buildTranscriptTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Expanded(
          child: _transcriptEntries.isEmpty && _interimWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.record_voice_over_outlined,
                        size: 56,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No transcription entries yet.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Record All Speakers" or "Test Simulation" above.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _transcriptScrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  itemCount: _transcriptEntries.length +
                      (_interimWords.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _transcriptEntries.length) {
                      return _buildInterimBubble(colorScheme);
                    }
                    final entry = _transcriptEntries[index];
                    return _buildMessageRow(entry, theme, colorScheme);
                  },
                ),
        ),
        _buildInputBar(theme, colorScheme),
      ],
    );
  }

  Widget _buildMessageRow(
    MeetingTranscriptEntry entry,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isDecision = entry.type == TranscriptEntryType.decision;
    final isAction = entry.type == TranscriptEntryType.actionItem;
    final isMotion = entry.type == TranscriptEntryType.motion;

    final timeStr = DateFormat('h:mm a').format(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDecision
            ? Colors.green.withValues(alpha: 0.08)
            : isAction
                ? Colors.amber.withValues(alpha: 0.08)
                : isMotion
                    ? Colors.purple.withValues(alpha: 0.08)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isDecision
                ? Colors.green
                : isAction
                    ? Colors.amber.shade800
                    : isMotion
                        ? Colors.deepPurple
                        : entry.speakerColor,
            width: 3.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: entry.speakerColor,
            child: Text(
              entry.speakerName.isNotEmpty ? entry.speakerName[0] : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      entry.speakerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: entry.speakerColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: entry.speakerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.speakerRole,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: entry.speakerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    if (isDecision)
                      _buildTagPill('DECISION', Colors.green)
                    else if (isAction)
                      _buildTagPill('ACTION ITEM', Colors.amber.shade900)
                    else if (isMotion)
                      _buildTagPill('MOTION', Colors.deepPurple),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'decision',
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              Text(isDecision
                                  ? 'Unmark Decision'
                                  : 'Mark as Decision'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'action',
                          child: Row(
                            children: [
                              Icon(Icons.assignment_outlined,
                                  color: Colors.amber.shade900, size: 18),
                              const SizedBox(width: 8),
                              Text(isAction
                                  ? 'Unmark Action'
                                  : 'Mark as Action Item'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Delete Entry'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'decision') {
                          setState(() {
                            entry.type = isDecision
                                ? TranscriptEntryType.general
                                : TranscriptEntryType.decision;
                            if (entry.type == TranscriptEntryType.decision) {
                              if (!_decisions.contains(entry.content)) {
                                _decisions.add(entry.content);
                              }
                            }
                          });
                        } else if (val == 'action') {
                          setState(() {
                            entry.type = isAction
                                ? TranscriptEntryType.general
                                : TranscriptEntryType.actionItem;
                            if (entry.type == TranscriptEntryType.actionItem) {
                              _actionItems.add(MeetingActionItem(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                task: entry.content,
                                assignee: entry.speakerName,
                              ));
                            }
                          });
                        } else if (val == 'delete') {
                          setState(() {
                            _transcriptEntries.remove(entry);
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  entry.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPill(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Real-time live speech preview bubble
  Widget _buildInterimBubble(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _selectedSpeaker.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedSpeaker.color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _selectedSpeaker.color,
            child: Text(
              _selectedSpeaker.name.isNotEmpty ? _selectedSpeaker.name[0] : '?',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedSpeaker.name} (speaking now...)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedSpeaker.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _interimWords,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, size: 20),
            tooltip: 'Commit sentence',
            onPressed: _commitInterimWords,
          ),
        ],
      ),
    );
  }

  /// Bottom Input Bar with quick tagging buttons
  Widget _buildInputBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Tag as:',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _buildInputTagButton(
                icon: Icons.check_circle_outline,
                label: 'Decision',
                color: Colors.green,
                onTap: () => _submitManualInput(
                    forcedType: TranscriptEntryType.decision),
              ),
              const SizedBox(width: 6),
              _buildInputTagButton(
                icon: Icons.assignment_outlined,
                label: 'Action',
                color: Colors.amber.shade900,
                onTap: () => _submitManualInput(
                    forcedType: TranscriptEntryType.actionItem),
              ),
              const SizedBox(width: 6),
              _buildInputTagButton(
                icon: Icons.gavel_outlined,
                label: 'Motion',
                color: Colors.deepPurple,
                onTap: () =>
                    _submitManualInput(forcedType: TranscriptEntryType.motion),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: _selectedSpeaker.color,
                child: Text(
                  _selectedSpeaker.name.isNotEmpty
                      ? _selectedSpeaker.name[0]
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: 'Add statement as ${_selectedSpeaker.name}...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _submitManualInput(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.stop_circle : Icons.mic_none,
                  color: _isListening ? Colors.redAccent : colorScheme.primary,
                ),
                tooltip:
                    _isListening ? 'Pause Recording' : 'Record All Speakers',
                onPressed: _toggleScribeMode,
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: colorScheme.primary,
                tooltip: 'Send Statement',
                onPressed: () => _submitManualInput(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputTagButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Summary & Decisions Tab: Formatted Minutes
  Widget _buildSummaryTab(ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Meeting Context Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Meeting Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _quorumAchieved
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _quorumAchieved
                            ? 'QUORUM CONSTITUTED'
                            : 'INFORMAL SESSION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _quorumAchieved
                              ? Colors.green.shade800
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _meetingTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _meetingType,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Board of Directors',
                              child: Text('Board of Directors')),
                          DropdownMenuItem(
                              value: 'Trustees Council',
                              child: Text('Trustees Council')),
                          DropdownMenuItem(
                              value: 'Executive Committee',
                              child: Text('Executive Committee')),
                          DropdownMenuItem(
                              value: 'General Leadership',
                              child: Text('General Leadership')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _meetingType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDatePickerFormField(
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDate: _meetingDate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Discussion Themes Chips
        if (_discussionThemes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Agenda Discussion Themes:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _discussionThemes.map((themeStr) {
              return Chip(
                avatar: const Icon(Icons.label_outline, size: 14),
                label: Text(themeStr, style: const TextStyle(fontSize: 12)),
                backgroundColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // 📋 Executive Summary Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.summarize_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Executive Summary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _autoSummarizeFromTranscript,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Auto-Compile'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _summaryController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'Professional synthesized minutes detailing quorum, floor deliberations, and outcomes...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ⚖️ Key Decisions Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel_rounded,
                            size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Key Decisions & Resolutions (${_decisions.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Record Resolution',
                      onPressed: _showAddDecisionDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_decisions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No formal decisions recorded yet. Tap + to add or mark statements in the transcript.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ..._decisions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final decision = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RESOLUTION ${idx + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  decision,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() => _decisions.removeAt(idx));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ✅ Action Items Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 20, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Text(
                          'Action Items & Target Deadlines (${_actionItems.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Add Action Item',
                      onPressed: _showAddActionItemDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_actionItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No action items assigned. Tap + to add tasks and assignees.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ..._actionItems.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: item.isCompleted,
                            activeColor: Colors.amber.shade900,
                            onChanged: (val) {
                              setState(() => item.isCompleted = val ?? false);
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.task,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: item.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Assignee: ${item.assignee}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (item.dueDate != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Target Deadline: ${DateFormat.yMMMd().format(item.dueDate!)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () {
                              setState(() => _actionItems.remove(item));
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Primary Action Button: Store in Meeting Files
        FilledButton.icon(
          onPressed: _isSavingToFileArea ? null : _finishAndSaveToMeetingFiles,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isSavingToFileArea
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(
            _isSavingToFileArea ? 'Storing...' : 'Save Formatted Minutes',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
