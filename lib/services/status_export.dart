import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'formatting.dart';
import 'study_day.dart';

class StudyStatusExporter {
  StudyStatusExporter({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<void> write({
    required DateTime now,
    required Duration total,
    required DateTime studyDay,
    required bool running,
  }) async {
    try {
      final directory = await _directory();
      final separator = Platform.pathSeparator;
      final text = File(
        '${directory.path}${separator}today_study_status.txt',
      );
      await text.writeAsString(formatHms(total), flush: true);
      final status = File('${directory.path}${separator}status.json');
      await status.writeAsString(
        jsonEncode({
          'totalMs': total.inMilliseconds,
          'totalHms': formatHms(total),
          'studyDay': studyDayKey(studyDay),
          'running': running,
          'updatedAt': now.toIso8601String(),
        }),
        flush: true,
      );
    } catch (_) {
      return;
    }
  }
}
