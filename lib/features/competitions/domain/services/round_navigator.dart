import '../../../../core/time/calendar_day.dart';
import '../../../matches/domain/entities/match.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../entities/stage.dart';
import 'phase_resolver.dart';
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
      case final ContinentalCupRules rules:
        for (final s in rules.stagesOf(season)) {
          if (s.phase == phase) entries.add((s.apiRound, s.kind));
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
          label: StageLabeler.label(definition, season, phase, apiRound, kind),
          order: index,
        ),
    ];
  }

  /// Etapa de un partido suelto (p. ej. el próximo partido de la liga) y
  /// las etapas de su fase, o `null` si la fase no se puede determinar con
  /// ese partido solo o la temporada no es válida.
  static ({Stage stage, List<Stage> stages})? locate(
    CompetitionDefinition definition,
    Match match,
  ) {
    final season = Season.tryParse(match.season);
    if (season == null) return null;
    final assignment = PhaseResolver(definition).classifyRound(
      season: season,
      apiRound: match.apiRound,
      matches: [match],
    )[match.id]!;
    if (!assignment.isDetermined) return null;
    final stages = stagesFor(
      definition,
      season,
      assignment.phase,
      knownMaxRound: match.apiRound,
    );
    for (final stage in stages) {
      if (stage.apiRound == match.apiRound &&
          stage.kind == assignment.stageKind) {
        return (stage: stage, stages: stages);
      }
    }
    return null;
  }

  /// Etapa vigente el [day] según las ventanas del catálogo: la que lo
  /// contiene o, si cae entre dos, la última que empezó. `null` si la
  /// competición no tiene ventanas por etapa (solo las copas
  /// internacionales las tienen) o ninguna etapa empezó.
  static Stage? stageOnDay(
    CompetitionDefinition definition,
    Season season,
    CalendarDay day,
  ) {
    if (definition.rules case final ContinentalCupRules rules) {
      final stages = rules.stagesOf(season);
      final current =
          stages.where((s) => s.contains(day)).firstOrNull ??
          stages.where((s) => s.from?.isAfter(day) == false).lastOrNull;
      if (current == null) return null;
      return stagesFor(definition, season, current.phase)
          .where(
            (s) => s.apiRound == current.apiRound && s.kind == current.kind,
          )
          .firstOrNull;
    }
    return null;
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
