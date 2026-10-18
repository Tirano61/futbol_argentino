import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/accessibility.dart';
import '../helpers/recorded_app.dart';
import 'visual_helpers.dart';

/// E1 (Hito E, §13): las pautas de accesibilidad de `accessibility_test`
/// (objetivos táctiles, etiquetas y contraste de texto) también en tema
/// oscuro, que hasta ahora no se verificaba. Diagnóstico del diseño actual
/// y base para las fases siguientes.
void main() {
  final screens = <String, String?>{
    'Inicio': null,
    'Fixture': '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
    'Tabla': '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
    'Calendario':
        '/competiciones/4406?temporada=2026&vista=calendario&mes=2026-10',
    'Llaves': '/competiciones/4406?temporada=2026&vista=llaves&llave=apertura',
    'Detalle': '/partidos/2398104',
  };

  for (final size in [VisualSizes.phone, VisualSizes.tabletLandscape]) {
    for (final MapEntry(key: screen, value: location) in screens.entries) {
      testWidgets('tema oscuro · $screen · ${size.width.round()} px', (
        tester,
      ) async {
        useBrightness(tester, Brightness.dark);
        await pumpApp(tester, size);
        if (screen == 'Detalle') {
          // El partido tiene que estar guardado (su fecha, la 11).
          await goTo(
            tester,
            '/competiciones/4406?temporada=2026&fase=clausura&ronda=11',
          );
        }
        if (location != null) {
          await goTo(tester, location, wait: const Duration(minutes: 2));
        }
        await expectGuidelines(tester);
      });
    }
  }
}
