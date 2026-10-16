import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';

/// Primer paso de un refresco manual (tablas, calendario): fuerza con P0
/// las rondas con partidos guardados sin terminar de ayer o de hoy (o en
/// juego).
class RefreshRecentRounds {
  const RefreshRecentRounds(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  /// [rounds]: solo esas rondas (p. ej. las regulares de una tabla); por
  /// defecto, cualquiera.
  ///
  /// Devuelve cuántas consultó la red y el error que detuvo el refresco.
  /// Lanza `SyncCancelled` si se cancela [cancelToken].
  Future<({int fetched, Failure? failure})> call(
    int competitionId,
    Season season, {
    required DateTime now,
    required CancelToken cancelToken,
    List<int>? rounds,
  }) async {
    var fetched = 0;
    for (final query in await _recentRounds(
      competitionId,
      season,
      rounds,
      now,
    )) {
      try {
        final queried = await _matches.syncRound(
          query,
          priority: SyncPriority.visible,
          forceRefresh: true,
          cancelToken: cancelToken,
        );
        if (queried) fetched++;
      } on Failure catch (failure) {
        return (fetched: fetched, failure: failure);
      }
    }
    return (fetched: fetched, failure: null);
  }

  Future<List<RoundQuery>> _recentRounds(
    int competitionId,
    Season season,
    List<int>? rounds,
    DateTime now,
  ) async {
    final today = ArgentinaTime.dayOf(now);
    bool recent(Match m) {
      if (m.status.isInPlay) return true;
      final day = m.kickoff.argentinaDay;
      return !m.status.isFinished &&
          day != null &&
          !day.isBefore(today.addDays(-1)) &&
          !day.isAfter(today);
    }

    final stored = await _matches.storedSeason(competitionId, season.apiValue);
    final definition = _catalog.where((d) => d.id == competitionId).firstOrNull;
    return [
      for (final r in {
        for (final m in stored)
          if ((rounds == null || rounds.contains(m.apiRound)) && recent(m))
            m.apiRound,
      })
        RoundQuery(
          competitionId: competitionId,
          season: season.apiValue,
          apiRound: r,
          expectedMinimum: definition?.expectedMinimumMatches(season, r),
        ),
    ];
  }
}
