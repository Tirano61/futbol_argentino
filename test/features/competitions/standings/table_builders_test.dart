import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/regular_season_matches.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/standings_table.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/table_builders.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/team_stats.dart';
import 'package:futbol_argentino/features/competitions/domain/standings/zone_validator.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';

const primera = CompetitionCatalog.primeraDivision;
final format =
    primera.standingsFor(const Season(2026)) as LeagueZonesWithAnnual;

/// Rondas 0–16 grabadas el 11/10/2026 (incluyen ronda 0 y octavos).
List<Match> recorded(int year) => [
  for (var r = 0; r <= 16; r++)
    ...fixtureMatches('eventsround_4406_r${r}_s$year'),
];

RegularSeasonMatches classify(int year, List<Match> matches) =>
    RegularSeasonMatches.classify(
      definition: primera,
      season: Season(year),
      matches: matches,
      rounds: format.regularRounds,
      tournaments: format.tournaments,
    );

StandingsTable zone(RegularSeasonMatches m, PhaseKey t, String zone) =>
    ZoneTableBuilder.build(
      format: format,
      season: const Season(2026),
      tournament: t,
      zone: zone,
      matches: m,
      roundsQueried: 16,
    );

TeamStats statsOf(StandingsTable table, int teamId) =>
    table.rows.singleWhere((r) => r.stats.team.id == teamId).stats;

