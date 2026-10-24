import 'dart:io';

import 'package:path_provider/path_provider.dart';

class BackupService {
  BackupService({
    Future<Directory> Function()? directory,
    this.dataFileName = 'study_data.json',
    this.backupFileName = 'study_data_backup.json',
  }) : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;
  final String dataFileName;
  final String backupFileName;

  Future<void> ensureBackup() async {
    try {
      final directory = await _directory();
      final separator = Platform.pathSeparator;
      final data = File('${directory.path}$separator$dataFileName');
      final backup = File('${directory.path}$separator$backupFileName');
      if (!await data.exists() || await backup.exists()) {
        return;
      }
      await data.copy(backup.path);
    } catch (_) {
      return;
    }
  }
}
