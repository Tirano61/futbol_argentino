import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/fixture_matches.dart';

void main() {
  const primera = CompetitionCatalog.primeraDivision;
  final rules = primera.rules as SplitSeasonLeagueRules;

  test('IDs verificados y búsqueda por id', () {
    expect(CompetitionCatalog.all.map((c) => c.id), [4406, 4616, 4500]);
    expect(
      CompetitionCatalog.byId(4500),
      same(CompetitionCatalog.copaArgentina),
    );
    expect(CompetitionCatalog.byId(1), isNull);
  });

  test('fases ofrecidas por competición', () {
    expect(primera.phases, [PhaseKey.apertura, PhaseKey.clausura]);
    expect(CompetitionCatalog.primeraNacional.phases, [PhaseKey.regular]);
    expect(CompetitionCatalog.copaArgentina.phases, [PhaseKey.unica]);
  });

  test('cantidad mínima esperada por ronda', () {
    expect(primera.expectedMinimumMatches(12), 15);
    expect(primera.expectedMinimumMatches(0), isNull);
    expect(CompetitionCatalog.primeraNacional.expectedMinimumMatches(33), 18);
    expect(CompetitionCatalog.copaArgentina.expectedMinimumMatches(125), 4);
    expect(
      CompetitionCatalog.copaArgentina.expectedMinimumMatches(999),
      isNull,
    );
  });

  test('las ventanas de cada temporada no se superponen', () {
    for (final entry in rules.windowsBySeason.entries) {
      final windows = entry.value;
      for (var i = 0; i < windows.length - 1; i++) {
        final last = windows[i].lastDay;
        expect(
          last,
          isNotNull,
          reason: '${entry.key}: solo el último puede estar en curso',
        );
        expect(last!.isBefore(windows[i + 1].regularFrom), isTrue);
      }
    }
  });

  for (final year in [2025, 2026]) {
    test('cada partido real de Primera $year cae en exactamente un torneo', () {
      final windows = rules.windowsBySeason[year]!;
      var checked = 0;
      for (var round = 0; round <= 16; round++) {
        for (final e in fixtureEvents('eventsround_4406_r${round}_s$year')) {
          final CalendarDay day = resolveEvent(e).argentinaDay!;
          final matching = windows.where((w) => w.containsInSpan(day)).toList();
          expect(matching, hasLength(1), reason: '${e['idEvent']} $day');
          checked++;
        }
      }
      expect(checked, year == 2026 ? 495 : 480);
    });
  }

  test('ventanas de eliminatorias 2026: octavos y ronda 0 del Apertura', () {
    final apertura = rules.windowsBySeason[2026]!.first;
    for (final e in fixtureEvents('eventsround_4406_r0_s2026')) {
      expect(
        apertura.containsInKnockout(resolveEvent(e).argentinaDay!),
        isTrue,
      );
    }
    expect(apertura.containsInKnockout(const CalendarDay(2026, 5, 4)), isFalse);
    expect(apertura.containsInRegular(const CalendarDay(2026, 5, 4)), isTrue);
  });

  test('Season', () {
    expect(Season.tryParse('2026'), const Season(2026));
    expect(Season.tryParse('2021-2022'), isNull);
    expect(const Season(2026).apiValue, '2026');
    expect(CompetitionCatalog.supportedSeasons(const Season(2026)), [
      const Season(2026),
      const Season(2025),
    ]);
  });
}
