import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/table_builders.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/team_stats.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/tie_breaker.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';

// Estadísticas y partidos ARMADOS EN EL TEST para probar la regla de
// desempate: no son datos reales ni se presentan como tales.

TeamRef team(String name) => TeamRef(id: name.codeUnitAt(0), name: name);

TeamStats stats(
  String name, {
  int w = 0,
  int d = 0,
  int l = 0,
  int gf = 0,
  int ga = 0,
}) => TeamStats(
  team: team(name),
  won: w,
  drawn: d,
  lost: l,
  goalsFor: gf,
  goalsAgainst: ga,
);

var _nextId = 1;

Match game(String home, int homeGoals, String away, int awayGoals) => Match(
  id: _nextId++,
  competitionId: 0,
  competitionName: 'Prueba',
  season: '2026',
  apiRound: 1,
  home: team(home),
  away: team(away),
  kickoff: const Kickoff(
    utc: null,
    argentinaDay: null,
    certainty: KickoffCertainty.unknown,
    evidence: KickoffEvidence.none,
  ),
  status: const MatchStatus(kind: MatchStatusKind.finished),
  score: Score(home: homeGoals, away: awayGoals),
  lastSeenAt: DateTime.utc(2026),
);

const zone = TieBreaker([
  TieBreakCriterion.goalDifference,
  TieBreakCriterion.goalsFor,
  TieBreakCriterion.headToHead,
  TieBreakCriterion.fairPlay,
  TieBreakCriterion.drawOfLots,
]);
const annual = TieBreaker([
  TieBreakCriterion.goalDifference,
  TieBreakCriterion.goalsFor,
  TieBreakCriterion.fairPlay,
  TieBreakCriterion.drawOfLots,
]);

List<String> order(List<StandingsRow> rows) => [
  for (final r in rows)
    '${r.position}${r.isShared ? '=' : ''} ${r.stats.team.name}',
];

