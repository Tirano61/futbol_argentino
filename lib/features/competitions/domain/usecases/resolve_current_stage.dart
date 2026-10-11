import '../../../../core/error/failure.dart';
import '../../../matches/domain/entities/match.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';
import '../entities/stage.dart';
import '../repositories/competition_repository.dart';
import '../services/phase_resolver.dart';
import '../services/round_navigator.dart';

/// Etapa con la que abre el fixture: la del próximo partido o, si no hay,
/// la del último jugado. Si no se puede determinar (sin red y sin caché,
/// otra temporada, fase dudosa), abre la primera etapa de la primera fase.
class ResolveCurrentStage {
  const ResolveCurrentStage(this._competitions);

  final CompetitionRepository _competitions;

  Future<Stage?> call(CompetitionDefinition definition, Season season) async {
    Match? pointer;
    try {
      final result = await _competitions.getSchedulePointers(definition.id);
      pointer = result.data.next ?? result.data.last;
    } on Failure {
      pointer = null;
    }

    if (pointer != null && pointer.season == season.apiValue) {
      final assignment = PhaseResolver(definition).classifyRound(
        season: season,
        apiRound: pointer.apiRound,
        matches: [pointer],
      )[pointer.id]!;
      if (assignment.isDetermined) {
        final stages = RoundNavigator.stagesFor(
          definition,
          season,
          assignment.phase,
          knownMaxRound: pointer.apiRound,
        );
        for (final stage in stages) {
          if (stage.apiRound == pointer.apiRound &&
              stage.kind == assignment.stageKind) {
            return stage;
          }
        }
      }
    }

    for (final phase in definition.phases) {
      final stages = RoundNavigator.stagesFor(definition, season, phase);
      if (stages.isNotEmpty) return stages.first;
    }
    return null;
  }
}
