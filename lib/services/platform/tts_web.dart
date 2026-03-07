class FlutterTts {
  Future<dynamic> setLanguage(String language) async {}
  Future<dynamic> setSpeechRate(double rate) async {}
  Future<dynamic> setVolume(double volume) async {}
  Future<dynamic> setPitch(double pitch) async {}
  Future<dynamic> get getVoices async => <dynamic>[];
  Future<dynamic> setVoice(Map<String, String> voice) async {}
  Future<dynamic> setEngine(String engine) async {}
  Future<dynamic> speak(String text) async {}
  Future<dynamic> stop() async {}
  Future<dynamic> pause() async {}
}
