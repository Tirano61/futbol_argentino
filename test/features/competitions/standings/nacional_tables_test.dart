import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/regular_season_matches.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/standings_table.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/table_builders.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/tie_breaker.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/zone_validator.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';

const nacional = CompetitionCatalog.primeraNacional;
final format = nacional.standingsFor(const Season(2026)) as LeagueZones;

/// Rondas 1–36 de 2026 grabadas el 11 y el 12/10/2026. Con [snapshot], las
/// 33–36 de la instantánea del 12/10 (la misma hora que `lookuptable`).
List<Match> recorded({bool snapshot = false}) => [
  for (var r = 1; r <= 36; r++)
    ...fixtureMatches(
      snapshot && r >= 33
          ? 'snapshot_20261012/eventsround_4616_r${r}_s2026'
          : 'eventsround_4616_r${r}_s2026',
    ),
];

RegularSeasonMatches classify(List<Match> matches) =>
    RegularSeasonMatches.classify(
      definition: nacional,
      season: const Season(2026),
      matches: matches,
      rounds: format.regularRounds,
      tournaments: format.tournaments,
    );

StandingsTable zone(RegularSeasonMatches m, String zone) =>
    LeagueZoneTableBuilder.build(
      format: format,
      season: const Season(2026),
      zone: zone,
      matches: m,
      roundsQueried: 36,
    );

