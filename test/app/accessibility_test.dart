import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/recorded_app.dart';

/// Pautas básicas de accesibilidad de Flutter: objetivos táctiles de al
/// menos 48 px, controles con nombre y contraste de texto.
Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (final size in [const Size(360, 780), const Size(1280, 800)]) {
    final width = size.width.toInt();

    testWidgets('$width px: pautas de accesibilidad en cada sección', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, size);
      await expectGuidelines(tester);

      await openSection(tester, 'Competiciones');
      await expectGuidelines(tester);

      await tester.tap(find.byType(MatchCard).first);
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
      if (size.width < 1200) {
        // `pageBack` busca el texto en inglés («Back»).
        await tester.tap(find.byTooltip('Atrás'));
        await tester.pumpAndSettle();
      }

      await openTable(tester);
      await expectGuidelines(tester);

      await openSection(tester, 'Equipos');
      await expectGuidelines(tester);

      await openSection(tester, 'Favoritos');
      await expectGuidelines(tester);

      await openSection(tester, 'Inicio');
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await expectGuidelines(tester);
      semantics.dispose();
    });
  }

  testWidgets('texto al 200 % en un teléfono: sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, const Size(360, 780));
    expect(find.text('Tus equipos'), findsOne);
    await tester.scrollUntilVisible(
      find.byType(MatchCard),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await openSection(tester, 'Competiciones');
    // Con los selectores (y «Fixture | Tabla») la lista queda baja.
    await tester.ensureVisible(find.byType(MatchCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MatchCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Hora (Argentina)'), findsOne);
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    await openTable(tester);
    expect(find.text('Tabla Anual 2026'), findsWidgets);
    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();

    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField), 'river');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('River Plate'));
    await tester.pumpAndSettle();
    expect(find.text('Próximos'), findsOne);
    // Cerrar la ficha detiene su sincronización; la petición que ya
    // esperaba cupo del límite por minuto se deja terminar.
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));

    await openSection(tester, 'Favoritos');

    await openSection(tester, 'Inicio');
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Datos guardados'), findsOne);
    // Los desbordes de layout fallan el test por sí solos.
  });
}
