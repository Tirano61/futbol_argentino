import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recorded_app.dart';

/// Fase D3: las copas tienen tres fases con nombres largos. En un teléfono
/// con texto al 200 % ocupaban un renglón cada una y la lista de partidos
/// quedaba casi sin alto: van en una sola fila con desplazamiento.
void main() {
  testWidgets('copa en un teléfono con texto al 200 %: las fases en una '
      'fila, sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, const Size(360, 780), now: continentalRecordingTime);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Libertadores');
    expect(find.text('Semifinales'), findsWidgets);

    Finder phase(String label) => find.widgetWithText(ChoiceChip, label);
    final row = tester.getCenter(phase('Fases previas')).dy;
    expect(tester.getCenter(phase('Fase de grupos')).dy, row);
    expect(tester.getCenter(phase('Eliminatorias')).dy, row);

    // La fila se desplaza hasta la fase que no entra, y se puede tocar.
    await tester.ensureVisible(phase('Fases previas'));
    await tester.pumpAndSettle();
    await tester.tap(phase('Fases previas'));
    await tester.pumpAndSettle();
    expect(find.text('Fase 1'), findsWidgets);
  });
}
