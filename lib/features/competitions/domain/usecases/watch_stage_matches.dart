import '../../../../core/result/data_result.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/phase_assignment.dart';
import '../entities/stage.dart';
import '../services/phase_resolver.dart';

/// Partidos de una etapa, ya filtrados por fase y ordenados.
final class StageMatches {
  const StageMatches({
    required this.stage,
    required this.matches,
    required this.assignments,
    required this.undeterminedInRound,
  });

  final Stage stage;

  /// Ordenados por día argentino y hora.
  final List<Match> matches;

  /// Fase asignada a cada partido de [matches].
  final Map<int, PhaseAssignment> assignments;

  /// Partidos de la misma ronda sin fase determinada (para ofrecer la
  /// opción «Sin fase determinada»).
  final int undeterminedInRound;
}

/// Carga la ronda de la API de una etapa y se queda con los partidos que
/// pertenecen a esa fase y tipo de etapa.
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

    return _matches
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
  }

  /// Precarga en segundo plano (prioridad baja) la ronda de [stage], por
  /// ejemplo la etapa siguiente a la que se está mirando.
  Future<void> prefetch(CompetitionDefinition definition, Stage stage) =>
      _matches.prefetchRound(_queryFor(definition, stage));

  static RoundQuery _queryFor(CompetitionDefinition definition, Stage stage) =>
      RoundQuery(
        competitionId: definition.id,
        season: stage.season.apiValue,
        apiRound: stage.apiRound,
        expectedMinimum: definition.expectedMinimumMatches(stage.apiRound),
      );
}
