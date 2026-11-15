import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class FlutterTts {
  String _language = 'en-US';
  double _speechRate = 1.0;
  double _volume = 1.0;
  double _pitch = 1.0;

  void Function()? _startHandler;
  void Function()? _completionHandler;
  void Function(dynamic message)? _errorHandler;
  void Function()? _cancelHandler;

  void setStartHandler(void Function() callback) => _startHandler = callback;
  void setCompletionHandler(void Function() callback) => _completionHandler = callback;
  void setErrorHandler(void Function(dynamic message) callback) => _errorHandler = callback;
  void setCancelHandler(void Function() callback) => _cancelHandler = callback;

  Future<dynamic> setLanguage(String language) async {
    _language = language;
    return 1;
  }

  Future<dynamic> setSpeechRate(double rate) async {
    // Web speech rate is 0.1 to 10 (1.0 is default normal).
    if (rate <= 0.6) {
      _speechRate = (rate * 2.0).clamp(0.5, 2.0);
    } else {
      _speechRate = rate.clamp(0.5, 2.0);
    }
    return 1;
  }

  Future<dynamic> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    return 1;
  }

  Future<dynamic> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.0, 2.0);
    return 1;
  }

  Future<dynamic> get getVoices async {
    final synth = web.window.speechSynthesis;
    return synth.getVoices().toDart.map((v) => {
      'name': v.name,
      'locale': v.lang,
    }).toList();
  }

  Future<dynamic> get getLanguages async {
    final synth = web.window.speechSynthesis;
    final langs = synth.getVoices().toDart.map((v) => v.lang).where((l) => l.isNotEmpty).toSet().toList();
    if (langs.isEmpty) return <String>['en-US', 'en-GB'];
    return langs;
  }

  Future<dynamic> isLanguageAvailable(String language) async {
    final synth = web.window.speechSynthesis;
    final voices = synth.getVoices().toDart;
    return voices.any((v) {
      final lang = v.lang.toLowerCase();
      return lang == language.toLowerCase() || lang.startsWith(language.toLowerCase());
    });
  }

  Future<dynamic> setVoice(Map<String, String> voice) async {
    return 1;
  }

  Future<dynamic> setEngine(String engine) async {
    return 1;
  }

  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    return 1;
  }

  Future<dynamic> setQueueMode(int mode) async {
    return 1;
  }

  Future<dynamic> speak(String text) async {
    final synth = web.window.speechSynthesis;

    try {
      synth.cancel(); // Stop any pending or ongoing speech
      final utterance = web.SpeechSynthesisUtterance(text);
      utterance.lang = _language;
      utterance.rate = _speechRate;
      utterance.volume = _volume;
      utterance.pitch = _pitch;

      utterance.onstart = ((web.Event _) {
        _startHandler?.call();
      }).toJS;

      utterance.onend = ((web.Event _) {
        _completionHandler?.call();
      }).toJS;

      utterance.onerror = ((web.Event e) {
        _errorHandler?.call(e);
      }).toJS;

      synth.speak(utterance);
      return 1;
    } catch (e) {
      _errorHandler?.call(e);
      return 0;
    }
  }

  Future<dynamic> stop() async {
    web.window.speechSynthesis.cancel();
    _cancelHandler?.call();
    _completionHandler?.call();
    return 1;
  }

  Future<dynamic> pause() async {
    web.window.speechSynthesis.pause();
    return 1;
  }
}
