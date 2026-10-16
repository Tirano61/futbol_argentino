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

/// Fase D4: tablas de grupos de Libertadores y Sudamericana con las rondas
/// grabadas el 14/10/2026 (D1).
const libertadores = CompetitionCatalog.copaLibertadores;
const sudamericana = CompetitionCatalog.copaSudamericana;

GroupStage formatOf(CompetitionDefinition cup, int year) =>
    cup.standingsFor(Season(year)) as GroupStage;

/// Rondas 1–6 grabadas (en 2026 traen también las fases previas).
List<Match> groupRounds(CompetitionDefinition cup, int year) => [
  for (var r = 1; r <= 6; r++)
    ...fixtureMatches('eventsround_${cup.id}_r${r}_s$year'),
];

RegularSeasonMatches classify(
  CompetitionDefinition cup,
  int year,
  List<Match> matches, {
  GroupStage? format,
}) {
  final f = format ?? formatOf(cup, year);
  return RegularSeasonMatches.classify(
    definition: cup,
    season: Season(year),
    matches: matches,
    rounds: f.regularRounds,
    tournaments: f.tournaments,
  );
}

StandingsTable groupTable(
  CompetitionDefinition cup,
  int year,
  RegularSeasonMatches matches,
  String group, {
  GroupStage? format,
}) => GroupTableBuilder.build(
  format: format ?? formatOf(cup, year),
  season: Season(year),
  group: group,
  matches: matches,
  roundsQueried: 6,
);

/// `idTeam` de los equipos de las rondas grabadas de [cup] en [year].
Set<int> teamsIn(CompetitionDefinition cup, int year, List<int> rounds) => {
  for (final r in rounds)
    for (final m in fixtureMatches('eventsround_${cup.id}_r${r}_s$year')) ...[
      m.home.id,
      m.away.id,
    ],
};

List<String> order(StandingsTable table) => [
  for (final r in table.rows)
    '${r.position}${r.isShared ? '=' : ''} ${r.stats.team.name}',
];

/// Los partidos hasta el día argentino [month]/[day] de 2026, inclusive.
List<Match> until(List<Match> matches, int month, int day) => [
  for (final m in matches)
    if (m.kickoff.argentinaDay case final d?
        when d.month < month || (d.month == month && d.day <= day))
      m,
];

/// [format] con otros criterios de desempate (armado en el test).
GroupStage withTieBreak(GroupStage format, List<TieBreakCriterion> c) =>
    GroupStage(
      groups: format.groups,
      regularRounds: format.regularRounds,
      tieBreak: c,
      pointsArticle: format.pointsArticle,
      tieBreakArticle: format.tieBreakArticle,
      qualificationNote: format.qualificationNote,
      regulation: format.regulation,
    );

