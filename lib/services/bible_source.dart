import '../constants/bible_verses.dart' show BibleVerse;
import '../constants/daily_verses.dart' as daily_data;

/// BibleSource provides a unified interface for accessing Bible verses
/// from the bundled corpus and, in future, remote sources.
class BibleSource {
  BibleSource._();
  static final BibleSource instance = BibleSource._();

  /// Returns the bundled daily verses corpus
  List<BibleVerse> get dailyCorpus => daily_data.dailyVerses;

  /// Find a verse by reference in the bundled corpus
  BibleVerse? findByReference(String reference) {
    final clean = reference.trim().toLowerCase();
    for (final verse in dailyCorpus) {
      if (verse.reference.toLowerCase() == clean) {
        return verse;
      }
    }
    return null;
  }

  /// Simple search across the bundled corpus by reference or text content
  List<BibleVerse> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return dailyCorpus.where((verse) {
      return verse.reference.toLowerCase().contains(q) ||
          verse.text.values.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Get a random verse from the daily corpus
  BibleVerse? randomVerse() {
    if (dailyCorpus.isEmpty) return null;
    final verses = List<BibleVerse>.of(dailyCorpus)..shuffle();
    return verses.first;
  }
}
