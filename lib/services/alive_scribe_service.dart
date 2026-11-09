import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'ports/meeting_gateway.dart';

/// Lightweight transcript packet broadcasted over LiveKit Data Channel
class ScribeTranscriptPacket {
  final String id;
  final String speakerId;
  final String speakerName;
  final String speakerRole;
  final String text;
  final DateTime timestamp;
  final bool isFinal;

  const ScribeTranscriptPacket({
    required this.id,
    required this.speakerId,
    required this.speakerName,
    required this.speakerRole,
    required this.text,
    required this.timestamp,
    this.isFinal = true,
  });

  Map<String, dynamic> toJson() => {
        'type': 'alive_scribe_packet',
        'id': id,
        'speaker_id': speakerId,
        'speaker_name': speakerName,
        'speaker_role': speakerRole,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'is_final': isFinal,
      };

  factory ScribeTranscriptPacket.fromJson(Map<String, dynamic> json) =>
      ScribeTranscriptPacket(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        speakerId: json['speaker_id']?.toString() ?? 'anonymous',
        speakerName: json['speaker_name']?.toString() ?? 'Attendee',
        speakerRole: json['speaker_role']?.toString() ?? 'Member',
        text: json['text']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        isFinal: json['is_final'] == true,
      );

  ScribeTranscriptPacket copyWith({
    String? id,
    String? speakerId,
    String? speakerName,
    String? speakerRole,
    String? text,
    DateTime? timestamp,
    bool? isFinal,
  }) {
    return ScribeTranscriptPacket(
      id: id ?? this.id,
      speakerId: speakerId ?? this.speakerId,
      speakerName: speakerName ?? this.speakerName,
      speakerRole: speakerRole ?? this.speakerRole,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
    );
  }
}

/// Council decision / resolution with traceable verbatim citation
class ScribeDecision {
  final String id;
  final String decision;
  final String speakerName;
  final String speakerRole;
  final String timestampFormatted;
  final String verbatimQuote;
  final String category; // 'Resolution', 'Motion', 'Consensus', 'Budget', 'Policy'

  const ScribeDecision({
    required this.id,
    required this.decision,
    required this.speakerName,
    required this.speakerRole,
    required this.timestampFormatted,
    required this.verbatimQuote,
    this.category = 'Resolution',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'decision': decision,
        'speaker_name': speakerName,
        'speaker_role': speakerRole,
        'timestamp': timestampFormatted,
        'verbatim_quote': verbatimQuote,
        'category': category,
      };
}

/// Assigned action item with assignee, target due date, and exact citation
class ScribeActionItem {
  final String id;
  final String task;
  final String assignee;
  final String? targetDueDate;
  final String speakerName;
  final String timestampFormatted;
  final String verbatimQuote;
  final bool isCompleted;

  const ScribeActionItem({
    required this.id,
    required this.task,
    required this.assignee,
    this.targetDueDate,
    required this.speakerName,
    required this.timestampFormatted,
    required this.verbatimQuote,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'task': task,
        'assignee': assignee,
        'target_due_date': targetDueDate,
        'speaker_name': speakerName,
        'timestamp': timestampFormatted,
        'verbatim_quote': verbatimQuote,
        'is_completed': isCompleted,
      };
}

/// High-accuracy, distributed, zero-cloud-LLM meeting scribe service
class AliveScribeService {
  final MeetingGateway _gateway;
  final String localUserId;
  final String localUserName;
  final String localUserRole;

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isSttInitialized = false;
  bool _isListening = false;
  bool _isRestarting = false;
  String _lastRecognizedWords = '';

  /// The best available STT locale resolved at init (en-NG → en-GB → en-US), matching Bible Game.
  String _resolvedSttLocale = 'en-NG';

  /// Ordered locale fallback chain: Nigerian English → British English → US English.
  static const _localeFallbackChain = [
    'en-NG',
    'en_NG',
    'en-GB',
    'en_GB',
    'en-US',
    'en_US',
  ];

