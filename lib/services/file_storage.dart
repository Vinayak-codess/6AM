import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'storage.dart';

class FileStorage implements Storage {
  FileStorage({this.fileName = 'study_data.json'});

  final String fileName;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String contents) async {
    final file = await _file();
    await file.writeAsString(contents, flush: true);
  }
}
