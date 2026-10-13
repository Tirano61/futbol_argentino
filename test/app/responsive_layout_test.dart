import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/recorded_app.dart';

void main() {
  // Teléfono, tablet vertical, notebook y monitor (plan T9.1).
  const phone = Size(360, 780);
  const tablet = Size(768, 1024);
  const laptop = Size(1280, 800);
  const monitor = Size(1920, 1080);

  for (final size in [phone, tablet, laptop, monitor]) {
    final width = size.width.toInt();
    final desktop = size.width >= 1200;

    testWidgets('$width px: las 4 secciones sin desbordes', (tester) async {
      await pumpApp(tester, size);

      expect(
        find.byType(NavigationBar),
        size.width < 600 ? findsOne : findsNothing,
      );
      if (size.width >= 600) {
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        expect(rail.extended, desktop);
      }
      expect(find.byType(MatchCard), findsWidgets);
      expect(
        find.widgetWithText(TextField, 'Buscar equipo'),
        desktop ? findsOne : findsNothing,
      );

      await openSection(tester, 'Competiciones');
      expect(find.text('Fecha 12'), findsOne);
      expect(find.byType(MatchCard), findsWidgets);

      await openSection(tester, 'Equipos');
      expect(find.text('Buscá un equipo'), findsOne);

      await openSection(tester, 'Favoritos');
      expect(find.text('Todavía no tenés equipos favoritos'), findsOne);
      // Los desbordes de layout fallan el test por sí solos.
    });

    testWidgets('$width px: Tabla sin desbordes', (tester) async {
      await pumpApp(tester, size);
      await openSection(tester, 'Competiciones');

      await openTable(tester);
      expect(find.text('Tabla Anual 2026'), findsWidgets);
      expect(find.text('Pts'), findsOne);
      expect(find.text('GF'), desktop ? findsOne : findsNothing);

      await tester.tap(find.text('Apertura · Zona A'));
      await tester.pumpAndSettle();
      expect(find.text('Apertura 2026 · Zona A'), findsOne);
      // Los desbordes de layout fallan el test por sí solos.
    });

    testWidgets('$width px: Ajustes sin desbordes', (tester) async {
      await pumpApp(tester, size);

      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Datos guardados'), findsOne);
      // Lo que guardó el Inicio: temporada actual, no se puede borrar.
      expect(find.text('Primera División'), findsOne);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(
        tester.getSize(find.byType(ListView)).width,
        lessThanOrEqualTo(720),
      );

      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      expect(find.text('Hoy'), findsOne);
    });
  }

  for (final size in [phone, tablet]) {
    testWidgets('${size.width.toInt()} px: Inicio en una columna', (
      tester,
    ) async {
      await pumpApp(tester, size);

      // Tus equipos arriba de Hoy, en la misma columna.
      final hoy = tester.getTopLeft(find.text('Hoy'));
      final tusEquipos = tester.getTopLeft(find.text('Tus equipos'));
      expect(tusEquipos.dy, lessThan(hoy.dy));
      expect(tusEquipos.dx, hoy.dx);
      expect(find.text('Buscar equipo'), findsOne);
    });
  }

  for (final size in [laptop, monitor]) {
    testWidgets('${size.width.toInt()} px: Inicio en dos columnas', (
      tester,
    ) async {
      await pumpApp(tester, size);

      final hoy = tester.getRect(find.text('Hoy'));
      final recientes = tester.getRect(find.text('Recientes'));
      final tusEquipos = tester.getRect(find.text('Tus equipos'));
      // Hoy a la izquierda; accesos, tus equipos y Recientes a la derecha.
      expect(recientes.left, greaterThan(hoy.right));
      expect(tusEquipos.left, recientes.left);
      expect(tusEquipos.top, lessThan(recientes.top));
      // El contenido no pasa de 1200 px.
      final list = tester.getRect(find.byType(ListView));
      expect(list.width, lessThanOrEqualTo(1200));
    });
  }

  testWidgets('escritorio: el buscador de la barra abre Equipos con la '
      'búsqueda', (tester) async {
    await pumpApp(tester, laptop);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar equipo'),
      'river',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // El índice local ya tiene los equipos de la primera etapa.
    expect(find.text('River Plate'), findsOne);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2);
  });

  testWidgets('el aviso de favoritos no pasa a otra sección', (tester) async {
    await pumpApp(tester, tablet);
    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField), 'river');
    // Espera de la búsqueda (debounce de 350 ms).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Agregar a favoritos').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('River Plate se agregó a favoritos'), findsOne);

    await tester.tap(find.text('Inicio'));
    // Se quita al terminar el frame del cambio de sección.
    await tester.pump();
    await tester.pump();
    expect(find.text('River Plate se agregó a favoritos'), findsNothing);
  });
}
