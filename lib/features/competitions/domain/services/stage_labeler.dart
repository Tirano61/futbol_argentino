import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';

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
}
