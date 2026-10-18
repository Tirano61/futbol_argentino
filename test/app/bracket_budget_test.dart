import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recorded_app.dart';

/// Presupuesto de la vista «Llaves» en la app completa (respuestas grabadas
/// del 11/10/2026).
void main() {
  String label(Uri u) =>
      '${u.queryParameters['id']}:r${u.queryParameters['r']}:'
      's${u.queryParameters['s']}';

  List<String> rounds(List<Uri> requests) => [
    for (final u in requests)
      if (u.pathSegments.last == 'eventsround.php') label(u),
  ];

  Future<void> openBracket(WidgetTester tester) async {
    await openView(tester, 'Llaves');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('Primera en frío: solo la ronda 16 y la 0, una vez cada una; '
      'en caliente 0', (tester) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);
    await openSection(tester, 'Competiciones');
    final before = requests.length;

    await openBracket(tester);
    expect(find.text('Campeón: Belgrano'), findsOne);
    expect(rounds(requests.sublist(before)), [
      '4406:r16:s2026',
      '4406:r0:s2026',
    ]);
    expect(rounds(requests).toSet(), hasLength(rounds(requests).length));

    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    final hot = requests.length;
    await openBracket(tester);
    expect(requests.length, hot);
  });

  testWidgets('Copa en frío: sus 6 rondas como máximo, una vez cada una en '
      'la sesión; en caliente 0', (tester) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Copa Argentina');
    final before = requests.length;

    await openBracket(tester);
    expect(find.text('A definir'), findsNWidgets(2));
    final bracket = rounds(requests.sublist(before));
    expect(bracket.length, lessThanOrEqualTo(6));
    expect(bracket.every((r) => r.startsWith('4500:')), isTrue);
    // Ninguna ronda de la Copa dos veces (la etapa del fixture tampoco).
    final copa = [
      for (final r in rounds(requests))
        if (r.startsWith('4500:')) r,
    ];
    expect(copa.toSet(), hasLength(copa.length));
    expect(copa.toSet(), hasLength(6));

    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    final hot = requests.length;
    await openBracket(tester);
    expect(requests.length, hot);
  });

  testWidgets('Fase D5: Libertadores en frío = octavos a final (4), '
      'Sudamericana = además los Playoffs (5); cada una una vez; en caliente '
      '0', (tester) async {
    final requests = <Uri>[];
    await pumpApp(
      tester,
      const Size(1280, 800),
      requests: requests,
      now: continentalRecordingTime,
    );
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Libertadores');
    // El fixture ya pidió las semifinales (etapa actual) y la final.
    final before = requests.length;

    await openBracket(tester);
    expect(find.text('Octavos de final'), findsOne);
    expect(rounds(requests.sublist(before)), [
      '4501:r16:s2026',
      '4501:r125:s2026',
    ]);
    final lib = [
      for (final r in rounds(requests))
        if (r.startsWith('4501:')) r,
    ];
    expect(lib.toSet(), {
      '4501:r16:s2026',
      '4501:r125:s2026',
      '4501:r150:s2026',
      '4501:r200:s2026',
    });
    expect(lib.toSet(), hasLength(lib.length), reason: '$lib');

    await selectCompetition(tester, 'Sudamericana');
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    final sud = [
      for (final r in rounds(requests))
        if (r.startsWith('4724:')) r,
    ];
    expect(sud.toSet(), {
      '4724:r32:s2026',
      '4724:r16:s2026',
      '4724:r125:s2026',
      '4724:r150:s2026',
      '4724:r200:s2026',
    });
    // Con la lista en orden: la intermitencia vista en E4 y E5 (una ronda
    // pedida dos veces) queda registrada si vuelve a aparecer.
    expect(sud.toSet(), hasLength(sud.length), reason: '$sud');

    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    // (Libertadores tiene una semifinal en vivo: su ronda vence a los 2
    // minutos y se vuelve a pedir; la Sudamericana, no.)
    final hot = requests.length;
    await openBracket(tester);
    expect(requests.length, hot);
  });
}
