import '../time/calendar_day.dart';

/// Cuándo ocurre un [CalendarEvent].
sealed class CalendarEventTime {
  const CalendarEventTime();
}

/// Con hora: instantes UTC de inicio y fin.
final class TimedEvent extends CalendarEventTime {
  const TimedEvent({required this.startUtc, required this.endUtc});

  final DateTime startUtc;
  final DateTime endUtc;
}

/// De día completo (p. ej. un partido con «Horario por confirmar»).
final class AllDayEvent extends CalendarEventTime {
  const AllDayEvent(this.day);

  final CalendarDay day;
}

/// Evento para agregar a un calendario (`.ics` en Web, el calendario del
/// sistema en Android).
final class CalendarEvent {
  const CalendarEvent({
    required this.uid,
    required this.title,
    required this.time,
    this.description,
    this.location,
  });

  /// Identificador estable: volver a importar el mismo partido actualiza el
  /// evento en lugar de duplicarlo (en los calendarios que lo respetan).
  final String uid;
  final String title;
  final CalendarEventTime time;
  final String? description;
  final String? location;
}
