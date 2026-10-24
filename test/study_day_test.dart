import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/services/study_day.dart';

void main() {
  group('studyDayFor', () {
    test('exactly 6:00:00 AM belongs to the same calendar day', () {
      expect(
        studyDayFor(DateTime(2026, 10, 15, 6, 0, 0)),
        DateTime(2026, 10, 15),
      );
    });

    test('exactly 5:59:59 AM belongs to the previous day', () {
      expect(
        studyDayFor(DateTime(2026, 10, 15, 5, 59, 59)),
        DateTime(2026, 10, 14),
      );
    });

    test('midnight belongs to the previous day', () {
      expect(
        studyDayFor(DateTime(2026, 10, 15, 0, 0, 0)),
        DateTime(2026, 10, 14),
      );
    });

    test('1 AM on the 15th counts toward the 14th', () {
      expect(
        studyDayFor(DateTime(2026, 10, 15, 1, 0, 0)),
        DateTime(2026, 10, 14),
      );
    });

    test('noon belongs to the same calendar day', () {
      expect(
        studyDayFor(DateTime(2026, 10, 15, 12, 30, 0)),
        DateTime(2026, 10, 15),
      );
    });

    test('early morning on the 1st maps to the last day of the month', () {
      expect(
        studyDayFor(DateTime(2026, 11, 1, 3, 0, 0)),
        DateTime(2026, 10, 31),
      );
    });
  });

  group('study day keys', () {
    test('round trips through JSON-friendly keys', () {
      final day = DateTime(2026, 10, 14);
      expect(studyDayKey(day), '2026-10-14');
      expect(studyDayFromKey('2026-10-14'), day);
    });

    test('addStudyDays moves across month boundaries', () {
      expect(addStudyDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
      expect(addStudyDays(DateTime(2026, 11, 1), -1), DateTime(2026, 10, 31));
    });
  });
}
