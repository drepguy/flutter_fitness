import 'package:flutter_fitness/utils/suggestion_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayMatchScore', () {
    test('returns 0 for an empty session', () {
      expect(dayMatchScore(const {}, <int>[1, 2, 3]), equals(0.0));
    });

    test('returns 0 when nothing overlaps', () {
      expect(dayMatchScore({7, 8}, <int>[1, 2, 3]), equals(0.0));
    });

    test('returns 1.0 when today is fully contained', () {
      expect(dayMatchScore({1, 2}, <int>[1, 2, 3]), equals(1.0));
    });

    test('returns the containment share for partial overlap', () {
      expect(dayMatchScore({1, 2, 3, 4}, <int>[3, 4, 9]), equals(0.5));
    });

    test('does not double-count duplicates in the past workout', () {
      expect(dayMatchScore({1, 2}, <int>[1, 1, 2]), equals(1.0));
    });
  });

  group('findBestDayMatch', () {
    test('picks the workout matching today, not the most recent one', () {
      // Alternating days, newest first: upper day, then lower day.
      final pastWorkouts = [
        <int>[1, 2, 3], // upper day (just trained)
        <int>[10, 11, 12], // lower day
      ];
      expect(findBestDayMatch({10, 12}, pastWorkouts), equals(1));
    });

    test('keeps the newest workout on ties', () {
      final pastWorkouts = [
        <int>[5, 1],
        <int>[6, 1],
      ];
      expect(findBestDayMatch({1}, pastWorkouts), equals(0));
    });

    test('prefers better containment over recency', () {
      final pastWorkouts = [
        <int>[1, 9], // newer, weak overlap
        <int>[1, 2, 3], // older, full overlap
      ];
      expect(findBestDayMatch({1, 2, 3}, pastWorkouts), equals(1));
    });

    test('returns null when no workout overlaps', () {
      expect(
        findBestDayMatch(
          {7},
          [
            <int>[1, 2],
            <int>[3, 4],
          ],
        ),
        isNull,
      );
    });

    test('returns null for an empty session', () {
      expect(
        findBestDayMatch(const {}, [
          <int>[1, 2],
        ]),
        isNull,
      );
    });
  });

  group('immediateSuccessor', () {
    test('returns the exercise directly after the anchor', () {
      expect(immediateSuccessor(2, <int>[1, 2, 3]), equals(3));
    });

    test('returns null when the anchor ends the workout', () {
      expect(immediateSuccessor(3, <int>[1, 2, 3]), isNull);
    });

    test('returns null when the anchor is unknown', () {
      expect(immediateSuccessor(99, <int>[1, 2, 3]), isNull);
    });

    test('uses the first occurrence of a duplicated anchor', () {
      expect(immediateSuccessor(2, <int>[2, 3, 2, 4]), equals(3));
    });
  });

  group('mostCommonSuccessor', () {
    test('votes for the exercise that most often follows the anchor', () {
      // History newest-first: Brustpresse → Facepulls once, → Latzug twice.
      // The outlier workout must not win over the usual Latzug.
      final successors = <int?>[3, 2, 2]; // Facepulls, Latzug, Latzug
      expect(mostCommonSuccessor(successors, const {}), equals(2));
    });

    test('ignores successors already done today', () {
      final successors = <int?>[2, 3, 3];
      expect(mostCommonSuccessor(successors, {3}), equals(2));
    });

    test('returns null when every successor is done', () {
      expect(mostCommonSuccessor(const <int?>[2, 2], {2}), isNull);
    });

    test('keeps the newest workout on ties', () {
      final successors = <int?>[5, 6];
      expect(mostCommonSuccessor(successors, const {}), equals(5));
    });

    test('skips workouts where the anchor ends the list', () {
      final successors = <int?>[null, 4, 4, null];
      expect(mostCommonSuccessor(successors, const {}), equals(4));
    });

    test('returns null for an empty history', () {
      expect(mostCommonSuccessor(const <int?>[], const {}), isNull);
    });
  });

  group('nextAfterAnchor', () {
    test('returns the following exercise', () {
      expect(nextAfterAnchor(1, <int>[1, 2, 3], const {}), equals(2));
    });

    test('skips exercises already done today', () {
      expect(nextAfterAnchor(1, <int>[1, 2, 3], {2}), equals(3));
    });

    test('never restarts at the top when exercises were picked '
        'out of history order', () {
      // History: [Schulterpresse, Brustpresse, Latzug] — the user started
      // with Brustpresse, so the opener must not be suggested again while
      // exercises after the anchor remain.
      expect(nextAfterAnchor(2, <int>[1, 2, 3], {2}), equals(3));
      expect(nextAfterAnchor(2, <int>[5, 1, 2, 3], {2}), equals(3));
    });

    test('returns null when the anchor ends the workout', () {
      expect(nextAfterAnchor(3, <int>[1, 2, 3], const {}), isNull);
    });

    test('returns null when the anchor is unknown', () {
      expect(nextAfterAnchor(99, <int>[1, 2, 3], const {}), isNull);
    });

    test('returns null when everything after the anchor is done', () {
      expect(nextAfterAnchor(1, <int>[1, 2, 3], {2, 3}), isNull);
    });
  });

  group('firstNotDone', () {
    test('returns the first exercise not done yet', () {
      expect(firstNotDone(<int>[1, 2, 3], {1}), equals(2));
    });

    test('returns the first exercise when nothing is done', () {
      expect(firstNotDone(<int>[1, 2, 3], const {}), equals(1));
    });

    test('returns null when all are done', () {
      expect(firstNotDone(<int>[1, 2], {1, 2}), isNull);
    });

    test('returns null for an empty workout', () {
      expect(firstNotDone(const <int>[], const {}), isNull);
    });
  });
}
