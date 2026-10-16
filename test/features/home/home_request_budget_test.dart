import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/query_metadata_store.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/data/datasources/competition_remote_data_source.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/data/repositories/competition_repository_impl.dart';
import 'package:futbol_argentino/features/home/domain/usecases/get_home_feed.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_local_data_source.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_remote_data_source.dart';
import 'package:futbol_argentino/features/matches/data/repositories/match_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fixtures.dart';

/// Aceptación de la Fase 6: Inicio en frío ≤ 12 peticiones; en caliente,
/// ninguna dentro de la vigencia. Repositorios reales, respuestas grabadas.
/// Fase 15: con el catálogo completo (5 competiciones) solo entran las
/// marcadas con `showInHome`.
void main() {
  late FakeClock clock;
  late Database db;
  late List<Uri> requests;

  Future<http.Response> fixtureHandler(http.Request request) async {
    final q = request.url.queryParameters;
    final name = switch (request.url.pathSegments.last) {
      'eventsround.php' => 'eventsround_${q['id']}_r${q['r']}_s${q['s']}',
      'eventsnextleague.php' => 'eventsnextleague_${q['id']}',
      'eventspastleague.php' => 'eventspastleague_${q['id']}',
      _ => throw StateError('sin fixture para ${request.url}'),
    };
    return http.Response.bytes(fixtureBytes(name), 200);
  }

  GetHomeFeed build() {
    final client = TheSportsDbClient(
      config: const AppConfig(apiKey: '123', enableDiagnostics: false),
      httpClient: MockClient((request) {
        requests.add(request.url);
        return fixtureHandler(request);
      }),
      rateLimiter: RateLimiter(
        maxRequests: 25,
        clock: clock,
        delay: clock.delay,
      ),
      retryDelay: clock.delay,
    );
    final scheduler = SyncScheduler();
    final metadata = QueryMetadataStore(db);
    return GetHomeFeed(
      competitions: CompetitionRepositoryImpl(
        remote: CompetitionRemoteDataSource(client),
        database: db,
        metadata: metadata,
        scheduler: scheduler,
        clock: clock,
      ),
      matches: MatchRepositoryImpl(
        remote: MatchRemoteDataSource(client),
        local: MatchLocalDataSource(db),
        metadata: metadata,
        scheduler: scheduler,
        clock: clock,
      ),
    );
  }

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    db = await newDatabaseFactoryMemory().openDatabase('app.db');
    requests = [];
  });

  test('en frío: 6 punteros + 6 rondas = 12 peticiones', () async {
    final feed = await build()(now: clock.now()).last;

    expect(requests, hasLength(12));
    expect(
      requests.where((u) => u.path.endsWith('eventsround.php')),
      hasLength(6),
    );
    expect(feed.todayMatches, isNotEmpty);
    expect(feed.failedCompetitions, isEmpty);
    // B Metro, Primera C y las copas internacionales están en el catálogo
    // pero no en el Inicio.
    expect(CompetitionCatalog.all, hasLength(7));
    expect(
      {for (final u in requests) u.queryParameters['id']},
      {'4406', '4616', '4500'},
    );
    expect(feed.competitions.map((c) => c.competition.id), [4406, 4616, 4500]);
  });

  test('en caliente, dentro de la vigencia: 0 peticiones', () async {
    final home = build();
    await home(now: clock.now()).last;
    requests.clear();

    // La fecha 12 tiene partidos en juego: vigencia de 2 minutos.
    clock.advance(const Duration(minutes: 1));
    final feed = await home(now: clock.now()).last;

    expect(requests, isEmpty);
    expect(feed.todayMatches, isNotEmpty);
  });

  test('también con otra instancia (datos guardados en la base)', () async {
    await build()(now: clock.now()).last;
    requests.clear();

    clock.advance(const Duration(minutes: 1));
    await build()(now: clock.now()).last;

    expect(requests, isEmpty);
  });

  test('vencidas solo las rondas en juego: se piden solo esas', () async {
    final home = build();
    await home(now: clock.now()).last;
    requests.clear();

    clock.advance(const Duration(minutes: 3));
    await home(now: clock.now()).last;

    // Primera fecha 12 y Nacional fecha 33 tienen partidos en juego.
    expect(
      requests.map(
        (u) => '${u.queryParameters['id']}:r${u.queryParameters['r']}',
      ),
      unorderedEquals(['4406:r12', '4616:r33']),
    );
  });
}
