import 'lap.dart';

class Session {
  const Session({
    this.laps = const [],
    this.accumulated = Duration.zero,
    this.runningSince,
    this.lastLapElapsed,
    this.lastLapEnd,
  });

  final List<Lap> laps;
  final Duration accumulated;
  final DateTime? runningSince;
  final Duration? lastLapElapsed;
  final DateTime? lastLapEnd;

  bool get isRunning => runningSince != null;

  bool get isEmpty =>
      laps.isEmpty && accumulated == Duration.zero && runningSince == null;

  Duration elapsedAt(DateTime now) {
    final since = runningSince;
    if (since == null) {
      return accumulated;
    }
    final segment = now.difference(since);
    return segment.isNegative ? accumulated : accumulated + segment;
  }

  Duration uncommittedAt(DateTime now) {
    final since = runningSince;
    if (since == null) {
      return Duration.zero;
    }
    final segment = now.difference(since);
    return segment.isNegative ? Duration.zero : segment;
  }

  Map<String, Object?> toJson() => {
    'laps': [for (final lap in laps) lap.toJson()],
    'accumulatedMs': accumulated.inMilliseconds,
    'runningSince': runningSince?.toIso8601String(),
    'lastLapElapsedMs': lastLapElapsed?.inMilliseconds,
    'lastLapEnd': lastLapEnd?.toIso8601String(),
  };

  factory Session.fromJson(Map<String, Object?> json) {
    final rawLaps = json['laps'];
    final rawRunningSince = json['runningSince'];
    final rawLastLapElapsed = json['lastLapElapsedMs'];
    final rawLastLapEnd = json['lastLapEnd'];
    return Session(
      laps: rawLaps is List
          ? [
              for (final entry in rawLaps)
                Lap.fromJson((entry as Map).cast<String, Object?>()),
            ]
          : const [],
      accumulated: Duration(
        milliseconds: ((json['accumulatedMs'] ?? 0) as num).toInt(),
      ),
      runningSince: rawRunningSince is String
          ? DateTime.parse(rawRunningSince)
          : null,
      lastLapElapsed: rawLastLapElapsed is num
          ? Duration(milliseconds: rawLastLapElapsed.toInt())
          : null,
      lastLapEnd: rawLastLapEnd is String ? DateTime.parse(rawLastLapEnd) : null,
    );
  }
}
