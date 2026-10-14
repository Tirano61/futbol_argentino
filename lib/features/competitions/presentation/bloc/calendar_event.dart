part of 'calendar_bloc.dart';

sealed class CalendarEvent {
  const CalendarEvent();
}

/// Eventos que (re)cargan el calendario; una carga nueva reemplaza a la
/// anterior.
sealed class CalendarLoadEvent extends CalendarEvent {
  const CalendarLoadEvent();
}

/// Calendario de una competición y temporada, con lo guardado (reemplaza a
/// la carga en curso: mandarlo solo si cambian).
final class CalendarStarted extends CalendarLoadEvent {
  const CalendarStarted({required this.competitionId, required this.season});

  final int competitionId;
  final Season season;
}

/// «Completar»: descarga (P2) las fechas que faltan o vencieron.
final class CalendarCompletionRequested extends CalendarLoadEvent {
  const CalendarCompletionRequested();
}

/// Refresco manual: fuerza las fechas con partidos de ayer y hoy (P0) y
/// completa la temporada.
final class CalendarRefreshRequested extends CalendarLoadEvent {
  const CalendarRefreshRequested();
}

/// El calendario dejó de verse (otra vista u otra sección): se detiene la
/// descarga.
final class CalendarPaused extends CalendarEvent {
  const CalendarPaused();
}

/// El calendario volvió a verse: sigue la descarga si había quedado a
/// medias; si no, vuelve a leer lo guardado (sin red).
final class CalendarResumed extends CalendarEvent {
  const CalendarResumed();
}

/// Sigue una descarga pausada.
final class _CalendarContinued extends CalendarLoadEvent {
  const _CalendarContinued();
}

/// Vuelve a leer lo guardado.
final class _CalendarReloaded extends CalendarLoadEvent {
  const _CalendarReloaded();
}