void main() {
  test('puntos, después diferencia de gol, después goles a favor', () {
    final rows = zone.rank([
      stats('Alfa', w: 3, gf: 5, ga: 4), // 9 pts, DG +1, GF 5
      stats('Beta', w: 3, gf: 9, ga: 6), // 9 pts, DG +3
      stats('Gama', w: 3, gf: 8, ga: 7), // 9 pts, DG +1, GF 8
      stats('Delta', w: 4), // 12 pts
    ]);
    expect(order(rows), ['1 Delta', '2 Beta', '3 Gama', '4 Alfa']);
  });

  test('enfrentamiento directo con 2 empatados', () {
    final rows = zone.rank(
      [
        stats('Alfa', w: 2, d: 1, gf: 5, ga: 3),
        stats('Beta', w: 2, d: 1, gf: 5, ga: 3),
      ],
      matches: [game('Beta', 1, 'Alfa', 0)],
    );
    expect(order(rows), ['1 Beta', '2 Alfa']);
  });

  test('enfrentamiento directo con 3: se repite con los que siguen '
      'empatados', () {
    // Mini tabla: Alfa 6 pts; Beta y Gama 0 pts, empatados también en
    // DG y GF entre los tres → se repite entre Beta y Gama: Gama ganó.
    final rows = zone.rank(
      [
        stats('Alfa', w: 3, gf: 6, ga: 3),
        stats('Beta', w: 3, gf: 6, ga: 3),
        stats('Gama', w: 3, gf: 6, ga: 3),
      ],
      matches: [
        game('Alfa', 1, 'Beta', 0),
        game('Alfa', 1, 'Gama', 0),
        // Fuera del grupo: no cuenta para el enfrentamiento directo.
        game('Beta', 5, 'Zeta', 0),
      ],
    );
    expect(order(rows), ['1 Alfa', '2= Beta', '2= Gama']);

    // Entre los tres: 3 pts y DG 0 cada uno; GF Alfa 3, Beta 2, Gama 2 →
    // Alfa primero; se repite entre Beta y Gama: Beta le ganó a Gama.
    final decided = zone.rank(
      [
        stats('Alfa', w: 3, gf: 6, ga: 3),
        stats('Beta', w: 3, gf: 6, ga: 3),
        stats('Gama', w: 3, gf: 6, ga: 3),
      ],
      matches: [
        game('Alfa', 2, 'Beta', 1),
        game('Gama', 2, 'Alfa', 1),
        game('Beta', 1, 'Gama', 0),
      ],
    );
    expect(order(decided), ['1 Alfa', '2 Beta', '3 Gama']);

    final repeated = zone.rank(
      [
        stats('Alfa', w: 3, gf: 6, ga: 3),
        stats('Beta', w: 3, gf: 6, ga: 3),
        stats('Gama', w: 3, gf: 6, ga: 3),
      ],
      matches: [
        game('Alfa', 3, 'Beta', 0),
        game('Gama', 3, 'Alfa', 0),
        game('Beta', 2, 'Gama', 1),
      ],
    );
    // Mini tabla de los tres: 3 pts cada uno; DG Alfa 0, Beta −2, Gama +2
    // → Gama, Alfa, Beta.
    expect(order(repeated), ['1 Gama', '2 Alfa', '3 Beta']);
  });

  test('la tabla anual no usa el enfrentamiento directo', () {
    final teams = [
      stats('Alfa', w: 2, d: 1, gf: 5, ga: 3),
      stats('Beta', w: 2, d: 1, gf: 5, ga: 3),
    ];
    final matches = [game('Beta', 1, 'Alfa', 0)];

    expect(order(zone.rank(teams, matches: matches)), ['1 Beta', '2 Alfa']);
    expect(order(annual.rank(teams, matches: matches)), ['1= Alfa', '1= Beta']);
  });

  test('posición compartida si solo quedan Fair Play o sorteo', () {
    final rows = zone.rank(
      [
        stats('Alfa', w: 1, gf: 2, ga: 1),
        stats('Beta', w: 1, gf: 2, ga: 1),
        stats('Gama'),
      ],
      matches: [game('Alfa', 1, 'Beta', 1)],
    );
    expect(order(rows), ['1= Alfa', '1= Beta', '3 Gama']);
    expect(
      StandingsNotes.shared(zone.criteria),
      'Posición compartida: se define por Fair Play o sorteo (no '
      'disponible).',
    );
  });

  test('Nacional (art. 112, puntos 1 a 3): sin Fair Play ni sorteo, los '
      'que siguen empatados comparten la posición', () {
    const nacional = TieBreaker([
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
      TieBreakCriterion.headToHead,
    ]);
    final teams = [
      stats('Alfa', w: 1, gf: 2, ga: 1),
      stats('Beta', w: 1, gf: 2, ga: 1),
    ];

    expect(order(nacional.rank(teams, matches: [game('Beta', 1, 'Alfa', 0)])), [
      '1 Beta',
      '2 Alfa',
    ]);
    expect(order(nacional.rank(teams, matches: [game('Alfa', 1, 'Beta', 1)])), [
      '1= Alfa',
      '1= Beta',
    ]);
    expect(
      StandingsNotes.shared(nacional.criteria),
      'Posición compartida: el reglamento no define más criterios.',
    );
    expect(
      StandingsNotes.tieBreak(nacional.criteria, source: 'art. 112'),
      'Desempate: diferencia de gol, goles a favor y partidos entre los '
      'empatados (art. 112).',
    );
  });

  test('directo una sola vez (CONMEBOL 2026) vs re-aplicado: con un '
      'triple empate, los dos que siguen empatados pasan al criterio '
      'siguiente', () {
    // Entre los tres: 3 pts y DG 0 cada uno; GF Alfa 3, Beta 2, Gama 2 →
    // Alfa primero. Beta y Gama siguen empatados: Beta le ganó a Gama,
    // pero Gama tiene mejor diferencia de gol en total.
    final teams = [
      stats('Alfa', w: 3, gf: 6, ga: 3),
      stats('Beta', w: 3, gf: 5, ga: 4),
      stats('Gama', w: 3, gf: 7, ga: 4),
    ];
    final matches = [
      game('Alfa', 2, 'Beta', 1),
      game('Gama', 2, 'Alfa', 1),
      game('Beta', 1, 'Gama', 0),
    ];
    const reapplied = TieBreaker([
      TieBreakCriterion.headToHead,
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
    ]);
    const once = TieBreaker([
      TieBreakCriterion.headToHeadOnce,
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
    ]);

    expect(order(reapplied.rank(teams, matches: matches)), [
      '1 Alfa',
      '2 Beta',
      '3 Gama',
    ]);
    expect(order(once.rank(teams, matches: matches)), [
      '1 Alfa',
      '2 Gama',
      '3 Beta',
    ]);
  });

  test('goles a favor como visitante (CONMEBOL 2025), después criterios no '
      'calculables', () {
    const conmebol2025 = TieBreaker([
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
      TieBreakCriterion.awayGoalsFor,
      UnavailableCriterion('Ranking de Clubes de CONMEBOL al 16/12/2024'),
      TieBreakCriterion.drawOfLots,
    ]);
    final teams = [
      stats('Alfa', w: 1, gf: 2, ga: 1),
      stats('Beta', w: 1, gf: 2, ga: 1),
    ];

    // Alfa hizo sus 2 goles de visitante; Beta, 1.
    expect(
      order(
        conmebol2025.rank(
          teams,
          matches: [game('Zeta', 1, 'Alfa', 2), game('Beta', 1, 'Alfa', 0)],
        ),
      ),
      ['1 Alfa', '2 Beta'],
    );
    // Mismos goles de visitante: el ranking y el sorteo no se calculan.
    expect(
      order(
        conmebol2025.rank(
          teams,
          matches: [game('Zeta', 1, 'Alfa', 1), game('Zeta', 0, 'Beta', 1)],
        ),
      ),
      ['1= Alfa', '1= Beta'],
    );
    expect(
      StandingsNotes.shared(conmebol2025.criteria),
      'Posición compartida: se define por Ranking de Clubes de CONMEBOL al '
      '16/12/2024 o sorteo (no disponible).',
    );
    expect(
      StandingsNotes.shared(const [
        TieBreakCriterion.headToHeadOnce,
        UnavailableCriterion('menos tarjetas rojas'),
        UnavailableCriterion('menos tarjetas amarillas'),
        TieBreakCriterion.drawOfLots,
      ]),
      'Posición compartida: se define por menos tarjetas rojas, menos '
      'tarjetas amarillas o sorteo (no disponible).',
    );
  });

  test('StatsAccumulator: cada partido una vez, solo terminados con '
      'resultado', () {
    final played = game('Alfa', 2, 'Beta', 1);
    final pending = Match(
      id: _nextId++,
      competitionId: 0,
      competitionName: 'Prueba',
      season: '2026',
      apiRound: 1,
      home: team('Alfa'),
      away: team('Beta'),
      kickoff: played.kickoff,
      status: const MatchStatus.scheduled(),
      lastSeenAt: DateTime.utc(2026),
    );
    final acc = StatsAccumulator()..addAll([played, played, pending]);

    expect(acc.matchCount, 1);
    expect(acc[team('Alfa').id]!.points, 3);
    expect(acc[team('Beta').id]!.played, 1);
  });
}
