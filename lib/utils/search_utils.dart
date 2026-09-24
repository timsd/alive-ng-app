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

  /// Stem English words for biblical search (inflections like kill/killed, die/died/dead, weep/wept).
  static String stem(String word) {
    if (word.length <= 2) return word;
    final lower = word.toLowerCase();
    // Common biblical irregulars
    if (lower == 'died' || lower == 'dead' || lower == 'dying') return 'die';
    if (lower == 'wept' || lower == 'weeping' || lower == 'weeps') return 'weep';
    if (lower == 'killed' || lower == 'killing' || lower == 'kills') return 'kill';
    if (lower == 'rose' || lower == 'risen' || lower == 'rising') return 'rise';
    if (lower == 'spoke' || lower == 'spoken' || lower == 'speaking') return 'speak';
    if (lower == 'came' || lower == 'coming') return 'come';
    if (lower == 'went' || lower == 'gone' || lower == 'going') return 'go';
    if (lower == 'saw' || lower == 'seen' || lower == 'seeing') return 'see';
    if (lower == 'knew' || lower == 'known' || lower == 'knowing') return 'know';

    if (lower.endsWith('ies') && lower.length > 4) {
      return '${lower.substring(0, lower.length - 3)}y';
    }
    if (lower.endsWith('ing') && lower.length > 5) {
      return lower.substring(0, lower.length - 3);
    }
    if (lower.endsWith('ed') && lower.length > 4) {
      return lower.substring(0, lower.length - 2);
    }
    if (lower.endsWith('es') && lower.length > 4) {
      return lower.substring(0, lower.length - 2);
    }
    if (lower.endsWith('s') && !lower.endsWith('ss') && lower.length > 3) {
      return lower.substring(0, lower.length - 1);
    }
    return lower;
  }

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
      score += 5000;
    } else if (refNorm.contains(phrase)) {
      score += 2500;
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
              score += 10000;
            } else if (refChapter == queryChapter) {
              score += 3000;
            } else {
              score += 500;
            }
          } else if (hasChapter) {
            if (refChapter == queryChapter) {
              score += 6000;
            } else {
              score += 1000;
            }
          } else {
            score += 4000;
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
      score += 1000;
    } else if (refHits > 0) {
      score += refHits * 100;
    }

    // Exact phrase in the verse text (e.g. "jesus wept").
    final phraseIndex = textNorm.indexOf(phrase);
    if (phraseIndex >= 0 && phrase.contains(' ')) {
      score += 8000 + (1000 ~/ (phraseIndex + 10));
    } else if (phraseIndex >= 0) {
      score += 1500;
    }

    if (tokens.isNotEmpty) {
      var hits = 0;
      var exactHits = 0;
      var firstPos = -1;
      for (final t in tokens) {
        final st = stem(t);
        final exactMatch = RegExp('\\b${RegExp.escape(t)}\\b').firstMatch(textNorm);
        final stemMatch = st != t ? RegExp('\\b${RegExp.escape(st)}[a-z]*\\b').firstMatch(textNorm) : null;
        final substrMatch = textNorm.contains(t) || (st != t && textNorm.contains(st));

        if (exactMatch != null) {
          hits++;
          exactHits++;
          score += 200;
          if (firstPos < 0 || exactMatch.start < firstPos) firstPos = exactMatch.start;
        } else if (stemMatch != null) {
          hits++;
          score += 150;
          if (firstPos < 0 || stemMatch.start < firstPos) firstPos = stemMatch.start;
        } else if (substrMatch) {
          hits++;
          score += 80;
        }
      }

      if (hits == tokens.length && tokens.length > 1) {
        // AND match: ALL query words present in the verse!
        score += 3000 + (exactHits == tokens.length ? 1000 : 0);
      } else if (hits > 0) {
        score += hits * 50;
      }
      if (firstPos >= 0) score += 500 ~/ (firstPos + 50);
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

  /// Builds text spans with every query token and stem highlighted.
  static List<TextSpan> highlightSpans(
    String text,
    String query,
    TextStyle normal,
    TextStyle highlight,
  ) {
    final rawTokens =
        tokensOf(query).where((t) => t.length >= 2).toList();
    if (rawTokens.isEmpty) return [TextSpan(text: text, style: normal)];

    final matchTerms = <String>{};
    for (final t in rawTokens) {
      matchTerms.add(t);
      final st = stem(t);
      if (st.length >= 3) matchTerms.add(st);
    }

    final pattern = RegExp(
      '(${matchTerms.map(RegExp.escape).join('|')})',
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
