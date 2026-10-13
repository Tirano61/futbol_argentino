import 'dart:convert';

import '../time/calendar_day.dart';
import 'calendar_event.dart';

/// Archivo iCalendar (RFC 5545) con un solo evento.
///
/// Las horas van en UTC (`…Z`): cada calendario las muestra en su zona. Los
/// eventos de día completo usan `VALUE=DATE` con fin exclusivo (el día
/// siguiente). Líneas terminadas en CRLF y plegadas a 75 bytes UTF-8.
abstract final class IcsBuilder {
  static const mimeType = 'text/calendar';

  static String build(CalendarEvent event, {required DateTime stampUtc}) {
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//futbol_argentino//Futbol Argentino//ES',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${escapeText(event.uid)}',
      'DTSTAMP:${_utc(stampUtc)}',
      ...switch (event.time) {
        TimedEvent(:final startUtc, :final endUtc) => [
          'DTSTART:${_utc(startUtc)}',
          'DTEND:${_utc(endUtc)}',
        ],
        AllDayEvent(:final day) => [
          'DTSTART;VALUE=DATE:${_date(day)}',
          'DTEND;VALUE=DATE:${_date(day.addDays(1))}',
        ],
      },
      'SUMMARY:${escapeText(event.title)}',
      if (event.description case final description?)
        'DESCRIPTION:${escapeText(description)}',
      if (event.location case final location?)
        'LOCATION:${escapeText(location)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return '${lines.map(fold).join('\r\n')}\r\n';
  }

  /// Escapa un valor TEXT (RFC 5545 §3.3.11).
  static String escapeText(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');

  /// Pliega una línea en tramos de 75 bytes como mucho (RFC 5545 §3.1): las
  /// siguientes empiezan con un espacio. Nunca corta un carácter UTF-8.
  static String fold(String line) {
    const limit = 75;
    final parts = <String>[];
    final current = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (bytes + size > limit) {
        parts.add(current.toString());
        current
          ..clear()
          ..write(' ');
        bytes = 1;
      }
      current.write(char);
      bytes += size;
    }
    parts.add(current.toString());
    return parts.join('\r\n');
  }

  /// `yyyyMMddTHHmmssZ`.
  static String _utc(DateTime value) {
    final d = value.toUtc();
    return '${_date(CalendarDay(d.year, d.month, d.day))}'
        'T${_two(d.hour)}${_two(d.minute)}${_two(d.second)}Z';
  }

  /// `yyyyMMdd`.
  static String _date(CalendarDay day) =>
      '${day.year.toString().padLeft(4, '0')}${_two(day.month)}'
      '${_two(day.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
