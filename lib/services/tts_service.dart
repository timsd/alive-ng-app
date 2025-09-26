import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _flutterTts = FlutterTts();

    // Configure for human-like voice
    await _configureVoice();
    
    _isInitialized = true;
  }

  Future<void> _configureVoice() async {
    if (_flutterTts == null) return;

    try {
      // Set language to English (US) for best quality
      await _flutterTts!.setLanguage('en-US');
      
      // Set speech rate for natural conversation pace (0.4-0.6 is most natural)
      await _flutterTts!.setSpeechRate(0.5);
      
      // Set volume to full
      await _flutterTts!.setVolume(1.0);
      
      // Set pitch for more natural sound (0.8-1.2 range)
      await _flutterTts!.setPitch(1.0);
      
      // Get available voices and select the best one
      List<dynamic> voices = await _flutterTts!.getVoices;
      
      // Try to find a high-quality neural voice
      String? bestVoice = _selectBestVoice(voices);
      if (bestVoice != null) {
        await _flutterTts!.setVoice({"name": bestVoice, "locale": "en-US"});
      }
      
      // Set speech engine if available (for Android)
      if (!kIsWeb) {
        await _flutterTts!.setEngine('com.google.android.tts');
      }
      
    } catch (e) {
      debugPrint('TTS Configuration Error: $e');
    }
  }

  String? _selectBestVoice(List<dynamic> voices) {
    // Priority order for human-like voices
    List<String> preferredVoices = [
      'en-us-x-sfg#female_2-local',  // Google's high-quality female voice
      'en-us-x-sfg#male_1-local',    // Google's high-quality male voice
      'en-US-Neural2-A',             // Azure Neural voices
      'en-US-Neural2-C',
      'en-US-AriaNeural',            // Microsoft Neural voices
      'en-US-JennyNeural',
      'com.apple.ttsbundle.Samantha-compact', // Apple voices
      'com.apple.ttsbundle.Alex-compact',
      'en-us-x-iol-local',          // Google enhanced voices
      'en-us-x-iom-local',
    ];

    // First, try to find exact matches
    for (String preferred in preferredVoices) {
      for (var voice in voices) {
        String voiceName = voice['name'] ?? '';
        if (voiceName.toLowerCase().contains(preferred.toLowerCase())) {
          debugPrint('Selected TTS Voice: $voiceName');
          return voiceName;
        }
      }
    }

    // Fallback: look for any neural or enhanced voice
    for (var voice in voices) {
      String voiceName = voice['name'] ?? '';
      String locale = voice['locale'] ?? '';
      
      if (locale.startsWith('en-US') || locale.startsWith('en-us')) {
        String lowerName = voiceName.toLowerCase();
        if (lowerName.contains('neural') || 
            lowerName.contains('enhanced') ||
            lowerName.contains('premium') ||
            lowerName.contains('high') ||
            lowerName.contains('quality')) {
          debugPrint('Selected TTS Voice (fallback): $voiceName');
          return voiceName;
        }
      }
    }

    debugPrint('Using default TTS voice');
    return null;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_flutterTts != null && text.isNotEmpty) {
      // Clean text for better pronunciation
      String cleanText = _cleanTextForSpeech(text);
      await _flutterTts!.speak(cleanText);
    }
  }

  String _cleanTextForSpeech(String text) {
    // Remove excessive punctuation and format for natural speech
    return text
        .replaceAll(RegExp(r'\s+'), ' ')  // Multiple spaces to single
        .replaceAll(RegExp(r'[\n\r]+'), '. ')  // Line breaks to pauses
        .replaceAll(RegExp(r'\.\.+'), '.')  // Multiple periods to single
        .replaceAll(RegExp(r'!!+'), '!')   // Multiple exclamations to single
        .replaceAll(RegExp(r'\?\?+'), '?')  // Multiple questions to single
        .trim();
  }

  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  Future<void> pause() async {
    if (_flutterTts != null) {
      await _flutterTts!.pause();
    }
  }

  bool get isPlaying {
    // FlutterTts doesn't have isPlaying getter, so we track state manually
    return _isInitialized && _flutterTts != null;
  }

  void dispose() {
    _flutterTts?.stop();
    _isInitialized = false;
  }

  // Convenience methods for different speech rates
  Future<void> setSpeechRate(double rate) async {
    if (_flutterTts != null) {
      // Clamp rate between 0.1 and 1.0 for natural speech
      double clampedRate = rate.clamp(0.1, 1.0);
      await _flutterTts!.setSpeechRate(clampedRate);
    }
  }

  Future<void> setPitch(double pitch) async {
    if (_flutterTts != null) {
      // Clamp pitch between 0.5 and 2.0 for natural speech
      double clampedPitch = pitch.clamp(0.5, 2.0);
      await _flutterTts!.setPitch(clampedPitch);
    }
  }
}



