import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/match_detail/presentation/pages/match_detail_page.dart';
import 'package:futbol_argentino/features/match_detail/presentation/widgets/match_hero.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../helpers/text_layout.dart';
import '../visual/visual_helpers.dart' show goTo, useBrightness, useTextScale;

/// Hito E, Fase E6: el detalle de un partido con `MatchHero` y los datos en
/// filas etiqueta | valor, con la fuente real (Roboto). El marcador nunca se
/// parte (observación de E4: «1 –» / «3» en el panel al 200 %), ninguna
/// palabra se corta, dos columnas de datos solo con 600 px disponibles, y el
/// ganador del partido se distingue de quien avanza en la llave.
void main() {
  setUpAll(loadRealFonts);

  final hero = find.byType(MatchHero);

  /// (nombre, ruta que guarda el partido, id, centro del héroe, copa).
  const cases = [
    (
      'Primera, final',
      '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
      2398116,
      '1 – 3',
      false,
    ),
    (
      'serie con penales',
      '/competiciones/4501?temporada=2026&fase=eliminatorias'
          '&ronda=125&etapa=eliminatoria',
      2600654,
      '3 – 2',
      true,
    ),
    (
      'Copa Argentina por penales',
      '/competiciones/4500?temporada=2026&vista=llaves',
      2540103,
      '0 – 0',
      false,
    ),
    (
      'programado, nombres largos',
      '/competiciones/4406?temporada=2026&fase=clausura&ronda=13',
      2398141,
      '17:00',
      false,
    ),
  ];

  Future<void> openDetail(
    WidgetTester tester,
    Size size,
    String route,
    int id, {
    required bool continental,
  }) async {
    await pumpApp(
      tester,
      size,
      now: continental ? continentalRecordingTime : null,
    );
    await goTo(tester, route, wait: const Duration(minutes: 1));
    await goTo(tester, '/partidos/$id');
  }

  /// El centro del héroe en un solo renglón, entero y dentro de [area].
  void expectWholeCenter(WidgetTester tester, String center, Rect area) {
    final text = find.descendant(of: hero, matching: find.text(center));
    expect(text, findsOne);
    final p = tester.renderObject<RenderParagraph>(text);
    expect(p.didExceedMaxLines, isFalse);
    expect(linesOf(p, 0, center.length), hasLength(1), reason: center);
    final rect = tester.getRect(text);
    expect(rect.left, greaterThanOrEqualTo(area.left), reason: '$rect');
    expect(rect.right, lessThanOrEqualTo(area.right), reason: '$rect');
  }

  group('pantalla completa: marcador entero, sin palabras partidas', () {
    for (final (name, route, id, center, continental) in cases) {
      for (final width in [360.0, 411.0, 800.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          final label =
              '$name · ${width.toInt()} px · ${(scale * 100).toInt()} %';
          testWidgets(label, (tester) async {
            if (scale != 1) useTextScale(tester, scale);
            await openDetail(
              tester,
              Size(width, 900),
              route,
              id,
              continental: continental,
            );
            expectWholeCenter(tester, center, Offset.zero & Size(width, 900));
            expectWholeWords(tester, find.byType(ListView).last);
          });
        }
      }
    }
  });

  group('panel de 440 px', () {
    for (final (width, scale) in [
      (1280.0, 1.0),
      (1280.0, 2.0),
      (1920.0, 1.0),
    ]) {
      testWidgets('${width.toInt()} px · ${(scale * 100).toInt()} %', (
        tester,
      ) async {
        if (scale != 1) useTextScale(tester, scale);
        await pumpApp(tester, Size(width, 900));
        await goTo(
          tester,
          '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
        );
        final row = find.byWidgetPredicate(
          (w) => w is MatchCard && w.match.id == 2398116,
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        final panel = find.byType(MatchDetailPanel);
        expect(panel, findsOne);
        expectWholeCenter(tester, '1 – 3', tester.getRect(panel));
        expectWholeWords(tester, panel);
        // Una sola columna de datos: la hora debajo de la fecha.
        expect(
          tester.getTopLeft(find.text('Hora (Argentina)')).dy,
          greaterThan(tester.getTopLeft(find.text('Fecha')).dy),
        );
      });
    }
  });

  testWidgets('dos columnas de datos con 600 px disponibles; una en un '
      'teléfono', (tester) async {
    await openDetail(
      tester,
      const Size(1280, 900),
      cases.first.$2,
      cases.first.$3,
      continental: false,
    );
    expect(
      tester.getTopLeft(find.text('Hora (Argentina)')).dy,
      tester.getTopLeft(find.text('Fecha')).dy,
    );

    await openDetail(
      tester,
      const Size(411, 900),
      cases.first.$2,
      cases.first.$3,
      continental: false,
    );
    expect(
      tester.getTopLeft(find.text('Hora (Argentina)')).dy,
      greaterThan(tester.getTopLeft(find.text('Fecha')).dy),
    );
  });

  FontWeight? weightOf(WidgetTester tester, String team) => tester
      .widget<Text>(find.descendant(of: hero, matching: find.text(team)))
      .style
      ?.fontWeight;

  testWidgets('serie: el ganador del partido en negrita y quien avanza en la '
      'llave, aparte', (tester) async {
    final semantics = tester.ensureSemantics();
    await openDetail(
      tester,
      const Size(411, 900),
      cases[1].$2,
      cases[1].$3,
      continental: true,
    );
    // La vuelta la ganó LDU 3-2; la serie, Palmeiras por penales.
    expect(weightOf(tester, 'LDU Quito'), FontWeight.w700);
    expect(weightOf(tester, 'Palmeiras'), FontWeight.w400);
    expect(find.text('Penales: 3-4'), findsOne);
    expect(find.text('Global Palmeiras 3-3 LDU Quito'), findsOne);
    expect(find.text('Clasificó Palmeiras por penales (4-3)'), findsOne);
    expect(
      find.bySemanticsLabel('Llave: Clasificó Palmeiras por penales (4-3)'),
      findsOne,
    );
    // Los datos conservan sus etiquetas y la serie lista las piernas.
    for (final label in ['Fecha', 'Hora (Argentina)', 'Estado', 'Estadio']) {
      expect(find.text(label), findsOne, reason: label);
    }
    expect(
      find.text(
        'Ida: Palmeiras 1-0 LDU Quito\n'
        'Vuelta: LDU Quito 3-2 Palmeiras (3-4 en penales)',
      ),
      findsOne,
    );
    expect(find.widgetWithText(FilledButton, 'Compartir'), findsOne);
    semantics.dispose();
  });

  testWidgets('partido único por penales: gana y avanza el mismo', (
    tester,
  ) async {
    await openDetail(
      tester,
      const Size(411, 900),
      cases[2].$2,
      cases[2].$3,
      continental: false,
    );
    expect(weightOf(tester, 'Boca Juniors'), FontWeight.w700);
    expect(weightOf(tester, 'Vélez Sarsfield'), FontWeight.w400);
    expect(find.text('Penales: 3-4'), findsOne);
    expect(find.text('Avanza Boca Juniors (3-4 en penales)'), findsOne);
  });

  testWidgets('programado: sin ganador, con la hora en el centro y '
      '«Agregar al calendario»', (tester) async {
    await openDetail(
      tester,
      const Size(360, 900),
      cases[3].$2,
      cases[3].$3,
      continental: false,
    );
    expect(weightOf(tester, "Newell's Old Boys"), FontWeight.w400);
    expect(find.textContaining('Avanza'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Compartir'), findsOne);
    expect(
      find.widgetWithText(FilledButton, 'Agregar al calendario'),
      findsOne,
    );
  });

  group('pautas de accesibilidad', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
      for (final width in [360.0, 1280.0]) {
        for (final (name, route, id, _, continental) in [cases[1], cases[3]]) {
          testWidgets('$name · ${width.toInt()} px · $theme', (tester) async {
            final semantics = tester.ensureSemantics();
            useBrightness(tester, brightness);
            await openDetail(
              tester,
              Size(width, 900),
              route,
              id,
              continental: continental,
            );
            await expectGuidelines(tester);
            semantics.dispose();
          });
        }
      }
    }
  });
}
