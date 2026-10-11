import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/argentina_time.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';

void main() {
  group('ArgentinaTime', () {
    test('convierte UTC a UTC−3 sin usar la zona del dispositivo', () {
      final utc = DateTime.utc(2026, 3, 21, 20, 45);

      expect(ArgentinaTime.formatTime(utc), '17:45');
      expect(ArgentinaTime.dayOf(utc), const CalendarDay(2026, 3, 21));
    });

    test('antes de las 03:00 UTC el día argentino es el anterior', () {
      // River Plate – Estudiantes de Río Cuarto: 2026-10-11T00:30:00 UTC.
      final utc = DateTime.utc(2026, 10, 11, 0, 30);

      expect(ArgentinaTime.dayOf(utc), const CalendarDay(2026, 10, 10));
      expect(ArgentinaTime.formatTime(utc), '21:30');
      expect(ArgentinaTime.formatDay(ArgentinaTime.dayOf(utc)), '10/10/2026');
    });

    test('cruce de año', () {
      final utc = DateTime.utc(2027, 1, 1, 1);

      expect(ArgentinaTime.dayOf(utc), const CalendarDay(2026, 12, 31));
    });

    test('startOf: el día argentino empieza a las 03:00 UTC', () {
      expect(
        ArgentinaTime.startOf(const CalendarDay(2026, 10, 11)),
        DateTime.utc(2026, 10, 11, 3),
      );
    });

    test('un DateTime local se convierte primero a UTC', () {
      final utc = DateTime.utc(2026, 10, 11, 23);

      expect(ArgentinaTime.formatTime(utc.toLocal()), '20:00');
    });
  });

  group('CalendarDay', () {
    test('tryParse acepta yyyy-MM-dd válidos y rechaza el resto', () {
      expect(
        CalendarDay.tryParse('2026-03-21'),
        const CalendarDay(2026, 3, 21),
      );
      expect(CalendarDay.tryParse('2026-02-30'), isNull);
      expect(CalendarDay.tryParse('21/03/2026'), isNull);
      expect(CalendarDay.tryParse(''), isNull);
      expect(CalendarDay.tryParse(null), isNull);
    });

    test('orden, diferencia y suma de días', () {
      const a = CalendarDay(2026, 5, 24);
      const b = CalendarDay(2026, 7, 23);

      expect(a.isBefore(b), isTrue);
      expect(b.differenceInDays(a), 60);
      expect(a.addDays(8), const CalendarDay(2026, 6, 1));
    });
  });
}
