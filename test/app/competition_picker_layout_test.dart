import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';

import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';

/// Fase D3: con las cuatro categorías, el selector de la tablet en
/// horizontal (1280 px, la columna del fixture junto al panel de detalle)
/// cortaba «Copas internacionales». Con la fuente real (Roboto), como en el
/// dispositivo.
void main() {
  setUpAll(loadRealFonts);

  Finder inPicker(Finder matching) => find.descendant(
    of: find.byKey(FixtureSelectors.competitionSelectorKey),
    matching: matching,
  );

  for (final (size, chips) in [
    (const Size(1280, 800), false),
    (const Size(800, 1280), true),
    (const Size(1920, 1080), true),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()}: '
        '${chips ? 'chips enteros' : 'botón con la hoja'}', (tester) async {
      await pumpApp(tester, size, now: continentalRecordingTime);
      await openSection(tester, 'Competiciones');
      await selectCompetition(tester, 'Libertadores');

      final picker = tester.getRect(
        find.byKey(FixtureSelectors.competitionSelectorKey),
      );
      if (chips) {
        expect(inPicker(find.byType(OutlinedButton)), findsNothing);
        for (final label in [
          'Primera División',
          'Ascenso',
          'Copas nacionales',
          'Copas internacionales',
          'Libertadores',
          'Sudamericana',
        ]) {
          final rect = tester.getRect(
            inPicker(find.widgetWithText(ChoiceChip, label)),
          );
          expect(rect.right, lessThanOrEqualTo(picker.right), reason: label);
        }
      } else {
        expect(inPicker(find.byType(ChoiceChip)), findsNothing);
        final button = inPicker(
          find.widgetWithText(
            OutlinedButton,
            'Copas internacionales · Libertadores',
          ),
        );
        expect(button, findsOne);
        expect(tester.getRect(button).right, lessThanOrEqualTo(picker.right));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // La competición elegida carga igual por los dos caminos.
      expect(find.text('Semifinales'), findsWidgets);
    });
  }
}
