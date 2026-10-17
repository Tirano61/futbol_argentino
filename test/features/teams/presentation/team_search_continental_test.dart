import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/ensure_continental_team_index.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/ensure_team_index.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/search_teams_online.dart';
import 'package:futbol_argentino/features/teams/presentation/bloc/team_search_bloc.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/recorded_api.dart';

const debounce = Duration(milliseconds: 20);

/// Fase D6: «Buscar también en copas internacionales» (arranque bajo
/// demanda) con los repositorios reales y las respuestas grabadas.
void main() {
  late FakeClock clock;
  late RecordedApi api;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 15, 0, 45));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  TeamSearchBloc build() => TeamSearchBloc(
    teams: api.teams,
    ensureIndex: EnsureTeamIndex(api.matches),
    ensureContinentalIndex: EnsureContinentalTeamIndex(api.matches),
    searchOnline: SearchTeamsOnline(api.teams),
    clock: FixedClock(clock.now()),
    debounce: debounce,
  );

  Future<TeamSearchState> settled(TeamSearchBloc bloc) => bloc.stream
      .firstWhere(
        (s) =>
            !s.isIndexing &&
            !s.isIndexingContinental &&
            s.results is! TeamSearchSearching &&
            s.results is! TeamSearchIdle,
      )
      .timeout(const Duration(seconds: 5));

  test('las rondas: Fecha 1 de grupos 2026 de cada copa (no la Fase 1)', () {
    final queries = EnsureContinentalTeamIndex(
      api.matches,
    ).queries(now: clock.now());
    expect(
      [for (final q in queries) (q.competitionId, q.season, q.apiRound)],
      [(4501, '2026', 1), (4724, '2026', 1)],
    );
    // La ronda 1 trae la Fase 1 (6) o la Primera fase (16) y la Fecha 1.
    expect([for (final q in queries) q.expectedMinimum], [22, 32]);
  });

  test('en marzo, antes de los grupos: la temporada anterior', () {
    final queries = EnsureContinentalTeamIndex(
      api.matches,
    ).queries(now: DateTime.utc(2026, 3, 10, 15));
    expect({for (final q in queries) q.season}, {'2025'});
  });

  test(
    '«Flamengo»: en línea primero; con las copas, entre los guardados',
    () async {
      final bloc = build()..add(const TeamSearchStarted());
      await bloc.stream.firstWhere((s) => !s.isIndexing);
      expect(bloc.state.offersContinental, isTrue);

      bloc.add(const TeamSearchQueryChanged('Flamengo'));
      final online = await settled(bloc);
      // Sin coincidencias guardadas: `searchteams` (equipo de Brasil que
      // juega la Libertadores).
      final found = online.results as TeamSearchFound;
      expect(found.isOnline, isTrue);
      expect(found.teams.single.team.id, 134287);
      expect(found.teams.single.competitionIds, [4501]);
      expect(online.offersContinental, isTrue);

      api.requests.clear();
      bloc.add(const TeamSearchContinentalRequested());
      final local = await bloc.stream
          .firstWhere(
            (s) =>
                !s.isIndexingContinental &&
                s.results is TeamSearchFound &&
                !(s.results as TeamSearchFound).isOnline,
          )
          .timeout(const Duration(seconds: 5));

      // 2 peticiones (P1), una por copa; la búsqueda en línea no se repite.
      expect(api.requestLabels, ['4501:r1:s2026', '4724:r1:s2026']);
      expect(local.offersContinental, isFalse);
      expect(local.continentalFailure, isNull);
      final team = (local.results as TeamSearchFound).teams.single;
      expect(team.team.name, 'Flamengo');
      expect(team.competitionIds, [4501]);
      await bloc.close();

      // Otra vez: ya no se ofrece y no pide nada.
      api.requests.clear();
      final again = build()..add(const TeamSearchStarted());
      await again.stream.firstWhere((s) => !s.isIndexing);
      expect(again.state.offersContinental, isFalse);
      expect(api.requestLabels.where((l) => l.startsWith('45')), isEmpty);
      await again.close();
    },
  );

  test('sin red: avisa y lo sigue ofreciendo', () async {
    final bloc = build()..add(const TeamSearchStarted());
    await bloc.stream.firstWhere((s) => !s.isIndexing);
    api.offline = true;

    bloc.add(const TeamSearchContinentalRequested());
    final state = await bloc.stream.firstWhere(
      (s) => !s.isIndexingContinental && s.continentalFailure != null,
    );

    expect(state.offersContinental, isTrue);
    expect(api.scheduler.pending, 0);
    await bloc.close();
  });

  test('el arranque es P1 (contexto)', () async {
    final synced = FakeMatchRepository({});
    await EnsureContinentalTeamIndex(synced)(now: clock.now());
    expect(synced.synced.map((s) => s.priority).toSet(), {
      SyncPriority.context,
    });
  });
}
