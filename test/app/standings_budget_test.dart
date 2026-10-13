import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import '../helpers/recorded_app.dart';

/// Presupuesto de la vista «Tabla» en la app completa (respuestas grabadas
/// del 11/10/2026).
void main() {
  testWidgets('Tabla en frío: solo las fechas 1–16 que faltan, de a una; '
      'en caliente 0', (tester) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);
    await openSection(tester, 'Competiciones');
    final before = requests.length;

    await openTable(tester);
    expect(find.text('Tabla Anual 2026'), findsWidgets);

    String label(Uri u) =>
        '${u.queryParameters['id']}:r${u.queryParameters['r']}:'
        's${u.queryParameters['s']}';
    final rounds = [
      for (final u in requests)
        if (u.pathSegments.last == 'eventsround.php' &&
            u.queryParameters['id'] == '4406')
          label(u),
    ];
    final table = requests.sublist(before).map(label).toList();
    // Cada fecha de Primera 2026 una sola vez en toda la sesión; nunca la
    // ronda 0 por la tabla.
    expect(rounds.toSet(), hasLength(rounds.length));
    expect(table, isNot(contains('4406:r0:s2026')));
    expect({...rounds}.where((r) => r != '4406:r0:s2026'), hasLength(16));
    expect(table.length, lessThanOrEqualTo(16));

    // Volver a la tabla: nada nuevo.
    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    final hot = requests.length;
    await openTable(tester);
    expect(requests.length, hot);
  });

  testWidgets('Tabla de Nacional en frío: solo las fechas 1–36 que faltan '
      'o vencieron; en caliente 0', (tester) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);
    await openSection(tester, 'Competiciones');
    await openTable(tester);
    final before = requests.length;

    await openNacionalTable(tester);
    expect(find.text('Posiciones 2026 · Zona A'), findsOne);

    final counts = <int, int>{};
    for (final u in requests.sublist(before)) {
      if (u.pathSegments.last == 'eventsround.php' &&
          u.queryParameters['id'] == '4616') {
        counts.update(
          int.parse(u.queryParameters['r']!),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
    }
    // Ninguna fuera de 1–36 (la 37 está vacía). La 34 la guardó el Inicio
    // y sigue vigente: no se pide. La 33 tiene un partido en juego (TTL
    // corto): la pide el fixture (P0) y, como vuelve a vencer antes de que
    // le toque, otra vez la tabla. Las demás, una sola vez.
    expect(counts.keys.every((r) => r >= 1 && r <= 36), isTrue);
    expect(counts.containsKey(34), isFalse);
    expect(counts[33], lessThanOrEqualTo(2));
    expect(
      {
        for (final MapEntry(key: r, value: n) in counts.entries)
          if (r != 33) n,
      },
      {1},
    );
    expect(counts.length, 35);

    // Volver a la tabla: nada nuevo.
    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    final hot = requests.length;
    await openTable(tester);
    expect(find.text('Posiciones 2026 · Zona A'), findsOne);
    expect(requests.length, hot);
  });
}
