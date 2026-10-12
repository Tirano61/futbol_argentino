part of 'team_detail_bloc.dart';

sealed class TeamDetailEvent {
  const TeamDetailEvent();
}

final class TeamDetailStarted extends TeamDetailEvent {
  const TeamDetailStarted(this.teamId);

  final int teamId;
}

/// Refresco manual: fuerza las rondas de los partidos cercanos (P0).
final class TeamDetailRefreshRequested extends TeamDetailEvent {
  const TeamDetailRefreshRequested();
}
