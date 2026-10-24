class Lap {
  const Lap({required this.start, required this.end, required this.duration});

  final DateTime start;
  final DateTime end;
  final Duration duration;

  Map<String, Object?> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'durationMs': duration.inMilliseconds,
  };

  factory Lap.fromJson(Map<String, Object?> json) => Lap(
    start: DateTime.parse(json['start']! as String),
    end: DateTime.parse(json['end']! as String),
    duration: Duration(milliseconds: (json['durationMs']! as num).toInt()),
  );
}
