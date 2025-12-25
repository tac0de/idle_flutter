import 'dart:io';

import 'package:idle_save/idle_save.dart';
import 'package:path_provider/path_provider.dart';

class PathFileStore {
  /// 예: fileName = 'idle_save.json'
  static Future<FileStore> documents(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}$fileName';
    return FileStore(path);
  }

  static Future<FileStore> temp(String fileName) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}${Platform.pathSeparator}$fileName';
    return FileStore(path);
  }
}
