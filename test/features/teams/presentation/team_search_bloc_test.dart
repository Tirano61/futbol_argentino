import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/ensure_team_index.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/search_teams_online.dart';
import 'package:futbol_argentino/features/teams/presentation/bloc/team_search_bloc.dart';

import '../../../helpers/fake_teams.dart';
import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fakes.dart';

const debounce = Duration(milliseconds: 20);
const offline = NetworkFailure(
  issue: NetworkIssue.connection,
  detail: 'Network is unreachable',
);

void main() {
  late FakeMatchRepository matches;
  late FakeTeamRepository teams;

  setUp(() {
    // Primeras etapas con partidos: el bootstrap no recurre a 2025.
    matches = FakeMatchRepository({
      1: fixtureMatches('eventsround_4406_r1_s2026'),
      64: fixtureMatches('eventsround_4500_r64_s2026'),
    });
    teams = FakeTeamRepository(stored: recordedTeamSummaries());
  });

  TeamSearchBloc build() => TeamSearchBloc(
    teams: teams,
    ensureIndex: EnsureTeamIndex(matches),
    searchOnline: SearchTeamsOnline(teams),
    clock: FixedClock(DateTime.utc(2026, 10, 11, 20, 35)),
    debounce: debounce,
  );

  List<String> names(TeamSearchState state) => switch (state.results) {
    TeamSearchFound(:final teams) => [for (final t in teams) t.team.name],
    _ => const [],
  };

  test('al abrir: índice guardado y bootstrap de 3 rondas (P1)', () async {
    final bloc = build()..add(const TeamSearchStarted());
    await bloc.stream.firstWhere((s) => !s.isIndexing && s.indexSize > 0);

    expect(bloc.state.indexSize, recordedTeamSummaries().length);
    expect(bloc.state.indexFailure, isNull);
    expect(
      matches.synced.map((s) => (s.query.competitionId, s.query.apiRound)),
      unorderedEquals([(4406, 1), (4616, 1), (4500, 64)]),
    );
    await bloc.close();
  });

  blocTest<TeamSearchBloc, TeamSearchState>(
    '«river» encuentra River Plate',
    build: build,
    act: (bloc) => bloc
      ..add(const TeamSearchStarted())
      ..add(const TeamSearchQueryChanged('river')),
    wait: debounce * 3,
    verify: (bloc) {
      expect(names(bloc.state), ['River Plate']);
      expect(teams.onlineQueries, isEmpty);
    },
  );

  blocTest<TeamSearchBloc, TeamSearchState>(
    'debounce: al escribir rápido solo se busca el texto final',
    build: build,
    seed: () => const TeamSearchState(),
    act: (bloc) async {
      bloc.add(const TeamSearchStarted());
      await Future<void>.delayed(debounce);
      for (final text in ['g', 'gi', 'gim', 'gimn', 'gimnasia']) {
        bloc.add(TeamSearchQueryChanged(text));
      }
    },
    wait: debounce * 3,
    verify: (bloc) {
      expect(bloc.state.query, 'gimnasia');
      expect(names(bloc.state), hasLength(5));
    },
  );

  test('nunca muestra resultados de un texto anterior', () async {
    final bloc = build()..add(const TeamSearchStarted());
    final shown = <List<String>>[];
    final sub = bloc.stream.listen((s) {
      if (s.results is TeamSearchFound) shown.add(names(s));
    });
    await Future<void>.delayed(debounce);

    bloc
      ..add(const TeamSearchQueryChanged('rive'))
      ..add(const TeamSearchQueryChanged('racing'));
    await Future<void>.delayed(debounce * 3);

    expect(shown, [
      ['Racing Club', 'Racing de Córdoba'],
    ]);
    await sub.cancel();
    await bloc.close();
  });

  group('respaldo en línea', () {
    setUp(() {
      teams = FakeTeamRepository(
        stored: recordedTeamSummaries(),
        online: {'Boca Unidos': recordedTeams('searchteams_Boca')},
      );
    });

    blocTest<TeamSearchBloc, TeamSearchState>(
      'sin coincidencias locales y ≥ 3 letras: busca en TheSportsDB',
      build: build,
      act: (bloc) => bloc
        ..add(const TeamSearchStarted())
        ..add(const TeamSearchQueryChanged('Boca Unidos')),
      wait: debounce * 3,
      verify: (bloc) {
        final results = bloc.state.results as TeamSearchFound;
        expect(results.isOnline, isTrue);
        expect(names(bloc.state), ['Boca Unidos']);
        // Federal A: fuera del catálogo.
        expect(results.teams.single.competitionIds, isEmpty);
        expect(teams.onlineQueries, ['Boca Unidos']);
      },
    );

    blocTest<TeamSearchBloc, TeamSearchState>(
      'con coincidencias locales no consulta la red',
      build: build,
      act: (bloc) => bloc
        ..add(const TeamSearchStarted())
        ..add(const TeamSearchQueryChanged('boca')),
      wait: debounce * 3,
      verify: (bloc) {
        expect(names(bloc.state), ['Boca Juniors']);
        expect(teams.onlineQueries, isEmpty);
      },
    );

    blocTest<TeamSearchBloc, TeamSearchState>(
      'menos de 3 letras: sin resultados y sin consultar la red',
      build: build,
      act: (bloc) => bloc
        ..add(const TeamSearchStarted())
        ..add(const TeamSearchQueryChanged('xz')),
      wait: debounce * 3,
      verify: (bloc) {
        expect(bloc.state.results, const TeamSearchNoResults());
        expect(teams.onlineQueries, isEmpty);
      },
    );

    blocTest<TeamSearchBloc, TeamSearchState>(
      'sin resultados en línea',
      build: build,
      act: (bloc) => bloc
        ..add(const TeamSearchStarted())
        ..add(const TeamSearchQueryChanged('Inexistente')),
      wait: debounce * 3,
      verify: (bloc) => expect(bloc.state.results, const TeamSearchNoResults()),
    );
  });

  blocTest<TeamSearchBloc, TeamSearchState>(
    'la búsqueda en línea falla: sin resultados con el error',
    build: () {
      teams = FakeTeamRepository(onlineFailure: offline);
      return build();
    },
    act: (bloc) => bloc
      ..add(const TeamSearchStarted())
      ..add(const TeamSearchQueryChanged('river')),
    wait: debounce * 3,
    verify: (bloc) => expect(
      bloc.state.results,
      const TeamSearchNoResults(onlineFailure: offline),
    ),
  );

  test('una respuesta en línea lenta no pisa la búsqueda nueva', () async {
    teams = FakeTeamRepository(
      stored: recordedTeamSummaries(),
      online: {'Boca Unidos': recordedTeams('searchteams_Boca')},
      onlineDelay: debounce * 4,
    );
    final bloc = build()..add(const TeamSearchStarted());
    await Future<void>.delayed(debounce);

    bloc.add(const TeamSearchQueryChanged('Boca Unidos'));
    await Future<void>.delayed(debounce * 2);
    expect(bloc.state.results, const TeamSearchSearching());

    bloc.add(const TeamSearchQueryChanged('river'));
    await Future<void>.delayed(debounce * 6);

    expect(teams.onlineQueries, ['Boca Unidos']);
    expect(names(bloc.state), ['River Plate']);
    await bloc.close();
  });

  blocTest<TeamSearchBloc, TeamSearchState>(
    'borrar vuelve al estado inicial',
    build: build,
    act: (bloc) async {
      bloc
        ..add(const TeamSearchStarted())
        ..add(const TeamSearchQueryChanged('river'));
      await Future<void>.delayed(debounce * 3);
      bloc.add(const TeamSearchCleared());
    },
    wait: debounce,
    verify: (bloc) {
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, const TeamSearchIdle());
    },
  );

  blocTest<TeamSearchBloc, TeamSearchState>(
    'búsqueda inicial desde la URL',
    build: build,
    act: (bloc) => bloc.add(const TeamSearchStarted(initialQuery: 'velez')),
    wait: debounce,
    verify: (bloc) {
      expect(bloc.state.query, 'velez');
      expect(names(bloc.state), ['Vélez Sarsfield']);
    },
  );

  group('primera vez (índice vacío)', () {
    blocTest<TeamSearchBloc, TeamSearchState>(
      'espera el índice en lugar de buscar en línea',
      build: () {
        teams = FakeTeamRepository();
        matches = _IndexingMatchRepository(() {
          teams.stored = recordedTeamSummaries();
        });
        return build();
      },
      act: (bloc) => bloc..add(const TeamSearchStarted(initialQuery: 'river')),
      wait: debounce * 3,
      verify: (bloc) {
        expect(names(bloc.state), ['River Plate']);
        expect(teams.onlineQueries, isEmpty);
      },
    );

    blocTest<TeamSearchBloc, TeamSearchState>(
      'sin red: avisa que no se pudo cargar la lista',
      build: () {
        teams = FakeTeamRepository(onlineFailure: offline);
        matches = FakeMatchRepository(const {}, failure: offline);
        return build();
      },
      act: (bloc) => bloc.add(const TeamSearchStarted()),
      wait: debounce,
      verify: (bloc) {
        expect(bloc.state.isIndexing, isFalse);
        expect(bloc.state.indexSize, 0);
        expect(bloc.state.indexFailure, offline);
      },
    );
  });
}

/// Al sincronizar, el índice se llena (como el bootstrap real).
class _IndexingMatchRepository extends FakeMatchRepository {
  _IndexingMatchRepository(this.onSync) : super(const {});

  final void Function() onSync;

  @override
  Future<void> syncRound(
    RoundQuery query, {
    SyncPriority priority = SyncPriority.context,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    await Future<void>.delayed(debounce);
    onSync();
  }
}
