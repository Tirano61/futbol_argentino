import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/view_tabs.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../visual/visual_helpers.dart' show goTo;

/// Hito E, Fase E4: la cabecera de Competiciones en tres niveles
/// (competición y temporada en la barra · vistas · filtros de la vista).
/// Criterio de aceptación: ≤ 200 px de controles debajo de la barra en un
/// teléfono (antes, 272 px a 360). Con la fuente real (Roboto).
void main() {
  setUpAll(loadRealFonts);

  final season = find.byKey(FixtureSelectors.seasonSelectorKey);

  Finder inBar(Finder matching) =>
      find.descendant(of: find.byType(AppBar), matching: matching);

  /// Alto de los controles: del borde inferior de la barra al principio
  /// del contenido de la vista (su lista).
  double controlsHeight(WidgetTester tester) {
    final bar = tester.getRect(find.byType(AppBar).first).bottom;
    final content = tester.getRect(find.byType(RefreshIndicator).first).top;
    return content - bar;
  }

  /// Toda la etiqueta del chip de [label] dentro de la pantalla.
  void expectChipVisible(WidgetTester tester, String label, double width) {
    final chip = tester.getRect(find.widgetWithText(ChoiceChip, label));
    expect(chip.left, greaterThanOrEqualTo(0), reason: label);
    expect(chip.right, lessThanOrEqualTo(width), reason: label);
  }

  for (final width in [360.0, 411.0]) {
    final size = Size(width, 780);
    group('teléfono de ${width.toInt()} px', () {
      for (final (name, location, minutes) in [
        (
          'Fixture de la Libertadores (eliminatorias)',
          '/competiciones/4501?temporada=2026&fase=eliminatorias',
          0,
        ),
        (
          'Fixture de Primera',
          '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
          0,
        ),
        (
          'Tabla de grupos de la Libertadores',
          '/competiciones/4501?temporada=2026&vista=tabla&tabla=grupo-a',
          1,
        ),
        (
          'Calendario de Primera',
          '/competiciones/4406?temporada=2026&vista=calendario&mes=2026-10',
          0,
        ),
        (
          'Llaves de la Copa Argentina',
          '/competiciones/4500?temporada=2026&vista=llaves',
          1,
        ),
      ]) {
        // «Copa Argentina» no tiene un nombre más corto: a 360, con el
        // logo, la temporada baja a los filtros (y sigue ≤ 200 px).
        final seasonInBar = !(width == 360 && name.contains('Copa Argentina'));
        testWidgets('$name: ≤ 200 px de controles', (tester) async {
          await pumpApp(tester, size, now: continentalRecordingTime);
          await goTo(tester, location, wait: Duration(minutes: minutes));

          final height = controlsHeight(tester);
          // ignore: avoid_print
          print('E4 · $name a ${width.toInt()} px: ${height.round()} px');
          expect(height, lessThanOrEqualTo(200));
          expect(inBar(season), seasonInBar ? findsOne : findsNothing);
          expect(season, findsOne);
          await expectGuidelines(tester);
        });
      }

      testWidgets('la fase elegida queda a la vista aunque la fila se '
          'desplace', (tester) async {
        await pumpApp(tester, size, now: continentalRecordingTime);
        await goTo(
          tester,
          '/competiciones/4501?temporada=2026&fase=eliminatorias',
        );
        expectChipVisible(tester, 'Eliminatorias', width);
        expect(find.byType(MatchCard), findsWidgets);
        // El primer partido entra en la primera pantalla.
        expect(
          tester.getRect(find.byType(MatchCard).first).bottom,
          lessThan(780),
        );
      });
    });
  }

  testWidgets('el contenido empieza antes que en el diseño anterior '
      '(272 px a 360)', (tester) async {
    await pumpApp(tester, const Size(360, 780), now: continentalRecordingTime);
    await goTo(tester, '/competiciones/4501?temporada=2026&fase=eliminatorias');
    expect(controlsHeight(tester), lessThan(272 - 80));
  });

  group('texto al 200 % en un teléfono', () {
    // Con nombres cortos («Primera») la temporada todavía entra en la
    // barra; con los largos baja al principio de los filtros.
    for (final (name, location, minutes, seasonInBar) in [
      (
        'Fixture de la Libertadores',
        '/competiciones/4501?temporada=2026&fase=eliminatorias',
        0,
        false,
      ),
      (
        'Fixture de Primera',
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
        0,
        true,
      ),
      (
        'Tabla Anual',
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
        2,
        true,
      ),
      (
        'Llaves de la Copa Argentina',
        '/competiciones/4500?temporada=2026&vista=llaves',
        1,
        false,
      ),
    ]) {
      testWidgets(
        '$name: temporada ${seasonInBar ? 'en la barra' : 'en '
                  'los filtros'}, sin desbordes ni etiquetas partidas',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await pumpApp(
            tester,
            const Size(360, 780),
            now: continentalRecordingTime,
          );
          await goTo(tester, location, wait: Duration(minutes: minutes));

          expect(season, findsOne);
          expect(inBar(season), seasonInBar ? findsOne : findsNothing);
          if (!seasonInBar) expect(find.text('Temporada 2026'), findsOne);
          // Las pestañas no se parten (se desplazan).
          for (final p in tester.renderObjectList<RenderParagraph>(
            find.descendant(
              of: find.byType(ViewTabs),
              matching: find.byType(Text),
            ),
          )) {
            expect(p.didExceedMaxLines, isFalse);
          }
          // ignore: avoid_print
          print(
            'E4 · $name a 360 px al 200 %: ${controlsHeight(tester).round()} px',
          );
          await expectGuidelines(tester);
        },
      );
    }

    testWidgets('elegir otra temporada desde los filtros', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        const Size(360, 780),
        now: continentalRecordingTime,
      );
      await goTo(tester, '/competiciones/4501?temporada=2026&fase=grupos');

      await tester.ensureVisible(season);
      await tester.pumpAndSettle();
      await tester.tap(season);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temporada 2025').last);
      await tester.pumpAndSettle();
      expect(find.text('Temporada 2025'), findsOne);
    });
  });

  testWidgets('teléfono: elegir otra temporada desde la barra', (tester) async {
    await pumpApp(tester, const Size(360, 780), now: continentalRecordingTime);
    await goTo(tester, '/competiciones/4501?temporada=2026&fase=grupos');

    expect(inBar(find.text('2026')), findsOne);
    await tester.tap(season);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025').last);
    await tester.pumpAndSettle();
    expect(inBar(find.text('2025')), findsOne);
    expect(find.text('Fase de grupos'), findsWidgets);
  });

  group('panel de detalle (≥ 1200 px)', () {
    for (final size in [const Size(1280, 800), const Size(1920, 1080)]) {
      testWidgets('${size.width.toInt()} px: elegir, cerrar y reabrir un '
          'partido; cambiar de competición con el panel abierto', (
        tester,
      ) async {
        await pumpApp(tester, size, now: continentalRecordingTime);
        await goTo(
          tester,
          '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
        );
        expect(find.text('Detalle del partido'), findsOne);
        // La cabecera queda en la columna del fixture.
        final panelLeft = tester
            .getRect(find.byType(VerticalDivider).last)
            .left;
        expect(
          tester.getRect(find.byType(ViewTabs)).right,
          lessThanOrEqualTo(panelLeft + 1),
        );
        expect(
          tester.getRect(find.byType(StageNavigator)).right,
          lessThanOrEqualTo(panelLeft + 1),
        );

        await tester.tap(find.byType(MatchCard).first);
        await tester.pumpAndSettle();
        expect(find.text('Detalle del partido'), findsNothing);
        expect(find.byTooltip('Cerrar detalle'), findsOne);
        await expectGuidelines(tester);

        await tester.tap(find.byTooltip('Cerrar detalle'));
        await tester.pumpAndSettle();
        expect(find.text('Detalle del partido'), findsOne);
        await tester.tap(find.byType(MatchCard).first);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Cerrar detalle'), findsOne);

        await selectCompetition(tester, 'Libertadores');
        expect(competitionTitle('Copa Libertadores'), findsOne);
        expect(find.text('Semifinales'), findsWidgets);
        expect(inBar(season), findsOne);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('1280 px con texto al 200 %: sin desbordes', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        const Size(1280, 800),
        now: continentalRecordingTime,
      );
      await goTo(
        tester,
        '/competiciones/4501?temporada=2026&fase=eliminatorias',
      );
      await tester.tap(find.byType(MatchCard).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar detalle'), findsOne);
      await expectGuidelines(tester);
    });
  });
}
