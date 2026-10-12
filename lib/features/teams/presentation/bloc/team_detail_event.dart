part of 'team_detail_bloc.dart';

sealed class TeamDetailEvent {
  const TeamDetailEvent();
}

/// Eventos que (re)cargan la ficha; una carga nueva reemplaza a la anterior.
sealed class TeamDetailLoadEvent extends TeamDetailEvent {
  const TeamDetailLoadEvent();
}

final class TeamDetailStarted extends TeamDetailLoadEvent {
  const TeamDetailStarted(this.teamId);

  final int teamId;
}

/// Refresco manual: fuerza las rondas de los partidos cercanos (P0).
final class TeamDetailRefreshRequested extends TeamDetailLoadEvent {
  const TeamDetailRefreshRequested();
}

/// La ficha dejó de verse sin cerrarse (otra sección del menú): se detiene
/// la descarga.
final class TeamDetailPaused extends TeamDetailEvent {
  const TeamDetailPaused();
}

/// La ficha volvió a verse: sigue la descarga si había quedado a medias.
final class TeamDetailResumed extends TeamDetailLoadEvent {
  const TeamDetailResumed();
}
