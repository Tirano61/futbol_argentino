part of 'competition_fixture_bloc.dart';

sealed class CompetitionFixtureEvent {
  const CompetitionFixtureEvent();
}

/// Abre el fixture. Los parámetros opcionales vienen de la URL; sin ellos
/// abre en la etapa actual.
final class FixtureOpened extends CompetitionFixtureEvent {
  const FixtureOpened({
    required this.competitionId,
    this.season,
    this.phase,
    this.apiRound,
    this.kind,
  });

  final int competitionId;
  final Season? season;
  final PhaseKey? phase;
  final int? apiRound;
  final StageKind? kind;
}

final class FixtureCompetitionChanged extends CompetitionFixtureEvent {
  const FixtureCompetitionChanged(this.competitionId);

  final int competitionId;
}

final class FixtureSeasonChanged extends CompetitionFixtureEvent {
  const FixtureSeasonChanged(this.season);

  final Season season;
}

final class FixturePhaseChanged extends CompetitionFixtureEvent {
  const FixturePhaseChanged(this.phase);

  final PhaseKey phase;
}

final class FixtureStageChanged extends CompetitionFixtureEvent {
  const FixtureStageChanged(this.stage);

  final Stage stage;
}

final class FixtureNextStageRequested extends CompetitionFixtureEvent {
  const FixtureNextStageRequested();
}

final class FixturePreviousStageRequested extends CompetitionFixtureEvent {
  const FixturePreviousStageRequested();
}

/// Refresco manual (pull-to-refresh o botón).
final class FixtureRefreshRequested extends CompetitionFixtureEvent {
  const FixtureRefreshRequested();
}

/// Auto-refresco con partidos en vivo (D11): vuelve a cargar la etapa sin
/// forzar (la ronda se pide solo si venció su vigencia `live`).
final class FixtureLiveTick extends CompetitionFixtureEvent {
  const FixtureLiveTick();
}
