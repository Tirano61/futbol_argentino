import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/calendar_panel.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/accessibility.dart';
import '../helpers/recorded_app.dart';

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
      await openNacionalTable(tester);
      expect(find.text('Posiciones 2026 · Zona A'), findsOne);
      await expectGuidelines(tester);
      await openView(tester, 'Calendario');
      expect(find.text('Octubre 2026'), findsOne);
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
    final semantics = tester.ensureSemantics();
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
    await openNacionalTable(tester);
    expect(find.text('Posiciones 2026 · Zona A'), findsOne);
    await openView(tester, 'Calendario');
    // Con los selectores, el calendario queda bajo: se desplaza la lista.
    final calendarList = find
        .descendant(
          of: find.byType(CalendarPanel),
          matching: find.byType(Scrollable),
        )
        .first;
    // Nacional (la última elegida): 12 partidos el sábado 17.
    final saturday = find.bySemanticsLabel('Sábado 17/10/2026: 12 partidos');
    await tester.scrollUntilVisible(saturday, 200, scrollable: calendarList);
    await tester.pumpAndSettle();
    expect(find.text('Octubre 2026'), findsOne);
    await tester.tap(saturday);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sábado 17/10/2026'),
      200,
      scrollable: calendarList,
    );
    await openView(tester, 'Fixture');

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
    semantics.dispose();
    // Los desbordes de layout fallan el test por sí solos.
  });
}
