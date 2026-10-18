import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/bracket_panel.dart';
import 'package:futbol_argentino/shared/presentation/theme/app_palette.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../helpers/text_layout.dart';
import '../visual/visual_helpers.dart' show goTo, useBrightness, useTextScale;

/// Hito E, Fase E6: los cuadros de llaves rediseñados, con la fuente real
/// (Roboto). Las tarjetas se miden con la escala de texto: al 200 % no se
/// recorta «Ida · Vuelta» (observación de E4) ni se parte un nombre, la
/// primera columna entra en un teléfono y el cuadro sigue desplazándose.
void main() {
  setUpAll(loadRealFonts);

  /// Nombres con el ✓ del que avanza (carácter de la fuente de íconos al
  /// final del texto) dentro de [scope].
  List<RenderParagraph> winnerNames(Finder scope) => [
    for (final p in paragraphsIn(scope))
      if (p.text.toPlainText().endsWith(
        String.fromCharCode(Icons.check.codePoint),
      ))
        p,
  ];

  /// Lleva la lista de Llaves hasta el final (Playoffs y notas).
  Future<void> scrollToEnd(WidgetTester tester) async {
    final list = find.descendant(
      of: find.byType(BracketPanel),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 30; i++) {
      await tester.drag(list.first, const Offset(0, -400));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  final panel = find.byType(BracketPanel);
  Finder firstColumn() =>
      find.bySemanticsLabel(RegExp(r'^Octavos de final\. '));

  const brackets = [
    (
      'Primera Apertura 2026',
      '/competiciones/4406?temporada=2026&vista=llaves&llave=apertura',
      false,
    ),
    (
      'Copa Argentina 2026',
      '/competiciones/4500?temporada=2026&vista=llaves',
      false,
    ),
    (
      'Libertadores 2025',
      '/competiciones/4501?temporada=2025&vista=llaves',
      true,
    ),
    (
      'Libertadores 2026',
      '/competiciones/4501?temporada=2026&vista=llaves',
      true,
    ),
    (
      'Sudamericana 2025',
      '/competiciones/4724?temporada=2025&vista=llaves',
      true,
    ),
  ];

  Future<void> openBracket(
    WidgetTester tester,
    double width,
    String route, {
    required bool continental,
  }) async {
    await pumpApp(
      tester,
      Size(width, 900),
      now: continental ? continentalRecordingTime : null,
    );
    await goTo(tester, route, wait: const Duration(minutes: 1));
  }

  group('sin recortes ni palabras partidas', () {
    for (final (name, route, continental) in brackets) {
      for (final width in [360.0, 411.0, 800.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          final label =
              '$name · ${width.toInt()} px · ${(scale * 100).toInt()} %';
          testWidgets(label, (tester) async {
            final semantics = tester.ensureSemantics();
            if (scale != 1) useTextScale(tester, scale);
            await openBracket(tester, width, route, continental: continental);

            expect(firstColumn(), findsWidgets);
            expectWholeWords(tester, panel);
            for (final card in firstColumn().evaluate()) {
              final rect = tester.getRect(find.byWidget(card.widget));
              // Tocable (≥ 48) y, en un teléfono, entera a la vista: la
              // columna no supera el ancho aunque el texto esté al 200 %.
              expect(rect.height, greaterThanOrEqualTo(48));
              if (width < 600) {
                expect(rect.right, lessThanOrEqualTo(width), reason: '$rect');
              }
            }
            semantics.dispose();
          });
        }
      }
    }
  });

  testWidgets('al 200 % las piernas de cada serie se leen enteras', (
    tester,
  ) async {
    useTextScale(tester, 2);
    await openBracket(
      tester,
      360,
      '/competiciones/4501?temporada=2025&vista=llaves',
      continental: true,
    );

    final legs = [
      for (final p in paragraphsIn(panel))
        if (p.text.toPlainText().contains('Vuelta')) p,
    ];
    expect(legs, isNotEmpty);
    for (final p in legs) {
      final text = p.text.toPlainText();
      expect(p.didExceedMaxLines, isFalse, reason: text);
      // Se parte entre piernas, nunca dentro de una («Vuelta 0-2»).
      for (final leg in RegExp(
        '(Ida|Vuelta)\u00A0[0-9]+-[0-9]+',
      ).allMatches(text)) {
        expect(linesOf(p, leg.start, leg.end), hasLength(1), reason: text);
      }
    }
    // Con 8 llaves de octavos, el cuadro se sigue desplazando de costado.
    expect(
      find.descendant(
        of: panel,
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('al 200 % el ✓ nunca queda solo en un renglón', (tester) async {
    useTextScale(tester, 2);
    // Sudamericana 2025: cuadro y Playoffs (en el teléfono, «Alianza Lima ✓»
    // dejaba el ✓ solo con un `WidgetSpan`).
    for (final width in [360.0, 411.0]) {
      await openBracket(
        tester,
        width,
        '/competiciones/4724?temporada=2025&vista=llaves',
        continental: true,
      );
      await scrollToEnd(tester);
      final names = winnerNames(panel);
      expect(names, isNotEmpty);
      for (final p in names) {
        final text = p.text.toPlainText();
        final check = text.length - 1;
        expect(
          linesOf(p, check, check + 1),
          linesOf(p, check - 2, check - 1),
          reason: '«$text» (${width.toInt()} px): el ✓ en otro renglón',
        );
      }
    }
  });

  testWidgets('el que avanza: ✓ y negrita solo con evidencia', (tester) async {
    await openBracket(
      tester,
      1280,
      '/competiciones/4406?temporada=2026&vista=llaves&llave=apertura',
      continental: false,
    );
    // Apertura 2026 completo: 8 + 4 + 2 + 1 llaves definidas.
    expect(winnerNames(panel), hasLength(15));
    expect(find.text('Campeón: Belgrano'), findsOne);
  });

  testWidgets('Sudamericana 2025: la final sin dato de la definición, sin ✓', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openBracket(
      tester,
      1280,
      '/competiciones/4724?temporada=2025&vista=llaves',
      continental: true,
    );
    final finalTie = find.bySemanticsLabel(RegExp(r'^Final\. '));
    final label = tester.getSemantics(finalTie).label;
    expect(label, contains('Sin dato de la definición'));
    expect(label, isNot(contains('Avanza')));
    final card = find
        .ancestor(
          of: find.textContaining('Sin dato de la definición'),
          matching: find.byType(Material),
        )
        .first;
    expect(winnerNames(card), isEmpty);
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.help_outline)),
      findsOne,
    );
    semantics.dispose();
  });

  testWidgets('Libertadores 2026: en juego en el color de «en vivo» y la '
      'final «A definir»', (tester) async {
    await openBracket(
      tester,
      1280,
      '/competiciones/4501?temporada=2026&vista=llaves',
      continental: true,
    );
    final live = tester.widget<Text>(find.text('Ida en juego'));
    expect(live.style?.color, AppPalette.light.live);
    expect(live.style?.fontWeight, FontWeight.w700);
    expect(find.text('A definir'), findsNWidgets(2));
    expect(find.text('Sin datos del partido'), findsOne);
  });

  // Con Roboto, la pauta de contraste mide píxeles: con «Apertura» elegida
  // el chip «Clausura» (el mismo estilo que el resto de los chips, de E4)
  // da 2,25:1 por el suavizado de esa palabra; con «Clausura» elegida pasa.
  // Por eso Primera se verifica en el Clausura y las tarjetas de llaves, en
  // las copas.
  group('pautas de accesibilidad', () {
    const cases = [
      (
        'Libertadores 2026',
        '/competiciones/4501?temporada=2026&vista=llaves',
        true,
      ),
      (
        'Sudamericana 2025',
        '/competiciones/4724?temporada=2025&vista=llaves',
        true,
      ),
      (
        'Copa Argentina 2026',
        '/competiciones/4500?temporada=2026&vista=llaves',
        false,
      ),
      (
        'Primera Clausura 2026',
        '/competiciones/4406?temporada=2026&vista=llaves&llave=clausura',
        false,
      ),
    ];
    for (final brightness in Brightness.values) {
      for (final width in [360.0, 1280.0]) {
        for (final (name, route, continental) in cases) {
          final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
          testWidgets('$name · ${width.toInt()} px · $theme', (tester) async {
            final semantics = tester.ensureSemantics();
            useBrightness(tester, brightness);
            await openBracket(tester, width, route, continental: continental);
            await expectGuidelines(tester);
            semantics.dispose();
          });
        }
      }
    }
  });
}
