import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/matches/data/models/match_record.dart';
import 'package:futbol_argentino/features/matches/domain/entities/knockout_tie.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/services/round_merge_policy.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_outcome.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_pairing.dart';

import '../../../helpers/fixture_matches.dart';

/// Tanda de penales (`intHomeScoreExtra`/`intAwayScoreExtra`) y quién
/// avanza, con partidos reales grabados.
void main() {
  Match recorded(String fixture, String home, [String? away]) =>
      fixtureMatches(fixture).singleWhere(
        (m) => m.home.name == home && (away == null || m.away.name == away),
      );

  group('tanda de penales', () {
    test('se lee de un PEN que la informa', () {
      // Cuartos de la Copa 2026: Riestra 1-1 Banfield, 6-7 en penales.
      final m = recorded('eventsround_4500_r125_s2026', 'Deportivo Riestra');
      expect(m.status.decidedBy, MatchDecision.penalties);
      expect(m.score, const Score(home: 1, away: 1));
      expect(m.penalties, const Score(home: 6, away: 7));
    });

    test('no se inventa en un PEN que no la informa (32avos de la Copa '
        '2026)', () {
      final m = recorded('eventsround_4500_r64_s2026', 'Barracas Central');
      expect(m.status.decidedBy, MatchDecision.penalties);
      expect(m.penalties, isNull);
    });

    test('ni en un partido sin penales', () {
      final m = recorded('eventsround_4406_r0_s2026', 'Rosario Central');
      expect(m.status.decidedBy, MatchDecision.extraTime);
      expect(m.penalties, isNull);
    });

    test('se guarda y se vuelve a leer; un registro anterior sin el campo '
        'se lee sin tanda', () {
      final m = recorded(
        'eventsround_4406_r16_s2026',
        'River Plate',
        'San Lorenzo',
      );
      expect(MatchRecord.fromMap(MatchRecord.toMap(m)).penalties, m.penalties);
      final old = MatchRecord.toMap(m)..remove('penalties');
      expect(MatchRecord.fromMap(old).penalties, isNull);
      expect(MatchRecord.fromMap(old).score, m.score);
    });

    test('el merge conserva la tanda si una respuesta llega sin ella', () {
      final m = recorded('eventsround_4500_r125_s2026', 'Deportivo Riestra');
      final without = rebuild(m, clearPenalties: true);
      final merged = RoundMergePolicy.mergeFields(m, without, defaultSeenAt);
      expect(merged.penalties, const Score(home: 6, away: 7));
    });
  });

  group('TieOutcome', () {
    test('por el resultado: Belgrano 2-0 Unión, cuartos del Apertura', () {
      final m = recorded('eventsround_4406_r0_s2026', 'Belgrano');
      final outcome = TieOutcome.of(m)!;
      expect(outcome.source, TieOutcomeSource.score);
      expect(outcome.winner.name, 'Belgrano');
    });

    test('por la tanda: River 1-1 San Lorenzo (4-3), octavos del Apertura', () {
      final m = recorded(
        'eventsround_4406_r16_s2026',
        'River Plate',
        'San Lorenzo',
      );
      final outcome = TieOutcome.of(m)!;
      expect(outcome.source, TieOutcomeSource.penalties);
      expect(outcome.winner.name, 'River Plate');
    });

    test('por la ronda siguiente si la API no informa la tanda', () {
      final m = recorded('eventsround_4500_r64_s2026', 'Barracas Central');
      final later = fixtureMatches('eventsround_4500_r32_s2026');
      final outcome = TieOutcome.of(m, laterMatches: later)!;
      expect(outcome.source, TieOutcomeSource.laterMatch);
      expect(outcome.winner.name, 'Barracas Central');
    });

    test('sin evidencia, no hay ganador', () {
      final m = recorded('eventsround_4500_r64_s2026', 'Barracas Central');
      expect(TieOutcome.of(m), isNull);
      // Los dos aparecen después (imposible en una llave): tampoco.
      final later = fixtureMatches('eventsround_4500_r32_s2026');
      final both = [...later, rebuild(later.first, home: m.away)];
      expect(TieOutcome.of(m, laterMatches: both), isNull);
    });

    test('un partido sin terminar no tiene ganador', () {
      final m = fixtureMatches('eventsround_4500_r150_s2026').first;
      expect(m.status.isScheduled, isTrue);
      expect(TieOutcome.of(m), isNull);
    });
  });

  group('TieOutcome.ofTie: partido único (regresión)', () {
    test('da lo mismo que TieOutcome.of', () {
      final later = fixtureMatches('eventsround_4500_r32_s2026');
      for (final m in [
        ...fixtureMatches('eventsround_4406_r0_s2026'),
        ...fixtureMatches('eventsround_4500_r64_s2026'),
        ...fixtureMatches('eventsround_4500_r150_s2026'),
      ]) {
        final single = TieOutcome.of(m, laterMatches: later);
        final tie = TieOutcome.ofTie(
          KnockoutTie.single(m),
          laterMatches: later,
        );
        expect(tie?.winner, single?.winner, reason: '${m.id}');
        expect(tie?.source, single?.source, reason: '${m.id}');
      }
    });
  });

  group('TieOutcome.ofTie: ida y vuelta', () {
    List<Match> season(int league, int year, List<int> rounds) => [
      for (final r in rounds)
        ...fixtureMatches('eventsround_${league}_r${r}_s$year'),
    ];

    KnockoutTie tieOf(String fixture, String firstHome) => TiePairing.pair(
      fixtureMatches(fixture),
      legs: 2,
    ).ties.singleWhere((t) => t.first.name == firstHome);

    test('por el global: Peñarol 1-0 / Racing 3-1 → Racing (global 2-3)', () {
      final outcome = TieOutcome.ofTie(
        tieOf('eventsround_4501_r16_s2025', 'Peñarol'),
      )!;
      expect(outcome.source, TieOutcomeSource.aggregate);
      expect(outcome.winner.name, 'Racing Club');
    });

    test('la vuelta ganada no alcanza: LDU 3-2 Palmeiras con la ida 0-1 es '
        'global 3-3 y Palmeiras gana la tanda 4-3', () {
      final tie = tieOf('eventsround_4501_r125_s2026', 'Palmeiras');
      // Partido a partido, la vuelta la ganó LDU.
      expect(TieOutcome.of(tie.decisive)!.winner.name, 'LDU Quito');
      final outcome = TieOutcome.ofTie(tie)!;
      expect(outcome.source, TieOutcomeSource.penalties);
      expect(outcome.winner.name, 'Palmeiras');
    });

    test('octavos de la Libertadores 2026: las tres tandas', () {
      final ties = TiePairing.pair(
        fixtureMatches('eventsround_4501_r16_s2026'),
        legs: 2,
      ).ties;
      final byPenalties = {
        for (final t in ties)
          if (TieOutcome.ofTie(t) case final o?
              when o.source == TieOutcomeSource.penalties)
            '${t.first.name} - ${t.second.name}': o.winner.name,
      };
      expect(byPenalties, {
        'Fluminense - Independiente Rivadavia': 'Fluminense',
        'Platense - Coquimbo Unido': 'Platense',
        'Mirassol - LDU Quito': 'LDU Quito',
      });
      // Todas las series tienen ganador sin mirar otras rondas.
      expect(ties.every((t) => TieOutcome.ofTie(t) != null), isTrue);
    });

    test('2025 sin penales: global empatado → el único que juega después '
        '(River ante Libertad, São Paulo ante Atlético Nacional)', () {
      final later = season(4501, 2025, [125, 150, 200]);
      final river = tieOf('eventsround_4501_r16_s2025', 'Club Libertad');
      expect(river.aggregate, const Score(home: 1, away: 1));
      expect(TieOutcome.ofTie(river), isNull);
      final outcome = TieOutcome.ofTie(river, laterMatches: later)!;
      expect(outcome.source, TieOutcomeSource.laterMatch);
      expect(outcome.winner.name, 'River Plate');
      expect(
        TieOutcome.ofTie(
          tieOf('eventsround_4501_r16_s2025', 'Atlético Nacional'),
          laterMatches: later,
        )!.winner.name,
        'São Paulo',
      );
    });

    test('Sudamericana 2026: PEN sin tanda (Atlético Mineiro 4-2 Santos, '
        'global 4-4) → por la semifinal guardada, o sin dato', () {
      final tie = tieOf('eventsround_4724_r125_s2026', 'Santos');
      expect(tie.decisive.status.decidedBy, MatchDecision.penalties);
      expect(tie.penalties, isNull);
      expect(TieOutcome.ofTie(tie), isNull);
      final outcome = TieOutcome.ofTie(
        tie,
        laterMatches: season(4724, 2026, [150]),
      )!;
      expect(outcome.source, TieOutcomeSource.laterMatch);
      expect(outcome.winner.name, 'Atlético Mineiro');
    });

    test('la evidencia posterior solo cuenta después de la serie: los '
        'partidos anteriores (grupos) no dicen nada', () {
      final tie = tieOf('eventsround_4724_r125_s2026', 'Santos');
      final before = season(4724, 2026, [4, 5, 6, 32, 16]);
      expect(before.any((m) => m.involvesTeam(tie.first.id)), isTrue);
      expect(TieOutcome.ofTie(tie, laterMatches: before), isNull);
    });

    test('dato contradictorio (PEN con el global distinto): ni el global ni '
        'la tanda; solo quien juega después', () {
      final tie = tieOf('eventsround_4501_r16_s2025', 'Peñarol');
      final pen = rebuild(
        tie.decisive,
        status: const MatchStatus(
          kind: MatchStatusKind.finished,
          decidedBy: MatchDecision.penalties,
          raw: 'PEN',
        ),
        penalties: const Score(home: 2, away: 4),
      );
      final contradictory = KnockoutTie(
        legs: [tie.legs.first, pen],
        expectedLegs: 2,
      );
      expect(TieOutcome.ofTie(contradictory), isNull);
      final outcome = TieOutcome.ofTie(
        contradictory,
        laterMatches: season(4501, 2025, [125]),
      )!;
      expect(outcome.source, TieOutcomeSource.laterMatch);
      expect(outcome.winner.name, 'Racing Club');
    });

    test('una serie sin terminar no tiene ganador, aunque uno juegue '
        'después', () {
      final tie = TiePairing.pair(
        fixtureMatches('eventsround_4501_r150_s2026'),
        legs: 2,
      ).ties.first;
      expect(tie.isComplete, isFalse);
      expect(TieOutcome.ofTie(tie), isNull);
    });

    test(
      'final a partido único 2025: Palmeiras 0-1 Flamengo; la de la '
      'Sudamericana (0-0, sin tanda ni partido posterior) queda sin dato',
      () {
        final lib = fixtureMatches('eventsround_4501_r200_s2025').single;
        expect(
          TieOutcome.ofTie(KnockoutTie.single(lib))!.winner.name,
          'Flamengo',
        );
        final sud = fixtureMatches('eventsround_4724_r200_s2025').single;
        expect(sud.score, const Score(home: 0, away: 0));
        expect(TieOutcome.ofTie(KnockoutTie.single(sud)), isNull);
      },
    );
  });
}
