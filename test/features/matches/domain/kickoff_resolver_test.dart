import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/argentina_time.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/services/kickoff_resolver.dart';

import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';

void main() {
  group('eventos reales', () {
    test('hora normal: confirmada y convertida a Argentina', () {
      // Defensa y Justicia – Unión, 2026-03-21T20:45:00 (strTimeLocal 18:00,
      // inconsistente: se ignora).
      final kickoff = resolveEvent(
        fixtureEvent('eventsround_4406_r12_s2026', '2397881'),
      );

      expect(kickoff.certainty, KickoffCertainty.confirmed);
      expect(kickoff.evidence, KickoffEvidence.timestamp);
      expect(ArgentinaTime.formatTime(kickoff.utc!), '17:45');
      expect(kickoff.argentinaDay, const CalendarDay(2026, 3, 21));
    });

    test('cruce de medianoche: 00:30 UTC es el día anterior a las 21:30', () {
      final kickoff = resolveEvent(
        fixtureEvent('eventsround_4406_r12_s2026', '2398125'),
      );

      expect(kickoff.certainty, KickoffCertainty.confirmed);
      expect(kickoff.argentinaDay, const CalendarDay(2026, 10, 10));
      expect(ArgentinaTime.formatTime(kickoff.utc!), '21:30');
    });

    test('00:00 UTC corroborado por strTimeLocal 21:00: confirmado', () {
      // 2025-03-15T00:00:00, strTimeLocal 21:00:00, dateEventLocal 2025-03-14.
      final kickoff = resolveEvent(
        fixtureEvent('eventsround_4406_r10_s2025', '2202760'),
      );

      expect(kickoff.certainty, KickoffCertainty.confirmed);
      expect(kickoff.evidence, KickoffEvidence.midnightCorroborated);
      expect(kickoff.argentinaDay, const CalendarDay(2025, 3, 14));
      expect(ArgentinaTime.formatTime(kickoff.confirmedUtc!), '21:00');
    });

    test(
      '00:00 UTC con strTimeLocal distinto: tentativo, sin mover el día',
      () {
        // Atlético Tucumán – Gimnasia LP: 2026-03-21T00:00:00, local 18:00.
        final kickoff = resolveEvent(
          fixtureEvent('eventsround_4406_r12_s2026', '2397877'),
        );

        expect(kickoff.certainty, KickoffCertainty.tentative);
        expect(kickoff.evidence, KickoffEvidence.midnightUncorroborated);
        expect(kickoff.confirmedUtc, isNull);
        expect(kickoff.argentinaDay, const CalendarDay(2026, 3, 21));
      },
    );

    test('00:00 UTC sin strTimeLocal: tentativo con el día de dateEvent', () {
      // Primera Nacional fecha 34, aún no jugado.
      final kickoff = resolveEvent(
        fixtureEvent('eventsround_4616_r34_s2026', '2405155'),
      );

      expect(kickoff.certainty, KickoffCertainty.tentative);
      expect(kickoff.argentinaDay, const CalendarDay(2026, 10, 17));
    });

    test('00:00 UTC tentativo usa dateEventLocal si existe', () {
      // 2026-08-12T00:00:00, strTimeLocal 19:45, dateEventLocal 2026-08-11.
      final kickoff = resolveEvent(
        fixtureEvent('eventsround_4406_r4_s2026', '2398008'),
      );

      expect(kickoff.certainty, KickoffCertainty.tentative);
      expect(kickoff.argentinaDay, const CalendarDay(2026, 8, 11));
    });

    test('strTime sin segundos ("20:00")', () {
      final kickoff = resolveEvent(
        fixtureEvent('eventspastleague_4406', '2398126'),
      );

      expect(kickoff.certainty, KickoffCertainty.confirmed);
      expect(ArgentinaTime.formatTime(kickoff.utc!), '17:00');
    });

    test('todos los eventos grabados se resuelven sin errores', () {
      for (final name in [
        'eventsround_4406_r0_s2026',
        'eventsround_4406_r16_s2026',
        'eventsround_4616_r33_s2026',
        'eventsround_4500_r64_s2026',
      ]) {
        for (final e in fixtureEvents(name)) {
          final kickoff = resolveEvent(e);
          expect(kickoff.argentinaDay, isNotNull, reason: '${e['idEvent']}');
        }
      }
    });
  });

  group('casos sin timestamp', () {
    test('dateEvent + strTime HH:mm', () {
      final kickoff = KickoffResolver.resolve(
        date: '2026-10-11',
        time: '17:45',
      );

      expect(kickoff.certainty, KickoffCertainty.confirmed);
      expect(kickoff.evidence, KickoffEvidence.dateAndTime);
      expect(kickoff.utc, DateTime.utc(2026, 10, 11, 17, 45));
    });

    test('solo fecha: desconocido con día', () {
      final kickoff = KickoffResolver.resolve(date: '2026-10-25');

      expect(kickoff.certainty, KickoffCertainty.unknown);
      expect(kickoff.evidence, KickoffEvidence.dateOnly);
      expect(kickoff.argentinaDay, const CalendarDay(2026, 10, 25));
    });

    test('sin fecha ni hora: desconocido sin día', () {
      final kickoff = KickoffResolver.resolve(timestamp: '', time: '20:00');

      expect(kickoff, const Kickoff.unknown());
    });

    test('timestamp con zona explícita se respeta', () {
      final kickoff = KickoffResolver.resolve(
        timestamp: '2026-10-11T17:00:00-03:00',
      );

      expect(kickoff.utc, DateTime.utc(2026, 10, 11, 20));
    });

    test('hora inválida se ignora', () {
      final kickoff = KickoffResolver.resolve(
        date: '2026-10-11',
        time: '25:99',
      );

      expect(kickoff.certainty, KickoffCertainty.unknown);
    });
  });
}
