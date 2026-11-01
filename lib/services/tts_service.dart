import 'platform/tts_adapter.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  static final Logger _logger = Logger('TTSService');
  factory TTSService() => _instance;
  TTSService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  final List<VoidCallback> _completionListeners = [];
  final List<VoidCallback> _startListeners = [];
  final List<void Function(dynamic)> _errorListeners = [];

  void addCompletionListener(VoidCallback listener) => _completionListeners.add(listener);
  void removeCompletionListener(VoidCallback listener) => _completionListeners.remove(listener);

  void addStartListener(VoidCallback listener) => _startListeners.add(listener);
  void removeStartListener(VoidCallback listener) => _startListeners.remove(listener);

  void addErrorListener(void Function(dynamic) listener) => _errorListeners.add(listener);
  void removeErrorListener(void Function(dynamic) listener) => _errorListeners.remove(listener);

  Future<void> initialize() async {
    if (_isInitialized && _flutterTts != null) return;

    try {
      _flutterTts = FlutterTts();

      _flutterTts!.setStartHandler(() {
        _isSpeaking = true;
        for (final l in List.of(_startListeners)) {
          l();
        }
      });

      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        for (final l in List.of(_completionListeners)) {
          l();
        }
      });

      _flutterTts!.setErrorHandler((msg) {
        _isSpeaking = false;
        _logger.warning('TTS error event: $msg');
        for (final l in List.of(_errorListeners)) {
          l(msg);
        }
      });

      _flutterTts!.setCancelHandler(() {
        _isSpeaking = false;
        for (final l in List.of(_completionListeners)) {
          l();
        }
      });

      // Configure for human-like voice
      await _configureVoice();
      _isInitialized = true;
    } catch (e) {
      _logger.warning('TTS Initialization warning: $e');
      _isInitialized = true; // Mark initialized to allow fallback speak attempts
    }
  }

  Future<void> _configureVoice() async {
    if (_flutterTts == null) return;

    try {
      // Set language to English (US) for default base
      await _flutterTts!.setLanguage('en-US');

      // Set speech rate for natural conversation pace
      await _flutterTts!.setSpeechRate(0.5);

      // Set volume to full
      await _flutterTts!.setVolume(1.0);

      // Set pitch for more natural sound
      await _flutterTts!.setPitch(1.0);

      // Try selecting high quality voice
      try {
        final voices = await _flutterTts!.getVoices;
        if (voices is List && voices.isNotEmpty) {
          final bestVoice = _selectBestVoice(voices);
          if (bestVoice != null) {
            await _flutterTts!.setVoice({"name": bestVoice, "locale": "en-US"});
          }
        }
      } catch (voiceError) {
        _logger.debug('Voice query skipped or unsupported: $voiceError');
      }

      // Set speech engine if available (for Android)
      if (!kIsWeb) {
        try {
          await _flutterTts!.setEngine('com.google.android.tts');
        } catch (_) {}
      }
    } catch (e) {
      _logger.warning('TTS Configuration Warning (using platform default): $e');
    }
  }

  String? _selectBestVoice(List<dynamic> voices) {
    List<String> preferredVoices = [
      'en-us-x-sfg#female_2-local',
      'en-us-x-sfg#male_1-local',
      'en-US-Neural2-A',
      'en-US-Neural2-C',
      'en-US-AriaNeural',
      'en-US-JennyNeural',
      'com.apple.ttsbundle.Samantha-compact',
      'com.apple.ttsbundle.Alex-compact',
      'en-us-x-iol-local',
      'en-us-x-iom-local',
    ];

    for (String preferred in preferredVoices) {
      for (var voice in voices) {
        String voiceName = voice['name']?.toString() ?? '';
        if (voiceName.toLowerCase().contains(preferred.toLowerCase())) {
          return voiceName;
        }
      }
    }

    for (var voice in voices) {
      String voiceName = voice['name']?.toString() ?? '';
      String locale = voice['locale']?.toString() ?? '';

      if (locale.toLowerCase().startsWith('en')) {
        String lowerName = voiceName.toLowerCase();
        if (lowerName.contains('neural') ||
            lowerName.contains('enhanced') ||
            lowerName.contains('premium') ||
            lowerName.contains('natural')) {
          return voiceName;
        }
      }
    }

    return null;
  }

  Future<void> speak(
    String text, {
    String? languageCode,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) async {
    try {
      if (!_isInitialized || _flutterTts == null) {
        await initialize();
      }

      if (_flutterTts == null || text.trim().isEmpty) return;

      // Handle language configuration
      if (languageCode != null && languageCode.isNotEmpty) {
        final langTag = {
          'yo': 'yo-NG',
          'ha': 'ha-NG',
          'ig': 'ig-NG',
          'en': 'en-US',
        }[languageCode] ?? languageCode;

        try {
          await _flutterTts!.setLanguage(langTag);
        } catch (_) {
          // If local African dialect tag is unsupported by host engine, fall back to en-US
          await _flutterTts!.setLanguage('en-US');
        }
      }

      if (onStart != null) {
        _startListeners.add(onStart);
      }
      if (onComplete != null) {
        _completionListeners.add(onComplete);
      }

      final cleanText = _cleanTextForSpeech(text);
      _isSpeaking = true;
      await _flutterTts!.speak(cleanText);
    } catch (e) {
      _isSpeaking = false;
      _logger.error('Error speaking text', e);
      onComplete?.call();
    }
  }

  String _cleanTextForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\n\r]+'), '. ')
        .replaceAll(RegExp(r'\.\.+'), '.')
        .replaceAll(RegExp(r'!!+'), '!')
        .replaceAll(RegExp(r'\?\?+'), '?')
        .trim();
  }

  Future<void> stop() async {
    _isSpeaking = false;
    try {
      if (_flutterTts != null) {
        await _flutterTts!.stop();
      }
    } catch (_) {}
    for (final l in List.of(_completionListeners)) {
      l();
    }
  }

  Future<void> pause() async {
    try {
      if (_flutterTts != null) {
        await _flutterTts!.pause();
      }
    } catch (_) {}
  }

  bool get isPlaying => _isSpeaking;

  void dispose() {
    stop();
    _completionListeners.clear();
    _startListeners.clear();
    _errorListeners.clear();
    _isInitialized = false;
  }

  Future<void> setSpeechRate(double rate) async {
    try {
      if (_flutterTts != null) {
        double clampedRate = rate.clamp(0.1, 1.0);
        await _flutterTts!.setSpeechRate(clampedRate);
      }
    } catch (e) {
      _logger.warning('Error setting speech rate: $e');
    }
  }

  Future<void> setPitch(double pitch) async {
    try {
      if (_flutterTts != null) {
        double clampedPitch = pitch.clamp(0.5, 2.0);
        await _flutterTts!.setPitch(clampedPitch);
      }
    } catch (e) {
      _logger.warning('Error setting pitch: $e');
    }
  }
}
