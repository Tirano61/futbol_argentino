import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recorded_app.dart';

void main() {
  testWidgets('la ficha deja de descargar en otra sección y sigue al volver', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(768, 1024), requests: requests);
    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField), 'river');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('River Plate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Completando partidos'), findsOne);

    // Otra sección: la ficha queda viva pero oculta.
    await openSection(tester, 'Inicio');
    final atLeave = requests.length;
    // Como mucho termina la que ya esperaba turno; después, nada.
    await tester.pump(const Duration(minutes: 1));
    expect(requests.length, lessThanOrEqualTo(atLeave + 1));
    final paused = requests.length;
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    expect(requests.length, paused, reason: 'oculta no pide nada');

    // De vuelta en la ficha: sigue con lo que faltaba.
    await openSection(tester, 'Equipos');
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    await tester.pumpAndSettle();
    expect(requests.length, greaterThan(paused));
    expect(find.textContaining('Completando partidos'), findsNothing);
  });

  testWidgets('actualizar con la descarga en curso no la cuelga', (
    tester,
  ) async {
    await pumpApp(tester, const Size(768, 1024));
    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField), 'river');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('River Plate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Completando partidos'), findsOne);

    // Deslizar para actualizar (el botón se desactiva mientras descarga).
    await tester.drag(find.text('Próximos'), const Offset(0, 600));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    await tester.pumpAndSettle();

    expect(find.textContaining('Completando partidos'), findsNothing);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });
}
