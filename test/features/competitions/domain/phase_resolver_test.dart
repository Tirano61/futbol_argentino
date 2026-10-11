import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/competition.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase_assignment.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/services/phase_resolver.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';

/// Cuenta asignaciones por (fase, tipo, fuente).
Map<String, int> summary(Map<int, PhaseAssignment> assigned) {
  final counts = <String, int>{};
  for (final a in assigned.values) {
    final key = '${a.phase.name}/${a.stageKind.name}/${a.source.name}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

Map<int, PhaseAssignment> classify(
  CompetitionDefinition definition,
  int year,
  int round,
  List<Match> matches,
) => PhaseResolver(
  definition,
).classifyRound(season: Season(year), apiRound: round, matches: matches);

/// Primera sin ventanas cargadas (temporada fuera del catálogo).
final primeraWithoutCatalog = CompetitionDefinition(
  id: 4406,
  name: 'Primera División',
  shortName: 'Primera',
  format: CompetitionFormat.league,
  rules: SplitSeasonLeagueRules(
    phases: const [PhaseKey.apertura, PhaseKey.clausura],
    regularRounds: 16,
    matchesPerRound: 15,
    knockoutRound: 0,
    knockoutOpeningRound: 16,
    knockoutOpeningLabel: 'Octavos de final',
    knockoutLabel: 'Cuartos, semifinales y final',
    windowsBySeason: const {},
  ),
);

void main() {
  const primera = CompetitionCatalog.primeraDivision;

  group('Primera con catálogo (datos reales)', () {
    test('fecha 12 de 2026: 15 Apertura + 15 Clausura', () {
      final result = classify(
        primera,
        2026,
        12,
        fixtureMatches('eventsround_4406_r12_s2026'),
      );

      expect(summary(result), {
        'apertura/regular/catalog': 15,
        'clausura/regular/catalog': 15,
      });
    });

    test(
      'ronda 16 de 2026: fecha 16 Apertura, octavos y fecha 16 Clausura',
      () {
        final matches = fixtureMatches('eventsround_4406_r16_s2026');
        final result = classify(primera, 2026, 16, matches);

        expect(summary(result), {
          'apertura/regular/catalog': 15,
          'apertura/knockout/catalog': 8,
          'clausura/regular/catalog': 15,
        });
        // Los octavos son los del 9 y 10 de mayo.
        for (final m in matches) {
          if (result[m.id]!.stageKind == StageKind.knockout) {
            expect(
              m.kickoff.argentinaDay!.isBefore(const CalendarDay(2026, 5, 9)),
              isFalse,
            );
          }
        }
      },
    );

    test('ronda 0 de 2026: eliminatorias del Apertura', () {
      final result = classify(
        primera,
        2026,
        0,
        fixtureMatches('eventsround_4406_r0_s2026'),
      );

      expect(summary(result), {'apertura/knockout/catalog': 7});
    });

    test('fecha 9 de 2026 jugada en mayo sigue siendo Apertura regular', () {
      final result = classify(
        primera,
        2026,
        9,
        fixtureMatches('eventsround_4406_r9_s2026'),
      );

      expect(summary(result)['apertura/regular/catalog'], 15);
    });

    test('todas las rondas 2025 y 2026 quedan determinadas', () {
      for (final year in [2025, 2026]) {
        for (var round = 0; round <= 16; round++) {
          final matches = fixtureMatches('eventsround_4406_r${round}_s$year');
          final result = classify(primera, year, round, matches);
          final undetermined = result.values.where((a) => !a.isDetermined);
          expect(undetermined, isEmpty, reason: '$year r$round');
        }
      }
    });
  });

  group('Primera: sin evidencia suficiente no se adivina', () {
    test('partido fuera de toda ventana: undetermined', () {
      final e = fixtureEvents('eventsround_4406_r5_s2026').first;
      final moved = matchFromEvent(
        e,
        kickoff: Kickoff(
          utc: DateTime.utc(2026, 6, 15, 20),
          argentinaDay: const CalendarDay(2026, 6, 15),
          certainty: KickoffCertainty.confirmed,
          evidence: KickoffEvidence.timestamp,
        ),
      );

      final result = classify(primera, 2026, 5, [moved]);

      expect(result[moved.id], const PhaseAssignment.undetermined());
    });

    test(
      'ronda 0 en el Clausura sin ventana de eliminatorias: undetermined',
      () {
        final e = fixtureEvents('eventsround_4406_r0_s2026').first;
        final december = matchFromEvent(
          e,
          kickoff: Kickoff(
            utc: DateTime.utc(2026, 12, 13, 20),
            argentinaDay: const CalendarDay(2026, 12, 13),
            certainty: KickoffCertainty.confirmed,
            evidence: KickoffEvidence.timestamp,
          ),
        );

        expect(
          classify(primera, 2026, 0, [december])[december.id],
          const PhaseAssignment.undetermined(),
        );
      },
    );

    test('sin día conocido: undetermined', () {
      final e = fixtureEvents('eventsround_4406_r5_s2026').first;
      final noDate = matchFromEvent(e, kickoff: const Kickoff.unknown());

      expect(
        classify(primera, 2026, 5, [noDate])[noDate.id]!.isDetermined,
        isFalse,
      );
    });

    test('equipo repetido en la misma fase: ambos partidos undetermined', () {
      final matches = fixtureMatches('eventsround_4406_r12_s2026');
      final clausura = matches
          .where((m) => m.kickoff.argentinaDay!.month == 10)
          .toList();
      // Partido de la fecha 12 del Clausura reprogramado al 20/10, con un
      // equipo que ya juega esa fecha: imposible saber cuál es cuál.
      final original = clausura.first;
      final duplicate = matchFromEvent(
        fixtureEvents(
          'eventsround_4406_r12_s2026',
        ).singleWhere((e) => e['idEvent'] == '${clausura[1].id}'),
        kickoff: Kickoff(
          utc: DateTime.utc(2026, 10, 20, 22),
          argentinaDay: const CalendarDay(2026, 10, 20),
          certainty: KickoffCertainty.confirmed,
          evidence: KickoffEvidence.timestamp,
        ),
      );
      final clash = Match(
        id: 999999,
        competitionId: 4406,
        competitionName: original.competitionName,
        season: '2026',
        apiRound: 12,
        home: original.home,
        away: duplicate.away,
        kickoff: duplicate.kickoff,
        status: duplicate.status,
        lastSeenAt: duplicate.lastSeenAt,
      );

      final result = classify(primera, 2026, 12, [...matches, clash]);

      expect(result[clash.id]!.isDetermined, isFalse);
      expect(result[original.id]!.isDetermined, isFalse);
      expect(
        result.values.where((a) => a.isDetermined),
        hasLength(29 - 1),
        reason: 'solo quedan fuera los dos partidos del equipo repetido',
      );
    });
  });

  group('Primera sin catálogo: inferencia conservadora', () {
    test('fecha 12 de 2025: dos grupos claros → inferido', () {
      final result = classify(
        primeraWithoutCatalog,
        2025,
        12,
        fixtureMatches('eventsround_4406_r12_s2025'),
      );

      expect(summary(result), {
        'apertura/regular/inferred': 15,
        'clausura/regular/inferred': 15,
      });
    });

    test('fecha 6 de 2025 (Clausura repartido en 3 grupos): undetermined', () {
      final result = classify(
        primeraWithoutCatalog,
        2025,
        6,
        fixtureMatches('eventsround_4406_r6_s2025'),
      );

      expect(summary(result), {'undetermined/regular/undetermined': 30});
    });

    test('ronda 16 con octavos mezclados: undetermined', () {
      final result = classify(
        primeraWithoutCatalog,
        2026,
        16,
        fixtureMatches('eventsround_4406_r16_s2026'),
      );

      expect(result.values.every((a) => !a.isDetermined), isTrue);
    });
  });

  group('Primera Nacional y Copa Argentina', () {
    test('Nacional fecha 33: 18 partidos de fase regular', () {
      final result = classify(
        CompetitionCatalog.primeraNacional,
        2026,
        33,
        fixtureMatches('eventsround_4616_r33_s2026'),
      );

      expect(summary(result), {'regular/regular/catalog': 18});
    });

    test('Nacional: ronda fuera de las 36 verificadas es undetermined', () {
      final matches = fixtureMatches('eventsround_4616_r33_s2026');

      final result = classify(
        CompetitionCatalog.primeraNacional,
        2026,
        37,
        matches,
      );

      expect(result.values.every((a) => !a.isDetermined), isTrue);
    });

    test('Copa: cuartos con código 125', () {
      final result = classify(
        CompetitionCatalog.copaArgentina,
        2026,
        125,
        fixtureMatches('eventsround_4500_r125_s2026'),
      );

      expect(summary(result), {'unica/knockout/catalog': 4});
    });

    test('Copa: código desconocido es knockout inferido', () {
      final matches = fixtureMatches('eventsround_4500_r150_s2026');

      final result = classify(
        CompetitionCatalog.copaArgentina,
        2026,
        175,
        matches,
      );

      expect(summary(result), {'unica/knockout/inferred': 2});
    });
  });
}
