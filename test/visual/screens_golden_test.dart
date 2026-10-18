import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/recorded_app.dart';
import 'visual_helpers.dart';

/// Capturas de referencia del Hito E (§14 de `docs/HITO_E.md`): la app
/// completa con los datos grabados, en los anchos y temas de la matriz.
///
/// En E1 las imágenes son el diseño **anterior** al rediseño («antes»).
/// Cada fase que cambie una pantalla las hace fallar a propósito; se
/// regeneran con `flutter test --update-goldens test/visual` solo después
/// de revisar las diferencias. Los escudos salen como iniciales (los tests
/// no tienen red).
void main() {
  setUpAll(loadVisualFonts);

  final scenes = <_Scene>[
    _Scene('inicio', (tester) async {}),
    _Scene(
      'fixture_primera',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
      ),
    ),
    _Scene(
      'fixture_libertadores_series',
      (tester) =>
          goTo(tester, '/competiciones/4501?temporada=2026&fase=eliminatorias'),
      continental: true,
    ),
    _Scene(
      'tabla_anual',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
        wait: const Duration(minutes: 2),
      ),
    ),
    _Scene(
      'tabla_zona',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=clausura-a',
        wait: const Duration(minutes: 2),
      ),
    ),
    _Scene(
      'tabla_nacional',
      (tester) => goTo(
        tester,
        '/competiciones/4616?temporada=2026&vista=tabla&tabla=zona-a',
        wait: const Duration(minutes: 4),
      ),
    ),
    _Scene(
      'tabla_grupo_libertadores',
      (tester) => goTo(
        tester,
        '/competiciones/4501?temporada=2026&vista=tabla&tabla=grupo-a',
        wait: const Duration(minutes: 1),
      ),
      continental: true,
    ),
    _Scene(
      'calendario',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=calendario&mes=2026-10',
      ),
    ),
    _Scene(
      'llaves_primera',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=llaves&llave=apertura',
        wait: const Duration(minutes: 1),
      ),
    ),
    _Scene(
      'llaves_libertadores_2025',
      (tester) => goTo(
        tester,
        '/competiciones/4501?temporada=2025&vista=llaves',
        wait: const Duration(minutes: 1),
      ),
      continental: true,
    ),
    _Scene(
      'ficha_boca',
      (tester) =>
          goTo(tester, '/equipos/135156', wait: const Duration(minutes: 5)),
      continental: true,
    ),
    _Scene('detalle_primera', (tester) async {
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=11',
      );
      await goTo(tester, '/partidos/2398104');
    }),
    _Scene('detalle_serie_penales', (tester) async {
      await goTo(
        tester,
        '/competiciones/4501?temporada=2026&fase=eliminatorias'
        '&ronda=125&etapa=eliminatoria',
      );
      await goTo(tester, '/partidos/2600654');
    }, continental: true),
  ];

  // Matriz: todas las pantallas a 360 y 1280 en claro y oscuro; las de
  // mayor uso también a 768 y 1920 (claro); y tres al 200 % en teléfono.
  const wideScenes = {
    'inicio',
    'fixture_primera',
    'fixture_libertadores_series',
    'tabla_anual',
    'llaves_libertadores_2025',
  };
  const scaledScenes = {'inicio', 'fixture_libertadores_series', 'tabla_zona'};

  for (final scene in scenes) {
    for (final brightness in Brightness.values) {
      for (final size in [VisualSizes.phone, VisualSizes.tabletLandscape]) {
        scene.register(size, brightness);
      }
    }
    if (wideScenes.contains(scene.name)) {
      scene.register(VisualSizes.tabletPortrait, Brightness.light);
      scene.register(VisualSizes.desktop, Brightness.light);
    }
    if (scaledScenes.contains(scene.name)) {
      scene.register(VisualSizes.phone, Brightness.light, textScale: 2);
    }
  }

  group('estados', () {
    for (final brightness in Brightness.values) {
      final theme = _themeName(brightness);
      testWidgets('error de la API · 360 · $theme', (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, brightness);
          await pumpApp(
            tester,
            VisualSizes.phone,
            respond: (url) => http.Response('error', 500),
          );
          await expectScreen(tester, 'estado_error_api_360_$theme');
        });
      });

      testWidgets('límite de consultas (429) · 360 · $theme', (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, brightness);
          var limited = false;
          await pumpApp(
            tester,
            VisualSizes.phone,
            respond: (url) {
              if (limited) return null;
              limited = true;
              return http.Response('{"error": "Too Many Requests"}', 429);
            },
            settle: false,
          );
          await tester.pump(const Duration(seconds: 1));
          await expectScreen(tester, 'estado_limite_360_$theme');
          // Deja terminar la pausa y las cargas antes de cerrar el test.
          await tester.pump(const Duration(seconds: 61));
          await tester.pumpAndSettle();
        });
      });
    }
  });
}

String _themeName(Brightness b) => b == Brightness.light ? 'claro' : 'oscuro';

class _Scene {
  _Scene(this.name, this.open, {this.continental = false});

  final String name;
  final Future<void> Function(WidgetTester tester) open;

  /// Usa la hora de las grabaciones de las copas (14/10/2026, D1).
  final bool continental;

  void register(Size size, Brightness brightness, {double textScale = 1}) {
    final theme = _themeName(brightness);
    final scale = textScale == 1 ? '' : '_${(textScale * 100).round()}';
    final file = '${name}_${size.width.round()}${scale}_$theme';
    testWidgets(file, (tester) async {
      await withRealShadows(() async {
        useBrightness(tester, brightness);
        if (textScale != 1) useTextScale(tester, textScale);
        await pumpApp(
          tester,
          size,
          now: continental ? continentalRecordingTime : null,
        );
        await open(tester);
        await expectScreen(tester, file);
      });
    });
  }
}
