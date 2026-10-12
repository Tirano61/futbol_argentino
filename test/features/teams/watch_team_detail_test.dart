import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
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

  Future<void> run({required bool forceRefresh}) =>
      WatchTeamDetail(
            teams: FakeTeamRepository(
              teams: {bocaId: recordedTeams('lookupteam_135156').single},
            ),
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
}