  final List<ScribeTranscriptPacket> _transcript = [];
  final List<ScribeDecision> _decisions = [];
  final List<ScribeActionItem> _actionItems = [];
  final Set<String> _attendees = {};

  final _transcriptStreamController =
      StreamController<List<ScribeTranscriptPacket>>.broadcast();
  final _decisionsStreamController =
      StreamController<List<ScribeDecision>>.broadcast();
  final _actionItemsStreamController =
      StreamController<List<ScribeActionItem>>.broadcast();

  StreamSubscription? _dataChannelSub;
  DateTime? _meetingStartTime;

  AliveScribeService({
    required MeetingGateway gateway,
    required this.localUserId,
    required this.localUserName,
    this.localUserRole = 'Leader',
  }) : _gateway = gateway {
    _meetingStartTime = DateTime.now();
    _attendees.add(localUserName);
    _listenToDataChannel();
  }

  List<ScribeTranscriptPacket> get transcript => List.unmodifiable(_transcript);
  List<ScribeDecision> get decisions => List.unmodifiable(_decisions);
  List<ScribeActionItem> get actionItems => List.unmodifiable(_actionItems);
  Set<String> get attendees => Set.unmodifiable(_attendees);
  bool get isListening => _isListening;

  Stream<List<ScribeTranscriptPacket>> get transcriptStream =>
      _transcriptStreamController.stream;
  Stream<List<ScribeDecision>> get decisionsStream =>
      _decisionsStreamController.stream;
  Stream<List<ScribeActionItem>> get actionItemsStream =>
      _actionItemsStreamController.stream;

  // ──────────────────────────────────────────────────────────
  //  LiveKit Data Channel Listener (Multi-Speaker Reception)
  // ──────────────────────────────────────────────────────────
  void _listenToDataChannel() {
    _dataChannelSub = _gateway.dataChannelMessagesStream.listen((msg) {
      try {
        if (msg['type'] == 'alive_scribe_packet') {
          final packet = ScribeTranscriptPacket.fromJson(msg);
          // Do not duplicate packets sent by this local client
          if (packet.speakerId != localUserId) {
            _handleIncomingPacket(packet);
          }
        }
      } catch (e) {
        debugPrint('[AliveScribeService] Error handling packet: $e');
      }
    });
  }

  // ──────────────────────────────────────────────────────────
  //  Local Audio Capture & Speech-to-Text
  // ──────────────────────────────────────────────────────────
  Future<bool> initializeSpeech() async {
    if (_isSttInitialized) return true;
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (err) {
          debugPrint('[AliveScribeService] STT error: $err');
          _commitPendingSpeech();
          if (_isListening) {
            _restartListening();
          }
        },
        onStatus: (status) {
          debugPrint('[AliveScribeService] STT status: $status');
          if ((status == 'notListening' || status == 'done') && _isListening) {
            _commitPendingSpeech();
            _restartListening();
          }
        },
      );

      // Resolve the best available STT locale from the fallback chain (matching Bible Game accuracy: en-NG → en-GB → en-US)
      if (_isSttInitialized) {
        try {
          final locales = await _speechToText.locales();
          final availableIds = locales.map((l) => l.localeId).toSet();
          for (final candidate in _localeFallbackChain) {
            if (availableIds.contains(candidate)) {
              _resolvedSttLocale = candidate;
              debugPrint('[AliveScribeService] STT locale resolved: $candidate');
              break;
            }
          }
          if (!_localeFallbackChain.contains(_resolvedSttLocale) ||
              !availableIds.contains(_resolvedSttLocale)) {
            final fallback = availableIds.firstWhere(
              (id) => id.startsWith('en'),
              orElse: () => 'en-US',
            );
            _resolvedSttLocale = fallback;
            debugPrint('[AliveScribeService] STT locale fallback to: $fallback');
          }
        } catch (e) {
          debugPrint('[AliveScribeService] Error resolving STT locales: $e');
        }
      }

