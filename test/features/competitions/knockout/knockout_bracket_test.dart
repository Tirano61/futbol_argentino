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

  group('Fase D5: copas internacionales (ida y vuelta)', () {
    String series(BracketSlot s) {
      final t = s.tie;
      return t == null ? '—' : '${t.first.name} - ${t.second.name}';
    }

    KnockoutBracket bracketOf(CompetitionDefinition d, int year) {
      final rounds = [
        ...d.bracketApiRounds(Season(year)),
        // Las previas y los grupos no entran al cuadro.
        if (year == 2025) 400 else 1,
        6,
      ];
      final brackets = KnockoutBracketBuilder.forSeason(
        definition: d,
        season: Season(year),
        matches: recorded(d.id, year, rounds),
      );
      expect(brackets.keys, [PhaseKey.knockoutStage]);
      return brackets[PhaseKey.knockoutStage]!;
    }

    test('Libertadores 2025: árbol completo de series hasta la final '
        'Palmeiras 0-1 Flamengo', () {
      final bracket = bracketOf(CompetitionCatalog.copaLibertadores, 2025);
      expect(bracket.unplaced, isEmpty);
      expect(bracket.preliminary, isEmpty);
      final rounds = bracket.rounds;
      expect([for (final r in rounds) r.slots.length], [8, 4, 2, 1]);
      expect([for (final r in rounds) r.legs], [2, 2, 2, 1]);
      for (final r in rounds) {
        expect(r.pairingUnknown, isFalse, reason: r.label);
        for (final s in r.slots) {
          expect(s.tie!.isComplete, isTrue, reason: series(s));
          expect(s.tie!.legs, hasLength(r.legs), reason: series(s));
          expect(s.outcome, isNotNull, reason: series(s));
        }
      }
      expect(rounds[2].slots.map(series), [
        'LDU Quito - Palmeiras',
        'Flamengo - Racing Club',
      ]);
      expect(rounds[1].slots.map(series), [
        'LDU Quito - São Paulo',
        'River Plate - Palmeiras',
        'Flamengo - Estudiantes de La Plata',
        'Vélez Sarsfield - Racing Club',
      ]);
      final finalSlot = rounds.last.slots.single;
      expect(series(finalSlot), 'Palmeiras - Flamengo');
      expect(finalSlot.outcome!.winner.name, 'Flamengo');
      expect(finalSlot.outcome!.source, TieOutcomeSource.score);
    });

    test('Libertadores 2025: cada llave al lado de las dos que la alimentan, '
        'por el ganador de cada serie', () {
      final rounds = bracketOf(
        CompetitionCatalog.copaLibertadores,
        2025,
      ).rounds;
      for (var k = 1; k < rounds.length; k++) {
        for (final (i, parent) in rounds[k].slots.indexed) {
          final winners = {
            for (final child in [
              rounds[k - 1].slots[2 * i],
              rounds[k - 1].slots[2 * i + 1],
            ])
              child.outcome!.winner.id,
          };
          expect(winners, {parent.tie!.first.id, parent.tie!.second.id});
        }
      }
    });

    test('Libertadores 2025: series empatadas sin penales (la API no los '
        'informa) → el que juega la ronda siguiente', () {
      final rounds = bracketOf(
        CompetitionCatalog.copaLibertadores,
        2025,
      ).rounds;
      final byLaterMatch = {
        for (final r in rounds)
          for (final s in r.slots)
            if (s.outcome!.source == TieOutcomeSource.laterMatch)
              series(s): s.outcome!.winner.name,
      };
      expect(byLaterMatch, {
        'Atlético Nacional - São Paulo': 'São Paulo',
        'Club Libertad - River Plate': 'River Plate',
        'Flamengo - Estudiantes de La Plata': 'Flamengo',
      });
      final byAggregate = [
        for (final r in rounds.take(3))
          for (final s in r.slots)
            if (s.outcome!.source == TieOutcomeSource.aggregate) series(s),
      ];
      expect(byAggregate, hasLength(14 - 3));
    });

    test('Libertadores 2026: octavos con sus tandas; semifinales en juego y '
        'final a definir', () {
      final rounds = bracketOf(
        CompetitionCatalog.copaLibertadores,
        2026,
      ).rounds;
      final byPenalties = [
        for (final s in rounds.first.slots)
          if (s.outcome?.source == TieOutcomeSource.penalties)
            s.outcome!.winner.name,
      ];
      expect(
        byPenalties,
        unorderedEquals(['Fluminense', 'Platense', 'LDU Quito']),
      );
      expect(rounds[0].slots.every((s) => s.outcome != null), isTrue);
      expect(rounds[1].slots.every((s) => s.outcome != null), isTrue);
      // Cuartos: la vuelta LDU 3-2 Palmeiras; la serie, Palmeiras.
      final ldu = rounds[1].slots.singleWhere(
        (s) => s.tie!.involvesTeam(138227),
      );
      expect(ldu.outcome!.winner.name, 'Palmeiras');
      expect(rounds[2].slots.map(series), [
        'Fluminense - Palmeiras',
        'Estudiantes de La Plata - Flamengo',
      ]);
      expect(rounds[2].slots.every((s) => s.outcome == null), isTrue);
      final finalSlot = rounds.last.slots.single;
      expect(finalSlot.tie, isNull);
      expect(finalSlot.qualified, isEmpty);
    });

    test('Sudamericana 2025: Playoffs como lista de series y final sin dato '
        'de la definición', () {
      final bracket = bracketOf(CompetitionCatalog.copaSudamericana, 2025);
      expect(bracket.unplaced, isEmpty);
      final playoffs = bracket.preliminary.single;
      expect(playoffs.label, 'Playoffs de octavos');
      expect(playoffs.legs, 2);
      expect(playoffs.slots, hasLength(8));
      expect(playoffs.slots.every((s) => s.outcome != null), isTrue);
      expect(playoffs.slots.every((s) => !s.linkedToNext), isTrue);
      // Global 1-1 sin penales: Atlético Mineiro juega los octavos.
      final mineiro = playoffs.slots.singleWhere(
        (s) => series(s) == 'Atlético Bucaramanga - Atlético Mineiro',
      );
      expect(mineiro.outcome!.source, TieOutcomeSource.laterMatch);
      expect(mineiro.outcome!.winner.name, 'Atlético Mineiro');

      expect([for (final r in bracket.rounds) r.slots.length], [8, 4, 2, 1]);
      final finalSlot = bracket.rounds.last.slots.single;
      expect(series(finalSlot), 'Lanús - Atlético Mineiro');
      expect(finalSlot.tie!.isComplete, isTrue);
      expect(finalSlot.outcome, isNull);
    });

    test('Sudamericana 2026: Playoffs en la ronda 32 (Boca por penales) y '
        'el PEN sin tanda de cuartos por la semifinal', () {
      final bracket = bracketOf(CompetitionCatalog.copaSudamericana, 2026);
      final boca = bracket.preliminary.single.slots.singleWhere(
        (s) => s.tie!.involvesTeam(135156),
      );
      expect(boca.outcome!.source, TieOutcomeSource.penalties);
      expect(boca.outcome!.winner.name, 'Boca Juniors');
      final santos = bracket.rounds[1].slots.singleWhere(
        (s) => series(s) == 'Santos - Atlético Mineiro',
      );
      expect(santos.outcome!.source, TieOutcomeSource.laterMatch);
      expect(santos.outcome!.winner.name, 'Atlético Mineiro');
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
