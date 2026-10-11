import 'calendar_day.dart';

/// Hora oficial de `America/Argentina/Buenos_Aires`: UTC−3 fijo (Argentina
/// no aplica horario de verano desde 2009). Nunca se usa la zona del
/// dispositivo: la app puede abrirse desde otro país.
abstract final class ArgentinaTime {
  static const offset = Duration(hours: -3);

  /// Fecha y hora de pared en Argentina para un instante UTC. El resultado
  /// se marca como UTC solo para que Dart no le aplique la zona local.
  static DateTime wallClock(DateTime utc) => utc.toUtc().add(offset);

  /// Día argentino de un instante.
  static CalendarDay dayOf(DateTime utc) {
    final local = wallClock(utc);
    return CalendarDay(local.year, local.month, local.day);
  }

  /// Instante UTC en que empieza [day] en Argentina (03:00 UTC).
  static DateTime startOf(CalendarDay day) => day.asUtcDate.subtract(offset);

  /// `dd/MM/yyyy`.
  static String formatDay(CalendarDay day) =>
      '${_two(day.day)}/${_two(day.month)}/'
      '${day.year.toString().padLeft(4, '0')}';

  /// `HH:mm` en Argentina.
  static String formatTime(DateTime utc) {
    final local = wallClock(utc);
    return '${_two(local.hour)}:${_two(local.minute)}';
  }
}

/// Fecha (`dd/MM/yyyy`) y hora (`HH:mm`) en Argentina, o `null` si no hay
/// un instante UTC válido. (Usado por la pantalla de diagnóstico.)
({String date, String time})? formatArgentinaDateTime(DateTime? utc) {
  if (utc == null) return null;
  return (
    date: ArgentinaTime.formatDay(ArgentinaTime.dayOf(utc)),
    time: ArgentinaTime.formatTime(utc),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');