void main() {
  test('formatos: 2025 sin enfrentamiento directo y con goles de '
      'visitante; 2026 con el directo una sola vez', () {
    for (final cup in [libertadores, sudamericana]) {
      final f2025 = formatOf(cup, 2025);
      final f2026 = formatOf(cup, 2026);
      expect(f2025.tieBreak.take(3), [
        TieBreakCriterion.goalDifference,
        TieBreakCriterion.goalsFor,
        TieBreakCriterion.awayGoalsFor,
      ]);
      expect(f2025.tieBreak.whereType<HeadToHeadCriterion>(), isEmpty);
      expect(f2026.tieBreak.take(3), [
        TieBreakCriterion.headToHeadOnce,
        TieBreakCriterion.goalDifference,
        TieBreakCriterion.goalsFor,
      ]);
      for (final f in [f2025, f2026]) {
        expect(f.groups.keys, ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']);
        expect(f.groups.values.every((g) => g.length == 4), isTrue);
        expect(f.groups.values.expand((g) => g).toSet(), hasLength(32));
        expect(f.regularRounds, [1, 2, 3, 4, 5, 6]);
        expect(f.interzonalsPerTeam, 0);
        expect(f.tournaments, [PhaseKey.groups]);
      }
    }
    expect(
      formatOf(libertadores, 2026).regulation.name,
      'Manual de Clubes CONMEBOL Libertadores 2026',
    );
    expect(formatOf(sudamericana, 2025).tieBreakArticle, '2.4.3');
  });

  for (final cup in [libertadores, sudamericana]) {
    for (final year in [2025, 2026]) {
      group('${cup.shortName} $year con los partidos grabados', () {
        final matches = classify(cup, year, groupRounds(cup, year));
        final format = formatOf(cup, year);
        final tables = {
          for (final g in format.groups.keys)
            g: groupTable(cup, year, matches, g),
        };

        test('96 partidos de grupos, sin las previas que comparten '
            'ronda', () {
          expect(matches.byTournament[PhaseKey.groups], hasLength(96));
          expect(matches.undetermined, isEmpty);
        });

        test('los grupos del catálogo coinciden con todos los partidos', () {
          final validation = ZoneValidator.validate(format, matches);
          expect(validation.issues, isEmpty);
          expect(validation.invalidZones, isEmpty);
        });

        test('`strGroup` (cuando la API lo trae) coincide con el '
            'catálogo', () {
          var checked = 0;
          for (var r = 1; r <= 6; r++) {
            for (final e in fixtureEvents(
              'eventsround_${cup.id}_r${r}_s$year',
            )) {
              final group = e['strGroup'] as String?;
              if (group == null || group.isEmpty) continue;
              for (final key in ['idHomeTeam', 'idAwayTeam']) {
                final id = int.parse(e[key] as String);
                expect(format.groups[group], contains(id), reason: '$id');
              }
              checked++;
            }
          }
          // Libertadores 2026 solo lo trae en la ronda 2.
          expect(checked, cup == libertadores && year == 2026 ? 16 : 96);
        });

        test('8 tablas completas: 4 filas de 6 PJ, 12 partidos', () {
          for (final table in tables.values) {
            expect(table.rows, hasLength(4));
            expect(table.rows.every((r) => r.stats.played == 6), isTrue);
            expect(table.coverage.isComplete, isTrue);
            expect(table.coverage.scheduled, 12);
            expect(table.coverage.roundsTotal, 6);
          }
        });

        test('el orden coincide con la etapa que jugó después cada '
            'equipo', () {
          // Libertadores: 1.º y 2.º a octavos (16), 3.º a los playoffs de la
          // Sudamericana; Sudamericana: 1.º a octavos, 2.º a los playoffs.
          final playoffs = teamsIn(sudamericana, year, [
            year == 2025 ? 160 : 32,
          ]);
          final octavos = teamsIn(cup, year, [16]);
          final direct = cup == libertadores ? 2 : 1;
          for (final MapEntry(key: group, value: table) in tables.entries) {
            for (final row in table.rows) {
              final id = row.stats.team.id;
              // La primera etapa después de los grupos (el 2.º de la
              // Sudamericana que gana los playoffs también juega octavos).
              final next = playoffs.contains(id)
                  ? 'playoffs'
                  : octavos.contains(id)
                  ? 'octavos'
                  : '—';
              expect(
                next,
                row.position <= direct
                    ? 'octavos'
                    : row.position == direct + 1
                    ? 'playoffs'
                    : '—',
                reason: 'Grupo $group: ${row.stats.team.name}',
              );
              // Ningún empate sin resolver en la línea de clasificación.
              if (row.position <= direct + 1) {
                expect(row.isShared, isFalse);
              }
            }
          }
        });

        test('títulos, claves y notas con el reglamento citado', () {
          final a = tables['A']!;
          expect(a.key, 'grupo-a');
          expect(a.shortTitle, 'Grupo A');
          expect(a.title, 'Fase de grupos $year · Grupo A');
          expect(
            a.notes.first,
            'Puntos de las 6 fechas de la fase de grupos: 3 por ganar y 1 '
            'por empatar (2.4.1 del ${format.regulation.name}).',
          );
          expect(a.notes, contains(format.qualificationNote));
          expect(a.notes.last, StandingsNotes.unofficial);
        });
      });
    }
  }

  group('Libertadores 2026: casos reales', () {
    final all = groupRounds(libertadores, 2026);
    final rule2026 = formatOf(libertadores, 2026);
    // La regla 2025 aplicada a 2026 (armado en el test, para contrastar).
    final rule2025 = withTieBreak(
      rule2026,
      formatOf(libertadores, 2025).tieBreak,
    );

    test('Grupo G completo: LDU y Mirassol con 12 puntos y la misma DG; '
        'los separa el partido entre ellos', () {
      final table = groupTable(
        libertadores,
        2026,
        classify(libertadores, 2026, all),
        'G',
      );
      expect(order(table), [
        '1 LDU Quito',
        '2 Mirassol',
        '3 Lanús',
        '4 Always Ready',
      ]);
      expect(table.rows[0].stats.points, 12);
      expect(table.rows[1].stats.points, 12);
      expect(table.notes[1], contains('una sola vez'));
    });

    test('Grupo G al 05/05 (prensa): LDU, Lanús, Mirassol con 6 puntos; '
        'con la regla 2025 Mirassol iría segundo', () {
      final partial = classify(libertadores, 2026, until(all, 5, 5));
      expect(order(groupTable(libertadores, 2026, partial, 'G')).take(3), [
        '1 LDU Quito',
        '2 Lanús',
        '3 Mirassol',
      ]);
      expect(
        order(
          groupTable(libertadores, 2026, partial, 'G', format: rule2025),
        ).take(3),
        ['1 LDU Quito', '2 Mirassol', '3 Lanús'],
      );
      // Re-aplicar el directo con los que siguen empatados no cambia nada
      // en este caso (D1).
      final reapplied = withTieBreak(rule2026, [
        TieBreakCriterion.headToHead,
        ...rule2026.tieBreak.skip(1),
      ]);
      expect(
        order(groupTable(libertadores, 2026, partial, 'G', format: reapplied)),
        order(groupTable(libertadores, 2026, partial, 'G')),
      );
    });

    test('Grupo D al 30/04 (prensa): U. Católica primero y Boca segundo '
        'pese a su mejor diferencia de gol', () {
      final partial = classify(libertadores, 2026, until(all, 4, 30));
      final table = groupTable(libertadores, 2026, partial, 'D');
      expect(order(table).take(2), [
        '1 Universidad Católica',
        '2 Boca Juniors',
      ]);
      expect(
        table.rows[1].stats.goalDifference,
        greaterThan(table.rows[0].stats.goalDifference),
      );
      expect(
        order(
          groupTable(libertadores, 2026, partial, 'D', format: rule2025),
        ).first,
        '1 Boca Juniors',
      );
    });

    test('el partido ganado por `AWD` suma con su resultado', () {
      final matches = classify(libertadores, 2026, all);
      final awd = matches.byTournament[PhaseKey.groups]!.singleWhere(
        (m) => m.status.raw == 'AWD',
      );
      expect(awd.score, isNotNull);
      final a = groupTable(libertadores, 2026, matches, 'A');
      expect(a.coverage.uncounted, isEmpty);
      expect(a.coverage.counted, 12);
    });
  });

  test('Libertadores 2025: el `WO` suma con su resultado', () {
    final matches = classify(
      libertadores,
      2025,
      groupRounds(libertadores, 2025),
    );
    final wo = matches.byTournament[PhaseKey.groups]!.singleWhere(
      (m) => m.status.raw == 'WO',
    );
    expect(wo.score, isNotNull);
    final format = formatOf(libertadores, 2025);
    final group = format.groups.entries
        .singleWhere((e) => e.value.contains(wo.home.id))
        .key;
    expect(
      groupTable(libertadores, 2025, matches, group).coverage.isComplete,
      isTrue,
    );
  });

  test('ZoneValidator: un equipo cambiado de grupo (armado en el test) '
      'invalida solo los dos grupos involucrados', () {
    final format = formatOf(libertadores, 2026);
    // Boca (Grupo D) pasado al Grupo A: armado para probar la regla.
    final wrong = GroupStage(
      groups: {
        for (final MapEntry(key: g, value: ids) in format.groups.entries)
          g: switch (g) {
            'A' => {...ids, 135156},
            'D' => {...ids}..remove(135156),
            _ => ids,
          },
      },
      regularRounds: format.regularRounds,
      tieBreak: format.tieBreak,
      pointsArticle: format.pointsArticle,
      tieBreakArticle: format.tieBreakArticle,
      qualificationNote: format.qualificationNote,
      regulation: format.regulation,
    );
    final matches = classify(
      libertadores,
      2026,
      groupRounds(libertadores, 2026),
      format: wrong,
    );

    final validation = ZoneValidator.validate(wrong, matches);
    expect(validation.isValid, isFalse);
    expect(validation.invalidZones, {'A', 'D'});
    expect(
      validation.issues,
      contains(
        'Boca Juniors tiene 6 partidos contra otro grupo (se esperan 0).',
      ),
    );
  });
}
