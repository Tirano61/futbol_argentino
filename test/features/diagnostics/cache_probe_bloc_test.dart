import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/features/diagnostics/presentation/bloc/cache_probe_bloc.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';

import '../../helpers/fixture_matches.dart';

class _StubRepository implements MatchRepository {
  _StubRepository(this.emissions, {this.error});

  final List<DataResult<List<Match>>> emissions;
  final Failure? error;
  final forced = <bool>[];

  @override
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
    SyncPriority priority = SyncPriority.visible,
  }) async* {
    forced.add(forceRefresh);
    for (final e in emissions) {
      yield e;
    }
    if (error != null) throw error!;
  }

  @override
  Future<void> prefetchRound(RoundQuery query) async {}

  @override
  Future<DataResult<Match>> getMatch(
    int matchId, {
    bool forceRefresh = false,
  }) => throw UnimplementedError();

  @override
  Future<bool> syncRound(
    RoundQuery query, {
    SyncPriority priority = SyncPriority.context,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<List<Match>> storedRound(RoundQuery query) =>
      throw UnimplementedError();

  @override
  Future<RoundCacheState> roundCacheState(RoundQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<Match>> storedSeason(int competitionId, String season) =>
      throw UnimplementedError();

  @override
  Future<List<StoredSeasonSummary>> storedSeasons() =>
      throw UnimplementedError();

  @override
  Future<int> deleteSeason(int competitionId, String season) =>
      throw UnimplementedError();

  @override
  Future<List<Match>> storedTeamMatches(int teamId) =>
      throw UnimplementedError();

  @override
  Stream<List<Match>> watchStoredTeamsMatches(Set<int> teamIds) =>
      throw UnimplementedError();
}

void main() {
  final fetchedAt = DateTime.utc(2026, 10, 11, 20);
  final now = DateTime.utc(2026, 10, 11, 21);
  final matches = fixtureMatches('eventsround_4406_r12_s2026');
  const offline = NetworkFailure(
    issue: NetworkIssue.connection,
    detail: 'Network is unreachable',
  );

  blocTest<CacheProbeBloc, CacheProbeState>(
    'registra caché y luego caché con error de actualización',
    build: () => CacheProbeBloc(
      _StubRepository([
        DataResult(
          data: matches,
          origin: DataOrigin.cache,
          fetchedAt: fetchedAt,
        ),
        DataResult(
          data: matches,
          origin: DataOrigin.cache,
          fetchedAt: fetchedAt,
          refreshError: offline,
        ),
      ]),
      now: () => now,
    ),
    act: (bloc) => bloc.add(const CacheProbeRequested(forceRefresh: true)),
    verify: (bloc) {
      final entries = bloc.state.entries;
      expect(bloc.state.running, isFalse);
      expect(entries, hasLength(2));
      expect(entries.first.error, offline);
      expect(entries.last.origin, DataOrigin.cache);
      expect(entries.every((e) => e.count == 30 && e.forced), isTrue);
    },
  );

  blocTest<CacheProbeBloc, CacheProbeState>(
    'sin datos y sin conexión: registra el error',
    build: () => CacheProbeBloc(
      _StubRepository(const [], error: offline),
      now: () => now,
    ),
    act: (bloc) => bloc.add(const CacheProbeRequested()),
    verify: (bloc) {
      final entry = bloc.state.entries.single;
      expect(entry.origin, isNull);
      expect(entry.error, offline);
    },
  );
}
