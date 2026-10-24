import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/services/status_export.dart';

void main() {
  test('writes the rainmeter text and json status files', () async {
    final directory = await Directory.systemTemp.createTemp('sixam_status');
    addTearDown(() => directory.delete(recursive: true));
    final exporter = StudyStatusExporter(directory: () async => directory);
    final separator = Platform.pathSeparator;

    await exporter.write(
      now: DateTime(2026, 10, 14, 10, 30),
      total: const Duration(hours: 1, minutes: 2, seconds: 3),
      studyDay: DateTime(2026, 10, 14),
      running: true,
    );

    final text = File(
      '${directory.path}${separator}today_study_status.txt',
    );
    expect(await text.readAsString(), '1:02:03');

    final status = File('${directory.path}${separator}status.json');
    final decoded = jsonDecode(await status.readAsString()) as Map;
    expect(decoded['totalMs'], const Duration(hours: 1, minutes: 2, seconds: 3).inMilliseconds);
    expect(decoded['totalHms'], '1:02:03');
    expect(decoded['studyDay'], '2026-10-14');
    expect(decoded['running'], isTrue);
    expect(decoded['updatedAt'], '2026-10-14T10:30:00.000');
  });

  test('does not throw when the directory is unavailable', () async {
    final exporter = StudyStatusExporter(
      directory: () async => throw const FileSystemException('missing'),
    );
    await expectLater(
      exporter.write(
        now: DateTime(2026, 10, 14),
        total: Duration.zero,
        studyDay: DateTime(2026, 10, 14),
        running: false,
      ),
      completes,
    );
  });
}
