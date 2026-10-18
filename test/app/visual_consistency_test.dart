import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/bracket_panel.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/view_tabs.dart';
import 'package:futbol_argentino/shared/presentation/theme/app_spacing.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/team_badge.dart';
import 'package:http/http.dart' as http;

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../helpers/text_layout.dart';
import '../visual/visual_helpers.dart' show goTo, useTextScale;

/// Hito E, Fase E7: correcciones visuales pendientes de E2–E6, con la
/// fuente real (Roboto) y la app completa sobre los datos grabados.
void main() {
  setUpAll(loadRealFonts);

  RenderParagraph paragraphOf(WidgetTester tester, Finder text) =>
      tester.renderObject<RenderParagraph>(text);

  int lineCount(RenderParagraph p) {
    final text = p.text.toPlainText();
    return linesOf(p, 0, text.length).length;
  }

  group('nombres largos en la fila de partido', () {
    for (final width in [360.0, 411.0]) {
      testWidgets('${width.toInt()} px: «Gimnasia y Esgrima de Mendoza» y '
          '«… de La Plata» enteros, sin palabras partidas', (tester) async {
        // Alta: todas las filas construidas (lo que se mide es el ancho).
        await pumpApp(tester, Size(width, 3000));
        await goTo(
          tester,
          '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
        );
        for (final name in [
          'Gimnasia y Esgrima de Mendoza',
          'Gimnasia y Esgrima de La Plata',
        ]) {
          final text = find.descendant(
            of: find.byType(MatchCard),
            matching: find.text(name),
          );
          expect(text, findsOne, reason: name);
          for (final p in [
            for (final e in text.evaluate()) e.renderObject! as RenderParagraph,
          ]) {
            expect(p.didExceedMaxLines, isFalse, reason: name);
          }
          expectWholeWords(
            tester,
            find.ancestor(of: text.first, matching: find.byType(MatchCard)),
          );
        }
      });
    }
  });

  testWidgets('iniciales de un escudo sin imagen al 200 %: en un renglón y '
      'dentro del círculo', (tester) async {
    useTextScale(tester, 2);
    await pumpApp(tester, const Size(360, 780));
    await goTo(
      tester,
      '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
    );
    final initials = find.descendant(
      of: find.byType(TeamBadge),
      matching: find.byType(RichText),
    );
    expect(initials, findsWidgets);
    for (final element in initials.evaluate()) {
      final p = element.renderObject! as RenderParagraph;
      final badge = tester.getSize(
        find
            .ancestor(
              of: find.byWidget(element.widget),
              matching: find.byType(TeamBadge),
            )
            .first,
      );
      expect(lineCount(p), 1, reason: p.text.toPlainText());
      expect(p.size.width, lessThanOrEqualTo(badge.width));
    }
  });

  group('Inicio', () {
    testWidgets('«Primera División» una sola vez en los accesos: el chip es '
        'el encabezado de su categoría', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final size in [const Size(360, 780), const Size(1280, 800)]) {
        await pumpApp(tester, size);
        final shortcuts = find.byType(ActionChip);
        expect(shortcuts, findsWidgets);
        final labels = find.descendant(
          of: find.ancestor(
            of: shortcuts.first,
            matching: find.byType(Scrollable).first.evaluate().isEmpty
                ? find.byType(Wrap)
                : find.byType(Row),
          ),
          matching: find.text('Primera División'),
        );
        expect(labels, findsOne, reason: '$size');
        expect(
          tester.getSemantics(
            find.widgetWithText(ActionChip, 'Primera División'),
          ),
          isSemantics(isHeader: true, isButton: true),
        );
        // Las demás categorías conservan su etiqueta.
        expect(find.text('Ascenso'), findsOne);
        expect(find.text('Copas internacionales'), findsOne);
      }
      semantics.dispose();
    });

    for (final size in [const Size(360, 780), const Size(800, 1280)]) {
      testWidgets('${size.width.toInt()} px: con el Inicio en error, el '
          'acceso a la búsqueda sigue a mano', (tester) async {
        await pumpApp(
          tester,
          size,
          respond: (url) => http.Response('error', 500),
        );
        expect(find.text('Reintentar'), findsOne);
        final search = find.text('Buscar equipo');
        expect(search, findsOne);
        expect(
          tester
              .getSize(
                find.ancestor(of: search, matching: find.byType(InkWell)).first,
              )
              .height,
          greaterThanOrEqualTo(AppSizes.tapTarget),
        );
        await tester.tap(search);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'Equipos'), findsOne);
      });
    }

    testWidgets('1920 px: el título de la barra sobre la columna de '
        'contenido', (tester) async {
      await pumpApp(tester, const Size(1920, 1080));
      final title = tester.getRect(find.text('Fútbol Argentino'));
      final content = tester.getRect(find.byType(ListView).first);
      // La barra empezaba en el borde de la sección (231 px antes).
      expect(title.left - content.left, lessThanOrEqualTo(AppSpacing.xl));
      expect(title.left, greaterThanOrEqualTo(content.left));
    });
  });

  testWidgets('1920 px: el selector de competición cerca de las pestañas', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1920, 1080));
    await goTo(tester, '/competiciones/4406?temporada=2026&fase=clausura');
    final selector = tester.getRect(
      find.byKey(FixtureSelectors.competitionSelectorKey),
    );
    final tabs = tester.getRect(find.byType(ViewTabs));
    expect((selector.left - tabs.left).abs(), lessThanOrEqualTo(AppSpacing.lg));
    await expectGuidelines(tester);
  });

  testWidgets('ficha: la barra dice «Equipo» mientras se ve la cabecera y el '
      'nombre del equipo cuando la cabecera sale de la vista', (tester) async {
    await pumpApp(tester, const Size(360, 780));
    await goTo(tester, '/equipos/135156', wait: const Duration(minutes: 5));
    final bar = find.byType(AppBar);
    expect(find.descendant(of: bar, matching: find.text('Equipo')), findsOne);
    expect(
      find.descendant(of: bar, matching: find.text('Boca Juniors')),
      findsNothing,
    );
    expect(find.text('Boca Juniors'), findsWidgets); // cabecera y filas

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.text('Boca Juniors')),
      findsOne,
    );

    // Lejos (la lista ya descartó la cabecera): sigue el nombre.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.text('Boca Juniors')),
      findsOne,
    );

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 6000));
    await tester.pumpAndSettle();
    expect(find.descendant(of: bar, matching: find.text('Equipo')), findsOne);
  });

  for (final width in [360.0, 411.0]) {
    testWidgets('${width.toInt()} px al 200 %: «Competiciones» de la barra '
        'inferior en un renglón', (tester) async {
      useTextScale(tester, 2);
      await pumpApp(tester, Size(width, 780));
      final label = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Competiciones'),
      );
      expect(lineCount(paragraphOf(tester, label)), 1);
      // Las etiquetas igual crecen respecto del tamaño normal.
      expect(
        tester.getSize(label).height,
        greaterThan(
          Theme.of(tester.element(label)).textTheme.labelMedium!.fontSize!,
        ),
      );
    });
  }

  testWidgets('Llaves al 200 %: cada tarjeta con el alto de su contenido, '
      'centrada en su lugar (conectores alineados)', (tester) async {
    useTextScale(tester, 2);
    await pumpApp(tester, const Size(360, 900));
    await goTo(
      tester,
      '/competiciones/4406?temporada=2026&vista=llaves&llave=apertura',
      wait: const Duration(minutes: 1),
    );
    final cards = find.descendant(
      of: find.byType(BracketPanel),
      matching: find.bySemanticsLabel(RegExp(r'^Octavos de final\. ')),
    );
    final rects = [
      for (final e in cards.evaluate()) tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects, hasLength(8));
    // Lugares iguales: los centros, a la misma distancia.
    final steps = [
      for (var i = 1; i < rects.length; i++)
        rects[i].center.dy - rects[i - 1].center.dy,
    ];
    for (final step in steps) {
      expect(step, moreOrLessEquals(steps.first, epsilon: 0.5));
    }
    // Las de nombres cortos ya no toman el alto de la más alta.
    final heights = {for (final r in rects) r.height.round()};
    expect(heights.length, greaterThan(1));
    for (final r in rects) {
      expect(r.height, greaterThanOrEqualTo(AppSizes.tapTarget));
    }
  });

  testWidgets('detalle de una serie al 200 % en 360: escudos de 32 con el '
      'marcador debajo, y «día · hora» y la etapa sin palabras sueltas', (
    tester,
  ) async {
    useTextScale(tester, 2);
    await pumpApp(tester, const Size(360, 780), now: continentalRecordingTime);
    await goTo(
      tester,
      '/competiciones/4501?temporada=2026&fase=eliminatorias'
      '&ronda=125&etapa=eliminatoria',
    );
    await goTo(tester, '/partidos/2600654');
    for (final badge in find.byType(TeamBadge).evaluate()) {
      expect((badge.widget as TeamBadge).size, AppSizes.badgeHeader);
    }
    final when = find.textContaining('16/09/2026');
    final p = paragraphOf(tester, when);
    final text = p.text.toPlainText();
    final date = text.indexOf('16/09/2026');
    // «16/09/2026 · 19:00» en un mismo renglón (la hora no queda sola).
    expect(linesOf(p, date, text.length), hasLength(1), reason: text);
    final stage = paragraphOf(tester, find.textContaining('Cuartos'));
    final stageText = stage.text.toPlainText();
    final cuartos = stageText.indexOf('Cuartos');
    expect(
      linesOf(stage, cuartos, stageText.length),
      hasLength(1),
      reason: stageText,
    );
    expect(find.text('Clasificó Palmeiras por penales (4-3)'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlace inválido: «Enlace no válido» (no «Próximamente») y '
      'vuelta al Inicio', (tester) async {
    await pumpApp(tester, const Size(360, 780));
    await goTo(tester, '/partidos/abc');
    expect(find.text('Enlace no válido'), findsOne);
    expect(find.text('Próximamente'), findsNothing);
    await tester.tap(find.text('Ir al inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Fútbol Argentino'), findsOne);
  });
}