void main() {
  test('formato 2026: dos zonas de 18, 36 fechas, art. 112 sin Fair Play '
      'ni sorteo; 2025 sin tablas', () {
    expect(format.zones.keys, ['A', 'B']);
    expect(format.zones.values.map((z) => z.length), [18, 18]);
    expect(format.zones['A']!.intersection(format.zones['B']!), isEmpty);
    expect(format.regularRounds, [for (var r = 1; r <= 36; r++) r]);
    expect(format.tieBreak, [
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
      TieBreakCriterion.headToHead,
    ]);
    expect(format.tieBreak.every((c) => c.isComputable), isTrue);
    expect(nacional.standingsFor(const Season(2025)), isA<NoStandings>());
  });

  group('Nacional 2026 con los partidos grabados (11/10/2026)', () {
    final season = classify(recorded());
    final tables = {
      for (final z in ['A', 'B']) z: zone(season, z),
    };

    test('648 partidos regulares (rondas 1–36), todos ubicados', () {
      expect(season.byTournament.keys, [PhaseKey.regular]);
      expect(season.all, hasLength(648));
      expect(season.undetermined, isEmpty);
    });

    test('las zonas del catálogo coinciden con todos los partidos', () {
      expect(ZoneValidator.validate(format, season).issues, isEmpty);
    });

    test('cada equipo: 34 de su zona y 2 interzonales contra el mismo '
        'rival, en las rondas 7 y 25', () {
      final zoneOf = {
        for (final MapEntry(key: z, value: ids) in format.zones.entries)
          for (final id in ids) id: z,
      };
      final sameZone = <int, int>{};
      final interzonal = <int, List<Match>>{};
      for (final m in season.all) {
        final cross = zoneOf[m.home.id] != zoneOf[m.away.id];
        for (final id in [m.home.id, m.away.id]) {
          if (cross) {
            (interzonal[id] ??= []).add(m);
          } else {
            sameZone.update(id, (n) => n + 1, ifAbsent: () => 1);
          }
        }
      }
      expect(sameZone, hasLength(36));
      expect(sameZone.values.toSet(), {34});
      expect(interzonal, hasLength(36));
      for (final MapEntry(key: id, value: games) in interzonal.entries) {
        expect(games, hasLength(2));
        expect(games.map((m) => m.apiRound).toSet(), {7, 25});
        final rivals = {for (final m in games) m.home.id + m.away.id - id};
        expect(rivals, hasLength(1), reason: '$id');
      }
    });

    test('18 filas por zona; PJ total = 2 × partidos sumados', () {
      for (final table in tables.values) {
        expect(table.rows, hasLength(18));
        expect(table.kind, StandingsKind.zone);
        // 306 de la zona + 36 interzonales.
        expect(table.coverage.scheduled, 342);
        expect(table.coverage.roundsTotal, 36);
        expect(
          table.coverage.counted + table.coverage.uncounted.length,
          table.coverage.scheduled,
        );
      }
      // Cada interzonal entra en las dos zonas: se suma una vez por equipo.
      final played = [
        for (final t in tables.values)
          for (final r in t.rows) r.stats.played,
      ].fold(0, (a, b) => a + b);
      final counted = season.all.where(
        (m) => m.status.isFinished && m.score != null,
      );
      expect(played, 2 * counted.length);
    });

    test('temporada en curso: partidos sin sumar en la cobertura', () {
      for (final table in tables.values) {
        expect(table.coverage.isComplete, isFalse);
        expect({
          for (final u in table.coverage.uncounted) u.reason,
        }, contains(UncountedReason.notPlayed));
      }
    });

    test('títulos, claves y notas con el reglamento citado', () {
      final a = tables['A']!;
      expect(a.key, 'zona-a');
      expect(a.title, 'Posiciones 2026 · Zona A');
      expect(a.shortTitle, 'Zona A');
      final notes = a.notes.join(' ');
      expect(notes, contains('punto 3 del Reglamento del Campeonato de '));
      expect(notes, contains('los interzonales también suman'));
      expect(notes, contains('art. 112 del Reglamento General de AFA'));
      expect(notes, contains('art. 111'));
      expect(notes, contains('la app no los define'));
      expect(notes, isNot(contains('Fair Play')));
      expect(notes, isNot(contains('sorteo')));
      expect(a.notes.last, StandingsNotes.unofficial);
    });

    test('un partido repetido (misma ronda guardada dos veces) cuenta una '
        'vez', () {
      final twice = classify([...recorded(), ...recorded()]);
      expect(zone(twice, 'B').rows, tables['B']!.rows);
    });
  });

  group('contraste con lookuptable (12/10/2026)', () {
    final season = classify(recorded(snapshot: true));
    final tables = {
      for (final z in ['A', 'B']) z: zone(season, z),
    };

    test('las 5 filas coinciden en posición, PJ, Pts, DG y GF', () {
      final table = fixtureJson('lookuptable_4616_s2026')['table'] as List;
      expect(table, hasLength(5));
      for (final raw in table.cast<Map<String, dynamic>>()) {
        // «Group 1» = Zona A; «Group 2» = Zona B (V14).
        final z = raw['strGroup'] == 'Group 1' ? 'A' : 'B';
        final row = tables[z]!.rows.singleWhere(
          (r) => '${r.stats.team.id}' == raw['idTeam'],
        );
        final s = row.stats;
        expect('${row.position}', raw['intRank'], reason: raw['strTeam']);
        expect('${s.played}', raw['intPlayed']);
        expect('${s.won}', raw['intWin']);
        expect('${s.drawn}', raw['intDraw']);
        expect('${s.lost}', raw['intLoss']);
        expect('${s.goalsFor}', raw['intGoalsFor']);
        expect('${s.goalsAgainst}', raw['intGoalsAgainst']);
        expect('${s.points}', raw['intPoints']);
      }
    });

    test('caso real: Tristán Suárez y Temperley con 59, la diferencia de '
        'gol los separa (Zona B)', () {
      final rows = tables['B']!.rows;
      final tristan = rows.singleWhere((r) => r.stats.team.id == 141015);
      final temperley = rows.singleWhere((r) => r.stats.team.id == 135176);
      expect(tristan.stats.points, 59);
      expect(temperley.stats.points, 59);
      expect(
        tristan.stats.goalDifference,
        greaterThan(temperley.stats.goalDifference),
      );
      expect([tristan.position, temperley.position], [1, 2]);
      expect(rows.any((r) => r.isShared), isFalse);
    });
  });

  test('ZoneValidator: un equipo cambiado de zona (armado en el test) se '
      'rechaza sin nombrar un torneo', () {
    final season = classify(recorded());
    // Ferro (Zona A) pasado a la Zona B: armado para probar la regla.
    final a = {...format.zones['A']!}..remove(137774);
    final wrong = LeagueZones(
      zones: {
        'A': a,
        'B': {...format.zones['B']!, 137774},
      },
      regularRounds: format.regularRounds,
      interzonalsPerTeam: format.interzonalsPerTeam,
      tieBreak: format.tieBreak,
      tableArticle: format.tableArticle,
      tieBreakArticle: format.tieBreakArticle,
      relegationNote: format.relegationNote,
      regulation: format.regulation,
    );
    final missing = LeagueZones(
      zones: {'A': a, 'B': format.zones['B']!},
      regularRounds: format.regularRounds,
      interzonalsPerTeam: format.interzonalsPerTeam,
      tieBreak: format.tieBreak,
      tableArticle: format.tableArticle,
      tieBreakArticle: format.tieBreakArticle,
      relegationNote: format.relegationNote,
      regulation: format.regulation,
    );

    expect(
      ZoneValidator.validate(wrong, season).issues,
      contains(
        'Ferro Carril Oeste tiene 34 partidos contra la otra zona (se '
        'esperan 2).',
      ),
    );
    expect(
      ZoneValidator.validate(missing, season).issues,
      contains('Ferro Carril Oeste no tiene zona.'),
    );
  });
}
