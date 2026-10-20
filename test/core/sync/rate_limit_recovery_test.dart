import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_progress.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season_completion.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/complete_rounds.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/teams/domain/entities/team_detail.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/watch_team_detail.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recorded_api.dart';

/// Fase R2: un HTTP 429 se reintenta solo desde el scheduler. Repositorios
/// reales y respuestas grabadas; los 429 los arma el test.
void main() {
  late FakeClock clock;
  late RecordedApi api;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  int count(String label) => api.requestLabels.where((l) => l == label).length;

  group('CompleteRounds (Primera 2026, 17 rondas)', () {
    Future<SeasonCompletion> load() => CompleteRounds(api.matches)(
      4406,
      const Season(2026),
      now: clock.now(),
      cancelToken: CancelToken(),
    ).last;

    test(
      'un 429 en una ronda: sigue sola y completa con 1 consulta más',
      () async {
        api.limit('4406:r5:s2026');

        final result = await load();

        expect(
          result.progress,
          const SyncProgress(
            done: 17,
            total: 17,
            isRunning: false,
            fetched: 17,
          ),
        );
        expect(api.requests, hasLength(18));
        expect(count('4406:r5:s2026'), 2);
        expect(api.requestLabels.toSet(), hasLength(17), reason: 'sin repetir');
      },
    );

    test(
      '429 persistente: se detiene tras 3 intentos y ofrece reintentar',
      () async {
        api.limit('4406:r5:s2026', times: 99);

        final result = await load();

        expect(result.progress.isRunning, isFalse);
        expect(result.progress.failure, isA<RateLimitFailure>());
        expect(result.progress.done, 4);
        expect(count('4406:r5:s2026'), 3);
        expect(api.requests, hasLength(7), reason: 'fechas 1–4 + 3 intentos');
      },
    );
  });

  group('ficha de Boca en frío (37 consultas sin 429)', () {
    Future<TeamDetail> load() => WatchTeamDetail(
      teams: api.teams,
      matches: api.matches,
    )(135156, now: clock.now(), cancelToken: CancelToken()).last;

    test('429 en `eventslast`: el reintento no repite `eventsnext`', () async {
      api.limit('eventslast:135156');

      final detail = await load();

      expect(count('eventsnext:135156'), 1);
      expect(count('eventslast:135156'), 2);
      expect(api.requests, hasLength(38));
      expect(detail.progress.failure, isNull);
      expect(detail.progress.done, 33);
      // Los dos punteros quedaron guardados (sin otra consulta).
      final pointers = (await api.teams.getTeamPointers(135156)).data;
      expect(pointers.next, isNotNull);
      expect(pointers.last, isNotNull);
      expect(api.requests, hasLength(38));
    });

    test('429 en una ronda P2: la ficha se completa sola', () async {
      api.limit('4406:r3:s2026');

      final detail = await load();

      expect(api.requests, hasLength(38));
      expect(count('4406:r3:s2026'), 2);
      expect(
        detail.progress,
        const SyncProgress(done: 33, total: 33, isRunning: false, fetched: 33),
      );
    });
  });

  group('refresco forzado de una ronda', () {
    const query = RoundQuery(competitionId: 4406, season: '2026', apiRound: 12);

    test('un 429 se reintenta y la ronda queda actualizada', () async {
      await api.matches.syncRound(query);
      clock.advance(const Duration(seconds: 40));
      final before = (await api.matches.roundCacheState(query)).fetchedAt!;
      api.limit('4406:r12:s2026');

      final queried = await api.matches.syncRound(
        query,
        priority: SyncPriority.visible,
        forceRefresh: true,
      );

      expect(queried, isTrue);
      expect(
        count('4406:r12:s2026'),
        3,
        reason: 'la primera + 429 + reintento',
      );
      final after = (await api.matches.roundCacheState(query)).fetchedAt!;
      expect(after.isAfter(before), isTrue);
    });

    test('dos pantallas esperando el reintento: una sola consulta', () async {
      api.limit('4406:r12:s2026');

      await Future.wait([
        api.matches.syncRound(query, priority: SyncPriority.visible),
        api.matches.syncRound(query),
        api.matches.watchRound(query).last,
      ]);

      expect(count('4406:r12:s2026'), 2, reason: '429 + reintento');
      expect(api.scheduler.pending, 0);
    });
  });
}
