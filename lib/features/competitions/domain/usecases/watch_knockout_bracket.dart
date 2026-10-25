import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../knockout/knockout_bracket.dart';
import 'complete_rounds.dart';
import 'refresh_recent_rounds.dart';

/// Cuadros de eliminación de una competición y temporada a medida que se
/// completan.
final class BracketView extends Equatable {
  const BracketView({
    required this.competitionId,
    required this.season,
    required this.brackets,
    required this.progress,
  }) : isAvailable = true;

  /// La competición no tiene un cuadro verificado (Nacional, B Metro…).
  const BracketView.unavailable({
    required this.competitionId,
    required this.season,
  }) : brackets = const {},
       progress = const SyncProgress(isRunning: false),
       isAvailable = false;

  final int competitionId;
  final Season season;

  /// Solo las fases con partidos de eliminatoria guardados.
  final Map<PhaseKey, KnockoutBracket> brackets;
  final SyncProgress progress;
  final bool isAvailable;

  @override
  List<Object?> get props => [
    competitionId,
    season,
    brackets,
    progress,
    isAvailable,
  ];
}

/// Cuadro de llaves (Fase 19.1): lo guardado enseguida y, con
/// [CompleteRounds] (P2), las rondas de eliminación que falten (Primera: la
/// 16 y la 0; Copa: sus 6 rondas; Libertadores: octavos a final, 4;
/// Sudamericana: además los Playoffs, 5). En caliente, 0 peticiones.
///
/// Con `forceRefresh` (refresco manual), primero se fuerzan con P0 las
/// rondas con partidos sin terminar de ayer y de hoy, y después se piden
/// también las vencidas cerradas o históricas (nunca las vigentes).
class WatchKnockoutBracket {
  const WatchKnockoutBracket(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  Stream<BracketView> call(
    int competitionId,
    Season season, {
    required DateTime now,
    required CancelToken cancelToken,
    bool forceRefresh = false,
  }) async* {
    final definition = _catalog.where((d) => d.id == competitionId).firstOrNull;
    final rounds = definition?.bracketApiRounds(season) ?? const <int>[];
    if (definition == null || rounds.isEmpty) {
      yield BracketView.unavailable(
        competitionId: competitionId,
        season: season,
      );
      return;
    }

    var forced = 0;
    Failure? forcedFailure;
    if (forceRefresh) {
      try {
        (
          fetched: forced,
          failure: forcedFailure,
        ) = await RefreshRecentRounds(_matches, catalog: _catalog)(
          competitionId,
          season,
          now: now,
          cancelToken: cancelToken,
          rounds: rounds,
        );
      } on SyncCancelled {
        return;
      }
    }

    await for (final completion in CompleteRounds(_matches, catalog: _catalog)(
      competitionId,
      season,
      now: now,
      cancelToken: cancelToken,
      rounds: rounds,
      forceRefresh: forceRefresh,
      // Un 429 en el paso forzado ya agotó lo que el scheduler intenta: el
      // resto de la descarga fallaría igual, después de otra pausa (R3.1).
      // Lo mismo si falló la recuperación de un posible 429 oculto (R4).
      fetch: !(forcedFailure?.limitsQueries ?? false),
    )) {
      final p = completion.progress;
      yield BracketView(
        competitionId: competitionId,
        season: season,
        brackets: KnockoutBracketBuilder.forSeason(
          definition: definition,
          season: season,
          matches: completion.matches,
        ),
        progress: SyncProgress(
          done: p.done,
          total: p.total,
          isRunning: p.isRunning,
          failure: p.failure ?? (p.isRunning ? null : forcedFailure),
          fetched: p.fetched + forced,
        ),
      );
    }
  }
}
