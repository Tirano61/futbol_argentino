part of 'standings_bloc.dart';

sealed class StandingsEvent {
  const StandingsEvent();
}

/// Eventos que (re)cargan las tablas; una carga nueva reemplaza a la
/// anterior.
sealed class StandingsLoadEvent extends StandingsEvent {
  const StandingsLoadEvent();
}

/// Tablas de una competición y temporada (reemplaza a la carga en curso:
/// mandarlo solo si cambian).
final class StandingsStarted extends StandingsLoadEvent {
  const StandingsStarted({required this.competitionId, required this.season});

  final int competitionId;
  final Season season;
}

/// Refresco manual: fuerza las fechas con partidos de ayer y hoy (P0).
final class StandingsRefreshRequested extends StandingsLoadEvent {
  const StandingsRefreshRequested();
}

/// Las tablas dejaron de verse (otra vista u otra sección): se detiene la
/// descarga.
final class StandingsPaused extends StandingsEvent {
  const StandingsPaused();
}

/// Las tablas volvieron a verse: sigue la descarga si había quedado a
/// medias (si no, no hace nada).
final class StandingsResumed extends StandingsEvent {
  const StandingsResumed();
}

/// Sigue una descarga pausada.
final class _StandingsContinued extends StandingsLoadEvent {
  const _StandingsContinued();
}
