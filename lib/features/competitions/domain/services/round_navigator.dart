import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../entities/stage.dart';
import 'stage_labeler.dart';

/// Lista ordenada de etapas de una fase y navegación anterior/siguiente.
abstract final class RoundNavigator {
  /// Etapas de [phase] en [season].
  ///
  /// [knownMaxRound]: última fecha conocida cuando el catálogo no la tiene
  /// (Primera Nacional en temporadas sin verificar). Sin ese dato la lista
  /// queda vacía.
  static List<Stage> stagesFor(
    CompetitionDefinition definition,
    Season season,
    PhaseKey phase, {
    int? knownMaxRound,
  }) {
    final entries = <(int, StageKind)>[];
    switch (definition.rules) {
      case final SplitSeasonLeagueRules rules:
        if (!rules.phases.contains(phase)) break;
        for (var r = 1; r <= rules.regularRounds; r++) {
          entries.add((r, StageKind.regular));
        }
        // Solo se ofrecen eliminatorias con ventana verificada.
        final window = rules.windowsBySeason[season.year]
            ?.where((w) => w.phase == phase)
            .firstOrNull;
        if (window?.knockoutFrom != null) {
          entries
            ..add((rules.knockoutOpeningRound, StageKind.knockout))
            ..add((rules.knockoutRound, StageKind.knockout));
        }
      case final SingleTableLeagueRules rules:
        if (phase != PhaseKey.regular) break;
        final last = rules.regularRoundsBySeason[season.year] ?? knownMaxRound;
        for (var r = 1; r <= (last ?? 0); r++) {
          entries.add((r, StageKind.regular));
        }
      case final KnockoutCupRules rules:
        if (phase != PhaseKey.unica) break;
        for (final round in rules.rounds) {
          entries.add((round.code, StageKind.knockout));
        }
    }

    return [
      for (final (index, (apiRound, kind)) in entries.indexed)
        Stage(
          competitionId: definition.id,
          season: season,
          phase: phase,
          apiRound: apiRound,
          kind: kind,
          label: StageLabeler.label(definition, apiRound, kind),
          order: index,
        ),
    ];
  }

  static Stage? next(List<Stage> stages, Stage current) {
    final index = stages.indexOf(current);
    return index >= 0 && index + 1 < stages.length ? stages[index + 1] : null;
  }

  static Stage? previous(List<Stage> stages, Stage current) {
    final index = stages.indexOf(current);
    return index > 0 ? stages[index - 1] : null;
  }
}
