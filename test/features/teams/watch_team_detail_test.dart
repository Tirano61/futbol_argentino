import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/teams/domain/entities/team_pointers.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/watch_team_detail.dart';

import '../../helpers/fake_teams.dart';
import '../../helpers/fakes.dart';
import '../../helpers/fixture_matches.dart';

const bocaId = 135156;

void main() {
  late FakeMatchRepository matches;

  setUp(() {
    // Primera 2026 (solo Primera: las rondas del fake van por número).
    matches = FakeMatchRepository({
      for (var r = 0; r <= 16; r++)
        r: fixtureMatches('eventsround_4406_r${r}_s2026'),
    });
  });

  late FakeTeamRepository teams;

  setUp(() {
    teams = FakeTeamRepository(
      teams: {bocaId: recordedTeams('lookupteam_135156').single},
    );
  });

  Future<void> run({required bool forceRefresh}) =>
      WatchTeamDetail(
            teams: teams,
            matches: matches,
            catalog: const [CompetitionCatalog.primeraDivision],
          )(
            bocaId,
            // Domingo 11/10/2026, 17:35 en Argentina.
            now: DateTime.utc(2026, 10, 11, 20, 35),
            cancelToken: CancelToken(),
            forceRefresh: forceRefresh,
          )
          .drain<void>();

  List<int> roundsWhere(bool Function(SyncPriority p, bool force) test) => [
    for (final s in matches.synced)
      if (test(s.priority, s.force)) s.query.apiRound,
  ];

  test('sin refresco: todo P2 y respetando la vigencia', () async {
    await run(forceRefresh: false);

    // Bootstrap (P1) de la fecha 1 y 17 rondas P2.
    expect(roundsWhere((p, f) => p == SyncPriority.context), [1]);
    expect(roundsWhere((p, f) => p == SyncPriority.team), hasLength(17));
    expect(roundsWhere((p, f) => f), isEmpty);
  });

  test(
    'refresco: fuerza con P0 solo las rondas de partidos cercanos',
    () async {
      await run(forceRefresh: true);

      // Boca–Talleres (fecha 13) es el 18/10: dentro de los 7 días. La fecha
      // 12 ya terminó y la 14 (25/10) queda fuera.
      expect(roundsWhere((p, f) => f), [13]);
      expect(roundsWhere((p, f) => p == SyncPriority.visible), [13]);
      // Primero la forzada; no se repite en la tanda P2.
      expect(matches.synced.skip(1).first.query.apiRound, 13);
      expect(roundsWhere((p, f) => p == SyncPriority.team), hasLength(16));
    },
  );

  test('los punteros del equipo siguen al refresco: P1 o forzados', () async {
    await run(forceRefresh: false);
    await run(forceRefresh: true);

    expect(teams.pointerCalls, [
      (id: bocaId, force: false),
      (id: bocaId, force: true),
    ]);
  });

  test('otras competiciones: próximo y último fuera del catálogo, sin '
      'repetir', () async {
    // Punteros reales de Boca: el próximo es de la Sudamericana y el último,
    // de Primera. Con un catálogo sin Primera, los dos son «otras».
    final next = fixtureMatches('eventsnext_135156').single;
    final last = recordedLastMatch('eventslast_135156');
    Future<List<String>> others(
      TeamPointers pointers,
      List<CompetitionDefinition> catalog,
    ) async {
      final detail =
          await WatchTeamDetail(
                teams: FakeTeamRepository(
                  teams: {bocaId: recordedTeams('lookupteam_135156').single},
                  pointers: {bocaId: pointers},
                ),
                matches: matches,
                catalog: catalog,
              )(
                bocaId,
                now: DateTime.utc(2026, 10, 11, 20, 35),
                cancelToken: CancelToken(),
              )
              .last;
      return [
        for (final m in detail.otherCompetitions)
          '${m.match.id} ${m.competitionName} · ${m.stageLabel}',
      ];
    }

    expect(
      await others(TeamPointers(next: next, last: last), const [
        CompetitionCatalog.primeraDivision,
      ]),
      ['2606044 Copa Sudamericana · Próximo partido'],
    );
    expect(
      await others(TeamPointers(next: next, last: last), const [
        CompetitionCatalog.copaArgentina,
      ]),
      [
        '2606044 Copa Sudamericana · Próximo partido',
        // Fuera del catálogo el nombre es el de la API (`strLeague`).
        '2398104 Argentinian Primera Division · Último partido',
      ],
    );
    // El mismo partido como próximo y último (en juego) va una sola vez.
    expect(
      await others(TeamPointers(next: next, last: next), const [
        CompetitionCatalog.primeraDivision,
      ]),
      ['2606044 Copa Sudamericana · Próximo partido'],
    );
  });
}
