import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../../../helpers/recorded_app.dart';

/// Fase 15: Primera B Metropolitana y Primera C en la app completa, con
/// respuestas grabadas. No entran en el Inicio ni en el índice de equipos:
/// se llega por el selector del fixture.
void main() {
  /// `eventsround` pedidos de la competición [id].
  List<String> roundsOf(List<Uri> requests, int id) => [
    for (final u in requests)
      if (u.pathSegments.last == 'eventsround.php' &&
          u.queryParameters['id'] == '$id')
        'r${u.queryParameters['r']}',
  ];

  testWidgets('el Inicio no consulta las competiciones nuevas', (tester) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);

    expect(
      requests.where((u) => ['5215', '5524'].contains(u.queryParameters['id'])),
      isEmpty,
    );
    // Los accesos del Inicio sí llevan a sus fixtures.
    expect(
      find.widgetWithText(ActionChip, 'Primera B Metropolitana'),
      findsOne,
    );
    expect(find.widgetWithText(ActionChip, 'Primera C'), findsOne);
  });

  testWidgets('B Metro: abre en la fecha del próximo partido, sin tabla', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(360, 780), requests: requests);
    await openSection(tester, 'Competiciones');
    requests.clear();

    await selectCompetition(tester, 'B Metro');

    expect(competitionTitle('Primera B Metropolitana'), findsOne);
    expect(find.text('Fecha 40'), findsOne);
    expect(find.byType(MatchCard), findsWidgets);
    // La fecha 40 y la siguiente (precarga P1; la 41 no está grabada).
    expect(roundsOf(requests, 5215), ['r40', 'r41']);

    // Sin tabla ni cuadro verificados: solo Fixture y Calendario (D2), y
    // no se baja la temporada.
    expect(find.text('Tabla'), findsNothing);
    expect(find.text('Llaves'), findsNothing);
    expect(find.text('Calendario'), findsOne);
    expect(roundsOf(requests, 5215), ['r40', 'r41']);
  });

  testWidgets('Primera C: sin próximo partido, abre en la fecha del último', (
    tester,
  ) async {
    final requests = <Uri>[];
    // Alta para que la lista construya las 14 tarjetas.
    await pumpApp(tester, const Size(1280, 4000), requests: requests);
    await openSection(tester, 'Competiciones');
    requests.clear();

    await selectCompetition(tester, 'Primera C');

    expect(find.text('Fecha 32'), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(14));
    // Es la última fecha conocida: no hay siguiente para precargar.
    expect(roundsOf(requests, 5524), ['r32']);
  });
}