      return _isSttInitialized;
    } catch (e) {
      debugPrint('[AliveScribeService] STT init failed: $e');
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isSttInitialized) {
      final ok = await initializeSpeech();
      if (!ok) return;
    }

    _isListening = true;
    _lastRecognizedWords = '';
    _startSttSession();
  }

  void _startSttSession() {
    if (!_isListening) return;

    try {
      _lastRecognizedWords = '';
      _speechToText.listen(
        onResult: (result) {
          final rawText = result.recognizedWords.trim();
          if (rawText.isEmpty) return;
          _lastRecognizedWords = rawText;

          if (result.finalResult) {
            _commitPendingSpeech();
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
          localeId: _resolvedSttLocale,
        ),
      );
    } catch (e) {
      debugPrint('[AliveScribeService] Start STT session error: $e');
      if (_isListening) {
        _restartListening();
      }
    }
  }

  void _commitPendingSpeech() {
    final pending = _lastRecognizedWords.trim();
    if (pending.isEmpty) return;
    _lastRecognizedWords = '';

    final cleanText = cleanDisfluencies(pending);
    if (cleanText.isEmpty) return;

    final packet = ScribeTranscriptPacket(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      speakerId: localUserId,
      speakerName: localUserName,
      speakerRole: localUserRole,
      text: cleanText,
      timestamp: DateTime.now(),
      isFinal: true,
    );

    _handleIncomingPacket(packet);
    _broadcastPacket(packet);
  }

  void _restartListening() {
    if (!_isListening || _isRestarting) return;
    _isRestarting = true;
    Future.delayed(const Duration(milliseconds: 300), () {
      _isRestarting = false;
      if (_isListening) {
        _startSttSession();
      }
    });
  }

  Future<void> stopListening() async {
    _isListening = false;
    _commitPendingSpeech();
    try {
      await _speechToText.stop();
    } catch (_) {}
  }

  Future<void> _broadcastPacket(ScribeTranscriptPacket packet) async {
    try {
      await _gateway.sendDataChannelMessage(packet.toJson(), reliable: true);
    } catch (e) {
      debugPrint('[AliveScribeService] Broadcast error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Pass 1: Disfluency & Filler Stripping
  // ──────────────────────────────────────────────────────────
  static String cleanDisfluencies(String input) {
    if (input.trim().isEmpty) return '';

    // Only clean pure speech hesitation noises (um, uh, er, ah, hmm), preserving all actual vocabulary
    final fillerRegex = RegExp(
      r'\b(um|uh|er|ah|hmm|erm)\b',
      caseSensitive: false,
    );

    var cleaned = input.replaceAll(fillerRegex, ' ');

    // Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first character
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  // ──────────────────────────────────────────────────────────
  //  Packet Ingestion & Intelligent Turn Consolidation
  // ──────────────────────────────────────────────────────────
  void _handleIncomingPacket(ScribeTranscriptPacket packet) {
    _attendees.add(packet.speakerName);

    // Merge rapid successive fragments from the same speaker within 3.5 seconds
    if (_transcript.isNotEmpty) {
      final last = _transcript.last;
      final diff = packet.timestamp.difference(last.timestamp).inMilliseconds;
      if (last.speakerId == packet.speakerId && diff < 3500) {
        final combinedText = '${last.text}. ${packet.text}';
        final updated = last.copyWith(
          text: combinedText,
          timestamp: packet.timestamp,
        );
        _transcript[_transcript.length - 1] = updated;
        _transcriptStreamController.add(List.unmodifiable(_transcript));

        // Run Pass 2 on the consolidated text
        _runPass2Extraction(updated);
        return;
      }
    }

    _transcript.add(packet);
    _transcriptStreamController.add(List.unmodifiable(_transcript));

    // Run Pass 2 Extraction
    _runPass2Extraction(packet);
  }

  // ──────────────────────────────────────────────────────────
  //  Pass 2: Real-Time Deterministic NLP & Traceable Citations
  // ──────────────────────────────────────────────────────────
  void _runPass2Extraction(ScribeTranscriptPacket packet) {
    final text = packet.text.trim();
    if (text.length < 12) return;

    final lower = text.toLowerCase();
    final timeStr = DateFormat('HH:mm').format(packet.timestamp);

    // 1. Council Decisions / Resolutions Matcher
    final decisionPatterns = [
      RegExp(r'\b(i\s+(hereby\s+)?move\s+that\s+(.+))', caseSensitive: false),
      RegExp(r'\b(second(ed)?\s+(the\s+motion|by\s+[A-Za-z\s]+))', caseSensitive: false),
      RegExp(r'\b(adopt(ed)?\s+(it|this|the\s+minutes|the\s+report)\s+as\s+a\s+working\s+document)', caseSensitive: false),
      RegExp(r'\b(we (agreed|decided) to\s+(.+))', caseSensitive: false),
      RegExp(r'\b(it is resolved that\s+(.+))', caseSensitive: false),
      RegExp(r'\b(council (agreed|resolves|approved)\s+(.+))', caseSensitive: false),
      RegExp(r'\b(board (agreed|resolves|approved|decided)\s+(.+))', caseSensitive: false),
      RegExp(r'\b(moved and seconded that\s+(.+))', caseSensitive: false),
      RegExp(r'\b(consensus (is|was) that\s+(.+))', caseSensitive: false),
      RegExp(r'\b(unanimously (approved|agreed|adopted)\s+(.+))', caseSensitive: false),
      RegExp(r'\b(approved the budget for\s+(.+))', caseSensitive: false),
      RegExp(r'\b(voted to (adopt|approve|appoint|proceed with)\s+(.+))', caseSensitive: false),
      RegExp(r'\b(confirmed the appointment of\s+(.+))', caseSensitive: false),
    ];

    for (final pattern in decisionPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var extractedDecision = match.group(0)!;
        // Clean leading indicators for a punchy resolution statement
        extractedDecision = extractedDecision
            .replaceFirst(RegExp(r'^(we agreed to|it is resolved that|council agreed that|board agreed that|consensus is that|unanimously approved that)\s*', caseSensitive: false), '')
            .trim();
        if (extractedDecision.isNotEmpty) {
          extractedDecision =
              extractedDecision[0].toUpperCase() + extractedDecision.substring(1);
        }

        // Avoid duplicate decisions
        final isDuplicate = _decisions.any((d) =>
            d.decision.toLowerCase() == extractedDecision.toLowerCase() ||
            d.verbatimQuote == text);

        if (!isDuplicate) {
          final decisionObj = ScribeDecision(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            decision: extractedDecision,
            speakerName: packet.speakerName,
            speakerRole: packet.speakerRole,
            timestampFormatted: timeStr,
            verbatimQuote: text,
            category: lower.contains('budget')
                ? 'Budget'
                : lower.contains('appoint')
                    ? 'Appointment'
                    : lower.contains('move') || lower.contains('second') || lower.contains('adopt')
                        ? 'Motion / Resolution'
                        : 'Resolution',
          );
          _decisions.add(decisionObj);
          _decisionsStreamController.add(List.unmodifiable(_decisions));
        }
        break;
      }
    }

    // 2. Action Items & Commitments Matcher
    final actionPatterns = [
      RegExp(r'\b(i (will|am going to|shall)\s+(.+))', caseSensitive: false),
      RegExp(r"\b(i'll\s+(.+))", caseSensitive: false),
      RegExp(r'\b(assigned to\s+([A-Za-z\s]+?)\s+(to|for|with)\s+(.+))', caseSensitive: false),
      RegExp(r'\b((bro|brother|sis|sister|pastor|elder|sir|uncle|aunty|dr)\s+[A-Za-z]+\s+(will|is to|to|should)\s+(.+))', caseSensitive: false),
      RegExp(r'\b(we will follow up on\s+(.+))', caseSensitive: false),
      RegExp(r'\b(take responsibility for\s+(.+))', caseSensitive: false),
      RegExp(r'\b(action point(\s+is)?\s+(.+))', caseSensitive: false),
    ];

    for (final pattern in actionPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var task = match.group(0)!;
        String assignee = packet.speakerName;

        // Detect third-party assignment
        final thirdPartyMatch = RegExp(
          r'\b(assigned to\s+([A-Za-z\s]+?)|(bro|brother|sis|sister|pastor|elder|sir|uncle|aunty|dr)\s+([A-Za-z]+))\b',
          caseSensitive: false,
        ).firstMatch(text);
        if (thirdPartyMatch != null) {
          final candidate = thirdPartyMatch.group(0)!;
          assignee = candidate.replaceFirst(RegExp(r'^assigned to\s+', caseSensitive: false), '').trim();
        }

        // Detect deadline or target date
        String? targetDueDate;
        final dateMatch = RegExp(
          r'\b(by\s+(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|tonight|next week|end of the month|month end|[0-9]{1,2}(st|nd|rd|th)?\s+[A-Za-z]+)|within\s+[0-9]+\s+(days|weeks|months))\b',
          caseSensitive: false,
        ).firstMatch(text);
        if (dateMatch != null) {
          targetDueDate = dateMatch.group(0)!.trim();
        }

        // Clean task description
        task = task
            .replaceFirst(RegExp(r"^(i will|i'll|we will follow up on|take responsibility for|action point is|action point)\s*", caseSensitive: false), '')
            .trim();
        if (task.isNotEmpty) {
          task = task[0].toUpperCase() + task.substring(1);
        }

        final isDuplicate = _actionItems.any((a) =>
            a.task.toLowerCase() == task.toLowerCase() ||
            a.verbatimQuote == text);

        if (!isDuplicate && task.length > 5) {
          final actionObj = ScribeActionItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            task: task,
            assignee: assignee,
            targetDueDate: targetDueDate,
            speakerName: packet.speakerName,
            timestampFormatted: timeStr,
            verbatimQuote: text,
          );
          _actionItems.add(actionObj);
          _actionItemsStreamController.add(List.unmodifiable(_actionItems));
        }
        break;
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Leadership Minutes Generator (Clean Markdown & Output)
  // ──────────────────────────────────────────────────────────
  String generateMarkdownMinutes({
    required String meetingTitle,
    required String meetingType,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_meetingStartTime ?? now);
    final duration = now.difference(_meetingStartTime ?? now);
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    // Attendee participation word count breakdown
    final wordCounts = <String, int>{};
    int totalWords = 0;
    for (final p in _transcript) {
      final count = p.text.split(RegExp(r'\s+')).length;
      wordCounts[p.speakerName] = (wordCounts[p.speakerName] ?? 0) + count;
      totalWords += count;
    }

    final quorumAchieved = _attendees.length >= 2 || _transcript.length >= 3;

    // Detect Devotional Metadata if available in the first parts of the session
    String? devotionHymn;
    String? devotionScripture;
    String? devotionSpeaker;
    for (final p in _transcript.take(15)) {
      final hymnM = RegExp(r'\b(SDAH\s*[0-9]+|hymn\s*(number\s*)?[0-9]+)\b', caseSensitive: false).firstMatch(p.text);
      if (hymnM != null && devotionHymn == null) {
        devotionHymn = hymnM.group(0);
      }
      final scriptM = RegExp(r'\b([1-3]?\s?[A-Za-z]+)\s+[0-9]+:[0-9]+(-[0-9]+)?\b').firstMatch(p.text);
      if (scriptM != null && devotionScripture == null) {
        devotionScripture = scriptM.group(0);
      }
      if ((p.text.toLowerCase().contains('prayer') || p.text.toLowerCase().contains('admonition')) && devotionSpeaker == null) {
        devotionSpeaker = p.speakerName;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('# ALIVE Council & Board Meeting Minutes');
    buffer.writeln('**$meetingTitle**');
    buffer.writeln();

    // 1. Executive Overview
    buffer.writeln('## 1. Executive Overview');
    buffer.writeln('- **Date:** $dateStr');
    buffer.writeln('- **Type:** $meetingType');
    buffer.writeln('- **Session Duration:** $durationStr');
    buffer.writeln('- **Quorum:** ${quorumAchieved ? "✅ Achieved" : "⚠️ Incomplete"} (${_attendees.length} members present)');
    buffer.writeln('- **Attendees:** ${_attendees.join(", ")}');
    buffer.writeln();

    if (devotionHymn != null || devotionScripture != null || devotionSpeaker != null) {
      buffer.writeln('### Preliminaries & Devotion');
      if (devotionHymn != null) buffer.writeln('- **Opening Hymn:** $devotionHymn');
      if (devotionScripture != null) buffer.writeln('- **Scripture Reading:** $devotionScripture');
      if (devotionSpeaker != null) buffer.writeln('- **Exhortation & Opening Prayer:** $devotionSpeaker');
      buffer.writeln();
    }

    if (totalWords > 0) {
      buffer.writeln('### Attendee Participation Breakdown');
      wordCounts.forEach((speaker, words) {
        final pct = ((words / totalWords) * 100).toStringAsFixed(1);
        buffer.writeln('- **$speaker:** $pct% of spoken contributions ($words words)');
      });
      buffer.writeln();
    }

    // 2. Council Resolutions & Decisions
    buffer.writeln('## 2. Council Resolutions & Decisions');
    if (_decisions.isEmpty) {
      buffer.writeln('_No formal resolutions adopted during this session._');
    } else {
      for (final dec in _decisions) {
        buffer.writeln('- **[${dec.timestampFormatted}] ${dec.category}:** ${dec.decision}');
        buffer.writeln('  > *Citation:* "${dec.verbatimQuote}" — *${dec.speakerName} (${dec.speakerRole})*');
      }
    }
    buffer.writeln();

    // 3. Assigned Action Items Table
    buffer.writeln('## 3. Assigned Action Items');
    if (_actionItems.isEmpty) {
      buffer.writeln('_No pending action items recorded._');
    } else {
      buffer.writeln('| Action / Deliverable | Assignee | Target Date | Citation Time |');
      buffer.writeln('| :--- | :--- | :--- | :--- |');
      for (final act in _actionItems) {
        final date = act.targetDueDate ?? 'TBD';
        buffer.writeln('| ${act.task} | **${act.assignee}** | $date | [${act.timestampFormatted}] |');
      }
      buffer.writeln();
      buffer.writeln('### Action Item Verification Quotes');
      for (final act in _actionItems) {
        buffer.writeln('- **${act.assignee}:** "${act.verbatimQuote}" `[${act.timestampFormatted}]`');
      }
    }
    buffer.writeln();

    // 4. Full Clean Chronological Transcript
    buffer.writeln('## 4. Complete Clean Transcript');
    if (_transcript.isEmpty) {
      buffer.writeln('_No transcript recorded._');
    } else {
      for (final p in _transcript) {
        final time = DateFormat('HH:mm:ss').format(p.timestamp);
        buffer.writeln('**[$time] ${p.speakerName} (${p.speakerRole}):**');
        buffer.writeln('${p.text}');
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('*Generated automatically by ALIVE Scribe on-device meeting engine. 100% private & verifiable.*');

    return buffer.toString();
  }

  void dispose() {
    stopListening();
    _dataChannelSub?.cancel();
    _transcriptStreamController.close();
    _decisionsStreamController.close();
    _actionItemsStreamController.close();
  }
}

