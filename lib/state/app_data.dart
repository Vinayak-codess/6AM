import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/lap.dart';
import '../models/session.dart';
import '../services/storage.dart';
import '../services/study_day.dart';

class AppData extends ChangeNotifier {
  AppData(this._storage);

  final Storage _storage;
  final Map<DateTime, Duration> _days = <DateTime, Duration>{};
  final Map<DateTime, List<int>> _hourly = <DateTime, List<int>>{};
  final Map<DateTime, List<Lap>> _lapsByDay = <DateTime, List<Lap>>{};
  Session _session = const Session();
  Future<void> _writes = Future<void>.value();

  Session get session => _session;

  bool get hasAnySavedTime => _days.values.any((d) => d > Duration.zero);

  Duration totalForStudyDay(DateTime studyDay) =>
      _days[studyDay] ?? Duration.zero;

  Duration totalForMoment(DateTime moment) =>
      totalForStudyDay(studyDayFor(moment));

  List<MapEntry<DateTime, Duration>> get daysNewestFirst {
    final entries =
        _days.entries.where((entry) => entry.value > Duration.zero).toList()
          ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  List<int> hourlyForStudyDay(DateTime studyDay) {
    final buckets = _hourly[studyDay];
    if (buckets == null) {
      return const <int>[];
    }
    return List<int>.unmodifiable(buckets);
  }

  List<Lap> lapsForStudyDay(DateTime studyDay) =>
      List<Lap>.unmodifiable(_lapsByDay[studyDay] ?? const <Lap>[]);

  List<DateTime> get sessionDays =>
      List<DateTime>.unmodifiable(_lapsByDay.keys);

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final days = decoded['days'];
          if (days is Map) {
            for (final entry in days.entries) {
              final key = entry.key;
              final value = entry.value;
              if (key is String && value is num) {
                _days[studyDayFromKey(key)] = Duration(
                  milliseconds: value.toInt(),
                );
              }
            }
          }
          final hourly = decoded['hourly'];
          if (hourly is Map) {
            for (final entry in hourly.entries) {
              final key = entry.key;
              final value = entry.value;
              if (key is String && value is List) {
                final buckets = List<int>.filled(studyDayHours, 0);
                for (var i = 0; i < studyDayHours && i < value.length; i++) {
                  final millis = value[i];
                  if (millis is num) {
                    buckets[i] = millis.toInt();
                  }
                }
                _hourly[studyDayFromKey(key)] = buckets;
              }
            }
          }
          final lapsByDay = decoded['lapsByDay'];
          if (lapsByDay is Map) {
            for (final entry in lapsByDay.entries) {
              final key = entry.key;
              final value = entry.value;
              if (key is String && value is List) {
                _lapsByDay[studyDayFromKey(key)] = [
                  for (final entry in value)
                    if (entry is Map)
                      Lap.fromJson(entry.cast<String, Object?>()),
                ];
              }
            }
          }
          final session = decoded['session'];
          if (session is Map) {
            _session = Session.fromJson(session.cast<String, Object?>());
          }
        }
      }
    } catch (_) {
      _days.clear();
      _hourly.clear();
      _lapsByDay.clear();
      _session = const Session();
    }
    notifyListeners();
  }

  void addStudyTime(DateTime moment, Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }
    final day = studyDayFor(moment);
    _days[day] = (_days[day] ?? Duration.zero) + duration;
    forEachHourChunk(moment, duration, (chunkMoment, chunk) {
      final buckets = _hourly.putIfAbsent(
        studyDayFor(chunkMoment),
        () => List<int>.filled(studyDayHours, 0),
      );
      buckets[studyHourIndex(chunkMoment)] += chunk.inMilliseconds;
    });
    notifyListeners();
    _save();
  }

  void archiveLaps(DateTime studyDay, List<Lap> laps) {
    if (laps.isEmpty) {
      return;
    }
    final bucket = _lapsByDay.putIfAbsent(studyDay, () => <Lap>[]);
    bucket.addAll(laps);
    bucket.sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
    _save();
  }

  void removeStudyTime({
    required DateTime start,
    required DateTime end,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) {
      return;
    }
    final day = studyDayFor(start);
    final total = _days[day] ?? Duration.zero;
    final removed = duration < total ? duration : total;
    if (removed > Duration.zero) {
      final left = total - removed;
      if (left > Duration.zero) {
        _days[day] = left;
      } else {
        _days.remove(day);
      }
    }
    var remaining = removed.inMilliseconds;
    final earliest = DateTime(start.year, start.month, start.day, start.hour);
    var cursor = DateTime(end.year, end.month, end.day, end.hour);
    while (remaining > 0 && !cursor.isBefore(earliest)) {
      final buckets = _hourly[studyDayFor(cursor)];
      if (buckets != null) {
        final index = studyHourIndex(cursor);
        final available = buckets[index];
        final take = remaining < available ? remaining : available;
        if (take > 0) {
          buckets[index] = available - take;
          remaining -= take;
        }
      }
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
      ).subtract(const Duration(hours: 1));
    }
    notifyListeners();
    _save();
  }

  void clearStudyDay(DateTime studyDay) {
    final removedTotal = _days.remove(studyDay) != null;
    final removedHourly = _hourly.remove(studyDay) != null;
    final removedLaps = _lapsByDay.remove(studyDay) != null;
    if (!removedTotal && !removedHourly && !removedLaps) {
      return;
    }
    notifyListeners();
    _save();
  }

  void setSession(Session session) {
    _session = session;
    _save();
  }

  Future<void> flush() => _writes;

  void _save() {
    final encoded = jsonEncode(_toJson());
    _writes = _writes
        .then((_) => _storage.write(encoded))
        .catchError((Object _) {});
  }

  Map<String, Object?> _toJson() => {
    'version': 1,
    'days': {
      for (final entry in _days.entries)
        studyDayKey(entry.key): entry.value.inMilliseconds,
    },
    'hourly': {
      for (final entry in _hourly.entries) studyDayKey(entry.key): entry.value,
    },
    'lapsByDay': {
      for (final entry in _lapsByDay.entries)
        studyDayKey(entry.key): [for (final lap in entry.value) lap.toJson()],
    },
    'session': _session.toJson(),
  };
}
