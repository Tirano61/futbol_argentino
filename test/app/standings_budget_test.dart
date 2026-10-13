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
}
