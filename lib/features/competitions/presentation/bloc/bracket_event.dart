part of 'bracket_bloc.dart';

sealed class BracketEvent {
  const BracketEvent();
}

/// Eventos que (re)cargan el cuadro; una carga nueva reemplaza a la
/// anterior.
sealed class BracketLoadEvent extends BracketEvent {
  const BracketLoadEvent();
}

/// Cuadro de una competición y temporada (reemplaza a la carga en curso:
/// mandarlo solo si cambian).
final class BracketStarted extends BracketLoadEvent {
  const BracketStarted({required this.competitionId, required this.season});

  final int competitionId;
  final Season season;
}

/// Refresco manual: fuerza las rondas con partidos de ayer y hoy (P0).
final class BracketRefreshRequested extends BracketLoadEvent {
  const BracketRefreshRequested();
}

/// El cuadro dejó de verse (otra vista u otra sección): se detiene la
/// descarga.
final class BracketPaused extends BracketEvent {
  const BracketPaused();
}

/// El cuadro volvió a verse: sigue la descarga si había quedado a medias
/// (si no, no hace nada).
final class BracketResumed extends BracketEvent {
  const BracketResumed();
}

/// Sigue una descarga pausada.
final class _BracketContinued extends BracketLoadEvent {
  const _BracketContinued();
}
