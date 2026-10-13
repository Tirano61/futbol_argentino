import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/calendar/calendar_event.dart';
import 'package:futbol_argentino/core/platform/external_actions.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';

/// Eventos armados en el test (no son partidos reales): prueban cómo se
/// pasan a Google Calendar (`add_2_calendar`), validado en la tablet.
void main() {
  test('con hora: instantes UTC en la zona de Argentina', () {
    final event = PlatformExternalActions.androidEvent(
      CalendarEvent(
        uid: 'x',
        title: 'Local vs. Visitante',
        time: TimedEvent(
          startUtc: DateTime.utc(2026, 10, 14, 22),
          endUtc: DateTime.utc(2026, 10, 15),
        ),
      ),
    );

    expect(event.allDay, isFalse);
    expect(event.startDate, DateTime.utc(2026, 10, 14, 22));
    expect(event.endDate, DateTime.utc(2026, 10, 15));
    expect(event.timeZone, 'America/Argentina/Buenos_Aires');
  });

  test('día completo: de medianoche a medianoche de Argentina', () {
    final event = PlatformExternalActions.androidEvent(
      const CalendarEvent(
        uid: 'x',
        title: 'Local vs. Visitante',
        time: AllDayEvent(CalendarDay(2026, 10, 17)),
      ),
    );

    expect(event.allDay, isTrue);
    // 00:00 en Argentina = 03:00 UTC; fin exclusivo al día siguiente.
    expect(event.startDate, DateTime.utc(2026, 10, 17, 3));
    expect(event.endDate, DateTime.utc(2026, 10, 18, 3));
    expect(event.timeZone, 'America/Argentina/Buenos_Aires');
  });
}
