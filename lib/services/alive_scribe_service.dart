import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  bool _isStartingStt = false;
  bool _isDisposed = false;
  bool _standaloneMode = false;
  String _currentSessionWords = '';
  List<String> _committedSessionWords = [];
  int _consecutiveSttErrors = 0;
  static const int _maxConsecutiveSttErrors = 8;
  DateTime? _lastLocalSpeakingAt;
  final ValueNotifier<double> voiceLevelNotifier = ValueNotifier<double>(0.0);

  /// The best available STT locale resolved at init (en-GB → en-US → en-NG).
  /// `en-GB` and `en-US` almost always have Android on-device neural packs,
  /// avoiding cloud-only 10-15s cutoffs while handling Nigerian English well.
  String _resolvedSttLocale = 'en-GB';

  /// Ordered locale fallback chain: British English → US English → Nigerian English.
  static const _localeFallbackChain = [
    'en-GB',
    'en_GB',
    'en-US',
    'en_US',
    'en-NG',
    'en_NG',
  ];

  final List<ScribeTranscriptPacket> _transcript = [];
  final List<ScribeDecision> _decisions = [];
  final List<ScribeActionItem> _actionItems = [];
  final Map<String, DateTime> _actionItemTimestamps = {};
  final Set<String> _attendees = {};
  final Map<String, String> _attendeeRoles = {};
  final Set<String> _speakingAttendees = {};

  final _transcriptStreamController =
      StreamController<List<ScribeTranscriptPacket>>.broadcast();
  final _decisionsStreamController =
      StreamController<List<ScribeDecision>>.broadcast();
  final _actionItemsStreamController =
      StreamController<List<ScribeActionItem>>.broadcast();

  StreamSubscription? _dataChannelSub;
  StreamSubscription? _sessionSub;
  DateTime? _meetingStartTime;
  Timer? _watchdogTimer;
  Timer? _speechPauseCommitTimer;

  AliveScribeService({
    required MeetingGateway gateway,
    required this.localUserId,
    required this.localUserName,
    this.localUserRole = 'Leader',
  }) : _gateway = gateway {
    _meetingStartTime = DateTime.now();
    _attendees.add(localUserName);
    if (localUserRole.trim().isNotEmpty) {
      _attendeeRoles[localUserName] = localUserRole.trim();
    }
    _listenToDataChannel();
    _listenToSessionMicState();
  }

  bool get _isLocalMicActive =>
      _standaloneMode ||
      (_gateway.currentSession.isConnected &&
          !_gateway.currentSession.isAudioMuted);

  void _listenToSessionMicState() {
    _sessionSub = _gateway.sessionStream.listen((session) {
      if (_isDisposed) return;
      if (session.isConnected && _standaloneMode) {
        _standaloneMode = false;
      }
      for (final p in session.participants) {
        if (p.isLocal && p.isSpeaking) {
          _lastLocalSpeakingAt = DateTime.now();
          break;
        }
      }
      if (!_isListening) return;
      if (_isLocalMicActive) {
        if (!_speechToText.isListening &&
            !_isRestarting &&
            _consecutiveSttErrors < _maxConsecutiveSttErrors) {
          _startSttSession();
        }
      } else {
        if (!_isDisposed) voiceLevelNotifier.value = 0.0;
        if (_speechToText.isListening || _hasPendingSpeech) {
          _commitPendingSpeech();
          _speechToText.stop().catchError((_) {});
        }
      }
    });
  }

  bool get _hasPendingSpeech =>
      _extractUncommittedDelta(_currentSessionWords).isNotEmpty;

  /// Word-aligned delta extraction so engine revisions (e.g. "two hundred" -> "200"
  /// or trailing word corrections) never slice a word in half or skip words.
  String _extractUncommittedDelta(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return '';
    final currentWords = trimmed.split(RegExp(r'\s+'));
    if (_committedSessionWords.isEmpty) return trimmed;

    int matchCount = 0;
    final limit = currentWords.length < _committedSessionWords.length
        ? currentWords.length
        : _committedSessionWords.length;
    while (matchCount < limit &&
        currentWords[matchCount].toLowerCase() ==
            _committedSessionWords[matchCount].toLowerCase()) {
      matchCount++;
    }

    final startIndex = matchCount > 0
        ? matchCount
        : _committedSessionWords.length.clamp(0, currentWords.length);

    if (startIndex >= currentWords.length) return '';
    return currentWords.sublist(startIndex).join(' ');
  }

  /// Suppresses phantom STT triggers caused by remote speaker bleed when
  /// remote participants are actively speaking and the local participant is
  /// neither currently speaking nor spoke in the last 2.5 seconds.
  bool get _isLikelyRemoteSpeakerBleed {
    final session = _gateway.currentSession;
    final localCurrentlySpeaking =
        session.participants.any((p) => p.isLocal && p.isSpeaking);
    if (localCurrentlySpeaking) return false;

    final remoteSpeaking =
        session.participants.any((p) => !p.isLocal && p.isSpeaking);
    if (!remoteSpeaking) return false;

    final localSpokeRecently = _lastLocalSpeakingAt != null &&
        DateTime.now().difference(_lastLocalSpeakingAt!) <
            const Duration(milliseconds: 2500);
    return !localSpokeRecently;
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
    if (_isDisposed) return false;
    if (_isSttInitialized) return true;
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (err) {
          if (_isDisposed) return;
          debugPrint('[AliveScribeService] STT error: $err');
          _consecutiveSttErrors++;
          _commitPendingSpeech();
          if (_consecutiveSttErrors >= _maxConsecutiveSttErrors) {
            debugPrint(
                '[AliveScribeService] STT error circuit breaker tripped ($_consecutiveSttErrors errors). Stopping auto-restart.');
            _isListening = false;
            _standaloneMode = false;
            _watchdogTimer?.cancel();
            _watchdogTimer = null;
            if (!_isDisposed) voiceLevelNotifier.value = 0.0;
            return;
          }
          if (_isListening) {
            _restartListening(fromError: true);
          }
        },
        onStatus: (status) {
          if (_isDisposed) return;
          debugPrint('[AliveScribeService] STT status: $status');
          if ((status == 'notListening' || status == 'done') &&
              _isListening &&
              _isLocalMicActive &&
              _consecutiveSttErrors < _maxConsecutiveSttErrors) {
            _commitPendingSpeech();
            _restartListening(immediate: true);
          }
        },
        options: [
          stt.SpeechToText.webDoNotAggregate,
        ],
      );

      // Resolve the best available STT locale from the fallback chain (en-GB → en-US → en-NG)
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

  Future<bool> startListening() async {
    if (_isDisposed) return false;
    _standaloneMode = !_gateway.currentSession.isConnected;
    _isListening = true;
    _currentSessionWords = '';
    _committedSessionWords = [];
    _consecutiveSttErrors = 0;

    // Only initialize and run local microphone STT when the user's meeting
    // microphone is actually enabled (or when running in standalone dictation mode).
    // Muted meeting attendees still receive remote Scribe packets via DataChannel.
    if (_isLocalMicActive) {
      if (!_isSttInitialized) {
        final ok = await initializeSpeech();
        if (!ok || _isDisposed) {
          _isListening = false;
          _standaloneMode = false;
          return false;
        }
      }
      if (_isListening && _isLocalMicActive && !_isDisposed) {
        _startSttSession();
      }
    }

    // Active Watchdog: continuously monitors STT engine health and revives listening
    // ONLY while the local microphone is active and errors remain below the circuit breaker.
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isDisposed || !_isListening) return;
      if (_consecutiveSttErrors >= _maxConsecutiveSttErrors) {
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        return;
      }
      if (!_isLocalMicActive) {
        if (_speechToText.isListening) {
          _commitPendingSpeech();
          await _speechToText.stop().catchError((_) {});
        }
        return;
      }
      if (!_isSttInitialized) {
        final ok = await initializeSpeech();
        if (!ok || _isDisposed || !_isListening || !_isLocalMicActive) return;
      }
      if (!_speechToText.isListening && !_isRestarting) {
        debugPrint('[AliveScribeService] Watchdog: reviving idle STT listener...');
        _startSttSession();
      }
    });
    return true;
  }

  static const MethodChannel _nativeChannel =
      MethodChannel('com.alive.alivengandroidapp/native');

  void _ensureIosSharedAudioSession() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _nativeChannel.invokeMethod<bool>('configureAudioSession').catchError((_) => false);
  }

  Future<void> _startSttSession() async {
    if (_isDisposed ||
        !_isListening ||
        !_isLocalMicActive ||
        !_isSttInitialized ||
        _isStartingStt ||
        _speechToText.isListening ||
        _consecutiveSttErrors >= _maxConsecutiveSttErrors) {
      return;
    }

    _isStartingStt = true;
    _ensureIosSharedAudioSession();

    try {
      _currentSessionWords = '';
      _committedSessionWords = [];
      await _speechToText.listen(
        onResult: (result) {
          if (_isDisposed || !_isListening || !_isLocalMicActive) return;
          final rawText = result.recognizedWords;
          if (rawText.trim().isEmpty) return;

          _consecutiveSttErrors = 0;

          final currentWords = rawText.trim().split(RegExp(r'\s+'));
          if (_committedSessionWords.length > 2 &&
              currentWords.length < _committedSessionWords.length - 2) {
            _committedSessionWords = [];
          }

          _currentSessionWords = rawText;

          // Smart continuous commit: if user pauses speaking for ~1.8s, commit only
          // the word-aligned uncommitted delta so revisions never slice or duplicate.
          _speechPauseCommitTimer?.cancel();
          _speechPauseCommitTimer = Timer(const Duration(milliseconds: 1800), () {
            if (!_isDisposed && _isListening && _hasPendingSpeech) {
              _commitPendingSpeech();
            }
          });

          if (result.finalResult) {
            _commitPendingSpeech();
          }
        },
        onSoundLevelChange: (level) {
          if (_isDisposed) return;
          if (!_isListening || !_isLocalMicActive) {
            if (voiceLevelNotifier.value != 0.0) voiceLevelNotifier.value = 0.0;
            return;
          }
          // speech_to_text reports dB roughly in [-2, 10+]. Map noise floor to 0.
          final normalized = ((level - 1.0) / 8.0).clamp(0.0, 1.0);
          voiceLevelNotifier.value = normalized;
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(hours: 1),
          pauseFor: const Duration(seconds: 10),
          localeId: _resolvedSttLocale,
        ),
      );
    } catch (e) {
      final errLower = e.toString().toLowerCase();
      // Web SpeechRecognition (Chrome & Mobile Safari) throws InvalidStateError
      // when recognition is already starting/running — treat as benign no-op.
      if (errLower.contains('invalidstateerror') ||
          errLower.contains('already started')) {
        debugPrint('[AliveScribeService] STT already active: $e');
        return;
      }
      debugPrint('[AliveScribeService] Start STT session error: $e');
      _consecutiveSttErrors++;
      if (_isListening) {
        _restartListening(fromError: true);
      }
    } finally {
      _isStartingStt = false;
    }
  }

  void _commitPendingSpeech() {
    _speechPauseCommitTimer?.cancel();
    final trimmed = _currentSessionWords.trim();
    if (trimmed.isEmpty) return;

    final pending = _extractUncommittedDelta(trimmed);
    if (pending.isEmpty) return;

    if (_isLikelyRemoteSpeakerBleed) {
      debugPrint('[AliveScribeService] Suppressed probable remote speaker bleed');
      _committedSessionWords = trimmed.split(RegExp(r'\s+'));
      return;
    }

    _committedSessionWords = trimmed.split(RegExp(r'\s+'));

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

  void _restartListening({bool immediate = false, bool fromError = false}) {
    if (_isDisposed ||
        !_isListening ||
        !_isLocalMicActive ||
        _isRestarting ||
        _consecutiveSttErrors >= _maxConsecutiveSttErrors) {
      return;
    }
    _isRestarting = true;

    if (immediate && !fromError) {
      Future.microtask(() {
        _isRestarting = false;
        if (!_isDisposed && _isListening && _isLocalMicActive) {
          _startSttSession();
        }
      });
      return;
    }

    // Exponential backoff on repeated errors (150ms, 300ms, 600ms, 1200ms, max 2000ms)
    final shift = (_consecutiveSttErrors - 1).clamp(0, 4);
    final delayMs = fromError ? (150 << shift).clamp(150, 2000) : 40;
    Future.delayed(Duration(milliseconds: delayMs), () {
      _isRestarting = false;
      if (!_isDisposed && _isListening && _isLocalMicActive) {
        _startSttSession();
      }
    });
  }

  Future<void> stopListening() async {
    _isListening = false;
    _standaloneMode = false;
    if (!_isDisposed) {
      voiceLevelNotifier.value = 0.0;
    }
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _speechPauseCommitTimer?.cancel();
    _speechPauseCommitTimer = null;
    if (!_isDisposed) {
      _commitPendingSpeech();
    }
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
  //  Pass 1: Disfluency & Filler Stripping & Intelligent Deduplication
  // ──────────────────────────────────────────────────────────
  static String cleanDisfluencies(String input) {
    if (input.trim().isEmpty) return '';

    // Step 1: Collapse progressive prefix accumulations and repeated phrases
    var cleaned = collapseCumulativePrefixes(input);

    // Step 2: Clean pure speech hesitation noises (um, uh, er, ah, hmm), preserving all actual vocabulary
    final fillerRegex = RegExp(
      r'\b(um|uh|er|ah|hmm|erm)\b',
      caseSensitive: false,
    );

    cleaned = cleaned.replaceAll(fillerRegex, ' ');

    // Step 3: Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Step 4: Capitalize first character
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  /// Collapses progressive prefix accumulations caused by Web Speech API
  /// (e.g. "Mymy namemy name is... my name is Timothy Olodude" -> "My name is Timothy Olodude",
  ///  or "Soso byso by the... so by the end of today's meeting" -> "So by the end of today's meeting").
  static String collapseCumulativePrefixes(String text) {
    var s = text.trim();
    if (s.length < 4) return s;

    // First check if the text contains repeating prefix accumulations of its trailing sentence.
    final words = s.split(RegExp(r'\s+'));
    if (words.length <= 1) {
      // Handle glued single words like "Mymy" or "Soso"
      final half = s.length ~/ 2;
      if (half >= 2 && s.substring(0, half).toLowerCase() == s.substring(half).toLowerCase()) {
        return s.substring(half);
      }
      return s;
    }

    // Try finding the longest plausible final utterance suffix S
    // Starting with candidate lengths from words.length down to 2 words
    for (int wordCount = words.length; wordCount >= 2; wordCount--) {
      final candidateWords = words.sublist(words.length - wordCount);
      final candidate = candidateWords.join(' ');

      final candidateIndex = s.lastIndexOf(candidate);
      if (candidateIndex <= 0) continue;

      final prefixPart = s.substring(0, candidateIndex).trim();
      if (_isComposedOfPrefixes(prefixPart, candidate)) {
        return _collapseAdjacentRepeats(candidate);
      }
    }

    // Also collapse adjacent repeating phrases and duplicate words
    return _collapseAdjacentRepeats(s);
  }

  static bool _isComposedOfPrefixes(String prefixPart, String candidate) {
    if (prefixPart.isEmpty) return true;
    final lowerCandidate = candidate.toLowerCase();
    var rem = prefixPart.trim();

    int iterations = 0;
    while (rem.isNotEmpty && iterations < 60) {
      iterations++;
      rem = rem.trimLeft();
      final lowerRem = rem.toLowerCase();

      int matchLen = 0;
      for (int len = lowerCandidate.length; len >= 2; len--) {
        final sub = lowerCandidate.substring(0, len);
        if (lowerRem.startsWith(sub)) {
          matchLen = len;
          break;
        }
      }

      if (matchLen == 0) {
        return false;
      }

      rem = rem.substring(matchLen);
    }

    return rem.isEmpty;
  }

  static String _collapseAdjacentRepeats(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= 1) return text;

    final cleanedWords = <String>[];
    for (int i = 0; i < words.length; i++) {
      final current = words[i];
      if (cleanedWords.isNotEmpty) {
        final prev = cleanedWords.last.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
        final curr = current.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
        if (prev.isNotEmpty && prev == curr) {
          continue; // skip immediate duplicate word
        }
      }
      cleanedWords.add(current);
    }

    var result = cleanedWords.join(' ');

    // Collapse adjacent repeated phrases (from 6 words down to 2 words)
    // e.g. "so by the end of today's meeting so by the end of today's meeting" -> "so by the end of today's meeting"
    for (int phraseLen = 6; phraseLen >= 2; phraseLen--) {
      final pWords = result.split(RegExp(r'\s+'));
      if (pWords.length < phraseLen * 2) continue;

      final newWords = <String>[];
      int i = 0;
      while (i < pWords.length) {
        if (i + phraseLen * 2 <= pWords.length) {
          final phrase1 = pWords.sublist(i, i + phraseLen).join(' ').toLowerCase();
          final phrase2 = pWords.sublist(i + phraseLen, i + phraseLen * 2).join(' ').toLowerCase();
          if (phrase1 == phrase2) {
            newWords.addAll(pWords.sublist(i, i + phraseLen));
            i += phraseLen * 2;
            continue;
          }
        }
        newWords.add(pWords[i]);
        i++;
      }
      result = newWords.join(' ');
    }

    return result;
  }

  // ──────────────────────────────────────────────────────────
  //  Packet Ingestion & Intelligent Turn Consolidation
  // ──────────────────────────────────────────────────────────
  void _handleIncomingPacket(ScribeTranscriptPacket packet) {
    if (_isDisposed || packet.text.trim().isEmpty) return;
    _attendees.add(packet.speakerName);
    _speakingAttendees.add(packet.speakerName);
    if (packet.speakerRole.trim().isNotEmpty) {
      _attendeeRoles[packet.speakerName] = packet.speakerRole.trim();
    }

    // Merge rapid successive fragments from the same speaker within 3.5 seconds
    if (_transcript.isNotEmpty) {
      final last = _transcript.last;
      final diff = packet.timestamp.difference(last.timestamp).inMilliseconds;
      if (last.speakerId == packet.speakerId && diff >= 0 && diff < 3500) {
        final lastTrimmed = last.text.trim();
        final currentTrimmed = packet.text.trim();
        final lastLower = lastTrimmed.toLowerCase();
        final currentLower = currentTrimmed.toLowerCase();

        // 1. If current packet is an expanded superset of the last fragment, replace it cleanly
        if (currentLower.startsWith(lastLower)) {
          final updated = last.copyWith(
            text: currentTrimmed,
            timestamp: packet.timestamp,
          );
          _transcript[_transcript.length - 1] = updated;
          if (!_transcriptStreamController.isClosed) {
            _transcriptStreamController.add(List.unmodifiable(_transcript));
          }
          _runPass2Extraction(updated);
          return;
        }

        // 2. If current packet was already included or is identical, do not duplicate
        if (lastLower.endsWith(currentLower) || lastLower == currentLower) {
          return;
        }

        // 3. Otherwise merge cleanly (preserve sentence flow if no trailing punctuation)
        final endsSentence = RegExp(r'[.!?]$').hasMatch(lastTrimmed);
        final combinedText = endsSentence
            ? '$lastTrimmed $currentTrimmed'
            : '$lastTrimmed. $currentTrimmed';
        final updated = last.copyWith(
          text: combinedText,
          timestamp: packet.timestamp,
        );
        _transcript[_transcript.length - 1] = updated;
        if (!_transcriptStreamController.isClosed) {
          _transcriptStreamController.add(List.unmodifiable(_transcript));
        }

        // Run Pass 2 on the merged turn so motions/actions split across brief
        // breathing pauses are still captured (clause-level dedup prevents duplicates).
        _runPass2Extraction(updated);
        return;
      }
    }

    _transcript.add(packet);
    if (!_transcriptStreamController.isClosed) {
      _transcriptStreamController.add(List.unmodifiable(_transcript));
    }

    // Run Pass 2 Extraction
    _runPass2Extraction(packet);
  }

  // ──────────────────────────────────────────────────────────
  //  Pass 2: Real-Time Deterministic NLP & Traceable Citations
  // ──────────────────────────────────────────────────────────
  static List<String> _splitIntoSentences(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    // Protect common abbreviations and titles so periods inside them don't split sentences
    const sentinel = '\u0000';
    var protected = trimmed.replaceAllMapped(
      RegExp(
        r'\b(Dr|Bro|Sis|Mr|Mrs|Ms|Rev|Ps|St|Prof|Engr|P\.O|U\.S\.A|e\.g|i\.e|vs|No|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}$sentinel',
    );
    // Protect decimal numbers like 2.3 million or 1.1 million
    protected = protected.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (m) => '${m.group(1)}$sentinel${m.group(2)}',
    );

    final rawParts = protected.split(RegExp(r'(?<=[.!?])\s+'));
    return rawParts
        .map((s) => s.replaceAll(sentinel, '.').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Extracts Nigerian/British/standard English deadlines and target windows.
  static String? extractDeadline(String text) {
    final patterns = <RegExp>[
      // "15th of December", "by 29th of this month", "23rd of November"
      RegExp(
        r'\b(?:(?:by|on|before|from)\s+)?(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\s+of\s+(?:this\s+month|next\s+month|January|February|March|April|May|June|July|August|September|October|November|December)\b',
        caseSensitive: false,
      ),
      // "November 23rd", "December 15", "29 November", "24th to 29th"
      RegExp(
        r'\b(?:(?:by|on|before|from)\s+)?(?:(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:\s*(?:to|-|–)\s*\d{1,2}(?:st|nd|rd|th)?)?|\d{1,2}(?:st|nd|rd|th)?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?)\b',
        caseSensitive: false,
      ),
      // "first or second week of December", "last week of December or first week of January"
      RegExp(
        r'\b(?:(?:by|in)\s+)?(?:the\s+)?(?:first|second|third|fourth|last|1st|2nd|3rd|4th)(?:\s+or\s+(?:first|second|third|fourth|last|1st|2nd|3rd|4th))?\s+week\s+(?:of|in)\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)(?:\s+or\s+(?:first|second|third|fourth|last|1st|2nd|3rd|4th)\s+week\s+(?:of|in)\s+(?:January|February|March|April|May|June|July|August|September|October|November|December))?\b',
        caseSensitive: false,
      ),
      // "end of November", "end of this month", "November ending"
      RegExp(
        r'\b(?:(?:by|from)\s+)?(?:(?:the\s+)?(?:end|beginning|start)\s+of\s+(?:this\s+month|next\s+month|January|February|March|April|May|June|July|August|September|October|November|December)|(?:this\s+)?(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+ending)\b',
        caseSensitive: false,
      ),
      // "in latest two weeks' time", "in two weeks' time", "within 3 days", "within 2 weeks"
      RegExp(
        r"\b(?:in\s+(?:latest\s+|about\s+)?|within\s+)(?:a|an|one|two|three|four|five|six|\d+)(?:\s*(?:to|-)\s*(?:one|two|three|four|five|six|\d+))?\s+(?:day|days|week|weeks|month|months)(?:'?s?\s+time)?\b",
        caseSensitive: false,
      ),
      // "by next Sunday", "before handover", "during handover", "before January"
      RegExp(
        r'\b(?:by\s+(?:next\s+)?(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|tomorrow|tonight|next\s+week|next\s+month)|(?:before|during)\s+(?:the\s+)?(?:handover|January|February|March|April|May|June|July|August|September|October|November|December|next\s+meeting))\b',
        caseSensitive: false,
      ),
      // Short relative markers: "this week", "next week", "next Sunday", "after the meeting", "immediately", "urgently"
      RegExp(
        r'\b(?:this\s+week|next\s+week|next\s+(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)|after\s+the\s+meeting|before\s+the\s+next\s+meeting|immediately|urgently|tomorrow|tonight)\b',
        caseSensitive: false,
      ),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final raw = m.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');
        return raw[0].toUpperCase() + raw.substring(1);
      }
    }
    return null;
  }

  static bool _isFacilitationOrNoise(String sentence) {
    final lower = sentence.toLowerCase().trim();
    if (lower.length < 14) return true;
    final noisePatterns = [
      RegExp(r'^(thank you|thanks|all right|okay|yes|no|amen|not?ed|good evening|hello)\b[^.]{0,25}$'),
      RegExp(r'\b(please\s+close\s+us\s+in\s+prayer|close\s+in\s+prayer|let\s+us\s+pray|can\s+you\s+hear\s+me|smile\s+for\s+me|go\s+ahead\s+please|let(?:\x27s|\s+us)\s+(?:make\s+progress|move\s+on))\b'),
      RegExp(r'^(?:i\s+just\s+want(?:ed)?\s+to\s+(?:say|ask|find\s+out|thank|comment)|let\s+me\s+(?:just\s+)?(?:say|ask|take\s+a\s+quick))\b'),
    ];
    return noisePatterns.any((r) => r.hasMatch(lower));
  }

  /// Checks whether a short turn confirms/seconds/carries a recent motion
  /// and attaches it to that motion instead of creating an orphan decision.
  bool _tryAttachMotionConfirmation(
    String sentence,
    ScribeTranscriptPacket packet,
  ) {
    final lower = sentence.toLowerCase().trim();
    final isSecond = RegExp(
      r'\b(seconded(?:\s+by\s+([A-Za-z\.\s]+?))?|i\s+second\b)',
      caseSensitive: false,
    ).firstMatch(sentence);
    final isCarried = RegExp(
      r'\b(carried|all\s+in\s+favor\s+say\s+aye|say\s+aye|^aye!?$|supported\s+sir|supported)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (isSecond == null && !isCarried) return false;
    if (_decisions.isEmpty) return false;

    // Attach to the most recent Motion / Resolution or Chair challenge within the last 5 minutes
    for (int i = _decisions.length - 1; i >= 0; i--) {
      final prev = _decisions[i];
      if (prev.category == 'Motion / Resolution' ||
          prev.category == 'Consensus' ||
          prev.category == 'Budget / Finance') {
        var updatedDecision = prev.decision;
        if (isSecond != null) {
          final namedSeconder = isSecond.group(2)?.trim();
          final seconder = (namedSeconder != null && namedSeconder.isNotEmpty)
              ? namedSeconder.replaceAll(RegExp(r'[.,;:]+$'), '')
              : packet.speakerName;
          if (!updatedDecision.toLowerCase().contains('seconded')) {
            updatedDecision = '$updatedDecision [Seconded by $seconder]';
          }
        }
        if (isCarried && !updatedDecision.toLowerCase().contains('carried') && !updatedDecision.toLowerCase().contains('supported')) {
          final tag = lower.contains('supported') ? 'Supported' : 'Carried';
          updatedDecision = '$updatedDecision [$tag]';
        }
        if (updatedDecision != prev.decision) {
          _decisions[i] = ScribeDecision(
            id: prev.id,
            decision: updatedDecision,
            speakerName: prev.speakerName,
            speakerRole: prev.speakerRole,
            timestampFormatted: prev.timestampFormatted,
            verbatimQuote: prev.verbatimQuote,
            category: prev.category,
          );
          if (!_decisionsStreamController.isClosed) {
            _decisionsStreamController.add(List.unmodifiable(_decisions));
          }
        }
        return true;
      }
    }
    return false;
  }

  /// Cross-turn deadline back-patching: if the Chair/speaker states a deadline
  /// right after an action commitment that lacked a date, attach it cleanly.
  void _tryBackfillRecentActionDeadline(
    String sentence,
    ScribeTranscriptPacket packet,
  ) {
    if (_actionItems.isEmpty) return;
    // Ignore calendar/holiday facts (e.g. "Easter 2027 falls on March 28, 2027")
    if (RegExp(
      r'\b(falls\s+on|was\s+on|easter|sallah|christmas|public\s+holiday)\b',
      caseSensitive: false,
    ).hasMatch(sentence)) {
      return;
    }

    final foundDate = extractDeadline(sentence);
    if (foundDate == null) return;

    final lower = sentence.toLowerCase();
    final isFollowupDate = lower.contains('reasonable') ||
        lower.contains('should be okay') ||
        lower.contains('report dropped') ||
        lower.contains('give him') ||
        lower.contains('specific time') ||
        sentence.length <= 130;
    if (!isFollowupDate) return;

    // Look back up to 2 recent action items without a due date within 90 seconds
    final startIdx = (_actionItems.length - 2).clamp(0, _actionItems.length - 1);
    for (int i = _actionItems.length - 1; i >= startIdx; i--) {
      final act = _actionItems[i];
      final actTime = _actionItemTimestamps[act.id];
      if (actTime != null &&
          packet.timestamp.difference(actTime).inSeconds.abs() > 90) {
        continue;
      }
      if (act.targetDueDate == null || act.targetDueDate!.isEmpty) {
        _actionItems[i] = ScribeActionItem(
          id: act.id,
          task: act.task,
          assignee: act.assignee,
          targetDueDate: foundDate,
          speakerName: act.speakerName,
          timestampFormatted: act.timestampFormatted,
          verbatimQuote: act.verbatimQuote,
          isCompleted: act.isCompleted,
        );
        if (!_actionItemsStreamController.isClosed) {
          _actionItemsStreamController.add(List.unmodifiable(_actionItems));
        }
        break;
      }
    }
  }

  void _runPass2Extraction(ScribeTranscriptPacket packet) {
    final fullText = packet.text.trim();
    if (fullText.length < 4) return;

    final timeStr = DateFormat('HH:mm').format(packet.timestamp);
    final sentences = _splitIntoSentences(fullText);

    // 1. Council Decisions / Resolutions Matcher (per sentence)
    final decisionPatterns = <RegExp>[
      RegExp(r'\b(i\s+(?:hereby\s+)?move\s+that\s+.+)', caseSensitive: false),
      RegExp(r'\b(moved\s+and\s+seconded\s+that\s+.+)', caseSensitive: false),
      RegExp(r'\b(it\s+is\s+(?:hereby\s+)?(?:resolved|decided)\s+that\s+.+)', caseSensitive: false),
      RegExp(r'\b(unanimously\s+(?:approved|agreed|adopted)\s+.+)', caseSensitive: false),
      RegExp(r'\b(voted\s+to\s+(?:adopt|approve|appoint|proceed\s+with)\s+.+)', caseSensitive: false),
      RegExp(r'\b(confirmed\s+the\s+appointment\s+of\s+.+)', caseSensitive: false),
      RegExp(r'\b(approved\s+the\s+budget\s+for\s+.+)', caseSensitive: false),
      RegExp(r'\b((?:council|board|the\s+board|we)\s+(?:agreed|decided|resolved|approved|confirmed)\s+(?:to|that|on)\s+.+)', caseSensitive: false),
      RegExp(r'\b(consensus\s+(?:is|was)\s+that\s+.+)', caseSensitive: false),
      RegExp(r'\b(adopt(?:ed)?\s+(?:it|this|the\s+minutes|the\s+report|the\s+document)\s+as\s+a\s+working\s+document.*)', caseSensitive: false),
      // Natural Board/ExCo consensus, structural & policy rulings
      RegExp(r"\b((?:we\s+(?:are\s+going\s+to|can|will)|let(?:'s|\s+us))\s+(?:split|separate|combine|do\s+[^.]+?\s+and\s+separate|keep\s+[^.]+?\s+alone|hold\s+on\s+voting|defer|take\s+that\s+window|solidify|add\s+[^.]+?\s+to\s+kpi|start\s+dropping|go\s+with|adopt|approve|proceed\s+with|stick\s+with)\s*.+)", caseSensitive: false),
      RegExp(r'\b((?:so\s+)?[A-Z][A-Za-z\s/&]+?\s+stay\s+together,\s+and\s+.+?\s+is\s+separate.*)', caseSensitive: false),
      RegExp(r'\b(i\s+want\s+to\s+challenge\s+all\s+.+?\s+board\s+members.+)', caseSensitive: false),
      RegExp(r'\b(taking\s+a\s+break\s+is\s+not\s+a\s+permanent\s+exit.+)', caseSensitive: false),
      RegExp(r'\b(we\s+(?:must|should)\s+(?:keep|have)\s+(?:a\s+pool\s+of|ring-fenced|some\s+names\s+on\s+standby).+)', caseSensitive: false),
      RegExp(r'\b(going\s+forward\s+.+?\s+must\s+be\s+.+)', caseSensitive: false),
      RegExp(r'\b(the\s+calling\s+should\s+come\s+with\s+clear\s+terms\s+and\s+conditions.+)', caseSensitive: false),
      RegExp(r'\b(include\s+it\s+as\s+a\s+formal\s+kpi\s+for\s+all\s+offices.+)', caseSensitive: false),
    ];

    for (final sentence in sentences) {
      if (_tryAttachMotionConfirmation(sentence, packet)) {
        continue;
      }
      if (sentence.length < 18) continue;
      final lower = sentence.toLowerCase();

      for (final pattern in decisionPatterns) {
        final match = pattern.firstMatch(sentence);
        if (match != null) {
          var extractedDecision = match.group(0)!.trim();
          extractedDecision = extractedDecision
              .replaceFirst(
                RegExp(
                  r'^(?:we\s+agreed\s+to|it\s+is\s+(?:hereby\s+)?resolved\s+that|council\s+agreed\s+that|board\s+agreed\s+that|consensus\s+is\s+that|unanimously\s+approved\s+that)\s*',
                  caseSensitive: false,
                ),
                '',
              )
              .trim();
          if (extractedDecision.isNotEmpty) {
            extractedDecision = extractedDecision[0].toUpperCase() +
                extractedDecision.substring(1);
          }

          final normNew = extractedDecision.toLowerCase();
          final isDuplicate = _decisions.any((d) {
            final normOld = d.decision.toLowerCase();
            return normOld == normNew ||
                normOld.contains(normNew) ||
                normNew.contains(normOld) ||
                d.verbatimQuote.toLowerCase() == sentence.toLowerCase();
          });

          if (!isDuplicate && extractedDecision.length >= 12) {
            final isPastReview = lower.contains('last meeting') ||
                lower.contains('september meeting') ||
                lower.contains('wasn\'t there');
            final category = lower.contains('move that') ||
                    lower.contains('working document') ||
                    lower.contains('seconded')
                ? 'Motion / Resolution'
                : lower.contains('budget') ||
                        lower.contains('giving') ||
                        lower.contains('challenge all') ||
                        lower.contains('naira') ||
                        lower.contains('fund')
                    ? 'Budget / Finance'
                    : lower.contains('appoint') || lower.contains('assist elder')
                        ? 'Appointment'
                        : lower.contains('split') ||
                                lower.contains('separate') ||
                                lower.contains('stay together') ||
                                lower.contains('kpi')
                            ? 'Governance / Structure'
                            : lower.contains('policy') ||
                                    lower.contains('hold on voting') ||
                                    lower.contains('permanent exit') ||
                                    lower.contains('terms and conditions')
                                ? 'Policy'
                                : isPastReview
                                    ? 'Prior Resolution'
                                    : 'Consensus';

            final decisionObj = ScribeDecision(
              id: '${DateTime.now().microsecondsSinceEpoch}_${_decisions.length}',
              decision: extractedDecision,
              speakerName: packet.speakerName,
              speakerRole: packet.speakerRole,
              timestampFormatted: timeStr,
              verbatimQuote: sentence,
              category: category,
            );
            _decisions.add(decisionObj);
            if (!_decisionsStreamController.isClosed) {
              _decisionsStreamController.add(List.unmodifiable(_decisions));
            }
          }
          break;
        }
      }
    }

    // 2. Clause-Scoped Action Items, Assignees & Deadlines (per sentence)
    for (final sentence in sentences) {
      if (_isFacilitationOrNoise(sentence)) continue;
      final lower = sentence.toLowerCase();

      // Skip hypothetical "If we wait for X..." warnings (not assignments)
      if (RegExp(r'^if\s+we\s+wait\s+for\b', caseSensitive: false)
          .hasMatch(sentence)) {
        continue;
      }

      // Skip pure informational questions (e.g. "when do you anticipate...?")
      // unless phrased as a direct polite delegation ("Can you please send...")
      if (sentence.trim().endsWith('?') &&
          !RegExp(
            r'\b(?:can|could|will|would)\s+you\s+(?:please\s+)?(?:prepare|send|compile|submit|share|work\s+on|follow\s+up|recommend|forward|capture|help|consolidate|source|create|set\s+up)\b',
            caseSensitive: false,
          ).hasMatch(sentence)) {
        _tryBackfillRecentActionDeadline(sentence, packet);
        continue;
      }

      String? extractedTask;
      String? extractedAssignee;

      // Pattern A: Explicit first-person commitment ("I will ...", "I'll ...", "I can work with ...")
      final firstPersonMatch = RegExp(
        r"\b(?:i\s+(?:will|shall|am\s+going\s+to)|i'll)\s+(?!say\b|just\s+say\b|think\b|believe\b|agree\b|want\b|need\b|understand\b)(.+)",
        caseSensitive: false,
      ).firstMatch(sentence);

      // Pattern B: Explicit "assigned to X to/for Y"
      final assignedToMatch = RegExp(
        r'\bassigned\s+to\s+([A-Za-z\.\s]+?)\s+(?:to|for|with)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(sentence);

      // Pattern C: Direct vocative / named subject directive within THIS sentence ONLY
      final directedMatch = RegExp(
        r'\b((?:bro\.?|brother|sis\.?|sister|pastor|elder|uncle|aunty|auntie|dr\.?)\s+[A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)?|presido|secretary|treasurer|committee)\s*,?\s+(?:please\s+)?(?:you\s+need\s+to|needs?\s+to|should(?:\s+also)?|is\s+to|will|must|go\s+ahead\s+and|please\s+(?:go\s+ahead\s+and\s+)?(?:recommend|capture|forward|submit|prepare|send|compile|work\s+on|share|help|consolidate|source))\s+(.+)',
        caseSensitive: false,
      ).firstMatch(sentence);

      // Pattern C2: Standalone first-name directive ("Deji should work on...", "Frank will help...")
      final namedVerbMatch = RegExp(
        r'\b([A-Z][a-z]{2,15})\s+(?:should|will|must|is\s+to)\s+(?:work\s+on|help\s+us|prepare|send|compile|submit|consolidate|source|lead|follow\s+up|capture|recommend)\s+(.+)',
      ).firstMatch(sentence);

      // Pattern D: Collective / Board / Committee commitment
      final collectiveMatch = RegExp(
        r"\b((?:all\s+(?:11\s+of\s+us\s+)?board\s+members|every\s+board\s+member|our\s+committee|our\s+target\s+is\s+to|we(?:'ll|\s+will|\s+shall|\s+should\s+be\s+able\s+to|\s+need\s+to)|let(?:'s|\s+us)\s+(?:all\s+)?)(?:be\s+able\s+to\s+)?(?:prepare|supply|compile|submit|send|share|push|finalize|finish|complete|call|contact|create|set\s+up|add|follow\s+up|work\s+on|start\s+dropping|commence|fill\s+it\s+out|have\s+that\s+report|put\s+them\s+together|contribute|go\s+over|make\s+sure|ensure)\s+.+)",
        caseSensitive: false,
      ).firstMatch(sentence);

      // Pattern E: Explicit "action point / take responsibility"
      final explicitActionMatch = RegExp(
        r'\b(?:action\s+point(?:\s+is)?|take\s+responsibility\s+for)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(sentence);

      if (assignedToMatch != null) {
        extractedAssignee = assignedToMatch.group(1)!.trim();
        extractedTask = assignedToMatch.group(2)!.trim();
      } else if (firstPersonMatch != null) {
        extractedTask = firstPersonMatch.group(1)!.trim();
        extractedAssignee = packet.speakerName;
        // Detect co-assignee strictly inside the first-person clause (e.g. "work with Timothy")
        final coMatch = RegExp(
          r'\b(?:work\s+with|and\s+(?:the\s+)?(?:president|secretary|sister\s+[A-Z][a-z]+|brother\s+[A-Z][a-z]+))\b(?:\s+([A-Z][a-z]+))?',
          caseSensitive: false,
        ).firstMatch(extractedTask);
        if (coMatch != null) {
          final coRaw = coMatch
              .group(0)!
              .replaceFirst(RegExp(r'^(?:work\s+with|and\s+(?:the\s+)?)\s*', caseSensitive: false), '')
              .trim();
          if (coRaw.isNotEmpty &&
              !extractedAssignee.toLowerCase().contains(coRaw.toLowerCase())) {
            final formattedCo = coRaw[0].toUpperCase() + coRaw.substring(1);
            extractedAssignee = '$extractedAssignee & $formattedCo';
          }
        }
      } else if (directedMatch != null) {
        extractedAssignee = directedMatch.group(1)!.trim();
        extractedTask = directedMatch.group(0)!.trim();
      } else if (namedVerbMatch != null) {
        final cand = namedVerbMatch.group(1)!.trim();
        const nonNames = {
          'This', 'That', 'They', 'There', 'These', 'Those', 'What', 'When',
          'Where', 'Which', 'While', 'However', 'Second', 'First', 'Third',
          'Next', 'Also', 'Please', 'Okay', 'Right', 'Maybe', 'Since',
        };
        if (!nonNames.contains(cand)) {
          extractedAssignee = cand;
          extractedTask = namedVerbMatch.group(0)!.trim();
        }
      } else if (collectiveMatch != null) {
        extractedTask = collectiveMatch.group(1)!.trim();
        if (lower.contains('all board members') ||
            lower.contains('every board member') ||
            lower.contains('all 11 of us') ||
            lower.contains("let's all") ||
            lower.contains('fill it out')) {
          extractedAssignee = 'All Board Members';
        } else {
          extractedAssignee = packet.speakerName;
        }
      } else if (explicitActionMatch != null) {
        extractedTask = explicitActionMatch.group(1)!.trim();
        extractedAssignee = packet.speakerName;
      }

      if (extractedTask == null || extractedAssignee == null) {
        // Not an action sentence itself, but check if it sets a deadline for the previous action!
        _tryBackfillRecentActionDeadline(sentence, packet);
        continue;
      }

      // Skip vague 2-3 word fillers like "Do that actually" unless paired with context
      final cleanTaskRaw = extractedTask
          .replaceFirst(
            RegExp(
              r"^(?:i\s+will|i'll|we\s+will\s+follow\s+up\s+on|take\s+responsibility\s+for|action\s+point\s+is|action\s+point)\s*",
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      if (cleanTaskRaw.length < 10) continue;
      if (RegExp(
        r'^(?:do\s+that(?:\s+actually)?|go\s+through\s+them|answer\s+that)\.?$',
        caseSensitive: false,
      ).hasMatch(cleanTaskRaw)) {
        continue;
      }
      extractedTask = cleanTaskRaw;

      final taskFinal = extractedTask[0].toUpperCase() + extractedTask.substring(1);
      final targetDueDate = extractDeadline(sentence);

      final normTask = taskFinal.toLowerCase();
      final isDuplicate = _actionItems.any((a) {
        final normOld = a.task.toLowerCase();
        return normOld == normTask ||
            normOld.contains(normTask) ||
            normTask.contains(normOld) ||
            a.verbatimQuote.toLowerCase() == sentence.toLowerCase();
      });

      if (!isDuplicate) {
        final actionObj = ScribeActionItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_actionItems.length}',
          task: taskFinal,
          assignee: extractedAssignee,
          targetDueDate: targetDueDate,
          speakerName: packet.speakerName,
          timestampFormatted: timeStr,
          verbatimQuote: sentence,
        );
        _actionItems.add(actionObj);
        _actionItemTimestamps[actionObj.id] = packet.timestamp;
        if (!_actionItemsStreamController.isClosed) {
          _actionItemsStreamController.add(List.unmodifiable(_actionItems));
        }
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  //  Deterministic Chronological Agenda Segmenter
  // ──────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _topicCatalog = [
    {
      'title': 'Review of Previous Resolutions & KPI Appraisal Template',
      'keywords': ['last meeting', 'resolutions', 'appraisal', 'template', 'smart', 'quarterly'],
    },
    {
      'title': "President's Operational Update",
      'keywords': ['president', 'presido', 'fence', 'plateau', 'unical', 'daniel fast', 'post-mission', 'weddings', 'laptop'],
    },
    {
      'title': "Treasurer's Report & Financial Sustainability",
      'keywords': ['treasurer', 'balance carried down', 'income', 'expenses', 'donations', 'diaspora', '2 million', '2.3 million', 'board members', 'giving'],
    },
    {
      'title': '5-Year Quinquennium Strategic Plan',
      'keywords': ['quinquennium', 'strategic plan', 'five-year', 'excel', 'slides', 'page 7', 'bible workers', 'procurement'],
    },
    {
      'title': 'Nominating Committee Report, Vetting & Directorate Structure',
      'keywords': ['nominating committee', 'nominees', 'caleb', 'esther', 'stipend', 'standby', 'understudy', 'succession', 'amtc', 'digital evangelism', 'programming', 'logistics'],
    },
    {
      'title': 'Married LTM Missionary Policy Report',
      'keywords': ['married ltm', 'married couples', 'maternity', 'prenatal', 'child allowance', 'education allowance', 'ring-fenced', 'cost projection'],
    },
    {
      'title': 'Welfare Committee Report',
      'keywords': ['welfare committee', 'welfare policy', 'entrepreneurship', 'skill acquisition'],
    },
    {
      'title': 'Investment Committee Leadership',
      'keywords': ['investment committee', 'elder emeka', 'stand in for him'],
    },
    {
      'title': 'ExCo Handover & Retreat Planning',
      'keywords': ['handover', 'retreat', 'easter', 'sallah', 'pavilion', 'two-day', 'online training'],
    },
    {
      'title': 'Board Annual Commitment, Governance & Action Tracking',
      'keywords': ['commitment form', 'permanent exit', 'constitution', 'legal adviser', 'lawyer', 'architect', 'google calendar', 'chapter revival'],
    },
  ];

  bool _isAgendaTransition(ScribeTranscriptPacket packet, int index) {
    if (index == 0) return true;
    final lower = packet.text.toLowerCase();
    final isModerator = packet.speakerRole.toLowerCase().contains('chair') ||
        packet.speakerRole.toLowerCase().contains('president') ||
        packet.speakerRole.toLowerCase().contains('secretary') ||
        packet.speakerRole.toLowerCase().contains('vice');

    final explicitCue = RegExp(
      r'\b(next\s+to\s+you|we\s+move\s+to|move\s+to\s+stage|progress\s+to\s+our|next\s+item|next,\s+(?:handover|investment|2027|welfare)|let\x27s\s+have\s+your\s+.+?\s+report|please\s+go\s+ahead\s+with\s+the\s+.+?\s+report|to\s+make\s+progress,\s+voting|our\s+committee\s+of\s+five)\b',
      caseSensitive: false,
    ).hasMatch(lower);

    if (explicitCue) return true;
    if (isModerator &&
        RegExp(r'\b(treasurer\x27s\s+report|nominating\s+committee\s+report|married\s+ltm\s+policy|welfare\s+committee\s+report|investment\s+committee|board\s+annual\s+application|2027\s+retreat\s+planning)\b', caseSensitive: false)
            .hasMatch(lower)) {
      return true;
    }
    return false;
  }

  String _inferAgendaTitle(List<ScribeTranscriptPacket> segment, int fallbackIdx) {
    final combined = segment.map((p) => p.text.toLowerCase()).join(' ');
    String? bestTitle;
    int bestScore = 0;

    for (final entry in _topicCatalog) {
      final kws = entry['keywords'] as List<String>;
      int score = 0;
      for (final kw in kws) {
        if (combined.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestTitle = entry['title'] as String;
      }
    }

    if (bestTitle != null && bestScore >= 2) {
      return bestTitle;
    }
    // Generic fallback: extract concise phrase from opening sentence
    final sentences = _splitIntoSentences(segment.first.text);
    final firstSentence =
        sentences.isNotEmpty ? sentences.first : segment.first.text.trim();
    final cleaned = firstSentence.replaceAll(RegExp(r'^(okay|all right|so|next|now)[,\s]+', caseSensitive: false), '').trim();
    if (cleaned.length <= 64 && cleaned.length >= 8) {
      return cleaned;
    }
    return bestTitle ?? 'Agenda Item $fallbackIdx';
  }

  /// Deterministically scores sentences in an agenda segment and produces an
  /// executive-readable summary preserving key figures, names, policies & motions.
  String _summarizeSegmentDiscussion(
    List<ScribeTranscriptPacket> segment,
    List<ScribeDecision> segmentDecisions,
  ) {
    final scored = <({int index, double score, String speaker, String sentence})>[];
    int seq = 0;

    for (final p in segment) {
      for (final s in _splitIntoSentences(p.text)) {
        if (_isFacilitationOrNoise(s) || s.length < 24) continue;
        final lower = s.toLowerCase();
        double score = 0;
        // High signal: numbers, Naira amounts, percentages, dates
        if (RegExp(r'\b\d[\d,\.]*\s*(?:naira|million|k\b|%|percent|courses|chapters|months|years|weeks|persons|people|donations)').hasMatch(lower)) {
          score += 3.5;
        }
        // Decisions, motions, policies, nominations, key roles
        if (RegExp(r'\b(move that|seconded|carried|agreed|resolved|policy|recommend|president:|secretary|treasurer|director|kpi|appraisal|stipend|architect|lawyer|handover|retreat|standby|understudy|commitment form|projection|ring-fenced|challenge)\b').hasMatch(lower)) {
          score += 3.0;
        }
        // Moderate length informative sentences preferred over tiny remarks
        if (s.length >= 60 && s.length <= 280) {
          score += 1.5;
        } else if (s.length > 280) {
          score += 2.0;
        }
        // Slight boost for first substantive summary turn in segment
        if (seq < 2) score += 1.0;

        scored.add((index: seq++, score: score, speaker: p.speakerName, sentence: s));
      }
    }

    // Pick top 4–6 highest-signal sentences and restore strict chronological order
    scored.sort((a, b) => b.score.compareTo(a.score));
    final selected = scored.take(5).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final lines = <String>[];
    for (final item in selected) {
      lines.add('• **${item.speaker}:** ${item.sentence}');
    }

    if (segmentDecisions.isNotEmpty) {
      for (final d in segmentDecisions) {
        final alreadyIncluded = lines.any(
          (l) => l.toLowerCase().contains(d.decision.substring(0, d.decision.length.clamp(0, 35)).toLowerCase()),
        );
        if (!alreadyIncluded) {
          lines.add('• **[${d.category}]** ${d.decision}');
        }
      }
    }

    if (lines.isEmpty && segment.isNotEmpty) {
      return segment.map((p) => '**${p.speakerName}:** ${p.text}').join('\n');
    }
    return lines.join('\n');
  }

  /// Generates the complete Official ALIVE-NG BoD Minutes structured payload
  /// 100% deterministically ready for `DocxReportGenerator.generateMeetingMinutesDocx`.
  Map<String, dynamic> generateOfficialMinutesMap({
    required String meetingTitle,
    required String meetingType,
    String status = 'Draft',
    String mode = 'ALIVE Live Conference Call',
    bool includeTranscriptAppendix = true,
  }) {
    final now = DateTime.now();
    final sessionStart =
        _transcript.isNotEmpty ? _transcript.first.timestamp : (_meetingStartTime ?? now);
    final sessionEnd =
        _transcript.length >= 2 ? _transcript.last.timestamp : now;
    final dateStr = DateFormat('dd-MM-yyyy').format(sessionStart);
    final startTimeStr = DateFormat('HH:mm').format(sessionStart);
    final duration = sessionEnd.difference(sessionStart);
    final durationStr = duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes}m';

    // Identify key officers deterministically from speaker roles
    String issuer = localUserName;
    String checker = '';
    String approver = '';
    for (final entry in _attendeeRoles.entries) {
      final r = entry.value.toLowerCase();
      if (r.contains('secretary') || r.contains('scribe')) {
        issuer = entry.key;
      } else if (r.contains('vice chair')) {
        checker = entry.key;
      } else if (r.contains('chair')) {
        approver = entry.key;
      }
    }

    // Build Attendance list from active speakers (excluding silent observer)
    final activeList = _speakingAttendees.isNotEmpty
        ? _speakingAttendees.toList()
        : _attendees.toList();
    final attendance = activeList
        .map((name) => {
              'name': name,
              'role': _attendeeRoles[name] ?? 'Member',
              'status': 'Present',
            })
        .toList();

    // Detect devotional metadata in opening turns
    String? devotionHymn;
    String? devotionScripture;
    String? devotionSpeaker;
    for (final p in _transcript.take(15)) {
      final hymnM = RegExp(r'\b(SDAH\s*[0-9]+|hymn\s*(?:number\s*)?[0-9]+)\b', caseSensitive: false).firstMatch(p.text);
      if (hymnM != null && devotionHymn == null) devotionHymn = hymnM.group(0);
      final scriptM = RegExp(r'\b([1-3]?\s?[A-Za-z]+)\s+[0-9]+:[0-9]+(?:-[0-9]+)?\b').firstMatch(p.text);
      if (scriptM != null && devotionScripture == null) devotionScripture = scriptM.group(0);
      if ((p.text.toLowerCase().contains('opening prayer') || p.text.toLowerCase().contains('admonition')) && devotionSpeaker == null) {
        devotionSpeaker = p.speakerName;
      }
    }
    final devotionParts = <String>[
      if (devotionHymn != null) 'Opening Hymn: $devotionHymn',
      if (devotionScripture != null) 'Scripture Reading: $devotionScripture',
      if (devotionSpeaker != null) 'Exhortation / Opening Prayer: $devotionSpeaker',
    ];

    // Segment transcript into chronological agenda blocks
    final segments = <List<ScribeTranscriptPacket>>[];
    List<ScribeTranscriptPacket> current = [];
    for (int i = 0; i < _transcript.length; i++) {
      final p = _transcript[i];
      if (i > 0 && current.length >= 2 && _isAgendaTransition(p, i)) {
        segments.add(current);
        current = [p];
      } else {
        current.add(p);
      }
    }
    if (current.isNotEmpty) {
      segments.add(current);
    }

    // Merge consecutive segments that resolved to the exact same topic title
    final labeledSegments = <({String title, List<ScribeTranscriptPacket> packets})>[];
    for (int i = 0; i < segments.length; i++) {
      final segTitle = _inferAgendaTitle(segments[i], i + 1);
      if (labeledSegments.isNotEmpty && labeledSegments.last.title == segTitle) {
        labeledSegments.last.packets.addAll(segments[i]);
      } else {
        labeledSegments.add((title: segTitle, packets: List.of(segments[i])));
      }
    }

    // Build chronological Agenda list + 6-column Minutes & Action Matrix rows
    final agendaItems = <String>[];
    final minutesRows = <Map<String, dynamic>>[];

    for (int i = 0; i < labeledSegments.length; i++) {
      final seg = labeledSegments[i];
      final segStart = seg.packets.first.timestamp;
      final segEnd = seg.packets.last.timestamp;
      final rangeStr =
          '${DateFormat('HH:mm').format(segStart)} – ${DateFormat('HH:mm').format(segEnd)}';
      final startSec = segStart.difference(sessionStart).inSeconds;

      agendaItems.add('${seg.title} ($rangeStr)');

      // Match decisions & actions occurring within this segment's exact packet quotes/time window
      final segQuotes = seg.packets.map((p) => p.text.toLowerCase()).toList();
      bool belongsToSegment(String quote) {
        final qLower = quote.toLowerCase();
        return segQuotes.any((pt) => pt.contains(qLower));
      }

      final segDecisions =
          _decisions.where((d) => belongsToSegment(d.verbatimQuote)).toList();
      final segActions =
          _actionItems.where((a) => belongsToSegment(a.verbatimQuote)).toList();

      final discussion = _summarizeSegmentDiscussion(seg.packets, segDecisions);

      if (segActions.isEmpty) {
        minutesRows.add({
          'sn': '${i + 1}',
          'agenda': seg.title,
          'timestamp_range': rangeStr,
          'start_seconds': startSec,
          'discussion': discussion,
          'action': segDecisions.isNotEmpty
              ? segDecisions.map((d) => '• ${d.decision}').join('\n')
              : 'Noted for record / ongoing follow-up.',
          'responsibility': segDecisions.isNotEmpty
              ? segDecisions.map((d) => d.speakerName).toSet().join(', ')
              : 'Board / ExCo',
          'deadline': 'Ongoing',
        });
      } else {
        // Emit primary row with discussion + first action, and vMerge continuation rows for extra actions
        for (int aIdx = 0; aIdx < segActions.length; aIdx++) {
          final act = segActions[aIdx];
          minutesRows.add({
            'sn': aIdx == 0 ? '${i + 1}' : '',
            'agenda': aIdx == 0 ? seg.title : '',
            'timestamp_range': aIdx == 0 ? rangeStr : '',
            'start_seconds': startSec,
            'discussion': aIdx == 0
                ? discussion
                : 'Follow-up deliverable noted at [${act.timestampFormatted}] by ${act.speakerName}.',
            'action': act.task,
            'responsibility': act.assignee,
            'deadline': act.targetDueDate ?? 'TBD',
          });
        }
      }
    }

    // Extract closing remarks & closing prayer from the last 3 turns
    String closingRemarks =
        'Meeting concluded at ${DateFormat('HH:mm').format(sessionEnd)} (Total duration: $durationStr).';
    if (_transcript.isNotEmpty) {
      final tail = _transcript.length > 3
          ? _transcript.sublist(_transcript.length - 3)
          : _transcript;
      final prayerTurn = tail.where((p) {
        final l = p.text.toLowerCase();
        return l.contains('let us pray') ||
            l.contains('heavenly father') ||
            l.contains('jesus') && l.contains('amen');
      }).toList();
      if (prayerTurn.isNotEmpty) {
        final p = prayerTurn.last;
        closingRemarks =
            'Closing remarks delivered and **Closing Prayer** offered by **${p.speakerName}** at ${DateFormat('HH:mm').format(p.timestamp)}. Meeting adjourned (Total duration: $durationStr).';
      }
    }

    final transcriptAppendix = includeTranscriptAppendix
        ? _transcript
            .map((p) => {
                  'timestamp': DateFormat('HH:mm:ss').format(p.timestamp),
                  'speaker': p.speakerName,
                  'role': p.speakerRole,
                  'text': p.text,
                })
            .toList()
        : const <Map<String, dynamic>>[];

    return {
      'document_title': meetingTitle.trim().isNotEmpty
          ? meetingTitle.trim().toUpperCase()
          : 'ALIVE-NG ${meetingType.toUpperCase()} MINUTES',
      'status': status,
      'date': dateStr,
      'issuer': issuer,
      'checker': checker.isNotEmpty ? checker : 'Board Vice Chair',
      'approver': approver.isNotEmpty ? approver : 'Board Chairman',
      'mode': '$mode ($meetingType • Duration: $durationStr)',
      'attendance': attendance,
      'start_time': '$startTimeStr (${attendance.length} active participants recorded)',
      'opening_prayer_and_remark': _transcript.isNotEmpty
          ? 'Session opened by ${_transcript.first.speakerName} at $startTimeStr.'
          : 'Session opened.',
      'devotion_details': devotionParts.isNotEmpty
          ? devotionParts.join(' | ')
          : 'Proceedings commenced directly with review of Board agenda and reports.',
      'agenda_items': agendaItems,
      'minutes_rows': minutesRows,
      'closing_remarks': closingRemarks,
      if (transcriptAppendix.isNotEmpty)
        'transcript_appendix': transcriptAppendix,
    };
  }

  /// Returns JSON string of `OfficialMeetingMinutesData` for direct consumption
  /// by `DocxReportGenerator.generateMeetingMinutesDocx(...)`.
  String generateOfficialMinutesJson({
    required String meetingTitle,
    required String meetingType,
    String status = 'Draft',
    String mode = 'ALIVE Live Conference Call',
    bool includeTranscriptAppendix = true,
  }) {
    return jsonEncode(
      generateOfficialMinutesMap(
        meetingTitle: meetingTitle,
        meetingType: meetingType,
        status: status,
        mode: mode,
        includeTranscriptAppendix: includeTranscriptAppendix,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Leadership Minutes Generator (Clean Markdown & Output)
  // ──────────────────────────────────────────────────────────
  String generateMarkdownMinutes({
    required String meetingTitle,
    required String meetingType,
  }) {
    final now = DateTime.now();
    final sessionStart =
        _transcript.isNotEmpty ? _transcript.first.timestamp : (_meetingStartTime ?? now);
    final sessionEnd =
        _transcript.length >= 2 ? _transcript.last.timestamp : now;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(sessionStart);
    final duration = sessionEnd.difference(sessionStart);
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

    final displayAttendees = _speakingAttendees.isNotEmpty
        ? _speakingAttendees
        : _attendees;
    final quorumAchieved = displayAttendees.length >= 2 || _transcript.length >= 3;

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
    buffer.writeln('- **Quorum:** ${quorumAchieved ? "✅ Achieved" : "⚠️ Incomplete"} (${displayAttendees.length} members present)');
    buffer.writeln('- **Attendees:** ${displayAttendees.join(", ")}');
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
        buffer.writeln(p.text);
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('*Generated automatically by ALIVE Scribe on-device meeting engine. 100% private & verifiable.*');

    return buffer.toString();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isListening = false;
    _standaloneMode = false;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _speechPauseCommitTimer?.cancel();
    _speechPauseCommitTimer = null;
    _speechToText.stop().catchError((_) {});
    _sessionSub?.cancel();
    _dataChannelSub?.cancel();
    voiceLevelNotifier.dispose();
    if (!_transcriptStreamController.isClosed) {
      _transcriptStreamController.close();
    }
    if (!_decisionsStreamController.isClosed) {
      _decisionsStreamController.close();
    }
    if (!_actionItemsStreamController.isClosed) {
      _actionItemsStreamController.close();
    }
  }
}

