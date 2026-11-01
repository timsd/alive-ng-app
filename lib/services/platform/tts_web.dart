import 'dart:async';
import 'dart:html' as html;

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
    final synth = html.window.speechSynthesis;
    if (synth == null) return <dynamic>[];
    return synth.getVoices().map((v) => {
      'name': v.name,
      'locale': v.lang,
    }).toList();
  }

  Future<dynamic> get getLanguages async {
    final synth = html.window.speechSynthesis;
    if (synth == null) return <String>['en-US'];
    final langs = synth.getVoices().map((v) => v.lang).whereType<String>().toSet().toList();
    if (langs.isEmpty) return <String>['en-US', 'en-GB'];
    return langs;
  }

  Future<dynamic> isLanguageAvailable(String language) async {
    final synth = html.window.speechSynthesis;
    if (synth == null) return false;
    final voices = synth.getVoices();
    return voices.any((v) {
      final lang = v.lang?.toLowerCase() ?? '';
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
    final synth = html.window.speechSynthesis;
    if (synth == null) {
      _completionHandler?.call();
      return 0;
    }

    try {
      synth.cancel(); // Stop any pending or ongoing speech
      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.lang = _language;
      utterance.rate = _speechRate;
      utterance.volume = _volume;
      utterance.pitch = _pitch;

      utterance.onStart.listen((_) {
        _startHandler?.call();
      });

      utterance.onEnd.listen((_) {
        _completionHandler?.call();
      });

      utterance.onError.listen((e) {
        _errorHandler?.call(e);
      });

      synth.speak(utterance);
      return 1;
    } catch (e) {
      _errorHandler?.call(e);
      return 0;
    }
  }

  Future<dynamic> stop() async {
    final synth = html.window.speechSynthesis;
    synth?.cancel();
    _cancelHandler?.call();
    _completionHandler?.call();
    return 1;
  }

  Future<dynamic> pause() async {
    html.window.speechSynthesis?.pause();
    return 1;
  }
}
