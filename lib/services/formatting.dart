import 'package:intl/intl.dart';

String _two(int value) => value.toString().padLeft(2, '0');

String formatStopwatch(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final hundredths = (d.inMilliseconds % 1000) ~/ 10;
  return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}.${_two(hundredths)}';
}

String formatTimer(
  Duration duration, {
  bool showMilliseconds = true,
  bool showSeconds = true,
}) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = _two(d.inHours);
  final minutes = _two(d.inMinutes % 60);
  if (!showSeconds) {
    return '$hours:$minutes';
  }
  final seconds = _two(d.inSeconds % 60);
  if (!showMilliseconds) {
    return '$hours:$minutes:$seconds';
  }
  final hundredths = (d.inMilliseconds % 1000) ~/ 10;
  return '$hours:$minutes:$seconds.${_two(hundredths)}';
}

String formatHms(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  return '${d.inHours}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';
}

String formatHoursMinutes(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) {
    return '${minutes}m';
  }
  return '${hours}h ${_two(minutes)}m';
}

String formatClockTimeSeconds(DateTime time) =>
    DateFormat('h:mm:ss a').format(time);

String formatClockTime(DateTime time) => DateFormat('h:mm a').format(time);

String formatDayLabel(DateTime day) => DateFormat('EEE, MMM d').format(day);

String formatChartDay(DateTime day) => DateFormat('MMM d').format(day);

String formatChartAxisDay(DateTime day, {required bool monthly}) =>
    monthly ? DateFormat('d').format(day) : DateFormat('E').format(day);

String formatAxisHours(double hours) {
  if (hours <= 0) {
    return '0';
  }
  if (hours < 1) {
    return '${(hours * 60).round()}m';
  }
  if (hours == hours.roundToDouble()) {
    return '${hours.round()}h';
  }
  return '${hours.toStringAsFixed(1)}h';
}
