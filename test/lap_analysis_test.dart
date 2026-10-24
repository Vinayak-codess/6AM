import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/models/lap.dart';
import 'package:sixam/services/lap_analysis.dart';

Lap lapOf(Duration duration, {DateTime? start}) {
  final s = start ?? DateTime(2026, 10, 14, 10);
  return Lap(start: s, end: s.add(duration), duration: duration);
}

void main() {
  group('computeLapHighlights', () {
    test('returns nothing for fewer than two laps', () {
      expect(computeLapHighlights(const []).longestIndex, isNull);
      final single = computeLapHighlights([lapOf(const Duration(seconds: 5))]);
      expect(single.longestIndex, isNull);
      expect(single.shortestIndex, isNull);
    });

    test('detects longest and shortest among distinct laps', () {
      final highlights = computeLapHighlights([
        lapOf(const Duration(seconds: 2)),
        lapOf(const Duration(seconds: 5)),
        lapOf(const Duration(seconds: 3)),
      ]);
      expect(highlights.longestIndex, 1);
      expect(highlights.shortestIndex, 0);
    });

    test('returns nothing when all laps are equal', () {
      final highlights = computeLapHighlights([
        lapOf(const Duration(seconds: 4)),
        lapOf(const Duration(seconds: 4)),
      ]);
      expect(highlights.longestIndex, isNull);
      expect(highlights.shortestIndex, isNull);
    });

    test('picks the first occurrence of tied extremes', () {
      final highlights = computeLapHighlights([
        lapOf(const Duration(seconds: 5)),
        lapOf(const Duration(seconds: 5)),
        lapOf(const Duration(seconds: 1)),
      ]);
      expect(highlights.longestIndex, 0);
      expect(highlights.shortestIndex, 2);
    });
  });
}
