import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/home/domain/entities/home_feed.dart';
import 'package:futbol_argentino/features/home/presentation/widgets/home_match_list.dart';
import 'package:futbol_argentino/features/matches/domain/services/match_grouping.dart';

import '../../helpers/recorded_home.dart';

/// Partidos reales de las rondas del Inicio, en orden cronológico, con un
/// contexto por competición y ronda (como el de `GetHomeFeed`).
List<HomeMatch> recordedHomeMatches() {
  final matches = [for (final round in recordedRounds().values) ...round]
    ..sort(MatchGrouping.compare);
  return [
    for (final m in matches)
      HomeMatch(
        match: m,
        competitionName: m.competitionName,
        stageLabel: 'Fecha ${m.apiRound}',
      ),
  ];
}

void main() {
  final matches = recordedHomeMatches();
  final days = HomeGrouping.byDay(matches);
  List<HomeMatch> flat(List<HomeMatchDay> days) => [
    for (final d in days)
      for (final g in d.groups) ...g.matches,
  ];

  test('cada partido queda en un solo grupo: ni repetidos ni omitidos', () {
    final grouped = flat(days);
    expect(grouped, hasLength(matches.length));
    expect(grouped.toSet(), matches.toSet());
  });

  test('un día por fecha argentina, en orden, y un grupo por contexto', () {
    expect([
      for (final d in days) d.day,
    ], {for (final m in matches) m.match.kickoff.argentinaDay}.toList());
    for (final d in days) {
      final titles = [
        for (final g in d.groups) '${g.competitionName} · ${g.detail}',
      ];
      expect(titles.toSet(), hasLength(titles.length));
      for (final g in d.groups) {
        for (final m in g.matches) {
          expect(m.match.kickoff.argentinaDay, d.day);
          expect(m.competitionName, g.competitionName);
          expect(m.stageLabel, g.detail);
        }
      }
    }
  });

  test('dentro de cada grupo se conserva el orden cronológico, y los grupos '
      'van en el orden de su primer partido', () {
    final position = {for (final (i, m) in matches.indexed) m.match.id: i};
    for (final d in days) {
      final firsts = [
        for (final g in d.groups) position[g.matches.first.match.id]!,
      ];
      expect(firsts, orderedEquals([...firsts]..sort()));
      for (final g in d.groups) {
        final order = [for (final m in g.matches) position[m.match.id]!];
        expect(order, orderedEquals([...order]..sort()));
      }
    }
  });

  test('un partido repetido se muestra una vez', () {
    final repeated = HomeGrouping.byDay([...matches, matches.first]);
    expect(flat(repeated), hasLength(matches.length));
  });

  test('la fase va en el detalle, antes de la etapa', () {
    final m = matches.first;
    final group = HomeGrouping.byDay([
      HomeMatch(
        match: m.match,
        competitionName: 'Primera División',
        phaseLabel: 'Clausura',
        stageLabel: 'Fecha 12',
      ),
    ]).single.groups.single;
    expect(group.competitionName, 'Primera División');
    expect(group.detail, 'Clausura · Fecha 12');
  });

  test('sin partidos, sin días', () {
    expect(HomeGrouping.byDay(const []), isEmpty);
  });
}
