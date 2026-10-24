import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/services/formatting.dart';

void main() {
  test('formats the stopwatch as HH:MM:SS.cs', () {
    expect(formatStopwatch(Duration.zero), '00:00:00.00');
    expect(
      formatStopwatch(
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 45),
      ),
      '01:02:03.04',
    );
    expect(formatStopwatch(const Duration(hours: 100)), '100:00:00.00');
  });

  test('formats totals as H:MM:SS', () {
    expect(formatHms(const Duration(minutes: 5)), '0:05:00');
    expect(
      formatHms(const Duration(hours: 2, minutes: 30, seconds: 9)),
      '2:30:09',
    );
  });

  test('formats the timer with configurable precision', () {
    const duration = Duration(
      hours: 1,
      minutes: 2,
      seconds: 3,
      milliseconds: 45,
    );
    expect(formatTimer(duration), '01:02:03.04');
    expect(formatTimer(duration, showMilliseconds: false), '01:02:03');
    expect(formatTimer(duration, showSeconds: false), '01:02');
  });

  test('formats clock times with AM/PM', () {
    expect(formatClockTime(DateTime(2026, 10, 14, 22, 42)), '10:42 PM');
    expect(formatClockTime(DateTime(2026, 10, 14, 9, 5)), '9:05 AM');
  });
}
