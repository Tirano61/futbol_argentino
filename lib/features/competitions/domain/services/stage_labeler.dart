import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/phase_assignment.dart';
import '../entities/season.dart';

/// Nombre visible de una etapa: «Fecha 12», «Octavos de final»…
abstract final class StageLabeler {
  /// Etapa [apiRound] de [phase] en [season].
  static String label(
    CompetitionDefinition definition,
    Season season,
    PhaseKey phase,
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
    final ContinentalCupRules r =>
      r.stageFor(season, phase, apiRound, kind)?.label ?? 'Ronda $apiRound',
  };

  /// Fase y etapa visibles de un partido: la fase solo en competiciones de
  /// más de una fase («Clausura»); sin fase determinada, «Ronda N».
  static ({String? phase, String stage}) describe(
    CompetitionDefinition definition,
    Season season,
    int apiRound,
    PhaseAssignment assignment,
  ) {
    final determined = assignment.isDetermined;
    return (
      phase: determined && definition.phases.length > 1
          ? assignment.phase.label
          : null,
      stage: determined
          ? label(
              definition,
              season,
              assignment.phase,
              apiRound,
              assignment.stageKind,
            )
          : 'Ronda $apiRound',
    );
  }
}
