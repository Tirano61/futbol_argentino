import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/competition.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';

final fakeFetchedAt = DateTime.utc(2026, 10, 11, 20, 35);

/// Repositorio de partidos en memoria con rondas reales.
///
/// - [delays]: demora por ronda (para simular respuestas fuera de orden).
/// - [refreshError]: emite los datos como caché con ese error.
/// - [failure]: sin datos, el stream termina con ese error.
class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository(
    this.rounds, {
    this.delays = const {},
    this.refreshError,
    this.failure,
  });

  final Map<int, List<Match>> rounds;
  final Map<int, Duration> delays;
  final Failure? refreshError;
  Failure? failure;
  final queries = <RoundQuery>[];
  final prefetched = <RoundQuery>[];

  @override
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
  }) async* {
    queries.add(query);
    final delay = delays[query.apiRound];
    if (delay != null) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    yield DataResult(
      data: rounds[query.apiRound] ?? const [],
      origin: refreshError == null ? DataOrigin.remote : DataOrigin.cache,
      fetchedAt: fakeFetchedAt,
      refreshError: refreshError,
    );
  }

  @override
  Future<void> prefetchRound(RoundQuery query) async => prefetched.add(query);

  @override
  Future<DataResult<Match>> getMatch(
    int matchId, {
    bool forceRefresh = false,
  }) async {
    if (failure != null) throw failure!;
    for (final round in rounds.values) {
      for (final m in round) {
        if (m.id == matchId) {
          return DataResult(
            data: m,
            origin: DataOrigin.remote,
            fetchedAt: fakeFetchedAt,
          );
        }
      }
    }
    throw NotFoundFailure(detail: 'sin partido $matchId');
  }
}

class FakeCompetitionRepository implements CompetitionRepository {
  FakeCompetitionRepository({
    this.pointers,
    this.failure,
    this.currentSeason = const Season(2026),
  });

  final SchedulePointers? pointers;
  final Failure? failure;
  final Season? currentSeason;

  @override
  Future<DataResult<Competition>> getCompetition(int competitionId) async {
    if (failure != null) throw failure!;
    return DataResult(
      data: Competition(
        id: competitionId,
        name: 'Competición $competitionId',
        shortName: '$competitionId',
        format: CompetitionFormat.league,
        currentSeason: currentSeason,
      ),
      origin: DataOrigin.remote,
      fetchedAt: fakeFetchedAt,
    );
  }

  @override
  Future<DataResult<SchedulePointers>> getSchedulePointers(
    int competitionId, {
    bool forceRefresh = false,
  }) async {
    if (failure != null) throw failure!;
    return DataResult(
      data: pointers ?? const SchedulePointers(),
      origin: DataOrigin.remote,
      fetchedAt: fakeFetchedAt,
    );
  }
}

class FixedClock implements Clock {
  const FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}
