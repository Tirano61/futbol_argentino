import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/phase_assignment.dart';

/// Nombre visible de una etapa: «Fecha 12», «Octavos de final»…
abstract final class StageLabeler {
  static String label(
    CompetitionDefinition definition,
    int apiRound,
    StageKind kind,
  ) => switch (definition.rules) {
    final SplitSeasonLeagueRules r when kind == StageKind.knockout =>
      apiRound == r.knockoutOpeningRound
          ? r.knockoutOpeningLabel
          : apiRound == r.knockoutRound
          ? r.knockoutLabel
          : 'Ronda $apiRound',
    SplitSeasonLeagueRules() || SingleTableLeagueRules() => 'Fecha $apiRound',
    final KnockoutCupRules r =>
      r.roundFor(apiRound)?.label ?? 'Ronda $apiRound',
  };

  /// Fase y etapa visibles de un partido: la fase solo en competiciones de
  /// más de una fase («Clausura»); sin fase determinada, «Ronda N».
  static ({String? phase, String stage}) describe(
    CompetitionDefinition definition,
    int apiRound,
    PhaseAssignment assignment,
  ) {
    final determined = assignment.isDetermined;
    return (
      phase: determined && definition.phases.length > 1
          ? assignment.phase.label
          : null,
      stage: determined
          ? label(definition, apiRound, assignment.stageKind)
          : 'Ronda $apiRound',
    );
  }
}
