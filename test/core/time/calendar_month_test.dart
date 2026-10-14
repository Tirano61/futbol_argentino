import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/core/time/calendar_month.dart';

void main() {
  test('interpreta yyyy-MM y rechaza lo inválido', () {
    expect(CalendarMonth.tryParse('2026-10'), const CalendarMonth(2026, 10));
    expect(CalendarMonth.tryParse(' 2026-01 '), const CalendarMonth(2026, 1));
    for (final bad in [
      null,
      '',
      '2026-13',
      '2026-00',
      '2026-1',
      '26-10',
      'x',
    ]) {
      expect(CalendarMonth.tryParse(bad), isNull, reason: '$bad');
    }
    expect(const CalendarMonth(2026, 3).toString(), '2026-03');
  });

  test('largo del mes, bisiestos y cambio de año', () {
    expect(const CalendarMonth(2026, 2).length, 28);
    expect(const CalendarMonth(2028, 2).length, 29);
    expect(const CalendarMonth(2026, 10).length, 31);
    expect(
      const CalendarMonth(2026, 12).addMonths(1),
      const CalendarMonth(2027, 1),
    );
    expect(
      const CalendarMonth(2026, 1).addMonths(-1),
      const CalendarMonth(2025, 12),
    );
    expect(
      CalendarMonth.of(const CalendarDay(2026, 10, 11)),
      const CalendarMonth(2026, 10),
    );
    expect(
      const CalendarMonth(2025, 12).isBefore(const CalendarMonth(2026, 1)),
      isTrue,
    );
  });

  test('semanas de lunes a domingo', () {
    // Octubre de 2026 empieza un jueves y termina un sábado.
    final weeks = const CalendarMonth(2026, 10).weeks;

    expect(weeks, hasLength(5));
    expect(weeks.every((w) => w.length == 7), isTrue);
    expect(weeks.first.take(3), everyElement(isNull));
    expect(weeks.first[3], const CalendarDay(2026, 10, 1));
    expect(weeks.first[3]!.weekday, DateTime.thursday);
    expect(weeks.last[5], const CalendarDay(2026, 10, 31));
    expect(weeks.last[6], isNull);
    expect(weeks.expand((w) => w).nonNulls, hasLength(31));

    // Febrero de 2027: de lunes a domingo justo, 4 semanas.
    final february = const CalendarMonth(2027, 2).weeks;
    expect(february, hasLength(4));
    expect(february.expand((w) => w).nonNulls, hasLength(28));
  });
}
