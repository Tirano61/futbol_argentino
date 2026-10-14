import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/matches/data/models/match_record.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/services/round_merge_policy.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_outcome.dart';

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
}
