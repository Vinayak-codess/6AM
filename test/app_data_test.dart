import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/models/lap.dart';
import 'package:sixam/models/session.dart';
import 'package:sixam/services/storage.dart';
import 'package:sixam/state/app_data.dart';

void main() {
  test('aggregates study time into the correct study day', () async {
    final data = AppData(InMemoryStorage());
    await data.load();

    data.addStudyTime(
      DateTime(2026, 10, 14, 23, 50),
      const Duration(minutes: 10),
    );
    data.addStudyTime(DateTime(2026, 10, 15, 1, 0), const Duration(minutes: 5));

    expect(
      data.totalForMoment(DateTime(2026, 10, 14, 10)),
      const Duration(minutes: 15),
    );
    expect(data.daysNewestFirst.single.key, DateTime(2026, 10, 14));
  });

  test('persists and reloads the session snapshot', () async {
    final storage = InMemoryStorage();
    final data = AppData(storage);
    await data.load();

    final restoredAt = DateTime(2026, 10, 14, 9);
    data.setSession(
      Session(
        accumulated: const Duration(minutes: 3),
        runningSince: restoredAt,
      ),
    );
    await data.flush();

    final reloaded = AppData(storage);
    await reloaded.load();
    expect(reloaded.session.accumulated, const Duration(minutes: 3));
    expect(reloaded.session.runningSince, restoredAt);
    expect(reloaded.session.isRunning, isTrue);
  });

  test('tracks hourly buckets for study time', () async {
    final data = AppData(InMemoryStorage());
    await data.load();

    data.addStudyTime(
      DateTime(2026, 10, 14, 10, 10),
      const Duration(minutes: 100),
    );

    final buckets = data.hourlyForStudyDay(DateTime(2026, 10, 14));
    expect(buckets, hasLength(24));
    expect(buckets[3], 0);
    expect(buckets[4], const Duration(minutes: 50).inMilliseconds);
    expect(buckets[5], const Duration(minutes: 50).inMilliseconds);
    expect(data.hourlyForStudyDay(DateTime(2026, 10, 13)), isEmpty);
  });

  test('splits hourly buckets across the 6 AM boundary', () async {
    final data = AppData(InMemoryStorage());
    await data.load();

    data.addStudyTime(DateTime(2026, 10, 15, 5, 30), const Duration(hours: 1));

    final first = data.hourlyForStudyDay(DateTime(2026, 10, 14));
    final second = data.hourlyForStudyDay(DateTime(2026, 10, 15));
    expect(first[23], const Duration(minutes: 30).inMilliseconds);
    expect(second[0], const Duration(minutes: 30).inMilliseconds);
    expect(
      data.totalForMoment(DateTime(2026, 10, 15, 5, 30)),
      const Duration(hours: 1),
    );
  });

  test('persists and reloads hourly buckets', () async {
    final storage = InMemoryStorage();
    final data = AppData(storage);
    await data.load();

    data.addStudyTime(
      DateTime(2026, 10, 14, 10, 10),
      const Duration(minutes: 100),
    );
    await data.flush();

    final reloaded = AppData(storage);
    await reloaded.load();
    final buckets = reloaded.hourlyForStudyDay(DateTime(2026, 10, 14));
    expect(buckets[4], const Duration(minutes: 50).inMilliseconds);
    expect(buckets[5], const Duration(minutes: 50).inMilliseconds);
  });

  test('tolerates a corrupt or empty storage file', () async {
    final data = AppData(InMemoryStorage('{not json'));
    await data.load();
    expect(data.daysNewestFirst, isEmpty);
    expect(data.hourlyForStudyDay(DateTime(2026, 10, 14)), isEmpty);
    expect(data.lapsForStudyDay(DateTime(2026, 10, 14)), isEmpty);
    expect(data.session.isEmpty, isTrue);
  });

  test('removing study time reduces the total and hourly buckets', () async {
    final data = AppData(InMemoryStorage());
    await data.load();

    data.addStudyTime(
      DateTime(2026, 10, 14, 10, 10),
      const Duration(minutes: 100),
    );
    data.removeStudyTime(
      start: DateTime(2026, 10, 14, 10, 10),
      end: DateTime(2026, 10, 14, 11, 50),
      duration: const Duration(minutes: 30),
    );

    expect(
      data.totalForStudyDay(DateTime(2026, 10, 14)),
      const Duration(minutes: 70),
    );
    final buckets = data.hourlyForStudyDay(DateTime(2026, 10, 14));
    expect(buckets[4], const Duration(minutes: 50).inMilliseconds);
    expect(buckets[5], const Duration(minutes: 20).inMilliseconds);
  });

  test('removing more time than recorded clamps at zero', () async {
    final data = AppData(InMemoryStorage());
    await data.load();

    data.addStudyTime(DateTime(2026, 10, 14, 10), const Duration(minutes: 5));
    data.removeStudyTime(
      start: DateTime(2026, 10, 14, 10),
      end: DateTime(2026, 10, 14, 10, 30),
      duration: const Duration(minutes: 20),
    );

    expect(data.totalForStudyDay(DateTime(2026, 10, 14)), Duration.zero);
    expect(data.daysNewestFirst, isEmpty);
  });

  test('persists archived sessions per study day', () async {
    final storage = InMemoryStorage();
    final data = AppData(storage);
    await data.load();

    final lap = Lap(
      start: DateTime(2026, 10, 13, 22),
      end: DateTime(2026, 10, 13, 22, 10),
      duration: const Duration(minutes: 10),
    );
    data.archiveLaps(DateTime(2026, 10, 13), [lap]);
    await data.flush();

    final reloaded = AppData(storage);
    await reloaded.load();
    final sessions = reloaded.lapsForStudyDay(DateTime(2026, 10, 13));
    expect(sessions, hasLength(1));
    expect(sessions.single.duration, const Duration(minutes: 10));
    expect(reloaded.lapsForStudyDay(DateTime(2026, 10, 14)), isEmpty);
  });

  test('clearing a study day also clears its archived sessions', () async {
    final data = AppData(InMemoryStorage());
    await data.load();

    final lap = Lap(
      start: DateTime(2026, 10, 14, 9),
      end: DateTime(2026, 10, 14, 9, 10),
      duration: const Duration(minutes: 10),
    );
    data.archiveLaps(DateTime(2026, 10, 14), [lap]);
    data.clearStudyDay(DateTime(2026, 10, 14));

    expect(data.lapsForStudyDay(DateTime(2026, 10, 14)), isEmpty);
  });
}
