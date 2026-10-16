import '../../../../core/error/failure.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../matches/domain/entities/match.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';
import '../entities/stage.dart';
import '../repositories/competition_repository.dart';
import '../services/round_navigator.dart';

/// Etapa con la que abre el fixture: la del próximo partido o, si no hay,
/// la del último jugado. Si no se puede determinar (sin red y sin caché,
/// otra temporada, fase dudosa), en las copas internacionales la etapa
/// vigente [today] según el catálogo (no la Fase 1 de febrero); si no, la
/// primera etapa de la primera fase.
class ResolveCurrentStage {
  const ResolveCurrentStage(this._competitions);

  final CompetitionRepository _competitions;

  Future<Stage?> call(
    CompetitionDefinition definition,
    Season season, {
    CalendarDay? today,
  }) async {
    Match? pointer;
    try {
      final result = await _competitions.getSchedulePointers(definition.id);
      pointer = result.data.next ?? result.data.last;
    } on Failure {
      pointer = null;
    }

    if (pointer != null && pointer.season == season.apiValue) {
      final located = RoundNavigator.locate(definition, pointer);
      if (located != null) return located.stage;
    }

    if (today != null) {
      final current = RoundNavigator.stageOnDay(definition, season, today);
      if (current != null) return current;
    }

    for (final phase in definition.phases) {
      final stages = RoundNavigator.stagesFor(definition, season, phase);
      if (stages.isNotEmpty) return stages.first;
    }
    return null;
  }
}
