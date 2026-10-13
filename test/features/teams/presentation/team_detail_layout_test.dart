import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/recorded_app.dart';

/// Fase 15 (D8): la ficha de Boca, con la sección «Otras competiciones», en
/// la app completa con respuestas grabadas: sin desbordes en cada ancho,
/// con las pautas de accesibilidad y con texto al 200 %.
void main() {
  final section = find.text('Otras competiciones (información parcial)');

  Future<void> openBoca(WidgetTester tester) async {
    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField).last, 'boca');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boca Juniors').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      section,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  /// Sale de la ficha y deja terminar la petición que ya esperaba cupo.
  Future<void> closeDetail(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
  }

  for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
    testWidgets('${width.toInt()} px: sin desbordes y con las pautas', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, Size(width, 900));
      await openBoca(tester);

      expect(section, findsOne);
      expect(find.text('Copa Sudamericana · Próximo partido'), findsOne);
      await expectGuidelines(tester);

      await closeDetail(tester);
      semantics.dispose();
    });
  }

  testWidgets('texto al 200 % en un teléfono: sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, const Size(360, 780));
    await openBoca(tester);

    expect(section, findsOne);
    await tester.scrollUntilVisible(
      find.text('Copa Sudamericana · Próximo partido'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    await closeDetail(tester);
  });
}
