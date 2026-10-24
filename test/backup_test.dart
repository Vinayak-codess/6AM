import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/services/backup.dart';

void main() {
  test('copies the data file once without overwriting the backup', () async {
    final directory = await Directory.systemTemp.createTemp('sixam_backup');
    addTearDown(() => directory.delete(recursive: true));
    final separator = Platform.pathSeparator;
    final data = File('${directory.path}${separator}study_data.json');
    final backup = File(
      '${directory.path}${separator}study_data_backup.json',
    );
    await data.writeAsString('{"version":1,"days":{}}');

    final service = BackupService(directory: () async => directory);
    await service.ensureBackup();

    expect(await backup.exists(), isTrue);
    expect(await backup.readAsString(), '{"version":1,"days":{}}');

    await data.writeAsString('changed');
    await service.ensureBackup();
    expect(await backup.readAsString(), '{"version":1,"days":{}}');
  });

  test('does nothing when there is no data file', () async {
    final directory = await Directory.systemTemp.createTemp('sixam_backup');
    addTearDown(() => directory.delete(recursive: true));

    final service = BackupService(directory: () async => directory);
    await service.ensureBackup();

    final backup = File(
      '${directory.path}${Platform.pathSeparator}study_data_backup.json',
    );
    expect(await backup.exists(), isFalse);
  });

  test('does not throw when the directory is unavailable', () async {
    final service = BackupService(
      directory: () async => throw const FileSystemException('missing'),
    );
    await expectLater(service.ensureBackup(), completes);
  });
}