void main() {
  group('Primera 2026 con los partidos grabados (11/10/2026)', () {
    final matches = recorded(2026);
    final season = classify(2026, matches);
    final annual = AnnualTableBuilder.build(
      format: format,
      season: const Season(2026),
      matches: season,
      roundsQueried: 16,
    );
    final zones = {
      for (final t in format.tournaments)
        for (final z in ['A', 'B']) (t, z): zone(season, t, z),
    };

    test('partidos regulares: 240 por torneo, sin la ronda 0 ni octavos', () {
      expect(season.byTournament[PhaseKey.apertura], hasLength(240));
      expect(season.byTournament[PhaseKey.clausura], hasLength(240));
      expect(season.undetermined, isEmpty);
      final counted = season.all.map((m) => m.id).toSet();
      for (final m in fixtureMatches('eventsround_4406_r0_s2026')) {
        expect(counted, isNot(contains(m.id)));
      }
      // Octavos del Apertura: los 8 partidos de mayo de la ronda 16.
      final octavos = [
        for (final m in fixtureMatches('eventsround_4406_r16_s2026'))
          if (m.kickoff.argentinaDay!.month == 5) m,
      ];
      expect(octavos, hasLength(8));
      expect(counted.intersection({for (final m in octavos) m.id}), isEmpty);
    });

    test('Tabla Anual: 30 filas; PJ total = 2 × partidos sumados', () {
      expect(annual.rows, hasLength(30));
      final played = annual.rows.fold(0, (n, r) => n + r.stats.played);
      expect(played, 2 * annual.coverage.counted);
      expect(played.isEven, isTrue);
      expect(annual.rows.map((r) => r.position).first, 1);
    });

    test('Tabla Anual = zona del Apertura + zona del Clausura', () {
      for (final row in annual.rows) {
        final id = row.stats.team.id;
        final parts = [
          for (final t in format.tournaments)
            for (final z in ['A', 'B'])
              if (format.zones[t]![z]!.contains(id))
                statsOf(zones[(t, z)]!, id),
        ];
        expect(parts, hasLength(2));
        expect(row.stats.played, parts[0].played + parts[1].played);
        expect(row.stats.points, parts[0].points + parts[1].points);
        expect(row.stats.goalsFor, parts[0].goalsFor + parts[1].goalsFor);
        expect(
          row.stats.goalsAgainst,
          parts[0].goalsAgainst + parts[1].goalsAgainst,
        );
      }
    });

    test('zonas del Apertura completas: 15 filas, 16 PJ cada uno', () {
      for (final z in ['A', 'B']) {
        final table = zones[(PhaseKey.apertura, z)]!;
        expect(table.rows, hasLength(15));
        expect(table.rows.every((r) => r.stats.played == 16), isTrue);
        expect(table.coverage.uncounted, isEmpty);
        expect(table.coverage.isComplete, isTrue);
        // 105 de la zona + 30 interzonales.
        expect(table.coverage.scheduled, 135);
      }
    });

    test('Clausura parcial: cobertura con los partidos sin sumar', () {
      for (final z in ['A', 'B']) {
        final table = zones[(PhaseKey.clausura, z)]!;
        expect(table.rows, hasLength(15));
        expect(table.coverage.scheduled, 135);
        expect(table.coverage.counted, lessThan(135));
        expect(
          table.coverage.counted + table.coverage.uncounted.length,
          table.coverage.scheduled,
        );
        expect(table.coverage.isComplete, isFalse);
      }
      final reasons = {
        for (final z in ['A', 'B'])
          for (final u in zones[(PhaseKey.clausura, z)]!.coverage.uncounted)
            u.reason,
      };
      expect(reasons, containsAll([UncountedReason.notPlayed]));
    });

    test('PJ por equipo en la anual = 16 del Apertura + jugados del '
        'Clausura', () {
      for (final row in annual.rows) {
        final id = row.stats.team.id;
        final clausura = season.byTournament[PhaseKey.clausura]!.where(
          (m) => m.involvesTeam(id) && StatsAccumulator.counts(m),
        );
        expect(row.stats.played, 16 + clausura.length);
      }
    });

    test('Apertura: coincide con lookuptable (5 filas, 12/10/2026)', () {
      final table = fixtureJson('lookuptable_4406_s2026')['table'] as List;
      for (final raw in table.cast<Map<String, dynamic>>()) {
        final z = (raw['strGroup'] as String).endsWith('A') ? 'A' : 'B';
        final t = zones[(PhaseKey.apertura, z)]!;
        final row = t.rows.singleWhere(
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

    test('notas: reglamento citado; la anual sin enfrentamiento directo', () {
      expect(annual.notes.join(' '), contains('art. 24'));
      expect(annual.notes.join(' '), contains('Sin partidos entre los'));
      expect(annual.notes.join(' '), contains('la app no los define'));
      expect(
        zones[(PhaseKey.apertura, 'A')]!.notes.join(' '),
        contains('art. 9 y 10'),
      );
      expect(
        zones[(PhaseKey.clausura, 'B')]!.notes.join(' '),
        contains('art. 15 y 16'),
      );
      for (final t in [annual, ...zones.values]) {
        expect(t.notes, contains(StandingsNotes.unofficial));
      }
    });

    test('caso real: empate en puntos y DG que separan los goles a favor '
        '(Clausura, Zona B, al 11/10)', () {
      final rows = zones[(PhaseKey.clausura, 'B')]!.rows;
      final sarmiento = rows.singleWhere((r) => r.stats.team.id == 135175);
      final central = rows.singleWhere((r) => r.stats.team.id == 135172);
      expect(sarmiento.stats.points, central.stats.points);
      expect(sarmiento.stats.goalDifference, central.stats.goalDifference);
      expect(sarmiento.stats.goalsFor, greaterThan(central.stats.goalsFor));
      expect(sarmiento.position, central.position - 1);
      expect(rows.any((r) => r.isShared), isFalse);
    });

    test('las zonas del catálogo coinciden con todos los partidos', () {
      expect(ZoneValidator.validate(format, season).issues, isEmpty);
    });

    test('un partido repetido (misma ronda guardada dos veces) cuenta una '
        'vez', () {
      final twice = classify(2026, [...matches, ...matches]);
      final again = AnnualTableBuilder.build(
        format: format,
        season: const Season(2026),
        matches: twice,
        roundsQueried: 16,
      );
      expect(again.rows, annual.rows);
    });
  });

  test('ZoneValidator: zonas cambiadas (armadas en el test) se rechazan', () {
    final season = classify(2026, recorded(2026));
    // Boca (Zona A) pasado a la Zona B: armado para probar la regla.
    final a = {...format.zones[PhaseKey.apertura]!['A']!}..remove(135156);
    final b = {...format.zones[PhaseKey.apertura]!['B']!, 135156};
    final wrong = LeagueZonesWithAnnual(
      zones: {
        PhaseKey.apertura: {'A': a, 'B': b},
      },
      regularRounds: format.regularRounds,
      interzonalsPerTeam: format.interzonalsPerTeam,
      zoneTieBreak: format.zoneTieBreak,
      annualTieBreak: format.annualTieBreak,
      zoneArticles: format.zoneArticles,
      annualArticle: format.annualArticle,
      regulation: format.regulation,
    );
    final missing = LeagueZonesWithAnnual(
      zones: {
        PhaseKey.apertura: {
          'A': a,
          'B': format.zones[PhaseKey.apertura]!['B']!,
        },
      },
      regularRounds: format.regularRounds,
      interzonalsPerTeam: format.interzonalsPerTeam,
      zoneTieBreak: format.zoneTieBreak,
      annualTieBreak: format.annualTieBreak,
      zoneArticles: format.zoneArticles,
      annualArticle: format.annualArticle,
      regulation: format.regulation,
    );

    expect(
      ZoneValidator.validate(wrong, season).issues,
      contains(startsWith('Boca Juniors tiene')),
    );
    expect(
      ZoneValidator.validate(missing, season).issues,
      contains('Boca Juniors no tiene zona en el Apertura.'),
    );
  });

  group('invariantes con los partidos de 2025 (sin formato en el '
      'catálogo: solo para probar los constructores)', () {
    final season = classify(2025, recorded(2025));
    final annual = AnnualTableBuilder.build(
      format: format,
      season: const Season(2025),
      matches: season,
      roundsQueried: 16,
    );

    test('480 partidos regulares, todos sumados una vez', () {
      expect(season.all, hasLength(480));
      expect(annual.coverage.counted, 480);
      expect(annual.rows, hasLength(30));
      expect(annual.rows.fold(0, (n, r) => n + r.stats.played), 2 * 480);
      expect(annual.rows.every((r) => r.stats.played == 32), isTrue);
    });

    test('el formato 2025 no tiene tablas', () {
      expect(primera.standingsFor(const Season(2025)), isA<NoStandings>());
      expect(
        CompetitionCatalog.copaArgentina.standingsFor(const Season(2026)),
        isA<NoStandings>(),
      );
      expect(
        CompetitionCatalog.primeraNacional.standingsFor(const Season(2026)),
        isA<NoStandings>(),
      );
    });
  });
}
