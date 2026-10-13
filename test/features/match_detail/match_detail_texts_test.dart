import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/calendar/calendar_event.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/match_detail/domain/entities/match_detail.dart';
import 'package:futbol_argentino/features/match_detail/domain/usecases/get_match_detail.dart';
import 'package:futbol_argentino/features/match_detail/presentation/formatters/match_detail_texts.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixture_matches.dart';

/// Partidos reales: Primera 2026 fecha 11 y Nacional 2026 fechas 33 y 34,
/// grabadas el 11/10/2026.
void main() {
  final getDetail = GetMatchDetail(
    FakeMatchRepository({
      11: fixtureMatches('eventsround_4406_r11_s2026'),
      33: fixtureMatches('eventsround_4616_r33_s2026'),
      34: fixtureMatches('eventsround_4616_r34_s2026'),
    }),
  );
  Future<MatchDetail> detail(int id) async => (await getDetail(id)).data;

  final now = DateTime.utc(2026, 10, 11, 20, 35);

  group('compartir', () {
    test('terminado: resultado, etapa y día, sin hora', () async {
      // Boca Juniors 3 – 0 Unión (03/10 00:30 UTC = 02/10 21:30).
      final text = MatchDetailTexts.share(
        await detail(2398104),
        now: now,
        fetchedAt: now,
      );

      expect(
        text,
        'Boca Juniors 3 – 0 Unión\n'
        'Primera División · Clausura · Fecha 11\n'
        'Final · Viernes 02/10/2026\n'
        'Estadio Alberto José Armando\n'
        'Horarios de Argentina · Datos de TheSportsDB',
      );
    });

    test('en juego: resultado parcial y hora de los datos', () async {
      final text = MatchDetailTexts.share(
        await detail(2405137), // Almirante Brown – San Miguel, 2H
        now: now,
        fetchedAt: DateTime.utc(2026, 10, 11, 20, 10),
      );

      expect(text.split('\n').take(3), [
        'Almirante Brown 1 – 0 San Miguel',
        'Primera Nacional · Fecha 33',
        'En juego · actualizado a las 17:10',
      ]);
    });

    test('programado: día y hora de Argentina', () async {
      // Sarmiento – River: 14/10 22:00 UTC = 19:00 en Argentina.
      final text = MatchDetailTexts.share(
        await detail(2398113),
        now: now,
        fetchedAt: now,
      );

      expect(
        text,
        'Sarmiento vs. River Plate\n'
        'Primera División · Clausura · Fecha 11\n'
        'Miércoles 14/10/2026 · 19:00\n'
        'Estadio Eva Perón de Junín\n'
        'Horarios de Argentina · Datos de TheSportsDB',
      );
    });

    test('00:00 UTC sin corroborar: «Horario por confirmar»', () async {
      final d = await detail(2405155); // Atlético de Rafaela – Quilmes
      expect(d.match.kickoff.certainty, KickoffCertainty.tentative);

      final text = MatchDetailTexts.share(d, now: now, fetchedAt: now);

      expect(text, contains('Sábado 17/10/2026 · Horario por confirmar'));
      expect(text, isNot(contains('21:00')));
    });
  });

  group('calendario', () {
    test('hora confirmada: evento de 2 h en UTC', () async {
      final event = MatchDetailTexts.calendarEvent(await detail(2398113), now)!;

      expect(event.uid, 'partido-2398113@futbol-argentino');
      expect(event.title, 'Sarmiento vs. River Plate');
      expect(event.location, 'Estadio Eva Perón de Junín');
      expect(
        event.description,
        'Primera División · Clausura · Fecha 11\nDatos de TheSportsDB.',
      );
      final time = event.time as TimedEvent;
      expect(time.startUtc, DateTime.utc(2026, 10, 14, 22));
      expect(time.endUtc, DateTime.utc(2026, 10, 15));
    });

    test('hora sin confirmar: día completo, con la aclaración', () async {
      final event = MatchDetailTexts.calendarEvent(await detail(2405155), now)!;

      expect((event.time as AllDayEvent).day, const CalendarDay(2026, 10, 17));
      expect(
        event.description,
        contains(
          'Horario por confirmar: TheSportsDB informa 00:00 UTC '
          '(21:00 en Argentina), sin confirmar.',
        ),
      );
    });

    test('terminado o en juego: no se ofrece', () async {
      expect(MatchDetailTexts.calendarEvent(await detail(2398104), now), null);
      expect(MatchDetailTexts.calendarEvent(await detail(2405137), now), null);
    });

    test('se ofrece hasta la hora de inicio', () async {
      final d = await detail(2398113);
      final start = DateTime.utc(2026, 10, 14, 22);

      expect(
        MatchDetailTexts.calendarEvent(
          d,
          start.subtract(const Duration(minutes: 1)),
        ),
        isNotNull,
      );
      expect(MatchDetailTexts.calendarEvent(d, start), isNull);
    });

    test('nombre del archivo .ics', () async {
      expect(
        MatchDetailTexts.calendarFileName(await detail(2398113)),
        'partido-2398113.ics',
      );
    });
  });
}
