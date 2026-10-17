import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';

/// Fase D7: con las cuatro vistas de una copa («Fixture | Tabla |
/// Calendario | Llaves»), en un teléfono de 360 px «Calendario» se partía a
/// mitad de palabra (visto en la Web release). Con la fuente real (Roboto).
void main() {
  setUpAll(loadRealFonts);

  const labels = ['Fixture', 'Tabla', 'Calendario', 'Llaves'];

  final selector = find.byWidgetPredicate((w) => w is SegmentedButton);

  Finder inSelector(Finder matching) =>
      find.descendant(of: selector, matching: matching);

  Finder label(String text) => inSelector(find.text(text));

  /// Cada etiqueta en un solo renglón (todas con la misma altura).
  void expectOneLine(WidgetTester tester) {
    final heights = {
      for (final text in labels)
        tester.renderObject<RenderParagraph>(label(text)).size.height,
    };
    expect(heights, hasLength(1), reason: '$heights');
  }

  bool scrolls(WidgetTester tester) => find
      .ancestor(
        of: selector,
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      )
      .evaluate()
      .isNotEmpty;

  Future<void> openCup(WidgetTester tester, Size size) async {
    await pumpApp(tester, size, now: continentalRecordingTime);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Libertadores');
  }

  testWidgets('360 px: las cuatro vistas entran, sin partir «Calendario»', (
    tester,
  ) async {
    await openCup(tester, const Size(360, 800));

    expect(inSelector(find.byType(Icon)), findsNothing);
    expect(scrolls(tester), isFalse);
    expectOneLine(tester);
    expect(tester.getRect(selector).right, lessThanOrEqualTo(360));
  });

  testWidgets('360 px con texto al 200 %: se desplaza, sin partir las '
      'etiquetas', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openCup(tester, const Size(360, 800));

    expect(scrolls(tester), isTrue);
    expectOneLine(tester);
  });

  testWidgets('800 px: con íconos, en una línea', (tester) async {
    await openCup(tester, const Size(800, 1280));

    expect(inSelector(find.byType(Icon)), findsNWidgets(4));
    expect(scrolls(tester), isFalse);
    expectOneLine(tester);
  });
}
