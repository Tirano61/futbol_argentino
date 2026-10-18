import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Carga Roboto (todos los pesos) y los íconos de Material desde el SDK de
/// Flutter, para que las capturas se vean como en un dispositivo. Sin esto,
/// los tests dibujan cada letra como un rectángulo del tamaño del texto y
/// los íconos no se ven.
Future<void> loadVisualFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String file) async =>
      ByteData.sublistView(File('$dir/$file').readAsBytesSync());

  final roboto = FontLoader('Roboto');
  for (final file in [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(read(file));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await icons.load();
}

/// Anchos de la matriz del Hito E con un alto realista de cada dispositivo
/// (lo que entra «en la primera pantalla» es parte de la evaluación).
abstract final class VisualSizes {
  static const phone = Size(360, 780);
  static const tabletPortrait = Size(768, 1024);
  static const tabletLandscape = Size(1280, 800);
  static const desktop = Size(1920, 1080);
}

/// Tema de la captura: la app sigue el del sistema por defecto.
void useBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Escala de texto de la captura (1 = 100 %).
void useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Navega a [location] con el router de la app (como un enlace compartido)
/// y deja pasar [wait] de tiempo simulado para las cargas con cupo (P2).
Future<void> goTo(
  WidgetTester tester,
  String location, {
  Duration wait = Duration.zero,
}) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(location);
  await tester.pumpAndSettle();
  if (wait > Duration.zero) {
    await tester.pump(wait);
    await tester.pumpAndSettle();
  }
}

/// Corre [body] (el test entero: las sombras se pintan al armar la
/// pantalla) con las sombras reales. Por defecto `flutter_test` las dibuja
/// como un borde negro (`debugDisableShadows`), que en una captura parece un
/// contorno que la app no tiene.
Future<void> withRealShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

/// Compara la pantalla completa con `goldens/<name>.png`.
///
/// Las imágenes se generan **solo** a mano con `--update-goldens`, después
/// de revisar la diferencia (Hito E, §14): nunca para que un test pase.
Future<void> expectScreen(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp).first,
    matchesGoldenFile('goldens/$name.png'),
  );
}
