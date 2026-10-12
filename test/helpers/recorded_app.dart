import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/app.dart';
import 'package:futbol_argentino/app/di/app_dependencies.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:futbol_argentino/core/time/clock.dart';
import 'fixtures.dart';
import 'recorded_api.dart';

/// Respuesta grabada para [url]; lo que no está grabado responde 404.
http.Response _recorded(Uri url) {
  final q = url.queryParameters;
  final name = switch (url.pathSegments.last) {
    'lookupleague.php' => 'lookupleague_${q['id']}',
    'lookupevent.php' => 'lookupevent_${q['id']}',
    _ => recordedFixtureFor(url),
  };
  return File('test/fixtures/api/$name.json').existsSync()
      ? http.Response.bytes(fixtureBytes(name), 200)
      : http.Response('sin grabar', 404);
}

/// Reloj que arranca en [start] y avanza con el tiempo simulado de `pump`
/// (el límite por minuto necesita ver pasar el tiempo).
class _PumpedClock implements Clock {
  _PumpedClock(this._tester, this.start)
    : _origin = _tester.binding.clock.now();

  final WidgetTester _tester;
  final DateTime start;
  final DateTime _origin;

  @override
  DateTime now() => start.add(_tester.binding.clock.now().difference(_origin));
}

/// La app completa con datos reales grabados, el domingo 11/10/2026 a las
/// 17:00 de Argentina. [respond] puede reemplazar una respuesta (si
/// devuelve `null`, se usa la grabada). Sin [settle] no espera a que
/// terminen las cargas. Cada petición se agrega a [requests].
Future<void> pumpApp(
  WidgetTester tester,
  Size size, {
  http.Response? Function(Uri url)? respond,
  bool settle = true,
  List<Uri>? requests,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = await newDatabaseFactoryMemory().openDatabase('app.db');
  final deps = AppDependencies.create(
    database: db,
    config: const AppConfig(apiKey: '123', enableDiagnostics: false),
    clock: _PumpedClock(tester, DateTime.utc(2026, 10, 11, 20)),
    httpClient: MockClient((request) async {
      requests?.add(request.url);
      return respond?.call(request.url) ?? _recorded(request.url);
    }),
  );
  addTearDown(deps.dispose);

  await tester.pumpWidget(FutbolArgentinoApp(dependencies: deps));
  if (settle) await tester.pumpAndSettle();
}

/// Abre una sección desde la navegación.
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
