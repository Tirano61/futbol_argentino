// Herramienta de prueba (no es parte de la app): la app completa con las
// respuestas reales grabadas en `test/fixtures/api/`, sin TheSportsDB.
//
// - Las respuestas salen de un `MockClient` en el proceso, como en
//   `pumpApp` (test/helpers/recorded_app.dart); lo no grabado responde 404.
// - Base en memoria: no toca los datos guardados de la app instalada.
// - Reloj: arranca en la hora de las grabaciones de la Fase D1 (14/10/2026
//   21:45 ART; `--dart-define=RECORDED_NOW=…` lo cambia) y avanza con el
//   tiempo real.
// - Una banda «DATOS GRABADOS» indica que no son datos en vivo.
//
// Android: `adb push test/fixtures/api/. /sdcard/Android/data/<paquete>/files/fixtures/`
// y `flutter run -t tool/recorded_app/main.dart`. Web: `flutter build web
// -t tool/recorded_app/main.dart` y copiar los JSON a `build/web/fixtures/`.
import 'package:flutter/material.dart';
import 'package:futbol_argentino/app/app.dart';
import 'package:futbol_argentino/app/di/app_dependencies.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import 'fixture_source.dart';

const _recordedNow = String.fromEnvironment(
  'RECORDED_NOW',
  defaultValue: '2026-10-15T00:45:00Z',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await newDatabaseFactoryMemory().openDatabase('grabado.db');
  final dependencies = AppDependencies.create(
    database: database,
    clock: _RecordedClock(DateTime.parse(_recordedNow)),
    httpClient: MockClient((request) async {
      final name = _fixtureFor(request.url);
      final bytes = name == null ? null : await readFixture(name);
      debugPrint('GRABADO ${bytes == null ? 404 : 200} ${request.url}');
      return bytes == null
          ? http.Response('sin grabar', 404)
          : http.Response.bytes(bytes, 200);
    }),
  );
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'DATOS GRABADOS',
        location: BannerLocation.bottomStart,
        child: FutbolArgentinoApp(dependencies: dependencies),
      ),
    ),
  );
}

/// Nombre de la grabación de [url] (como `recordedFixtureFor` de los tests).
String? _fixtureFor(Uri url) {
  final q = url.queryParameters;
  return switch (url.pathSegments.last) {
    'eventsround.php' => 'eventsround_${q['id']}_r${q['r']}_s${q['s']}',
    'eventsnextleague.php' => 'eventsnextleague_${q['id']}',
    'eventspastleague.php' => 'eventspastleague_${q['id']}',
    'eventsnext.php' => 'eventsnext_${q['id']}',
    'eventslast.php' => 'eventslast_${q['id']}',
    'lookupteam.php' => 'lookupteam_${q['id']}',
    'lookupleague.php' => 'lookupleague_${q['id']}',
    'lookupevent.php' => 'lookupevent_${q['id']}',
    'searchteams.php' => 'searchteams_${q['t']?.replaceAll(' ', '_')}',
    _ => null,
  };
}

class _RecordedClock implements Clock {
  _RecordedClock(this._start);

  final DateTime _start;
  final _elapsed = Stopwatch()..start();

  @override
  DateTime now() => _start.toUtc().add(_elapsed.elapsed);
}
