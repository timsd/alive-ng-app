// Daily verse translations for Yoruba, Hausa, and Igbo.
// SINGLE SOURCE OF TRUTH: All translations are now centralized in BibleSource.
// This getter derives directly from BibleSource.instance.dailyCorpus.

import '../services/bible_source.dart';

Map<String, Map<String, String>>? _cachedTranslations;

Map<String, Map<String, String>> get dailyVerseTranslations {
  if (_cachedTranslations != null) return _cachedTranslations!;
  final map = <String, Map<String, String>>{};
  for (final v in BibleSource.instance.dailyCorpus) {
    final yo = v.text['yo'] ?? v.text['BM'];
    final ha = v.text['ha'] ?? v.text['HAU'];
    final ig = v.text['ig'] ?? v.text['IGBOB'];
    if (yo != null || ha != null || ig != null) {
      map[v.reference] = {
        if (yo != null) 'yo': yo,
        if (ha != null) 'ha': ha,
        if (ig != null) 'ig': ig,
      };
    }
  }
  return _cachedTranslations = map;
}
