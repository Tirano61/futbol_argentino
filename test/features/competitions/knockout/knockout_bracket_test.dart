import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/knockout/knockout_bracket.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_outcome.dart';

import '../../../helpers/fixture_matches.dart';

/// Cuadro de llaves armado con partidos reales grabados.
void main() {
  List<Match> recorded(int league, int year, List<int> rounds) => [
    for (final r in rounds)
      ...fixtureMatches('eventsround_${league}_r${r}_s$year'),
  ];

  String tie(BracketSlot s) {
    final m = s.match;
    return m == null ? '—' : '${m.home.name} - ${m.away.name}';
  }

  test('el catálogo: cada ronda del cuadro tiene la mitad de partidos que la '
      'anterior y la final, uno', () {
    for (final d in CompetitionCatalog.all) {
      final rounds = d.bracketRounds;
      if (rounds.isEmpty) continue;
      expect(rounds.last.matches, 1, reason: d.name);
      for (var i = 1; i < rounds.length; i++) {
        expect(rounds[i - 1].matches, rounds[i].matches * 2, reason: d.name);
      }
    }
    expect(CompetitionCatalog.primeraNacional.bracketRounds, isEmpty);
  });

  group('Primera 2026: Apertura', () {
    late Map<PhaseKey, KnockoutBracket> brackets;

    setUp(() {
      // La ronda 16 trae también las fechas 16 regulares de los dos
      // torneos: quedan afuera.
      brackets = KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.primeraDivision,
        season: const Season(2026),
        matches: recorded(4406, 2026, [16, 0]),
      );
    });

    test('solo el Apertura tiene eliminatorias (el Clausura no las jugó)', () {
      expect(brackets.keys, [PhaseKey.apertura]);
    });

    test('octavos, cuartos, semifinales y final, completos y unidos', () {
      final bracket = brackets[PhaseKey.apertura]!;
      expect(bracket.unplaced, isEmpty);
      expect(
        [for (final r in bracket.rounds) r.label],
        ['Octavos de final', 'Cuartos de final', 'Semifinales', 'Final'],
      );
      expect([for (final r in bracket.rounds) r.slots.length], [8, 4, 2, 1]);
      for (final r in bracket.rounds) {
        expect(r.slots.every((s) => s.match != null), isTrue);
        expect(r.slots.every((s) => s.outcome != null), isTrue);
        expect(r.pairingUnknown, isFalse);
      }
      for (final r in bracket.rounds.take(3)) {
        expect(r.slots.every((s) => s.linkedToNext), isTrue);
      }
    });

    test('la ronda 0 se reparte por equipo: cuartos, semis y final', () {
      final rounds = brackets[PhaseKey.apertura]!.rounds;
      expect(rounds[1].slots.map(tie), [
        'River Plate - Gimnasia y Esgrima de La Plata',
        'Rosario Central - Racing Club',
        'Argentinos Juniors - Huracán',
        'Belgrano - Unión',
      ]);
      expect(rounds[2].slots.map(tie), [
        'River Plate - Rosario Central',
        'Argentinos Juniors - Belgrano',
      ]);
      expect(rounds[3].slots.map(tie), ['River Plate - Belgrano']);
    });

    test('cada llave queda al lado de las dos que la alimentan', () {
      final rounds = brackets[PhaseKey.apertura]!.rounds;
      for (var k = 1; k < rounds.length; k++) {
        for (final (i, parent) in rounds[k].slots.indexed) {
          final winners = {
            for (final child in [
              rounds[k - 1].slots[2 * i],
              rounds[k - 1].slots[2 * i + 1],
            ])
              child.outcome!.winner.id,
          };
          expect(winners, {parent.match!.home.id, parent.match!.away.id});
        }
      }
    });

    test('ganadores por penales y campeón', () {
      final rounds = brackets[PhaseKey.apertura]!.rounds;
      final octavos = rounds[0].slots.firstWhere(
        (s) => s.match!.home.name == 'River Plate',
      );
      expect(octavos.outcome!.source, TieOutcomeSource.penalties);
      expect(octavos.outcome!.winner.name, 'River Plate');
      final semi = rounds[2].slots[1];
      expect(semi.outcome!.source, TieOutcomeSource.penalties);
      expect(semi.outcome!.winner.name, 'Belgrano');
      expect(rounds.last.slots.single.outcome!.winner.name, 'Belgrano');
    });

    test('datos inconsistentes: lo que no se puede ubicar va aparte, sin '
        'inventar un lugar', () {
      // Sin los cuartos de Belgrano, su semifinal y la final no cierran.
      final bracket = KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.primeraDivision,
        season: const Season(2026),
        matches: [
          for (final m in recorded(4406, 2026, [16, 0]))
            if (!(m.apiRound == 0 && m.home.name == 'Belgrano')) m,
        ],
      )[PhaseKey.apertura]!;
      expect(bracket.unplaced.map((m) => '${m.home.name} - ${m.away.name}'), [
        'Argentinos Juniors - Belgrano',
        'River Plate - Belgrano',
      ]);
      expect(bracket.rounds.last.slots.single.match, isNull);
      expect(
        bracket.rounds[1].slots.where((s) => s.match == null),
        hasLength(1),
      );
    });
  });

  group('Copa Argentina', () {
    test('2026: hasta las semifinales; la final, a definir y alimentada por '
        'las dos', () {
      final bracket = KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.copaArgentina,
        season: const Season(2026),
        matches: recorded(4500, 2026, [64, 32, 16, 125, 150, 200]),
      )[PhaseKey.unica]!;
      expect(bracket.unplaced, isEmpty);
      expect(
        [for (final r in bracket.rounds) r.slots.length],
        [32, 16, 8, 4, 2, 1],
      );
      expect(bracket.rounds.every((r) => !r.pairingUnknown), isTrue);
      expect(bracket.rounds[4].slots.map(tie), [
        'Atlético Tucumán - Platense',
        'Banfield - Boca Juniors',
      ]);
      expect(bracket.rounds[4].slots.every((s) => s.linkedToNext), isTrue);
      final finalSlot = bracket.rounds.last.slots.single;
      expect(finalSlot.match, isNull);
      // Las semis no se jugaron: no se sabe quién llega.
      expect(finalSlot.qualified, isEmpty);
    });

    test('2026: los 32avos por penales sin la tanda se resuelven con la '
        'ronda siguiente', () {
      final bracket = KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.copaArgentina,
        season: const Season(2026),
        matches: recorded(4500, 2026, [64, 32, 16, 125, 150, 200]),
      )[PhaseKey.unica]!;
      final byLaterMatch = [
        for (final s in bracket.rounds.first.slots)
          if (s.outcome?.source == TieOutcomeSource.laterMatch)
            s.outcome!.winner.name,
      ];
      expect(byLaterMatch, hasLength(5));
      expect(byLaterMatch, contains('Barracas Central'));
      expect(
        bracket.rounds.first.slots.every((s) => s.outcome != null),
        isTrue,
      );
    });

    test('2025 (la API no tiene todas las rondas): huecos sin datos y cruces '
        'sin unir, nunca inventados', () {
      final bracket = KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.copaArgentina,
        season: const Season(2025),
        matches: recorded(4500, 2025, [32, 16, 125, 150, 200]),
      )[PhaseKey.unica]!;
      final rounds = bracket.rounds;
      // Final grabada: Independiente Rivadavia 2-2 Argentinos (sin PEN ni
      // tanda en la API): sin ganador.
      final finalSlot = rounds.last.slots.single;
      expect(tie(finalSlot), 'Independiente Rivadavia - Argentinos Juniors');
      expect(finalSlot.outcome, isNull);
      // Semifinales vacías: se sabe quién llegó a la final desde cada una.
      expect(rounds[4].slots.map((s) => s.match), [null, null]);
      expect(rounds[4].slots.map((s) => s.qualified.single.name), [
        'Independiente Rivadavia',
        'Argentinos Juniors',
      ]);
      // Octavos con 4 de 8 y cuartos vacíos: sin unir.
      expect(rounds[2].pairingUnknown, isTrue);
      expect(
        rounds[2].slots
            .where((s) => s.match != null)
            .every((s) => !s.linkedToNext),
        isTrue,
      );
      expect(rounds[3].slots.every((s) => s.qualified.isEmpty), isTrue);
    });
  });

  test('sin partidos de eliminación: sin cuadro', () {
    expect(
      KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.primeraDivision,
        season: const Season(2025),
        matches: recorded(4406, 2025, [16, 0]),
      ),
      isEmpty,
    );
    expect(
      KnockoutBracketBuilder.forSeason(
        definition: CompetitionCatalog.primeraNacional,
        season: const Season(2026),
        matches: recorded(4616, 2026, [36]),
      ),
      isEmpty,
    );
  });
}
