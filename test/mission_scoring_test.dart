import 'package:alive_flutter_app/utils/mission_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scoreRecitation', () {
    test('scores a perfect recitation of the passage', () {
      const passage = 'Blessed are the poor in spirit for theirs is the kingdom '
          'of heaven';
      expect(MissionScoring.scoreRecitation(passage, passage), 100);
    });

    test('an empty or unrelated answer scores zero', () {
      const passage = 'Blessed are the poor in spirit';
      expect(MissionScoring.scoreRecitation(passage, ''), 0);
      expect(
        MissionScoring.scoreRecitation(passage, 'completely unrelated words'),
        0,
      );
    });

    test('one spoken word cannot satisfy two expected words', () {
      // Regression: a prefix match used to increment `matched` without
      // consuming the word, so "heaven" scored both "heaven" and "heavens"
      // and a child could pass without saying the passage.
      const passage = 'heaven heavens';
      final score = MissionScoring.scoreRecitation(passage, 'heaven');
      expect(score, 50, reason: 'only one of the two words was actually said');
    });

    test('repeating a word does not earn repeated credit', () {
      // "God" once should not cover two occurrences of "God".
      final score = MissionScoring.scoreRecitation('God God is love', 'God is love');
      expect(score, lessThan(100));
    });
  });

  group('scoreAnswer', () {
    test('an exact typed answer scores 100', () {
      expect(MissionScoring.scoreAnswer('Genesis 1:1', 'Genesis 1:1'), 100);
    });

    test('punctuation and casing are forgiven', () {
      expect(
        MissionScoring.scoreAnswer('In the beginning', 'in the BEGINNING!'),
        100,
      );
    });
  });

  group('thresholds', () {
    test('are a pass mark, not a speech-accuracy measure', () {
      // These are the scores a child's answer must reach. They are unrelated
      // to how accurately speech was transcribed.
      expect(MissionScoring.recitationPassThreshold, 60);
      expect(MissionScoring.quizPassThreshold, 80);
    });
  });
}
