import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/calendar_panel.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_group.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../visual/visual_helpers.dart' show goTo, useBrightness, useTextScale;

/// Hito E, Fase E5: el calendario mensual rediseñado, con la fuente real
/// (Roboto). Mes y lista lado a lado según el **ancho disponible** y la
/// escala de texto; hoy con anillo, el día elegido relleno; celdas que
/// crecen con el texto; la lista del día agrupada por etapa.
void main() {
  setUpAll(loadRealFonts);

  const october =
      '/competiciones/4406?temporada=2026&vista=calendario&mes=2026-10';

  Finder dayCell(String label) => find.bySemanticsLabel(label);

  /// El mes y la lista lado a lado: la primera fila de partido empieza a
  /// la derecha de la grilla.
  bool isSplit(WidgetTester tester) {
    final month = tester.getRect(find.text('Octubre 2026'));
    final grid = tester.getRect(find.text('31'));
    final row = tester.getRect(find.byType(MatchCard).first);
    return row.left > grid.right && row.left > month.right;
  }

  group('mes y lista: uno debajo del otro o lado a lado', () {
    for (final (size, scale, split) in [
      (const Size(360, 780), 1.0, false),
      (const Size(411, 860), 1.0, false),
      (const Size(768, 1024), 1.0, false),
      (const Size(800, 1280), 1.0, false),
      // Con el riel (unos 104 px), el contenido llega a 900 px.
      (const Size(1000, 800), 1.0, false),
      (const Size(1024, 768), 1.0, true),
      (const Size(1280, 800), 1.0, true),
      (const Size(1920, 1080), 1.0, true),
      // Con texto grande, la lista no entraría cómoda al costado.
      (const Size(1280, 800), 2.0, false),
      (const Size(1920, 1080), 2.0, false),
    ]) {
      final name = '${size.width.toInt()} px al ${(scale * 100).round()} %';
      testWidgets('$name: ${split ? 'lado a lado' : 'uno debajo del otro'}', (
        tester,
      ) async {
        if (scale != 1) useTextScale(tester, scale);
        await pumpApp(tester, size);
        await goTo(tester, october);

        final panel = tester.getSize(find.byType(CalendarPanel)).width;
        expect(isSplit(tester), split, reason: 'vista de $panel px');
        // La regla: ≥ 900 px disponibles y la lista con 400 px a escala 1.
        expect(
          panel >= 900 && panel - 480 - 1 >= 400 * scale,
          split,
          reason: 'vista de $panel px',
        );
      });
    }
  });

  testWidgets('hoy con anillo y elegido; tocar otro día lo elige y hoy '
      'queda solo con el anillo', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, const Size(360, 780));
    await goTo(tester, october);

    bool isSelected(String label) {
      try {
        expect(
          tester.getSemantics(dayCell(label)),
          isSemantics(isSelected: true),
        );
        return true;
      } on TestFailure {
        return false;
      }
    }

    Material cell(String day) => tester.widget<Material>(
      find.ancestor(of: find.text(day), matching: find.byType(Material)).first,
    );
    final colors = Theme.of(
      tester.element(find.byType(CalendarPanel)),
    ).colorScheme;

    const today = 'Domingo 11/10/2026, hoy: 5 partidos';
    const sunday = 'Domingo 18/10/2026: 15 partidos';
    expect(isSelected(today), isTrue);
    expect(isSelected(sunday), isFalse);
    expect(cell('11').color, colors.primary);
    // Elegido y hoy: el anillo en el color del texto, así se sigue viendo.
    expect(
      (cell('11').shape! as RoundedRectangleBorder).side.color,
      colors.onPrimary,
    );

    await tester.tap(dayCell(sunday));
    await tester.pumpAndSettle();
    expect(isSelected(sunday), isTrue);
    expect(isSelected(today), isFalse);
    expect(cell('18').color, colors.primary);
    expect(cell('11').color, Colors.transparent);
    expect(
      (cell('11').shape! as RoundedRectangleBorder).side.color,
      colors.primary,
    );
    // Un día sin partidos no tiene anillo ni relleno, y no se elige.
    expect((cell('13').shape! as RoundedRectangleBorder).side, BorderSide.none);
    await tester.tap(dayCell('Martes 13/10/2026: sin partidos guardados'));
    await tester.pumpAndSettle();
    expect(isSelected(sunday), isTrue);
    semantics.dispose();
  });

  testWidgets('día argentino: el partido de las 00:30 UTC del lunes 12 se '
      'juega el domingo 11 a las 21:30', (tester) async {
    await pumpApp(tester, const Size(360, 780));
    await goTo(tester, october);

    expect(dayCell('Domingo 11/10/2026, hoy: 5 partidos'), findsOne);
    expect(dayCell('Lunes 12/10/2026: 2 partidos'), findsOne);
    final sundayGroup = find.ancestor(
      of: find.text('Clausura · Fecha 12'),
      matching: find.byType(MatchGroup),
    );
    expect(
      find.descendant(of: sundayGroup, matching: find.text('21:30')),
      findsOne,
    );
    expect(
      find.descendant(
        of: sundayGroup,
        matching: find.text('Talleres de Córdoba'),
      ),
      findsOne,
    );
  });

  testWidgets('al 200 %: las celdas crecen con el texto (el número no se '
      'achica) y nada desborda', (tester) async {
    double dayHeight() => tester.getRect(find.text('9')).height;

    await pumpApp(tester, const Size(360, 780));
    await goTo(tester, october);
    final normal = dayHeight();

    useTextScale(tester, 2);
    await tester.pumpAndSettle();
    expect(dayHeight(), closeTo(normal * 2, 1));
    // La celda llega al menos a la altura del número y su cantidad.
    final cell = tester.getRect(dayCell('Viernes 09/10/2026: 4 partidos'));
    expect(cell.height, greaterThan(dayHeight() * 1.5));
  });

  group('accesibilidad', () {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(360, 780), const Size(1280, 800)]) {
        testWidgets('${size.width.toInt()} px, ${brightness.name}: pautas', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          useBrightness(tester, brightness);
          await pumpApp(tester, size);
          await goTo(tester, october);
          await expectGuidelines(tester);
          semantics.dispose();
        });
      }
    }
  });
}
