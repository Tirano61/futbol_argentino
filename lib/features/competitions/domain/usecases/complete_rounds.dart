import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/match_status.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';
import '../entities/season_completion.dart';
import '../services/round_navigator.dart';

/// Completa a pedido las rondas de una temporada de una competición
/// (historial): emite lo guardado enseguida y se va completando.
///
/// - Prioridad P2 (cupo de 10 por minuto, de a una, en pausa con la app
///   oculta). Cancelar [cancelToken] descarta las rondas que faltan.
/// - Nunca vuelve a pedir una ronda guardada y vigente.
/// - Una ronda cerrada (todo terminado hace más de 48 h, vigencia de 30
///   días) que venció solo se pide si tiene partidos sin resultado.
/// - De una temporada anterior ya terminada, una ronda guardada y completa
///   no se vuelve a pedir aunque haya vencido (histórica).
/// - Con `forceRefresh` (refresco manual) se piden también las vencidas
///   cerradas o históricas; las vigentes, nunca.
///
/// Un error detiene la descarga: las siguientes fallarían igual.
///
/// Con `fetch: false` solo informa lo guardado y qué rondas faltan o
/// vencieron (una emisión, sin red): el calendario lo usa al abrirse.
class CompleteRounds {
  const CompleteRounds(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  /// [rounds]: rondas de la API a completar, en orden; por defecto, todas
  /// las etapas de la temporada (Primera 2026: fechas 1–16 y la ronda 0 de
  /// eliminatorias del Apertura).
  Stream<SeasonCompletion> call(
    int competitionId,
    Season season, {
    required DateTime now,
    required CancelToken cancelToken,
    List<int>? rounds,
    bool forceRefresh = false,
    bool fetch = true,
  }) async* {
    final definition = _catalog.where((d) => d.id == competitionId).firstOrNull;
    final today = ArgentinaTime.dayOf(now);
    final finished = season.year < today.year;
    final apiRounds = [
      ...{
        ...?rounds,
        if (rounds == null && definition != null)
          ...seasonRounds(
            definition,
            season,
            await _matches.storedSeason(competitionId, season.apiValue),
          ),
      },
    ];

    final statuses = <int, RoundCompletionStatus>{};
    for (final r in apiRounds) {
      final query = _query(definition, competitionId, season, r);
      statuses[r] = classify(
        await _matches.roundCacheState(query),
        await _matches.storedRound(query),
        seasonFinished: finished,
        forceRefresh: forceRefresh,
      );
    }

    Future<SeasonCompletion> build(SyncProgress progress) async =>
        SeasonCompletion(
          competitionId: competitionId,
          season: season,
          matches: await _matches.storedSeason(competitionId, season.apiValue),
          rounds: [
            for (final r in apiRounds)
              SeasonRound(apiRound: r, status: statuses[r]!),
          ],
          progress: progress,
        );

    final toFetch = [
      for (final r in apiRounds)
        if (statuses[r]!.needsFetch) r,
    ];
    var done = apiRounds.length - toFetch.length;
    var fetched = 0;
    Failure? failure;
    yield await build(
      SyncProgress(
        done: done,
        total: apiRounds.length,
        isRunning: fetch && toFetch.isNotEmpty,
      ),
    );
    if (!fetch || toFetch.isEmpty) return;

    for (final r in toFetch) {
      try {
        final queried = await _matches.syncRound(
          _query(definition, competitionId, season, r),
          priority: SyncPriority.team,
          cancelToken: cancelToken,
        );
        statuses[r] = queried
            ? RoundCompletionStatus.fetched
            : RoundCompletionStatus.fresh;
        if (queried) fetched++;
      } on SyncCancelled {
        return;
      } on Failure catch (error) {
        failure = error;
        break;
      }
      if (cancelToken.isCancelled) return;
      done++;
      yield await build(
        SyncProgress(done: done, total: apiRounds.length, fetched: fetched),
      );
    }

    yield await build(
      SyncProgress(
        done: done,
        total: apiRounds.length,
        isRunning: false,
        failure: failure,
        fetched: fetched,
      ),
    );
  }

  /// Qué hacer con una ronda según lo guardado.
  static RoundCompletionStatus classify(
    RoundCacheState state,
    List<Match> stored, {
    required bool seasonFinished,
    bool forceRefresh = false,
  }) {
    switch (state.freshness) {
      case RoundFreshness.missing:
        return RoundCompletionStatus.missing;
      case RoundFreshness.fresh:
        return RoundCompletionStatus.fresh;
      case RoundFreshness.stale:
        if (forceRefresh || !state.isComplete) {
          return RoundCompletionStatus.stale;
        }
        final complete = stored.every(
          (m) => _hasFinalState(m, seasonFinished: seasonFinished),
        );
        if (complete && seasonFinished) return RoundCompletionStatus.historic;
        if (complete && state.isClosed) return RoundCompletionStatus.settled;
        return RoundCompletionStatus.stale;
    }
  }

  /// El partido ya no va a cambiar: terminado con resultado, cancelado o
  /// abandonado. En una temporada terminada, un postergado tampoco.
  static bool _hasFinalState(Match m, {required bool seasonFinished}) =>
      switch (m.status.kind) {
        MatchStatusKind.finished => m.score != null,
        MatchStatusKind.cancelled || MatchStatusKind.abandoned => true,
        MatchStatusKind.postponed => seasonFinished,
        _ => false,
      };

  /// Rondas de todas las etapas de la temporada, sin repetir (la ronda de
  /// los octavos de Primera es también una fecha regular).
  static List<int> seasonRounds(
    CompetitionDefinition definition,
    Season season,
    List<Match> stored,
  ) {
    // Sin cantidad de fechas en el catálogo: hasta la última guardada.
    final lastKnown = stored.isEmpty
        ? null
        : stored.map((m) => m.apiRound).reduce((a, b) => a > b ? a : b);
    return [
      ...{
        for (final phase in definition.phases)
          for (final stage in RoundNavigator.stagesFor(
            definition,
            season,
            phase,
            knownMaxRound: lastKnown,
          ))
            stage.apiRound,
      },
    ];
  }

  static RoundQuery _query(
    CompetitionDefinition? definition,
    int competitionId,
    Season season,
    int apiRound,
  ) => RoundQuery(
    competitionId: competitionId,
    season: season.apiValue,
    apiRound: apiRound,
    expectedMinimum: definition?.expectedMinimumMatches(season, apiRound),
  );
}
