import 'package:equatable/equatable.dart';

import '../../../../core/result/data_result.dart';
import '../../../matches/domain/entities/knockout_tie.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../matches/domain/services/tie_outcome.dart';
import '../../../matches/domain/services/tie_pairing.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/phase_assignment.dart';
import '../entities/stage.dart';
import '../services/phase_resolver.dart';

/// Serie de ida y vuelta de una etapa y quién avanzó, si se sabe.
final class StageSeries extends Equatable {
  const StageSeries({required this.tie, this.outcome});

  final KnockoutTie tie;
  final TieOutcome? outcome;

  @override
  List<Object?> get props => [tie, outcome?.winner, outcome?.source];
}

/// Partidos de una etapa, ya filtrados por fase y ordenados.
final class StageMatches {
  const StageMatches({
    required this.stage,
    required this.matches,
    required this.assignments,
    required this.undeterminedInRound,
    this.series = const [],
    this.unpaired = const [],
  });

  final Stage stage;

  /// Ordenados por día argentino y hora.
  final List<Match> matches;

  /// Fase asignada a cada partido de [matches].
  final Map<int, PhaseAssignment> assignments;

  /// Partidos de la misma ronda sin fase determinada (para ofrecer la
  /// opción «Sin fase determinada»).
  final int undeterminedInRound;

  /// Etapas de ida y vuelta de las copas internacionales: [matches]
  /// agrupados en series, en el orden de la ida. Vacío en el resto.
  final List<StageSeries> series;

  /// Partidos de una etapa de ida y vuelta que no se pudieron emparejar.
  final List<Match> unpaired;

  StageMatches withSeries(List<StageSeries> series, List<Match> unpaired) =>
      StageMatches(
        stage: stage,
        matches: matches,
        assignments: assignments,
        undeterminedInRound: undeterminedInRound,
        series: series,
        unpaired: unpaired,
      );
}

/// Carga la ronda de la API de una etapa y se queda con los partidos que
/// pertenecen a esa fase y tipo de etapa. En una etapa de ida y vuelta (copas
/// internacionales) los agrupa en series; quién avanzó sale de lo guardado
/// de la temporada (0 peticiones extra).
class WatchStageMatches {
  const WatchStageMatches(this._matches);

  final MatchRepository _matches;

  Stream<DataResult<StageMatches>> call(
    CompetitionDefinition definition,
    Stage stage, {
    bool forceRefresh = false,
  }) {
    final query = _queryFor(definition, stage);
    final resolver = PhaseResolver(definition);

    final stageMatches = _matches
        .watchRound(query, forceRefresh: forceRefresh)
        .map(
          (result) => result.map((round) {
            final assigned = resolver.classifyRound(
              season: stage.season,
              apiRound: stage.apiRound,
              matches: round,
            );
            bool belongs(Match m) {
              final a = assigned[m.id]!;
              return stage.phase == PhaseKey.undetermined
                  ? !a.isDetermined
                  : a.phase == stage.phase && a.stageKind == stage.kind;
            }

            final selected = MatchGrouping.sorted(round.where(belongs));
            return StageMatches(
              stage: stage,
              matches: selected,
              assignments: {for (final m in selected) m.id: assigned[m.id]!},
              undeterminedInRound: assigned.values
                  .where((a) => !a.isDetermined)
                  .length,
            );
          }),
        );
    final legs = _legs(definition, stage);
    // Sin series, el stream queda igual (sin la lectura de lo guardado).
    if (legs < 2) return stageMatches;
    return _withSeries(definition, stage, legs, stageMatches);
  }

  /// Agrupa cada emisión en series. Lo guardado de la temporada (evidencia
  /// de quién avanzó) se lee una vez antes: transformar cada emisión con
  /// una espera retrasa el cierre del stream de la ronda.
  Stream<DataResult<StageMatches>> _withSeries(
    CompetitionDefinition definition,
    Stage stage,
    int legs,
    Stream<DataResult<StageMatches>> stageMatches,
  ) async* {
    final stored = await _matches.storedSeason(
      definition.id,
      stage.season.apiValue,
    );
    yield* stageMatches.map((result) {
      final (:ties, :unpaired) = TiePairing.pair(
        result.data.matches,
        legs: legs,
      );
      final series = [
        for (final tie in ties)
          StageSeries(
            tie: tie,
            outcome: TieOutcome.ofTie(tie, laterMatches: stored),
          ),
      ];
      return result.map((m) => m.withSeries(series, unpaired));
    });
  }

  /// Piernas de la etapa: 2 en las series de ida y vuelta de las copas
  /// internacionales; 1 en el resto.
  static int _legs(
    CompetitionDefinition definition,
    Stage stage,
  ) => switch (definition.rules) {
    final ContinentalCupRules r =>
      r.stageFor(stage.season, stage.phase, stage.apiRound, stage.kind)?.legs ??
          1,
    _ => 1,
  };

  /// Precarga en segundo plano (prioridad baja) la ronda de [stage], por
  /// ejemplo la etapa siguiente a la que se está mirando.
  Future<void> prefetch(CompetitionDefinition definition, Stage stage) =>
      _matches.prefetchRound(_queryFor(definition, stage));

  static RoundQuery _queryFor(CompetitionDefinition definition, Stage stage) =>
      RoundQuery(
        competitionId: definition.id,
        season: stage.season.apiValue,
        apiRound: stage.apiRound,
        expectedMinimum: definition.expectedMinimumMatches(
          stage.season,
          stage.apiRound,
        ),
      );
}
