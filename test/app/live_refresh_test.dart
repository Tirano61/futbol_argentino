import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/live_auto_refresh.dart';

import '../helpers/recorded_app.dart';

/// Auto-refresco en vivo (D11) con la app completa y datos reales: el
/// domingo 11/10/2026 a las 17:00 la fecha 12 de Primera y la 33 de
/// Primera Nacional tienen partidos en juego (grabadas a las 20:10 UTC).
void main() {
  const r12 = 'eventsround.php?id=4406&r=12&s=2026';
  const r33 = 'eventsround.php?id=4616&r=33&s=2026';
  const live = [r12, r33];
  final interval = LiveAutoRefresh.interval;

  List<String> names(List<Uri> requests) => [
    for (final u in requests) '${u.pathSegments.last}?${u.query}',
  ];

  /// La app al abrir, con la carga inicial del Inicio terminada.
  Future<List<Uri>> open(WidgetTester tester, Size size) async {
    final requests = <Uri>[];
    await pumpApp(tester, size, requests: requests);
    // El cierre del stream de la carga inicial se agenda fuera de FakeAsync
    // (ver `home_page_test.dart`): sin esta vuelta, `droppable` descarta
    // el aviso.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    requests.clear();
    return requests;
  }

  Future<void> wait(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.pumpAndSettle();
  }

  testWidgets('Inicio: cada aviso pide solo las fechas en juego', (
    tester,
  ) async {
    // En frío fueron 12: punteros y 2 fechas por competición.
    final requests = await open(tester, const Size(1280, 6000));

    await wait(tester, interval - const Duration(seconds: 10));
    expect(requests, isEmpty);

    await wait(tester, const Duration(seconds: 10));
    expect(names(requests), unorderedEquals(live));

    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await wait(tester, interval);
    expect(names(requests), unorderedEquals([...live, ...live]));
  });

  testWidgets('Inicio oculto: ninguna consulta; al volver se pone al día', (
    tester,
  ) async {
    final requests = await open(tester, const Size(1280, 6000));

    await openSection(tester, 'Favoritos');
    await wait(tester, interval * 3);
    expect(requests, isEmpty);

    await openSection(tester, 'Inicio');
    expect(names(requests), unorderedEquals(live));
  });

  testWidgets('fixture de Nacional: la fecha en juego en cada aviso', (
    tester,
  ) async {
    final requests = await open(tester, const Size(1280, 6000));
    await openSection(tester, 'Competiciones');
    await selectCompetition(tester, 'Nacional');
    requests.clear();

    await wait(tester, interval);

    expect(names(requests), [r33]);
  });

  testWidgets('detalle de un partido en juego: solo ese partido', (
    tester,
  ) async {
    final requests = await open(tester, const Size(360, 6000));
    // Almirante Brown – San Miguel, 2.º tiempo.
    await tester.tap(find.textContaining('Almirante Brown').first);
    await tester.pumpAndSettle();
    expect(requests, isEmpty);

    await wait(tester, interval);

    // El Inicio, tapado por el detalle, no avisa (sus fechas en juego no
    // se piden).
    expect(names(requests), ['lookupevent.php?id=2405137']);
  });
}
