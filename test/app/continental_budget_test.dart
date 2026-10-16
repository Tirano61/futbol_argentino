import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/recorded_app.dart';

/// Fase D3: fixture de las copas internacionales en la app completa, con
/// las respuestas grabadas el 14/10/2026 (D1) y el reloj en esa hora.
void main() {
  String label(Uri u) => switch (u.pathSegments.last) {
    'eventsround.php' =>
      '${u.queryParameters['id']}:r${u.queryParameters['r']}:'
          's${u.queryParameters['s']}',
    final endpoint =>
      '${endpoint.replaceAll('.php', '')}:'
          '${u.queryParameters['id']}',
  };

  Future<List<Uri>> openCompetitions(WidgetTester tester, Size size) async {
    final requests = <Uri>[];
    await pumpApp(
      tester,
      size,
      requests: requests,
      now: continentalRecordingTime,
    );
    await openSection(tester, 'Competiciones');
    return requests;
  }

  Future<void> choosePhase(WidgetTester tester, String phase) async {
    final chip = find.widgetWithText(ChoiceChip, phase);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('Libertadores en frío: liga, 2 punteros, la ronda y la '
      'siguiente (≤ 5); en caliente 0', (tester) async {
    final requests = await openCompetitions(tester, const Size(1280, 800));
    final before = requests.length;

    await selectCompetition(tester, 'Libertadores');
    final cold = [for (final u in requests.sublist(before)) label(u)];
    expect(cold, [
      'lookupleague:4501',
      'eventsnextleague:4501',
      'eventspastleague:4501',
      '4501:r150:s2026',
      // Precarga de la etapa siguiente (la final, todavía vacía).
      '4501:r200:s2026',
    ]);
    // Abre en la etapa del próximo partido; sin «Tabla» ni «Llaves».
    expect(find.text('Semifinales'), findsWidgets);
    expect(find.text('Calendario'), findsOne);
    expect(find.text('Tabla'), findsNothing);
    expect(find.text('Llaves'), findsNothing);

    await selectCompetition(tester, 'Sudamericana');
    final hot = requests.length;
    await selectCompetition(tester, 'Libertadores');
    expect(requests.sublist(hot).map(label), isEmpty);
    // El Inicio no pidió nada de las copas.
    expect(
      requests.take(before).map(label).where((r) => r.contains('4501')),
      isEmpty,
    );
  });

  testWidgets('Libertadores 2026, ronda 1: 6 partidos en «Fases previas · '
      'Fase 1» y 16 en «Fase de grupos · Fecha 1», con una sola consulta', (
    tester,
  ) async {
    // Vista alta: todas las tarjetas de la etapa se construyen.
    final requests = await openCompetitions(tester, const Size(800, 6000));
    await selectCompetition(tester, 'Libertadores');

    await choosePhase(tester, 'Fases previas');
    expect(find.text('Fase 1'), findsWidgets);
    expect(find.byType(MatchCard), findsNWidgets(6));

    await choosePhase(tester, 'Fase de grupos');
    expect(find.text('Fecha 1'), findsWidgets);
    expect(find.byType(MatchCard), findsNWidgets(16));

    final cup = [
      for (final u in requests)
        if (label(u).startsWith('4501:')) label(u),
    ];
    expect(cup.where((r) => r == '4501:r1:s2026'), hasLength(1));
    expect(cup.toSet(), hasLength(cup.length));
  });

  testWidgets('Sudamericana 2025: los códigos de esa temporada (Primera '
      'fase en la ronda 400, playoffs en la 160)', (tester) async {
    final requests = await openCompetitions(tester, const Size(800, 6000));
    await selectCompetition(tester, 'Sudamericana');

    await tester.tap(find.text('Temporada 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 2025').last);
    await tester.pumpAndSettle();
    await choosePhase(tester, 'Fases previas');
    expect(find.text('Primera fase'), findsWidgets);
    expect(find.byType(MatchCard), findsNWidgets(16));

    await choosePhase(tester, 'Eliminatorias');
    expect(find.text('Playoffs de octavos'), findsWidgets);
    expect(find.byType(MatchCard), findsNWidgets(16));
    expect(
      requests.map(label),
      containsAll(['4724:r400:s2025', '4724:r160:s2025']),
    );
  });
}
