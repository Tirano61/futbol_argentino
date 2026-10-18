import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';

/// Hito E (E-D8, Fase E4): el selector de competición en el título de la
/// barra, junto a la búsqueda (escritorio), «Actualizar», el riel y el panel
/// de detalle. Antes (Fase D3), a 1280 px los chips de categoría cortaban
/// «Copas internacionales». Con la fuente real (Roboto), como en el
/// dispositivo.
void main() {
  setUpAll(loadRealFonts);

  final selector = find.byKey(FixtureSelectors.competitionSelectorKey);
  final season = find.byKey(FixtureSelectors.seasonSelectorKey);

  Finder inBar(Finder matching) =>
      find.descendant(of: find.byType(AppBar), matching: matching);

  /// Texto visible del selector (nombre completo o corto).
  RenderParagraph title(WidgetTester tester) => tester
      .renderObjectList<RenderParagraph>(
        find.descendant(of: selector, matching: find.byType(Text)),
      )
      .single;

  for (final (size, name, seasonText) in [
    (const Size(1280, 800), 'Copa Libertadores', 'Temporada 2026'),
    (const Size(800, 1280), 'Copa Libertadores', 'Temporada 2026'),
    (const Size(1920, 1080), 'Copa Libertadores', 'Temporada 2026'),
    // En un teléfono, el año solo; a 360 todavía entra el nombre completo.
    (const Size(411, 900), 'Copa Libertadores', '2026'),
    (const Size(360, 780), 'Copa Libertadores', '2026'),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()}: «$name» y la '
        'temporada en la barra, sin cortes ni superposiciones', (tester) async {
      await pumpApp(tester, size, now: continentalRecordingTime);
      await openSection(tester, 'Competiciones');
      await selectCompetition(tester, 'Libertadores');

      expect(inBar(selector), findsOne);
      expect(competitionTitle('Copa Libertadores'), findsOne);
      final text = title(tester);
      expect(text.text.toPlainText(), name);
      expect(text.didExceedMaxLines, isFalse);
      expect(inBar(season), findsOne);
      expect(inBar(find.text(seasonText)), findsOne);
      // Cada control con su propio nodo semántico (en la Web la temporada
      // se mezclaba con el tooltip del selector).
      final selectorNode = tester.getSemantics(
        find.descendant(of: selector, matching: find.byType(Text)),
      );
      final seasonNode = tester.getSemantics(
        find.descendant(of: season, matching: find.text(seasonText)).first,
      );
      expect(seasonNode.id, isNot(selectorNode.id));
      expect(selectorNode.label, 'Competición: Copa Libertadores');
      expect(selectorNode.tooltip, 'Elegir competición');
      expect(seasonNode.label, contains('2026'));
      expect(seasonNode.label, isNot(contains('competición')));

      // Selector, temporada, búsqueda (escritorio) y «Actualizar» en orden,
      // sin pisarse, dentro de la barra.
      final bar = tester.getRect(find.byType(AppBar));
      final refresh = tester.getRect(find.byTooltip('Actualizar'));
      final rects = [
        tester.getRect(selector),
        tester.getRect(season),
        if (size.width >= 1200)
          tester.getRect(find.widgetWithText(TextField, 'Buscar equipo')),
        refresh,
      ];
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right));
      }
      expect(rects.first.left, greaterThanOrEqualTo(bar.left));
      expect(refresh.right, lessThanOrEqualTo(bar.right));
      await expectGuidelines(tester);
      // La competición elegida cargó (semifinales de la Libertadores).
      expect(find.text('Semifinales'), findsWidgets);
    });
  }

  testWidgets('1280 px: el menú se abre debajo del título, sobre el '
      'contenido, y cambia la competición', (tester) async {
    await pumpApp(tester, const Size(1280, 800), now: continentalRecordingTime);
    await openSection(tester, 'Competiciones');

    await tester.tap(selector);
    await tester.pumpAndSettle();
    final item = find.widgetWithText(MenuItemButton, 'Copa Sudamericana');
    expect(find.byType(MenuItemButton), findsNWidgets(7));
    expect(
      tester.getRect(item).top,
      greaterThan(tester.getRect(selector).bottom - 1),
    );
    // El contraste del menú se mide en `competition_picker_test` (acá la
    // pauta lee también el texto que el menú tapa).
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(competitionTitle('Copa Sudamericana'), findsOne);
    expect(title(tester).text.toPlainText(), 'Copa Sudamericana');
  });

  testWidgets('el nombre más largo (Primera B Metropolitana) a 360 px: el '
      'corto con la temporada, sin desbordes', (tester) async {
    await pumpApp(tester, const Size(360, 780));
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'B Metro');

    expect(competitionTitle('Primera B Metropolitana'), findsOne);
    final text = title(tester);
    expect(text.text.toPlainText(), 'B Metro');
    expect(text.didExceedMaxLines, isFalse);
    expect(inBar(season), findsOne);
    await expectGuidelines(tester);
  });

  testWidgets('el nombre más largo a 800 px: completo con la temporada', (
    tester,
  ) async {
    await pumpApp(tester, const Size(800, 1280));
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'B Metro');

    final text = title(tester);
    expect(text.text.toPlainText(), 'Primera B Metropolitana');
    expect(text.didExceedMaxLines, isFalse);
    expect(inBar(find.text('Temporada 2026')), findsOne);
  });
}
