import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Android: los JSON copiados con `adb push` a la carpeta propia de la app
/// (`/sdcard/Android/data/<paquete>/files/fixtures/`).
Future<List<int>?> readFixture(String name) async {
  final dir = await getExternalStorageDirectory();
  final file = File('${dir?.path}/fixtures/$name.json');
  return file.existsSync() ? file.readAsBytes() : null;
}
