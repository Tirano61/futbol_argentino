import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Roboto (la fuente de Material en Android) desde el SDK de Flutter.
///
/// Por defecto los tests dibujan con una fuente en la que cada letra mide
/// lo mismo que el tamaño del texto: los anchos salen mucho más grandes que
/// en un dispositivo. Los tests que dependen de si algo entra en una línea
/// la cargan con `setUpAll(loadRealFonts)`.
Future<void> loadRealFonts() async {
  final fonts =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final file in ['roboto-regular.ttf', 'roboto-medium.ttf']) {
    final bytes = File('$fonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
