import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/calendar/calendar_event.dart';
import 'package:futbol_argentino/core/calendar/ics_builder.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';

/// Eventos armados en el test: solo prueban el formato RFC 5545, no son
/// partidos reales.
void main() {
  final stamp = DateTime.utc(2026, 10, 13, 15, 4, 5);

  CalendarEvent event({
    CalendarEventTime? time,
    String title = 'Local vs. Visitante',
    String? description,
    String? location,
  }) => CalendarEvent(
    uid: 'partido-1@futbol-argentino',
    title: title,
    time:
        time ??
        TimedEvent(
          startUtc: DateTime.utc(2026, 10, 14, 22),
          endUtc: DateTime.utc(2026, 10, 15),
        ),
    description: description,
    location: location,
  );

  List<String> lines(String ics) {
    expect(ics, endsWith('\r\n'));
    // Ningún salto de línea suelto: todos son CRLF.
    expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
    return ics.substring(0, ics.length - 2).split('\r\n');
  }

  test('evento con hora: en UTC, con envoltorio VCALENDAR', () {
    final ics = IcsBuilder.build(event(location: 'Estadio'), stampUtc: stamp);

    expect(lines(ics), [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//futbol_argentino//Futbol Argentino//ES',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:partido-1@futbol-argentino',
      'DTSTAMP:20261013T150405Z',
      'DTSTART:20261014T220000Z',
      'DTEND:20261015T000000Z',
      'SUMMARY:Local vs. Visitante',
      'LOCATION:Estadio',
      'END:VEVENT',
      'END:VCALENDAR',
    ]);
  });

  test('día completo: VALUE=DATE con fin exclusivo (día siguiente)', () {
    final ics = IcsBuilder.build(
      event(time: const AllDayEvent(CalendarDay(2026, 12, 31))),
      stampUtc: stamp,
    );

    expect(
      lines(ics),
      containsAllInOrder([
        'DTSTART;VALUE=DATE:20261231',
        'DTEND;VALUE=DATE:20270101',
      ]),
    );
    expect(ics, isNot(contains('DTSTART:')));
  });

  test('escapa barra invertida, punto y coma, coma y saltos de línea', () {
    expect(
      IcsBuilder.escapeText(
        r'a\b; c, d'
        '\nline\r\nend',
      ),
      r'a\\b\; c\, d\nline\nend',
    );
    final ics = IcsBuilder.build(
      event(description: 'Primera; Fecha 1\nDatos, TheSportsDB'),
      stampUtc: stamp,
    );
    expect(
      lines(ics),
      contains(r'DESCRIPTION:Primera\; Fecha 1\nDatos\, TheSportsDB'),
    );
  });

  test('pliega a 75 bytes sin cortar caracteres UTF-8', () {
    final title =
        'Gimnasia y Esgrima de Mendoza vs. Central Córdoba de Santiago del '
        'Estero · Estadio Víctor Antonio Legrotaglie · Ñandú';
    final ics = IcsBuilder.build(event(title: title), stampUtc: stamp);
    final all = lines(ics);

    for (final line in all) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
    }
    // Desplegar (CRLF + espacio) devuelve la línea original.
    final unfolded = ics.replaceAll('\r\n ', '');
    expect(unfolded, contains('SUMMARY:$title\r\n'));
    final start = all.indexWhere((l) => l.startsWith('SUMMARY:'));
    expect(all[start + 1], startsWith(' '));
  });

  test('una línea corta no se pliega', () {
    expect(IcsBuilder.fold('SUMMARY:corto'), 'SUMMARY:corto');
  });
}
