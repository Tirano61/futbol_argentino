import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/core/time/calendar_month.dart';
import 'package:futbol_argentino/features/competitions/domain/calendar/month_calendar.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';

/// Partidos reales de Primera 2026 (rondas 0–16, grabadas el 11/10/2026).
List<Match> primera2026() => [
  for (var r = 0; r <= 16; r++)
    ...fixtureMatches('eventsround_4406_r${r}_s2026'),
];

void main() {
  const october = CalendarMonth(2026, 10);
  const today = CalendarDay(2026, 10, 11);

  test('agrupa por día argentino: Primera 2026, octubre', () {
    final calendar = MonthCalendar.of(october, primera2026());

    expect(calendar.matchCount, 60);
    expect(calendar.days.keys.map((d) => d.day), [
      2, 3, 4, 5, 9, 10, 11, 12, 14, 18, 25, //
    ]);
    // Fecha 12: 5 partidos el domingo 11 (2 en juego a las 18:00).
    final sunday = calendar.matchesOn(today);
    expect(sunday, hasLength(5));
    expect(sunday.map((m) => m.apiRound).toSet(), {12});
    expect(sunday.first.home.name, 'San Lorenzo');
    // La fecha 13, toda el 18/10; el partido pendiente de la 11, el 14/10.
    expect(calendar.matchesOn(const CalendarDay(2026, 10, 18)), hasLength(15));
    expect(
      calendar.matchesOn(const CalendarDay(2026, 10, 14)).single.apiRound,
      11,
    );
    expect(calendar.matchesOn(const CalendarDay(2026, 10, 1)), isEmpty);
  });

  test('cada partido cae en un solo mes, sin repetir', () {
    final matches = primera2026();
    final months = MonthCalendar.monthsWithMatches(matches);

    // Junio sin partidos (Mundial 2026).
    expect(months, [
      for (final m in [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]) CalendarMonth(2026, m),
    ]);
    final perMonth = [
      for (final m in months) MonthCalendar.of(m, matches).matchCount,
    ];
    expect(perMonth, [34, 71, 60, 60, 30, 27, 78, 45, 60, 30]);
    expect(perMonth.reduce((a, b) => a + b), 495);
    expect(MonthCalendar.undated(matches), isEmpty);
    expect(
      MonthCalendar.of(const CalendarMonth(2026, 6), matches).days,
      isEmpty,
    );
  });

  test('un partido repetido (dos rondas) cuenta una vez', () {
    // La ronda 12 trae la fecha 12 del Apertura (marzo) y la del Clausura.
    final round = fixtureMatches('eventsround_4406_r12_s2026');
    final calendar = MonthCalendar.of(october, [...round, ...round]);

    expect(calendar.matchCount, 15);
    expect(MonthCalendar.monthsWithMatches(round), [
      const CalendarMonth(2026, 3),
      october,
    ]);
  });

  test('día por defecto: hoy, el próximo con partidos o el último; en '
      'otro mes, el primero', () {
    final calendar = MonthCalendar.of(october, primera2026());

    expect(calendar.defaultDay(today), today);
    // Martes 13 sin partidos: el próximo es el 14.
    expect(
      calendar.defaultDay(const CalendarDay(2026, 10, 13)),
      const CalendarDay(2026, 10, 14),
    );
    // Después del último: el último.
    expect(
      calendar.defaultDay(const CalendarDay(2026, 10, 28)),
      const CalendarDay(2026, 10, 25),
    );
    expect(
      MonthCalendar.of(
        const CalendarMonth(2026, 3),
        primera2026(),
      ).defaultDay(today),
      const CalendarDay(2026, 3, 1),
    );
    expect(
      MonthCalendar.of(
        const CalendarMonth(2026, 11),
        primera2026(),
      ).defaultDay(today),
      const CalendarDay(2026, 11, 1),
    );
    expect(
      MonthCalendar.of(
        const CalendarMonth(2026, 6),
        primera2026(),
      ).defaultDay(today),
      isNull,
    );
  });

  group('mes inicial', () {
    test('el de hoy si cae dentro de la temporada', () {
      expect(
        MonthCalendar.initialMonth(
          primera2026(),
          today: today,
          season: const Season(2026),
        ),
        october,
      );
    });

    test('temporada terminada: su último mes con partidos', () {
      final copa2025 = fixtureMatches('eventsround_4500_r200_s2025');
      final finalDay = copa2025.single.kickoff.argentinaDay!;

      expect(
        MonthCalendar.initialMonth(
          copa2025,
          today: today,
          season: const Season(2025),
        ),
        CalendarMonth.of(finalDay),
      );
    });

    test('antes del primer partido: el primer mes con partidos', () {
      // Las fechas 15 y 16 del Clausura (las rondas traen también las del
      // Apertura, de abril y mayo).
      final november = [
        for (final r in [15, 16])
          for (final m in fixtureMatches('eventsround_4406_r${r}_s2026'))
            if (m.kickoff.argentinaDay!.isAfter(today)) m,
      ];
      expect(november, hasLength(30));

      expect(
        MonthCalendar.initialMonth(
          november,
          today: today,
          season: const Season(2026),
        ),
        const CalendarMonth(2026, 11),
      );
    });

    test('sin partidos guardados', () {
      CalendarMonth initial(int year) => MonthCalendar.initialMonth(
        const [],
        today: today,
        season: Season(year),
      );

      expect(initial(2026), october);
      expect(initial(2025), const CalendarMonth(2025, 12));
      expect(initial(2027), const CalendarMonth(2027, 1));
    });
  });

  test('meses navegables: del primero al último con partidos', () {
    final matches = primera2026();

    expect(MonthCalendar.navigableRange(matches, october), (
      first: const CalendarMonth(2026, 1),
      last: const CalendarMonth(2026, 11),
    ));
    // Un mes fuera de la temporada (de la URL) amplía el rango.
    expect(
      MonthCalendar.navigableRange(matches, const CalendarMonth(2027, 2)).last,
      const CalendarMonth(2027, 2),
    );
    expect(MonthCalendar.navigableRange(const [], october), (
      first: october,
      last: october,
    ));
  });

  test('partidos sin fecha: aparte, en ningún mes', () {
    // Variante de un evento real sin fecha (rotulada como tal).
    final event = fixtureEvents('eventsround_4406_r13_s2026').first;
    final undated = matchFromEvent(event, kickoff: const Kickoff.unknown());
    final matches = [...fixtureMatches('eventsround_4406_r12_s2026'), undated];

    expect(MonthCalendar.undated(matches), [undated]);
    expect(MonthCalendar.of(october, matches).matchCount, 15);
    expect(MonthCalendar.monthsWithMatches(matches), [
      const CalendarMonth(2026, 3),
      october,
    ]);
  });
}
