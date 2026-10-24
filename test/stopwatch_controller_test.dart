import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/models/lap.dart';
import 'package:sixam/services/storage.dart';
import 'package:sixam/services/study_day.dart';
import 'package:sixam/state/app_data.dart';
import 'package:sixam/state/stopwatch_controller.dart';

class FakeClock {
  FakeClock(this.now);

  DateTime now;

  void advance(Duration duration) => now = now.add(duration);
}

Future<(StopwatchController, AppData, FakeClock)> build({
  Storage? storage,
  DateTime? start,
}) async {
  final data = AppData(storage ?? InMemoryStorage());
  await data.load();
  final clock = FakeClock(start ?? DateTime(2026, 10, 14, 10));
  final controller = StopwatchController(
    data,
    clock: () => clock.now,
    tickInterval: null,
    autoSaveInterval: null,
  );
  addTearDown(controller.dispose);
  return (controller, data, clock);
}

void main() {
  group('pauses', () {
    test('paused time does not count as study time', () async {
      final (controller, data, clock) = await build();

      controller.start();
      clock.advance(const Duration(seconds: 5));
      expect(controller.elapsed, const Duration(seconds: 5));

      controller.pause();
      clock.advance(const Duration(seconds: 30));
      expect(controller.isRunning, isFalse);
      expect(controller.elapsed, const Duration(seconds: 5));

      controller.start();
      clock.advance(const Duration(seconds: 7));
      expect(controller.elapsed, const Duration(seconds: 12));

      controller.pause();
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 15)),
        const Duration(seconds: 12),
      );

      clock.advance(const Duration(hours: 2));
      expect(controller.elapsed, const Duration(seconds: 12));
    });

    test('elapsed is derived from timestamps, not ticks', () async {
      final (controller, _, clock) = await build();
      controller.start();
      clock.advance(const Duration(minutes: 1, milliseconds: 250));
      expect(controller.elapsed, const Duration(minutes: 1, milliseconds: 250));
    });
  });

  group('laps', () {
    test('lap durations come from start and end timestamps', () async {
      final (controller, _, clock) = await build();

      controller.start();
      clock.advance(const Duration(seconds: 5));
      controller.lap();
      clock.advance(const Duration(seconds: 20));
      controller.lap();
      clock.advance(const Duration(seconds: 10));
      controller.lap();

      final laps = controller.laps;
      expect(laps, hasLength(3));
      expect(laps[0].duration, const Duration(seconds: 5));
      expect(laps[1].duration, const Duration(seconds: 20));
      expect(laps[2].duration, const Duration(seconds: 10));
      expect(laps[1].start, laps[0].end);
      expect(laps[1].end, laps[2].start);
    });

    test('lapElapsed tracks time since the last lap', () async {
      final (controller, _, clock) = await build();

      expect(controller.lapElapsed, Duration.zero);

      controller.start();
      clock.advance(const Duration(seconds: 5));
      expect(controller.lapElapsed, const Duration(seconds: 5));
      expect(controller.elapsed, const Duration(seconds: 5));

      controller.lap();
      expect(controller.lapElapsed, Duration.zero);
      expect(controller.elapsed, const Duration(seconds: 5));

      clock.advance(const Duration(seconds: 3));
      expect(controller.lapElapsed, const Duration(seconds: 3));

      controller.pause();
      expect(controller.lapElapsed, const Duration(seconds: 3));

      controller.start();
      clock.advance(const Duration(seconds: 2));
      expect(controller.lapElapsed, const Duration(seconds: 5));
      expect(controller.elapsed, const Duration(seconds: 10));

      controller.reset();
      expect(controller.lapElapsed, Duration.zero);
    });

    test('a lap crossing 6 AM is assigned to the day it started in', () async {
      final (controller, data, clock) = await build(
        start: DateTime(2026, 10, 15, 5, 59),
      );

      controller.start();
      clock.advance(const Duration(seconds: 90));
      controller.lap();

      final lap = controller.laps.single;
      expect(lap.start, DateTime(2026, 10, 15, 5, 59));
      expect(lap.end, DateTime(2026, 10, 15, 6, 0, 30));
      expect(lap.duration, const Duration(seconds: 90));

      expect(
        data.totalForMoment(DateTime(2026, 10, 15, 5, 59)),
        const Duration(seconds: 90),
      );
      expect(data.totalForMoment(DateTime(2026, 10, 15, 12)), Duration.zero);
      expect(studyDayFor(lap.start), DateTime(2026, 10, 14));
    });

    test('laps are committed to daily totals right away', () async {
      final (controller, data, clock) = await build();
      controller.start();
      clock.advance(const Duration(seconds: 8));
      controller.lap();
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 10)),
        const Duration(seconds: 8),
      );
    });

    test('records a lap from time accrued before a pause', () async {
      final (controller, data, clock) = await build();

      controller.start();
      expect(controller.canLap, isTrue);
      clock.advance(const Duration(seconds: 10));
      controller.pause();
      clock.advance(const Duration(seconds: 30));
      expect(controller.canLap, isTrue);

      final lap = controller.lap();
      expect(lap, isNotNull);
      expect(lap!.duration, const Duration(seconds: 10));
      expect(lap.start, DateTime(2026, 10, 14, 10));
      expect(lap.end, DateTime(2026, 10, 14, 10, 0, 10));
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 10)),
        const Duration(seconds: 10),
      );

      expect(controller.canLap, isFalse);
      expect(controller.lap(), isNull);
      expect(controller.laps, hasLength(1));

      controller.start();
      clock.advance(const Duration(seconds: 5));
      final second = controller.lap();
      expect(second, isNotNull);
      expect(second!.duration, const Duration(seconds: 5));
      expect(controller.laps, hasLength(2));
    });

    test('deleting a session removes it and its study time', () async {
      final storage = InMemoryStorage();
      final (controller, data, clock) = await build(storage: storage);

      controller.start();
      clock.advance(const Duration(seconds: 10));
      controller.lap();
      clock.advance(const Duration(seconds: 5));
      controller.lap();

      final deleted = controller.laps.first;
      expect(controller.deleteSession(deleted), isTrue);
      expect(controller.laps, hasLength(1));
      expect(controller.laps.single.duration, const Duration(seconds: 5));
      expect(
        data.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(seconds: 5),
      );

      await data.flush();
      final (restored, restoredData, _) = await build(
        storage: storage,
        start: DateTime(2026, 10, 14, 10, 1),
      );
      expect(restored.laps, hasLength(1));
      expect(
        restoredData.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(seconds: 5),
      );
    });

    test('deleting an unknown session is a no-op', () async {
      final (controller, _, _) = await build();

      expect(
        controller.deleteSession(
          Lap(
            start: DateTime(2026, 10, 14, 9),
            end: DateTime(2026, 10, 14, 9, 5),
            duration: const Duration(minutes: 5),
          ),
        ),
        isFalse,
      );
    });

    test('lap is a no-op on an idle stopwatch', () async {
      final (controller, _, _) = await build();

      expect(controller.canLap, isFalse);
      expect(controller.lap(), isNull);
      expect(controller.laps, isEmpty);
    });

    test('a lap spanning a pause keeps the time before the pause', () async {
      final (controller, data, clock) = await build();

      controller.start();
      clock.advance(const Duration(seconds: 2));
      controller.pause();
      clock.advance(const Duration(seconds: 30));
      controller.start();
      clock.advance(const Duration(seconds: 5));
      controller.lap();

      final lap = controller.laps.single;
      expect(lap.start, DateTime(2026, 10, 14, 10));
      expect(lap.end, DateTime(2026, 10, 14, 10, 0, 37));
      expect(lap.duration, const Duration(seconds: 7));
      expect(controller.elapsed, const Duration(seconds: 7));
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 10)),
        const Duration(seconds: 7),
      );
    });

    test('lap durations stay correct across a restore', () async {
      final storage = InMemoryStorage();
      final (controller, data, clock) = await build(storage: storage);
      controller.start();
      clock.advance(const Duration(seconds: 5));
      controller.lap();
      clock.advance(const Duration(seconds: 3));
      controller.pause();
      await data.flush();

      final (restored, _, restoredClock) = await build(
        storage: storage,
        start: DateTime(2026, 10, 14, 10, 10),
      );
      restored.start();
      restoredClock.advance(const Duration(seconds: 2));
      restored.lap();

      expect(restored.laps, hasLength(2));
      expect(restored.laps[0].duration, const Duration(seconds: 5));
      expect(restored.laps[1].duration, const Duration(seconds: 5));
    });
  });

  group('reset', () {
    test('reset current session keeps today and archives its laps', () async {
      final (controller, data, clock) = await build();

      controller.start();
      clock.advance(const Duration(seconds: 10));
      controller.lap();
      clock.advance(const Duration(seconds: 5));
      controller.resetCurrentSession();

      expect(controller.laps, isEmpty);
      expect(controller.isRunning, isFalse);
      expect(controller.isActive, isFalse);
      expect(controller.elapsed, Duration.zero);
      expect(
        data.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(seconds: 10),
      );
      expect(data.lapsForStudyDay(DateTime(2026, 10, 14)), hasLength(1));
    });

    test(
      'reset all sessions clears the day even when the timer is idle',
      () async {
        final (controller, data, _) = await build();

        data.addStudyTime(
          DateTime(2026, 10, 14, 9),
          const Duration(minutes: 4),
        );
        data.archiveLaps(DateTime(2026, 10, 14), [
          Lap(
            start: DateTime(2026, 10, 14, 9),
            end: DateTime(2026, 10, 14, 9, 4),
            duration: const Duration(minutes: 4),
          ),
        ]);

        controller.resetAllSessionsToday();

        expect(data.totalForStudyDay(DateTime(2026, 10, 14)), Duration.zero);
        expect(data.lapsForStudyDay(DateTime(2026, 10, 14)), isEmpty);
        expect(data.daysNewestFirst, isEmpty);
        expect(controller.isActive, isFalse);
      },
    );

    test('clears the session and zeroes the current study day', () async {
      final (controller, data, clock) = await build();

      controller.start();
      clock.advance(const Duration(seconds: 10));
      controller.lap();
      clock.advance(const Duration(seconds: 4));
      controller.reset();

      expect(controller.laps, isEmpty);
      expect(controller.isRunning, isFalse);
      expect(controller.isActive, isFalse);
      expect(controller.elapsed, Duration.zero);
      expect(data.totalForStudyDay(DateTime(2026, 10, 14)), Duration.zero);
      expect(data.hourlyForStudyDay(DateTime(2026, 10, 14)), isEmpty);
      expect(data.daysNewestFirst, isEmpty);
    });

    test('leaves older study days untouched', () async {
      final storage = InMemoryStorage(
        jsonEncode({
          'version': 1,
          'theme': 'dark',
          'days': {'2026-10-13': 3600000},
          'session': {'laps': [], 'accumulatedMs': 0, 'runningSince': null},
        }),
      );
      final (controller, data, clock) = await build(storage: storage);

      controller.start();
      clock.advance(const Duration(seconds: 6));
      controller.pause();
      controller.reset();

      expect(
        data.totalForStudyDay(DateTime(2026, 10, 13)),
        const Duration(hours: 1),
      );
      expect(data.totalForStudyDay(DateTime(2026, 10, 14)), Duration.zero);
    });

    test('ignores an idle session', () async {
      final storage = InMemoryStorage(
        jsonEncode({
          'version': 1,
          'theme': 'dark',
          'days': {'2026-10-14': 60000},
          'session': {'laps': [], 'accumulatedMs': 0, 'runningSince': null},
        }),
      );
      final (controller, data, _) = await build(storage: storage);

      controller.reset();

      expect(
        data.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(minutes: 1),
      );
    });
  });

  group('crash recovery', () {
    test(
      'restores a running stopwatch from the original start timestamp',
      () async {
        final storage = InMemoryStorage();
        final (controller, data, clock) = await build(storage: storage);
        controller.start();
        clock.advance(const Duration(minutes: 2));
        await data.flush();

        final (restoredController, _, restoredClock) = await build(
          storage: storage,
          start: DateTime(2026, 10, 14, 10, 2),
        );
        expect(restoredController.isRunning, isTrue);
        expect(restoredController.elapsed, const Duration(minutes: 2));
        expect(restoredController.runningSince, DateTime(2026, 10, 14, 10));

        restoredClock.advance(const Duration(minutes: 1));
        expect(restoredController.elapsed, const Duration(minutes: 3));
      },
    );

    test('restores a paused stopwatch with accumulated time', () async {
      final storage = InMemoryStorage();
      final (controller, data, clock) = await build(storage: storage);
      controller.start();
      clock.advance(const Duration(seconds: 90));
      controller.pause();
      clock.advance(const Duration(minutes: 5));
      await data.flush();

      final (restoredController, restoredData, _) = await build(
        storage: storage,
        start: DateTime(2026, 10, 14, 10, 10),
      );
      expect(restoredController.isRunning, isFalse);
      expect(restoredController.elapsed, const Duration(seconds: 90));
      expect(
        restoredData.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(seconds: 90),
      );
    });

    test('a reset session stays reset after reload', () async {
      final storage = InMemoryStorage();
      final (controller, data, clock) = await build(storage: storage);
      controller.start();
      clock.advance(const Duration(seconds: 5));
      controller.reset();
      await data.flush();

      final (restoredController, restoredData, _) = await build(
        storage: storage,
        start: DateTime(2026, 10, 14, 10, 10),
      );
      expect(restoredController.isActive, isFalse);
      expect(restoredController.elapsed, Duration.zero);
      expect(
        restoredData.totalForStudyDay(DateTime(2026, 10, 14)),
        Duration.zero,
      );
    });
  });

  group('day rollover', () {
    test('stale sessions are hidden and archived on load', () async {
      final storage = InMemoryStorage(
        jsonEncode({
          'version': 1,
          'days': {'2026-10-13': 600000},
          'session': {
            'laps': [
              {
                'start': '2026-10-13T22:00:00.000',
                'end': '2026-10-13T22:10:00.000',
                'durationMs': 600000,
              },
            ],
            'accumulatedMs': 600000,
            'runningSince': null,
            'lastLapElapsedMs': 600000,
            'lastLapEnd': '2026-10-13T22:10:00.000',
          },
        }),
      );
      final (controller, data, _) = await build(
        storage: storage,
        start: DateTime(2026, 10, 14, 10),
      );

      expect(controller.laps, isEmpty);
      expect(controller.elapsed, Duration.zero);
      expect(controller.isActive, isFalse);
      expect(
        data.lapsForStudyDay(DateTime(2026, 10, 13)).single.duration,
        const Duration(minutes: 10),
      );
      expect(
        data.totalForStudyDay(DateTime(2026, 10, 13)),
        const Duration(minutes: 10),
      );
    });

    test('rolls over while running and keeps counting', () async {
      final (controller, data, clock) = await build(
        start: DateTime(2026, 10, 15, 5, 50),
      );

      controller.start();
      clock.advance(const Duration(minutes: 20));
      controller.tick();

      expect(controller.isRunning, isTrue);
      expect(controller.laps, isEmpty);
      expect(controller.elapsed, Duration.zero);
      expect(
        data.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(minutes: 20),
      );
      expect(data.totalForStudyDay(DateTime(2026, 10, 15)), Duration.zero);

      clock.advance(const Duration(minutes: 5));
      expect(controller.lapElapsed, const Duration(minutes: 5));
      expect(
        controller.liveUncommittedForDay(DateTime(2026, 10, 15)),
        const Duration(minutes: 5),
      );
    });

    test('a paused session rolls over on the next start', () async {
      final (controller, data, clock) = await build(
        start: DateTime(2026, 10, 15, 5, 50),
      );

      controller.start();
      clock.advance(const Duration(minutes: 9));
      controller.lap();
      clock.advance(const Duration(minutes: 2));
      controller.pause();

      controller.start();

      expect(controller.isRunning, isTrue);
      expect(controller.elapsed, Duration.zero);
      expect(controller.laps, isEmpty);
      expect(data.lapsForStudyDay(DateTime(2026, 10, 14)), hasLength(1));
      expect(
        data.totalForStudyDay(DateTime(2026, 10, 14)),
        const Duration(minutes: 11),
      );
      expect(data.totalForStudyDay(DateTime(2026, 10, 15)), Duration.zero);
    });
  });

  group('exam', () {
    test('counts down and pauses with study time committed', () async {
      final (controller, data, clock) = await build();

      controller.startExam(const Duration(minutes: 25));
      expect(controller.mode, TimerMode.exam);
      expect(controller.examRemaining, const Duration(minutes: 25));

      clock.advance(const Duration(minutes: 5));
      expect(controller.examRemaining, const Duration(minutes: 20));
      expect(controller.elapsed, const Duration(minutes: 5));

      controller.pause();
      expect(controller.isRunning, isFalse);
      expect(controller.examRemaining, const Duration(minutes: 20));
      expect(controller.laps, hasLength(1));
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 10)),
        const Duration(minutes: 5),
      );

      clock.advance(const Duration(minutes: 30));
      expect(controller.examRemaining, const Duration(minutes: 20));

      controller.toggleExam(const Duration(minutes: 25));
      clock.advance(const Duration(minutes: 3));
      expect(controller.examRemaining, const Duration(minutes: 17));
      expect(controller.elapsed, const Duration(minutes: 8));

      controller.endExam();
      expect(controller.mode, TimerMode.stopwatch);
      expect(controller.examRemaining, isNull);
      expect(controller.laps, hasLength(2));
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 10)),
        const Duration(minutes: 8),
      );
    });

    test('completion pauses the exam and records the session', () async {
      final (controller, data, clock) = await build();

      controller.startExam(const Duration(minutes: 1));
      clock.advance(const Duration(minutes: 1));
      controller.tick();

      expect(controller.isRunning, isFalse);
      expect(controller.examCompleted, isTrue);
      expect(controller.examRemaining, Duration.zero);
      expect(controller.laps, hasLength(1));
      expect(
        data.totalForMoment(DateTime(2026, 10, 14, 10)),
        const Duration(minutes: 1),
      );

      controller.endExam();
      expect(controller.mode, TimerMode.stopwatch);
      expect(controller.examRemaining, isNull);
      expect(controller.examCompleted, isFalse);
    });

    test('mode cannot change while running', () async {
      final (controller, _, clock) = await build();
      controller.startExam(const Duration(minutes: 10));
      clock.advance(const Duration(seconds: 1));

      controller.setMode(TimerMode.stopwatch);

      expect(controller.mode, TimerMode.exam);
      expect(controller.isRunning, isTrue);
    });
  });
}
