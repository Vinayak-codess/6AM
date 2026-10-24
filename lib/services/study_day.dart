const int studyDayHours = 24;

DateTime studyDayFor(DateTime moment) {
  if (moment.hour < 6) {
    return DateTime(moment.year, moment.month, moment.day - 1);
  }
  return DateTime(moment.year, moment.month, moment.day);
}

int studyHourIndex(DateTime moment) {
  final day = studyDayFor(moment);
  final start = DateTime(day.year, day.month, day.day, 6);
  return moment.difference(start).inHours.clamp(0, studyDayHours - 1);
}

void forEachHourChunk(
  DateTime start,
  Duration duration,
  void Function(DateTime moment, Duration chunk) onChunk,
) {
  var cursor = start;
  var remaining = duration;
  while (remaining > Duration.zero) {
    final hourEnd = DateTime(
      cursor.year,
      cursor.month,
      cursor.day,
      cursor.hour,
    ).add(const Duration(hours: 1));
    final untilHourEnd = hourEnd.difference(cursor);
    if (untilHourEnd <= Duration.zero) {
      onChunk(cursor, remaining);
      return;
    }
    final chunk = remaining < untilHourEnd ? remaining : untilHourEnd;
    onChunk(cursor, chunk);
    cursor = cursor.add(chunk);
    remaining -= chunk;
  }
}

String studyDayKey(DateTime day) {
  final y = day.year.toString().padLeft(4, '0');
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime studyDayFromKey(String key) => DateTime.parse(key);

DateTime addStudyDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);
