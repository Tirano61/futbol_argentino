import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/query_metadata_store.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/data/datasources/competition_remote_data_source.dart';
import 'package:futbol_argentino/features/competitions/data/repositories/competition_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/home/domain/entities/favorite_team_overview.dart';
import 'package:futbol_argentino/features/home/domain/usecases/get_home_feed.dart';
import 'package:futbol_argentino/features/home/domain/usecases/watch_favorite_teams.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_local_data_source.dart';
import 'package:futbol_argentino/features/matches/data/datasources/match_remote_data_source.dart';
import 'package:futbol_argentino/features/matches/data/repositories/match_repository_impl.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_teams.dart';
import '../../helpers/fixtures.dart';

/// «Tus equipos» con repositorios reales y respuestas grabadas: solo lee lo
/// guardado (el presupuesto del Inicio no cambia).
void main() {
  late FakeClock clock;
  late Database db;
  late List<Uri> requests;
  late FavoritesRepositoryImpl favorites;
  late GetHomeFeed home;
  late WatchFavoriteTeams watch;

  setUp(() async {
    // Domingo 11/10/2026, 17:35 en Argentina.
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    db = await newDatabaseFactoryMemory().openDatabase('app.db');
    requests = [];
    final client = TheSportsDbClient(
      config: const AppConfig(apiKey: '123', enableDiagnostics: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        final q = request.url.queryParameters;
        final name = switch (request.url.pathSegments.last) {
          'eventsround.php' => 'eventsround_${q['id']}_r${q['r']}_s${q['s']}',
          'eventsnextleague.php' => 'eventsnextleague_${q['id']}',
          'eventspastleague.php' => 'eventspastleague_${q['id']}',
          _ => throw StateError('sin fixture para ${request.url}'),
        };
        return http.Response.bytes(fixtureBytes(name), 200);
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
    final matches = MatchRepositoryImpl(
      remote: MatchRemoteDataSource(client),
      local: MatchLocalDataSource(db),
      metadata: metadata,
      scheduler: scheduler,
      clock: clock,
    );
    home = GetHomeFeed(
      competitions: CompetitionRepositoryImpl(
        remote: CompetitionRemoteDataSource(client),
        database: db,
        metadata: metadata,
        scheduler: scheduler,
        clock: clock,
      ),
      matches: matches,
    );
    favorites = FavoritesRepositoryImpl(db);
    watch = WatchFavoriteTeams(favorites: favorites, matches: matches);
  });

  tearDown(() => db.close());

  Future<void> favorite(TeamRef team) =>
      favorites.save(FavoriteTeam.fromRef(team, addedAt: clock.now()));

  String describe(FavoriteTeamOverview o) => [
    o.team.name,
    for (final m in [o.next, o.last])
      m == null
          ? '-'
          : '${m.match.home.name} vs ${m.match.away.name} '
                '(${[m.competitionName, ?m.phaseLabel, m.stageLabel].join(' · ')})',
  ].join(' | ');

  test('próximo y último de cada favorito, sin peticiones', () async {
    await home(now: clock.now()).last;
    final homeRequests = requests.length;
    await favorite(recordedTeam('Boca Juniors'));
    await favorite(recordedTeam('River Plate'));

    final teams = await watch(now: clock.now).first;

    expect(requests, hasLength(homeRequests));
    // Clausura: fecha 12 jugada (09 y 10/10), fecha 13 el 18/10. Las mismas
    // rondas traen partidos del Apertura (marzo/abril), más viejos.
    expect(teams.map(describe), [
      'Boca Juniors | '
          'Boca Juniors vs Talleres de Córdoba '
          '(Primera División · Clausura · Fecha 13) | '
          'Instituto vs Boca Juniors (Primera División · Clausura · Fecha 12)',
      'River Plate | '
          'Belgrano vs River Plate (Primera División · Clausura · Fecha 13) | '
          'River Plate vs Estudiantes de Río Cuarto '
          '(Primera División · Clausura · Fecha 12)',
    ]);
  });

  test(
    'se actualiza al guardarse partidos y al cambiar los favoritos',
    () async {
      await favorite(recordedTeam('Boca Juniors'));
      final emitted = <List<FavoriteTeamOverview>>[];
      final sub = watch(now: clock.now).listen(emitted.add);
      await pumpEventQueue();

      // Todavía no hay partidos guardados.
      expect(emitted.last.single.hasMatches, isFalse);

      await home(now: clock.now()).last;
      await pumpEventQueue();
      expect(emitted.last.single.next, isNotNull);
      expect(emitted.last.single.last, isNotNull);

      await favorite(recordedTeam('River Plate'));
      await pumpEventQueue();
      expect(emitted.last.map((o) => o.team.name), [
        'Boca Juniors',
        'River Plate',
      ]);

      await favorites.remove(recordedTeam('Boca Juniors').id);
      await favorites.remove(recordedTeam('River Plate').id);
      await pumpEventQueue();
      expect(emitted.last, isEmpty);
      await sub.cancel();
    },
  );
}
