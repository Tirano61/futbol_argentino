import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recorded_app.dart';

/// Presupuesto de la vista «Calendario» en la app completa (respuestas
/// grabadas del 11/10/2026): abrirla no consulta nada; «Completar» pide
/// solo las fechas que faltan, cada una una vez.
void main() {
  String label(Uri u) =>
      '${u.queryParameters['id']}:r${u.queryParameters['r']}:'
      's${u.queryParameters['s']}';

  testWidgets('abrir el calendario: 0 peticiones; «Completar»: solo las '
      'fechas de Primera 2026 que faltan; en caliente 0', (tester) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);
    await openSection(tester, 'Competiciones');
    final before = requests.length;

    await openView(tester, 'Calendario');
    expect(find.text('Octubre 2026'), findsOne);
    expect(requests.length, before, reason: 'abrir el calendario no consulta');
    // Lo guardado por el Inicio y el fixture: hoy, con la fecha 12.
    expect(find.text('Domingo 11/10/2026'), findsOne);
    expect(find.textContaining('faltan consultar o actualizar'), findsOne);

    await tester.tap(find.text('Completar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();

    final primera = [
      for (final u in requests)
        if (u.pathSegments.last == 'eventsround.php' &&
            u.queryParameters['id'] == '4406')
          label(u),
    ];
    // Cada ronda de Primera 2026 (0–16) una sola vez en toda la sesión.
    expect(primera.toSet(), hasLength(primera.length));
    expect(primera.toSet(), {for (var r = 0; r <= 16; r++) '4406:r$r:s2026'});
    final completed = requests.sublist(before).map(label).toList();
    // Las fechas 12 y 13 ya las guardaron el Inicio y el fixture.
    expect(completed, hasLength(15));
    expect(completed, isNot(contains('4406:r12:s2026')));
    expect(completed, isNot(contains('4406:r13:s2026')));
    expect(find.textContaining('faltan consultar'), findsNothing);

    // Volver al calendario: nada nuevo.
    await openView(tester, 'Fixture');
    final hot = requests.length;
    await openView(tester, 'Calendario');
    expect(find.text('Octubre 2026'), findsOne);
    expect(requests.length, hot);
  });

  testWidgets('cambiar de competición en el calendario: 0 peticiones', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpApp(tester, const Size(1280, 800), requests: requests);
    await openSection(tester, 'Competiciones');
    await openView(tester, 'Calendario');
    final before = requests.length;

    await selectCompetition(tester, 'Copa Argentina');

    // El fixture de fondo resuelve y carga la etapa de la Copa (como con
    // «Tabla»); el calendario, nada.
    final added = requests.sublist(before);
    expect(added.map((u) => u.pathSegments.last), [
      'lookupleague.php',
      'eventsround.php',
    ]);
    expect(added.map((u) => u.queryParameters['id']).toSet(), {'4500'});
    expect(find.textContaining('faltan consultar'), findsOne);
  });
}
