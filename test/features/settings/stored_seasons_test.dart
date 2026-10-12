import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/storage/local_database.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/settings/domain/entities/stored_season.dart';
import 'package:futbol_argentino/features/settings/domain/usecases/stored_seasons.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recorded_api.dart';

RoundQuery round(int competitionId, String season, int apiRound) => RoundQuery(
  competitionId: competitionId,
  season: season,
  apiRound: apiRound,
);

/// Fase 12: vigencia por ronda, temporadas guardadas y limpieza manual con
/// repositorios reales y respuestas grabadas.
void main() {
  late FakeClock clock;
  late Database db;
  late RecordedApi api;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    db = await newDatabaseFactoryMemory().openDatabase('app.db');
    api = RecordedApi(clock: clock, db: db);
  });

  Future<void> sync(List<RoundQuery> queries) async {
    for (final q in queries) {
      await api.matches.syncRound(q);
    }
  }

  group('roundCacheState', () {
    test('falta → vigente → vencida', () async {
      final q = round(4406, '2025', 1);
      expect(await api.matches.roundCacheState(q), RoundCacheState.missing);

      await sync([q]);
      final fresh = await api.matches.roundCacheState(q);
      expect(fresh.freshness, RoundFreshness.fresh);
      expect(fresh.fetchedAt, clock.now());
      // Fecha 1 de 2025: todo terminado hace meses.
      expect(fresh.isClosed, isTrue);
      expect(fresh.isComplete, isTrue);

      clock.advance(const Duration(days: 31));
      final stale = await api.matches.roundCacheState(q);
      expect(stale.freshness, RoundFreshness.stale);
      expect(stale.isClosed, isTrue);
    });

    test('ronda en juego: no cerrada; ronda vacía: no completa', () async {
      final playing = round(4406, '2026', 12);
      final empty = round(4406, '2026', 17);
      await sync([playing, empty]);

      final p = await api.matches.roundCacheState(playing);
      expect(p.freshness, RoundFreshness.fresh);
      expect(p.isClosed, isFalse);
      expect(p.isComplete, isTrue);

      final e = await api.matches.roundCacheState(empty);
      expect(e.isClosed, isFalse);
      expect(e.isComplete, isFalse);
    });
  });

  test('storedSeason: todas las rondas guardadas de la temporada', () async {
    await sync([
      round(4406, '2025', 1),
      round(4406, '2025', 2),
      round(4406, '2026', 1),
    ]);

    final stored = await api.matches.storedSeason(4406, '2025');

    expect(stored, hasLength(60));
    expect(stored.every((m) => m.season == '2025'), isTrue);
    expect(stored.map((m) => m.apiRound).toSet(), {1, 2});
  });

  group('datos guardados', () {
    late FavoritesRepositoryImpl favorites;

    setUp(() async {
      await sync([
        round(4406, '2025', 1),
        round(4406, '2025', 2),
        round(4406, '2026', 1),
        round(4500, '2025', 32),
        round(4500, '2026', 64),
      ]);
      favorites = FavoritesRepositoryImpl(db);
      await favorites.save(
        FavoriteTeam(
          teamId: 135156,
          name: 'Boca Juniors',
          addedAt: DateTime.utc(2026, 10, 1),
        ),
      );
    });

    test('lista por competición, la más reciente primero', () async {
      final seasons = await GetStoredSeasons(api.matches)(now: clock.now());

      expect(seasons, [
        const StoredSeason(
          competitionId: 4406,
          competitionName: 'Primera División',
          season: '2026',
          matchCount: 30,
          isCurrent: true,
        ),
        const StoredSeason(
          competitionId: 4406,
          competitionName: 'Primera División',
          season: '2025',
          matchCount: 60,
          isCurrent: false,
        ),
        const StoredSeason(
          competitionId: 4500,
          competitionName: 'Copa Argentina',
          season: '2026',
          matchCount: 32,
          isCurrent: true,
        ),
        const StoredSeason(
          competitionId: 4500,
          competitionName: 'Copa Argentina',
          season: '2025',
          matchCount: 16,
          isCurrent: false,
        ),
      ]);
    });

    test('borrar una temporada anterior: sus partidos y sus consultas; '
        'nada más', () async {
      final seasons = await GetStoredSeasons(api.matches)(now: clock.now());
      final primera2025 = seasons.singleWhere((s) => s.key == '4406:2025');

      final deleted = await DeleteStoredSeasons(api.matches)([
        primera2025,
      ], now: clock.now());

      expect(deleted, 60);
      expect(await api.matches.storedSeason(4406, '2025'), isEmpty);
      for (final r in [1, 2]) {
        expect(
          await api.matches.roundCacheState(round(4406, '2025', r)),
          RoundCacheState.missing,
        );
      }
      final metaKeys = await AppStores.queryMeta.findKeys(db);
      expect(metaKeys.where((k) => k.startsWith('round:4406:2025:')), isEmpty);
      expect(metaKeys, contains('round:4406:2026:1'));
      expect(metaKeys, contains('round:4500:2025:32'));

      // Lo demás queda igual.
      expect(await api.matches.storedSeason(4406, '2026'), hasLength(30));
      expect(await api.matches.storedSeason(4500, '2025'), hasLength(16));
      expect(await favorites.contains(135156), isTrue);
      expect(
        (await GetStoredSeasons(api.matches)(
          now: clock.now(),
        )).map((s) => s.key),
        ['4406:2026', '4500:2026', '4500:2025'],
      );
    });

    test('lo borrado se vuelve a pedir si hace falta', () async {
      final seasons = await GetStoredSeasons(api.matches)(now: clock.now());
      await DeleteStoredSeasons(api.matches)([
        seasons.singleWhere((s) => s.key == '4406:2025'),
      ], now: clock.now());
      api.requests.clear();

      final result = await api.matches.watchRound(round(4406, '2025', 1)).last;

      expect(api.requestLabels, ['4406:r1:s2025']);
      expect(result.data, hasLength(30));
    });

    test('la temporada actual no se puede borrar', () async {
      final seasons = await GetStoredSeasons(api.matches)(now: clock.now());
      final current = seasons.singleWhere((s) => s.key == '4406:2026');
      final previous = seasons.singleWhere((s) => s.key == '4406:2025');
      expect(current.canDelete, isFalse);
      expect(previous.canDelete, isTrue);

      await expectLater(
        DeleteStoredSeasons(api.matches)([previous, current], now: clock.now()),
        throwsArgumentError,
      );
      // No se borró nada, tampoco la anterior.
      expect(await api.matches.storedSeason(4406, '2025'), hasLength(60));
      expect(await api.matches.storedSeason(4406, '2026'), hasLength(30));
    });

    test(
      'en enero, la temporada del año que terminó ya se puede borrar',
      () async {
        // 1/1/2027 00:30 en Argentina (03:30 UTC).
        final seasons = await GetStoredSeasons(api.matches)(
          now: DateTime.utc(2027, 1, 1, 3, 30),
        );

        expect(seasons.where((s) => s.isCurrent), isEmpty);
        // 31/12/2026 23:30 en Argentina: 2026 sigue siendo la actual.
        final lastDay = await GetStoredSeasons(api.matches)(
          now: DateTime.utc(2027, 1, 1, 2, 30),
        );
        expect(lastDay.where((s) => s.isCurrent).map((s) => s.key), [
          '4406:2026',
          '4500:2026',
        ]);
      },
    );
  });
}
