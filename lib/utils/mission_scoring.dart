import 'dart:math';

/// Scoring engine for Kids Mission activities — recitations, quiz answers
/// and short responses. Pure functions so they are unit-testable.
class MissionScoring {
  MissionScoring._();

  /// Minimum score (0–100) considered a pass for recitations.
  static const int recitationPassThreshold = 60;

  /// Minimum score (0–100) considered a pass for quiz answers.
  static const int quizPassThreshold = 80;

  static final RegExp _strip = RegExp(r'[^\w\s]');
  static final RegExp _space = RegExp(r'\s+');

  /// Normalizes text: lowercase, punctuation removed, collapsed whitespace.
  static String normalize(String input) {
    final lowered = input
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll(_strip, '');
    return lowered.split(_space).where((w) => w.isNotEmpty).join(' ').trim();
  }

  static List<String> tokens(String input) =>
      normalize(input).split(' ').where((w) => w.isNotEmpty).toList();

  /// Scores a spoken recitation against the expected passage.
  ///
  /// Score = fraction of expected words the child said (word recall),
  /// forgiving of extra filler words and word order — the standard way
  /// word-perfect memory games grade speech.
  ///
  /// Returns a value from 0–100.
  static int scoreRecitation(String expected, String spoken) {
    final expectedTokens = tokens(expected);
    if (expectedTokens.isEmpty) return 0;
    final spokenTokens = tokens(spoken);
    if (spokenTokens.isEmpty) return 0;

    final spokenSet = spokenTokens.toSet();
    final spokenBag = <String, int>{};
    for (final w in spokenTokens) {
      spokenBag[w] = (spokenBag[w] ?? 0) + 1;
    }

    int matched = 0;
    for (final word in expectedTokens) {
      // Exact match first.
      if ((spokenBag[word] ?? 0) > 0) {
        spokenBag[word] = spokenBag[word]! - 1;
        matched++;
        continue;
      }
      // Simple singular/plural + prefix tolerance (kids drop endings).
      //
      // The match MUST consume the word it used. Without that, one spoken
      // word could satisfy several expected words at once -- saying "heaven"
      // scored both "heaven" and "heavens" -- letting a child reach 100%
      // without having said the passage.
      String? consumed;
      for (final s in spokenSet) {
        final isMatch =
            s == '${word}s' ||
            s == '${word}es' ||
            (word.length > 3 && s.startsWith(word)) ||
            (s.length > 3 && word.startsWith(s));
        if (!isMatch) continue;
        // Only claim an occurrence that has not already been spent.
        if ((spokenBag[s] ?? 0) <= 0) continue;
        consumed = s;
        break;
      }
      if (consumed != null) {
        spokenBag[consumed] = spokenBag[consumed]! - 1;
        matched++;
      }
    }

    final ratio = matched / expectedTokens.length;
    return (ratio * 100).round().clamp(0, 100);
  }

  /// Scores a typed answer against the expected answer.
  /// Combines exact-match, word overlap and Levenshtein similarity so
  /// near-correct answers still get partial credit.
  static int scoreAnswer(String expected, String answer) {
    final expectedNorm = normalize(expected);
    final answerNorm = normalize(answer);
    if (expectedNorm.isEmpty || answerNorm.isEmpty) return 0;
    if (answerNorm == expectedNorm) return 100;

    // Word-overlap component.
    final expectedWords = expectedNorm.split(' ').toSet();
    final answerWords = answerNorm.split(' ').toSet();
    final overlap = expectedWords.intersection(answerWords).length /
        max(1, expectedWords.length);
    final wordScore = overlap * 100;

    // Character-similarity component (handles spelling slips).
    final lev = _levenshtein(expectedNorm, answerNorm);
    final similarity =
        1 - lev / max(expectedNorm.length, answerNorm.length);
    final charScore = similarity * 100;

    // Answers must at least overlap in words to count; the final score is
    // the better of the two signals, slightly favouring word coverage.
    final score = max(wordScore * 0.7 + charScore * 0.3, charScore * 0.6);
    return score.round().clamp(0, 100);
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = min(min(curr[j] + 1, prev[j + 1] + 1), prev[j] + cost);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  /// Encouraging feedback label for a score.
  static String feedbackFor(int score) {
    if (score >= 90) return 'Perfect! 🌟';
    if (score >= recitationPassThreshold) return 'Well done! 👏';
    if (score >= 40) return 'Good try — listen once more and retry!';
    return 'Almost — read the passage again and try once more.';
  }
}
