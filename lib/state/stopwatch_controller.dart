import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/lap.dart';
import '../models/session.dart';
import '../services/study_day.dart';
import 'app_data.dart';

enum TimerMode { stopwatch, exam }

class StopwatchController extends ChangeNotifier {
  StopwatchController(
    this._data, {
    DateTime Function()? clock,
    this.tickInterval = const Duration(milliseconds: 40),
    this.autoSaveInterval = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now {
    _restore(_data.session);
    _scheduleRolloverCheck();
  }

  final AppData _data;
  final DateTime Function() _clock;
  final Duration? tickInterval;
  final Duration? autoSaveInterval;

  final List<Lap> _laps = <Lap>[];
  Duration _accumulated = Duration.zero;
  Duration _lastLapElapsed = Duration.zero;
  DateTime? _lastLapEnd;
  DateTime? _runningSince;
  DateTime? _pausedAt;
  DateTime _sessionDay = DateTime(1970);
  Timer? _ticker;
  Timer? _autoSaveTimer;
  Timer? _rolloverTimer;

  TimerMode _mode = TimerMode.stopwatch;
  Duration? _examTarget;
  Duration _examRemaining = Duration.zero;
  DateTime? _examRunningSince;
  bool _examCompleted = false;

  bool get isRunning => _runningSince != null;

  DateTime? get runningSince => _runningSince;

  TimerMode get mode => _mode;

  bool get isExam => _mode == TimerMode.exam;

  Duration? get examTarget => _examTarget;

  bool get examCompleted => _examCompleted;

  Duration? get examRemaining {
    final target = _examTarget;
    if (target == null) {
      return null;
    }
    final since = _examRunningSince;
    if (since == null || !isRunning) {
      return _examRemaining;
    }
    final segment = _clock().difference(since);
    if (segment.isNegative) {
      return _examRemaining;
    }
    final remaining = _examRemaining - segment;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<Lap> get laps {
    final today = studyDayFor(_clock());
    return List<Lap>.unmodifiable(
      _laps.where((lap) => studyDayFor(lap.end) == today),
    );
  }

  bool get isActive =>
      _runningSince != null || _accumulated > Duration.zero || _laps.isNotEmpty;

  bool get canLap => isRunning || (isActive && _accumulated > _lastLapElapsed);

  String get primaryLabel =>
      isRunning ? 'Pause' : (isActive ? 'Resume' : 'Start');

  Duration get elapsed {
    final since = _runningSince;
    if (since == null) {
      return _accumulated;
    }
    final segment = _clock().difference(since);
    return segment.isNegative ? _accumulated : _accumulated + segment;
  }

  Duration get lapElapsed {
    final pending = elapsed - _lastLapElapsed;
    return pending.isNegative ? Duration.zero : pending;
  }

  Duration get liveUncommitted {
    final since = _runningSince;
    if (since == null) {
      return Duration.zero;
    }
    final segment = _clock().difference(since);
    return segment.isNegative ? Duration.zero : segment;
  }

  DateTime? get liveUncommittedDay {
    final since = _runningSince;
    return since == null ? null : studyDayFor(since);
  }

  Duration liveUncommittedForDay(DateTime day) {
    final since = _runningSince;
    if (since == null) {
      return Duration.zero;
    }
    final segment = _clock().difference(since);
    if (segment.isNegative) {
      return Duration.zero;
    }
    var total = Duration.zero;
    forEachHourChunk(since, segment, (moment, chunk) {
      if (studyDayFor(moment) == day) {
        total += chunk;
      }
    });
    return total;
  }

  void toggle() => isRunning ? pause() : start();

  void setMode(
    TimerMode mode, {
    Duration examTarget = const Duration(minutes: 60),
  }) {
    if (isRunning || mode == _mode) {
      return;
    }
    if (mode == TimerMode.stopwatch) {
      endExam();
      return;
    }
    if (lapElapsed > Duration.zero) {
      lap();
    }
    _mode = TimerMode.exam;
    _examTarget = examTarget;
    _examRemaining = examTarget;
    _examRunningSince = null;
    _examCompleted = false;
    _persist();
    notifyListeners();
  }

  void startExam(Duration target) {
    if (isRunning) {
      return;
    }
    if (_mode != TimerMode.exam) {
      setMode(TimerMode.exam, examTarget: target);
    } else {
      if (lapElapsed > Duration.zero) {
        lap();
      }
      _examTarget = target;
      _examRemaining = target;
      _examRunningSince = null;
      _examCompleted = false;
      _persist();
      notifyListeners();
    }
    start();
  }

  void toggleExam(Duration target) {
    if (isRunning) {
      pause();
      return;
    }
    if (_mode != TimerMode.exam || _examCompleted) {
      startExam(target);
      return;
    }
    start();
  }

  @visibleForTesting
  void tick() => _onTick();

  void endExam() {
    if (_mode != TimerMode.exam) {
      return;
    }
    _finishExam(completed: _examCompleted);
    _mode = TimerMode.stopwatch;
    _examTarget = null;
    _examRemaining = Duration.zero;
    _examRunningSince = null;
    _examCompleted = false;
    _persist();
    notifyListeners();
  }

  void start() {
    if (isRunning) {
      return;
    }
    if (isExam && _examCompleted) {
      return;
    }
    _checkDayRollover();
    final now = _clock();
    if (_accumulated == Duration.zero && _laps.isEmpty) {
      _lastLapElapsed = Duration.zero;
      _lastLapEnd = now;
    }
    _runningSince = now;
    if (isExam) {
      _examRunningSince = now;
    }
    _pausedAt = null;
    _persist();
    _startTimers();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) {
      return;
    }
    if (isExam && lapElapsed > Duration.zero) {
      lap();
    }
    final since = _runningSince;
    if (since == null) {
      return;
    }
    final now = _clock();
    final remaining = examRemaining;
    final segment = now.difference(since);
    _runningSince = null;
    _pausedAt = now;
    if (remaining != null) {
      _examRemaining = remaining;
      _examRunningSince = null;
    }
    if (!segment.isNegative) {
      _accumulated += segment;
      _data.addStudyTime(since, segment);
    }
    _persist();
    _stopTimers();
    notifyListeners();
  }

  Lap? lap() {
    final now = _clock();
    final since = _runningSince;
    if (since != null) {
      final segment = now.difference(since);
      if (segment.isNegative) {
        return null;
      }
      final totalElapsed = _accumulated + segment;
      final lapDuration = totalElapsed - _lastLapElapsed;
      if (lapDuration.isNegative) {
        return null;
      }
      final lap = Lap(
        start: _lastLapEnd ?? since,
        end: now,
        duration: lapDuration,
      );
      _laps.add(lap);
      _accumulated = totalElapsed;
      _data.addStudyTime(since, segment);
      _lastLapElapsed = totalElapsed;
      _lastLapEnd = now;
      _runningSince = now;
      _persist();
      notifyListeners();
      return lap;
    }
    final lapDuration = _accumulated - _lastLapElapsed;
    if (lapDuration <= Duration.zero) {
      return null;
    }
    final end = _pausedAt ?? now;
    final lap = Lap(
      start: _lastLapEnd ?? end.subtract(lapDuration),
      end: end,
      duration: lapDuration,
    );
    _laps.add(lap);
    _lastLapElapsed = _accumulated;
    _lastLapEnd = end;
    _persist();
    notifyListeners();
    return lap;
  }

  bool deleteSession(Lap session) {
    final index = _laps.indexWhere(
      (lap) => lap.start == session.start && lap.end == session.end,
    );
    if (index < 0) {
      return false;
    }
    _laps.removeAt(index);
    _data.removeStudyTime(
      start: session.start,
      end: session.end,
      duration: session.duration,
    );
    if (_laps.isEmpty) {
      _lastLapEnd = null;
    } else if (index == _laps.length) {
      _lastLapEnd = _laps.last.end;
    }
    _persist();
    notifyListeners();
    return true;
  }

  void reset() {
    if (!isActive) {
      return;
    }
    resetAllSessionsToday();
  }

  void resetAllSessionsToday() {
    _data.clearStudyDay(studyDayFor(_clock()));
    _clearTimerSession();
    _persist();
    _stopTimers();
    notifyListeners();
  }

  void resetCurrentSession() {
    if (!isActive) {
      return;
    }
    _archiveLaps(_laps.toList());
    _clearTimerSession();
    _persist();
    _stopTimers();
    notifyListeners();
  }

  void _clearTimerSession() {
    _runningSince = null;
    _pausedAt = null;
    _laps.clear();
    _accumulated = Duration.zero;
    _lastLapElapsed = Duration.zero;
    _lastLapEnd = null;
    _sessionDay = studyDayFor(_clock());
    _mode = TimerMode.stopwatch;
    _examTarget = null;
    _examRemaining = Duration.zero;
    _examRunningSince = null;
    _examCompleted = false;
  }

  void _restore(Session session) {
    _laps
      ..clear()
      ..addAll(session.laps);
    _accumulated = session.accumulated;
    _runningSince = session.runningSince;
    _lastLapElapsed =
        session.lastLapElapsed ??
        _laps.fold(Duration.zero, (sum, lap) => sum + lap.duration);
    _lastLapEnd = session.lastLapEnd ?? (_laps.isEmpty ? null : _laps.last.end);
    _sessionDay = _sessionDayFor(session);
    _splitStaleLaps();
    _checkDayRollover();
    if (isRunning) {
      _startTimers();
    }
  }

  DateTime _sessionDayFor(Session session) {
    final since = session.runningSince;
    if (since != null) {
      return studyDayFor(since);
    }
    if (session.laps.isNotEmpty) {
      return studyDayFor(session.laps.last.end);
    }
    return studyDayFor(_clock());
  }

  void _splitStaleLaps() {
    final today = studyDayFor(_clock());
    final stale = _laps.where((lap) => studyDayFor(lap.end) != today).toList();
    if (stale.isEmpty) {
      return;
    }
    _laps.removeWhere((lap) => studyDayFor(lap.end) != today);
    _archiveLaps(stale);
    _persist();
  }

  void _archiveLaps(Iterable<Lap> laps) {
    final byDay = <DateTime, List<Lap>>{};
    for (final lap in laps) {
      byDay.putIfAbsent(studyDayFor(lap.end), () => <Lap>[]).add(lap);
    }
    for (final entry in byDay.entries) {
      _data.archiveLaps(entry.key, entry.value);
    }
  }

  void _checkDayRollover() {
    final today = studyDayFor(_clock());
    if (today == _sessionDay) {
      return;
    }
    _rollOverDay(today);
  }

  void _rollOverDay(DateTime today) {
    final now = _clock();
    final since = _runningSince;
    final wasRunning = since != null;
    if (since != null) {
      final segment = now.difference(since);
      if (!segment.isNegative && segment > Duration.zero) {
        _data.addStudyTime(since, segment);
      }
    }
    _archiveLaps(_laps.toList());
    _laps.clear();
    _accumulated = Duration.zero;
    _lastLapElapsed = Duration.zero;
    _lastLapEnd = wasRunning ? now : null;
    _runningSince = wasRunning ? now : null;
    _sessionDay = today;
    _persist();
    _scheduleRolloverCheck();
    notifyListeners();
  }

  void _finishExam({required bool completed}) {
    if (lapElapsed > Duration.zero) {
      lap();
    }
    if (isRunning) {
      pause();
    }
    _examCompleted = completed;
    _persist();
    notifyListeners();
  }

  void _persist() {
    _data.setSession(
      Session(
        laps: List<Lap>.of(_laps),
        accumulated: _accumulated,
        runningSince: _runningSince,
        lastLapElapsed: _lastLapElapsed,
        lastLapEnd: _lastLapEnd,
      ),
    );
  }

  void _scheduleRolloverCheck() {
    _rolloverTimer?.cancel();
    final now = _clock();
    final today = studyDayFor(now);
    var next = DateTime(today.year, today.month, today.day + 1, 6);
    if (!next.isAfter(now)) {
      next = DateTime(today.year, today.month, today.day + 2, 6);
    }
    _rolloverTimer = Timer(next.difference(now), () {
      _checkDayRollover();
      _scheduleRolloverCheck();
    });
  }

  void _onTick() {
    if (isExam && isRunning && examRemaining == Duration.zero) {
      _finishExam(completed: true);
      return;
    }
    _checkDayRollover();
    notifyListeners();
  }

  void _startTimers() {
    final tick = tickInterval;
    if (tick != null) {
      _ticker ??= Timer.periodic(tick, (_) => _onTick());
    }
    final save = autoSaveInterval;
    if (save != null) {
      _autoSaveTimer ??= Timer.periodic(save, (_) => _persist());
    }
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  @override
  void dispose() {
    _stopTimers();
    _rolloverTimer?.cancel();
    _rolloverTimer = null;
    super.dispose();
  }
}
