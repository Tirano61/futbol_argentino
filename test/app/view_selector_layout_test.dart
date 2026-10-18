import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/view_tabs.dart';
import 'package:futbol_argentino/shared/presentation/widgets/scroll_row.dart';

import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';

/// Fase D7 y Hito E (E4): las vistas de una copa («Fixture · Tabla ·
/// Calendario · Llaves») como pestañas. En un teléfono de 360 px
/// «Calendario» se partía a mitad de palabra (visto en la Web release):
/// nunca se parte una etiqueta; si no entran, se desplazan con el borde
/// esfumado. Con la fuente real (Roboto).
void main() {
  setUpAll(loadRealFonts);

  const labels = ['Fixture', 'Tabla', 'Calendario', 'Llaves'];

  final tabs = find.byType(ViewTabs);

  Finder inTabs(Finder matching) =>
      find.descendant(of: tabs, matching: matching);

  Finder label(String text) => inTabs(find.text(text));

  /// Cada etiqueta en un solo renglón (todas con la misma altura).
  void expectOneLine(WidgetTester tester) {
    final heights = {
      for (final text in labels)
        tester.renderObject<RenderParagraph>(label(text)).size.height,
    };
    expect(heights, hasLength(1), reason: '$heights');
    for (final text in labels) {
      expect(
        tester.renderObject<RenderParagraph>(label(text)).didExceedMaxLines,
        isFalse,
        reason: text,
      );
    }
  }

  final scrollRow = inTabs(find.byType(ScrollRow));

  bool scrolls(WidgetTester tester) => scrollRow.evaluate().isNotEmpty;

  /// La pestaña elegida: semántica de elegida, color y subrayado.
  void expectSelected(WidgetTester tester, CompetitionsView view, String text) {
    expect(tester.widget<ViewTabs>(tabs).view, view);
    expect(
      tester.getSemantics(label(text)),
      isSemantics(isSelected: true, isButton: true),
    );
    for (final other in labels.where((l) => l != text)) {
      expect(tester.getSemantics(label(other)), isSemantics(isSelected: false));
    }
  }

  Future<void> openCup(WidgetTester tester, Size size) async {
    await pumpApp(tester, size, now: continentalRecordingTime);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Libertadores');
  }

  testWidgets('360 px: las cuatro vistas entran, sin partir «Calendario»', (
    tester,
  ) async {
    await openCup(tester, const Size(360, 800));

    expect(inTabs(find.byType(Icon)), findsNothing);
    expect(scrolls(tester), isFalse);
    expectOneLine(tester);
    expect(tester.getRect(tabs).right, lessThanOrEqualTo(360));
    expect(tester.getRect(label('Llaves')).right, lessThanOrEqualTo(360));
    expectSelected(tester, CompetitionsView.fixture, 'Fixture');
    // Área táctil de cada pestaña.
    for (final text in labels) {
      final tab = find.ancestor(
        of: label(text),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tab.first).height, greaterThanOrEqualTo(48));
    }

    await openView(tester, 'Calendario');
    expectSelected(tester, CompetitionsView.calendar, 'Calendario');
    expect(find.text('Octubre 2026'), findsOne);
  });

  testWidgets('360 px con texto al 200 %: se desplaza, sin partir las '
      'etiquetas, con el borde esfumado del lado que sigue', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openCup(tester, const Size(360, 800));

    expect(scrolls(tester), isTrue);
    expectOneLine(tester);
    final row = tester.state<ScrollRowState>(scrollRow);
    expect(row.hints, (before: false, after: true));

    // La última se elige desplazando; queda a la vista y el borde del
    // principio pasa a esfumarse.
    await openView(tester, 'Llaves');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expectSelected(tester, CompetitionsView.bracket, 'Llaves');
    expect(tester.getRect(label('Llaves')).right, lessThanOrEqualTo(360));
    expect(row.hints.before, isTrue);
    expectOneLine(tester);
  });

  testWidgets('800 px: con íconos, en una línea', (tester) async {
    await openCup(tester, const Size(800, 1280));

    expect(inTabs(find.byType(Icon)), findsNWidgets(4));
    expect(scrolls(tester), isFalse);
    expectOneLine(tester);
  });

  testWidgets('1280 px junto al panel de detalle: en una línea, dentro de la '
      'columna', (tester) async {
    await openCup(tester, const Size(1280, 800));

    expect(scrolls(tester), isFalse);
    expectOneLine(tester);
    final column = tester.getRect(tabs);
    expect(tester.getRect(label('Llaves')).right, lessThan(column.right));
    // La columna del fixture termina donde empieza el panel.
    expect(find.text('Detalle del partido'), findsOne);
    expect(
      column.right,
      lessThanOrEqualTo(tester.getRect(find.text('Detalle del partido')).left),
    );
  });

  testWidgets('B Metro: solo Fixture y Calendario', (tester) async {
    await pumpApp(tester, const Size(360, 800));
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'B Metro');

    expect(label('Fixture'), findsOne);
    expect(label('Calendario'), findsOne);
    expect(label('Tabla'), findsNothing);
    expect(label('Llaves'), findsNothing);
    expect(scrolls(tester), isFalse);
  });
}
