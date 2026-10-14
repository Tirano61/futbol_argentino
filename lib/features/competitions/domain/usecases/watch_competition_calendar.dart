import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';
import '../entities/season_completion.dart';
import '../services/phase_resolver.dart';
import '../services/stage_labeler.dart';
import 'complete_rounds.dart';
import 'refresh_recent_rounds.dart';

/// Fase y etapa visibles de un partido del calendario («Clausura»,
/// «Fecha 12»).
typedef CalendarMatchLabel = ({String? phase, String stage});

/// Calendario de una competición y temporada: los partidos guardados y
/// cuánto de la temporada cubren.
final class CompetitionCalendar extends Equatable {
  const CompetitionCalendar({
    required this.competitionId,
    required this.season,
    required this.matches,
    required this.labels,
    required this.roundsTotal,
    required this.roundsStored,
    required this.roundsPending,
    required this.progress,
  });

  final int competitionId;
  final Season season;

  /// Partidos visibles guardados de la temporada (todas sus rondas).
  final List<Match> matches;

  /// Fase y etapa de cada partido, por `idEvent`.
  final Map<int, CalendarMatchLabel> labels;

  /// Rondas de la temporada (Primera 2026: fechas 1–16 y la ronda 0).
  final int roundsTotal;

  /// Rondas consultadas alguna vez (guardadas).
  final int roundsStored;

  /// Rondas sin consultar, o vencidas y que todavía pueden cambiar: el
  /// calendario puede estar incompleto o desactualizado.
  final int roundsPending;

  final SyncProgress progress;

  @override
  List<Object?> get props => [
    competitionId,
    season,
    matches,
    labels,
    roundsTotal,
    roundsStored,
    roundsPending,
    progress,
  ];
}

/// Calendario de una temporada (T18): al abrirse, solo lo guardado (sin
/// red); [CompleteRounds] (P2) completa las rondas que faltan **solo si se
/// pide** (`download`).
///
/// Con `forceRefresh` (refresco manual), primero se fuerzan con P0 las
/// rondas con partidos sin terminar de ayer y de hoy, y después se piden
/// también las vencidas cerradas o históricas (nunca las vigentes).
class WatchCompetitionCalendar {
  const WatchCompetitionCalendar(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  Stream<CompetitionCalendar> call(
    int competitionId,
    Season season, {
    required DateTime now,
    required CancelToken cancelToken,
    bool download = false,
    bool forceRefresh = false,
  }) async* {
    final definition = _catalog.where((d) => d.id == competitionId).firstOrNull;

    var forced = 0;
    Failure? forcedFailure;
    if (forceRefresh) {
      try {
        (fetched: forced, failure: forcedFailure) = await RefreshRecentRounds(
          _matches,
          catalog: _catalog,
        )(competitionId, season, now: now, cancelToken: cancelToken);
      } on SyncCancelled {
        return;
      }
    }

    await for (final completion in CompleteRounds(_matches, catalog: _catalog)(
      competitionId,
      season,
      now: now,
      cancelToken: cancelToken,
      forceRefresh: forceRefresh,
      fetch: download || forceRefresh,
    )) {
      final p = completion.progress;
      yield _build(
        definition,
        completion,
        SyncProgress(
          done: p.done,
          total: p.total,
          isRunning: p.isRunning,
          failure: p.failure ?? (p.isRunning ? null : forcedFailure),
          fetched: p.fetched + forced,
        ),
      );
    }
  }

  static CompetitionCalendar _build(
    CompetitionDefinition? definition,
    SeasonCompletion completion,
    SyncProgress progress,
  ) => CompetitionCalendar(
    competitionId: completion.competitionId,
    season: completion.season,
    matches: completion.matches,
    labels: labelsFor(definition, completion.season, completion.matches),
    roundsTotal: completion.rounds.length,
    roundsStored: completion.rounds
        .where((r) => r.status != RoundCompletionStatus.missing)
        .length,
    roundsPending: completion.rounds.where((r) => r.status.needsFetch).length,
    progress: progress,
  );

  /// Fase y etapa de cada partido, sin red: la fase se resuelve con la
  /// ronda guardada completa (como en el fixture).
  static Map<int, CalendarMatchLabel> labelsFor(
    CompetitionDefinition? definition,
    Season season,
    List<Match> matches,
  ) {
    final byRound = <int, List<Match>>{};
    for (final m in matches) {
      (byRound[m.apiRound] ??= []).add(m);
    }
    if (definition == null) {
      return {
        for (final m in matches)
          m.id: (phase: null, stage: 'Ronda ${m.apiRound}'),
      };
    }
    final resolver = PhaseResolver(definition);
    return {
      for (final MapEntry(key: apiRound, value: round) in byRound.entries)
        for (final MapEntry(key: id, value: assignment)
            in resolver
                .classifyRound(
                  season: season,
                  apiRound: apiRound,
                  matches: round,
                )
                .entries)
          id: StageLabeler.describe(definition, apiRound, assignment),
    };
  }
}
