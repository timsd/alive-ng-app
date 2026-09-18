// Shared search standard used across the app.
//
// Rules:
// 1. Normalize (lowercase, strip punctuation, collapse whitespace). Unicode
//    letters are preserved so Yoruba/Igbo/Hausa diacritics still match.
// 2. Exact-phrase matches rank first ("jesus wept" -> John 11:35).
// 3. Then items containing ALL query words (AND).
// 4. Then items containing ANY query word, best scored first.
// 5. Reference matches (e.g. "John 3") score alongside text matches.
import 'package:flutter/material.dart';
import '../constants/bible_data.dart';

class SearchUtils {
  static final RegExp _punct = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _digits = RegExp(r'^\d+$');

  /// Lowercase, remove punctuation, collapse whitespace.
  static String normalize(String input) => input
      .toLowerCase()
      .replaceAll(_punct, ' ')
      .replaceAll(_spaces, ' ')
      .trim();

  /// Split a query into searchable tokens. Single letters are dropped
  /// (they only create noise) but numbers are kept ("John 3", "Psalm 23").
  static List<String> tokensOf(String query) => normalize(query)
      .split(' ')
      .where((t) => t.isNotEmpty && (t.length > 1 || _digits.hasMatch(t)))
      .toList();

  static bool containsWord(String normalizedHaystack, String token) =>
      RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(normalizedHaystack);

  /// Score a (reference, text) pair against a raw query. Higher is better,
  /// 0 means no match.
  static int scoreVerse({
    required String reference,
    required String text,
    required String query,
  }) {
    final phrase = normalize(query);
    if (phrase.isEmpty) return 0;
    final tokens = tokensOf(query);
    final refNorm = normalize(reference);
    final textNorm = normalize(text);

    var score = 0;

    // Direct reference match, e.g. query "john 3" vs reference "john 3 16".
    if (refNorm.startsWith(phrase)) {
      score += 1000;
    } else if (refNorm.contains(phrase)) {
      score += 500;
    }

    // Canonical reference match check using BibleData
    final parsedQuery = BibleData.parseReference(query);
    if (parsedQuery['isValid'] == true) {
      final queryBook = parsedQuery['book'] as String;
      final queryChapter = parsedQuery['chapter'] as int;
      final hasVerse = parsedQuery['hasVerse'] as bool;
      final hasChapter = parsedQuery['hasChapter'] as bool;

      final parsedRef = BibleData.parseReference(reference);
      if (parsedRef['isValid'] == true) {
        final refBook = parsedRef['book'] as String;
        final refChapter = parsedRef['chapter'] as int;
        final refStartVerse = parsedRef['startVerse'] as int;
        final refEndVerse = parsedRef['endVerse'] as int;

        if (queryBook.toLowerCase() == refBook.toLowerCase()) {
          if (hasVerse) {
            if (refChapter == queryChapter &&
                parsedQuery['startVerse'] <= refEndVerse &&
                parsedQuery['endVerse'] >= refStartVerse) {
              score += 5000;
            } else if (refChapter == queryChapter) {
              score += 1200;
            } else {
              score += 200;
            }
          } else if (hasChapter) {
            if (refChapter == queryChapter) {
              score += 3000;
            } else {
              score += 400;
            }
          } else {
            score += 2000;
          }
        }
      }
    }

    // Check token matches across reference
    var refHits = 0;
    for (final t in tokens) {
      if (refNorm.contains(t)) {
        refHits++;
      }
    }
    if (tokens.isNotEmpty && refHits == tokens.length) {
      score += 400;
    } else if (refHits > 0) {
      score += refHits * 30;
    }

    // Exact phrase in the verse text ("jesus wept").
    final phraseIndex = textNorm.indexOf(phrase);
    if (phraseIndex >= 0 && phrase.contains(' ')) {
      score += 300 + (1000 ~/ (phraseIndex + 10));
    } else if (phraseIndex >= 0) {
      score += 150;
    }

    if (tokens.isNotEmpty) {
      var hits = 0;
      var firstPos = -1;
      for (final t in tokens) {
        final m = RegExp('\\b${RegExp.escape(t)}\\b').firstMatch(textNorm);
        if (m != null) {
          hits++;
          if (firstPos < 0) firstPos = m.start;
        } else if (textNorm.contains(t)) {
          hits++;
        }
      }
      if (hits == tokens.length && tokens.length > 1) {
        // AND match: every word present.
        score += 200 + hits * 10;
      } else if (hits > 0) {
        score += hits * 10;
      }
      if (firstPos > 0) score += 500 ~/ (firstPos + 50);
    }

    return score;
  }

  /// Generic multi-field ranked filter used by every in-app search box.
  ///
  /// Standard: normalized exact phrase first, then ALL words present, then
  /// ANY word, preserving original order inside each tier.
  static List<T> rankFilter<T>(
    List<T> items,
    String query,
    List<String> Function(T item) fields,
  ) {
    final phrase = normalize(query);
    if (phrase.isEmpty) return List<T>.of(items);
    final tokens = tokensOf(query);
    final exact = <T>[];
    final allWords = <T>[];
    final anyWord = <T>[];
    for (final item in items) {
      final haystack =
          fields(item).map(normalize).join(' \n ').trim();
      if (haystack.isEmpty) continue;
      if (haystack.contains(phrase)) {
        exact.add(item);
        continue;
      }
      if (tokens.isEmpty) continue;
      var hits = 0;
      for (final t in tokens) {
        if (haystack.contains(t)) hits++;
      }
      if (hits == tokens.length) {
        allWords.add(item);
      } else if (hits > 0) {
        anyWord.add(item);
      }
    }
    return [...exact, ...allWords, ...anyWord];
  }

  /// Builds text spans with every query token highlighted.
  static List<TextSpan> highlightSpans(
    String text,
    String query,
    TextStyle normal,
    TextStyle highlight,
  ) {
    final tokens =
        tokensOf(query).where((t) => t.length >= 2).toList();
    if (tokens.isEmpty) return [TextSpan(text: text, style: normal)];
    final pattern = RegExp(
      '(${tokens.map(RegExp.escape).join('|')})',
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: normal));
      }
      spans.add(TextSpan(text: m.group(0), style: highlight));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: normal));
    }
    return spans;
  }
}
