import 'package:futbol_argentino/core/cache/query_metadata_store.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_local_data_source.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_remote_data_source.dart';
import 'package:futbol_argentino/features/matches/data/repositories/match_repository_impl.dart';
import 'package:futbol_argentino/features/teams/data/datasources/team_remote_data_source.dart';
import 'package:futbol_argentino/features/teams/data/repositories/team_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast.dart';

import 'fake_clock.dart';
import 'fixtures.dart';

/// Nombre del fixture grabado que responde a [url] (`searchteams?t=River
/// Plate` → `searchteams_River_Plate`).
String recordedFixtureFor(Uri url) {
  final q = url.queryParameters;
  return switch (url.pathSegments.last) {
    'eventsround.php' => 'eventsround_${q['id']}_r${q['r']}_s${q['s']}',
    'eventsnextleague.php' => 'eventsnextleague_${q['id']}',
    'eventspastleague.php' => 'eventspastleague_${q['id']}',
    'eventsnext.php' => 'eventsnext_${q['id']}',
    'eventslast.php' => 'eventslast_${q['id']}',
    'lookupteam.php' => 'lookupteam_${q['id']}',
    'searchteams.php' => 'searchteams_${q['t']!.replaceAll(' ', '_')}',
    _ => throw StateError('sin fixture para $url'),
  };
}

/// Repositorios reales sobre una base en memoria y un cliente HTTP que
/// responde con las respuestas grabadas. Registra cada petición; con
/// [offline] simula la falta de red y con [respond], otra respuesta (p. ej.
/// un HTTP 429).
class RecordedApi {
  RecordedApi({required this.clock, required this.db});

  final FakeClock clock;
  final Database db;
  final requests = <Uri>[];

  /// Hora (del reloj falso) de cada petición.
  final requestTimes = <DateTime>[];
  var offline = false;

  /// Respuesta propia para una petición; `null` = la grabada.
  http.Response? Function(Uri url)? respond;

  late final rateLimiter = RateLimiter(
    maxRequests: 25,
    clock: clock,
    delay: clock.delay,
  );

  late final client = TheSportsDbClient(
    config: const AppConfig(apiKey: '123', enableDiagnostics: false),
    httpClient: MockClient((request) async {
      if (offline) throw http.ClientException('Sin red (test)');
      requests.add(request.url);
      requestTimes.add(clock.now());
      if (respond?.call(request.url) case final response?) return response;
      return http.Response.bytes(
        fixtureBytes(recordedFixtureFor(request.url)),
        200,
      );
    }),
    rateLimiter: rateLimiter,
    retryDelay: clock.delay,
    clock: clock,
  );

  late final scheduler = SyncScheduler(
    clock: clock,
    delay: clock.delay,
    rateLimit: rateLimiter,
  );
  late final metadata = QueryMetadataStore(db);

  late final matches = MatchRepositoryImpl(
    remote: MatchRemoteDataSource(client),
    local: MatchLocalDataSource(db),
    metadata: metadata,
    scheduler: scheduler,
    clock: clock,
  );

  late final teams = TeamRepositoryImpl(
    remote: TeamRemoteDataSource(client),
    matches: MatchLocalDataSource(db),
    database: db,
    metadata: metadata,
    scheduler: scheduler,
    clock: clock,
  );

  /// Peticiones como `4406:r12:s2026`, `lookupteam:135156`…
  List<String> get requestLabels => [for (final u in requests) labelOf(u)];

  static String labelOf(Uri u) => switch (u.pathSegments.last) {
    'eventsround.php' =>
      '${u.queryParameters['id']}:r${u.queryParameters['r']}'
          ':s${u.queryParameters['s']}',
    final endpoint =>
      '${endpoint.replaceAll('.php', '')}:'
          '${u.queryParameters['id'] ?? u.queryParameters['t']}',
  };

  /// Responde HTTP 429 a las primeras [times] peticiones de [label] (ver
  /// [labelOf]); las demás, con lo grabado.
  void limit(String label, {int times = 1}) {
    var left = times;
    respond = (url) {
      if (left == 0 || labelOf(url) != label) return null;
      left--;
      return http.Response('{"error": "Too Many Requests"}', 429);
    };
  }
}
