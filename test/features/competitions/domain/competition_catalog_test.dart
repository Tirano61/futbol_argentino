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
    expect(CompetitionCatalog.all.map((c) => c.id), [
      4406,
      4616,
      4500,
      5215,
      5524,
      4501,
      4724,
    ]);
    expect(
      CompetitionCatalog.byId(4500),
      same(CompetitionCatalog.copaArgentina),
    );
    expect(CompetitionCatalog.byId(1), isNull);
  });

  group('Fase D2: categorías y vistas', () {
    test('categorías en el orden del selector; sin las vacías', () {
      final byCategory = CompetitionCatalog.byCategory();

      expect(byCategory.keys, [
        CompetitionCategory.firstDivision,
        CompetitionCategory.promotion,
        CompetitionCategory.nationalCup,
        CompetitionCategory.internationalCup,
      ]);
      expect(byCategory.map((k, v) => MapEntry(k, [for (final c in v) c.id])), {
        CompetitionCategory.firstDivision: [4406],
        CompetitionCategory.promotion: [4616, 5215, 5524],
        CompetitionCategory.nationalCup: [4500],
        CompetitionCategory.internationalCup: [4501, 4724],
      });
      // Cada competición en una sola categoría.
      expect(
        byCategory.values.expand((c) => c).length,
        CompetitionCatalog.all.length,
      );
    });

    test('dentro de la categoría, el orden del catálogo recibido', () {
      final byCategory = CompetitionCatalog.byCategory([
        CompetitionCatalog.primeraC,
        CompetitionCatalog.primeraNacional,
      ]);

      expect(byCategory.keys, [CompetitionCategory.promotion]);
      expect(byCategory[CompetitionCategory.promotion]!.map((c) => c.id), [
        5524,
        4616,
      ]);
    });

    test('nombres cortos sin ambigüedad con las copas internacionales', () {
      expect(CompetitionCatalog.copaArgentina.shortName, 'Copa Argentina');
      final shortNames = CompetitionCatalog.all.map((c) => c.shortName);
      expect(shortNames.toSet(), hasLength(shortNames.length));
    });

    test('vistas «Tabla» y «Llaves» solo donde hay formato verificado', () {
      expect(
        {for (final d in CompetitionCatalog.all) d.id: d.hasStandings},
        {
          4406: true,
          4616: true,
          4500: false,
          5215: false,
          5524: false,
          // Tablas de grupos desde la Fase D4.
          4501: true,
          4724: true,
        },
      );
      expect(
        {for (final d in CompetitionCatalog.all) d.id: d.hasBracket},
        {
          4406: true,
          4616: false,
          4500: true,
          5215: false,
          5524: false,
          // Cuadro desde la Fase D5.
          4501: true,
          4724: true,
        },
      );
    });
  });

  test('fases ofrecidas por competición', () {
    expect(primera.phases, [PhaseKey.apertura, PhaseKey.clausura]);
    expect(CompetitionCatalog.primeraNacional.phases, [PhaseKey.regular]);
    expect(CompetitionCatalog.copaArgentina.phases, [PhaseKey.unica]);
  });

  test('cantidad mínima esperada por ronda', () {
    expect(primera.expectedMinimumMatches(const Season(2026), 12), 15);
    expect(primera.expectedMinimumMatches(const Season(2026), 0), isNull);
    expect(
      CompetitionCatalog.primeraNacional.expectedMinimumMatches(
        const Season(2026),
        33,
      ),
      18,
    );
    expect(
      CompetitionCatalog.copaArgentina.expectedMinimumMatches(
        const Season(2026),
        125,
      ),
      4,
    );
    expect(
      CompetitionCatalog.copaArgentina.expectedMinimumMatches(
        const Season(2026),
        999,
      ),
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

  group('Fase D3: copas internacionales', () {
    const libertadores = CompetitionCatalog.copaLibertadores;
    const sudamericana = CompetitionCatalog.copaSudamericana;
    const recordedRounds = {
      (4501, 2025): [400, 1, 2, 3, 4, 5, 6, 16, 125, 150, 200],
      (4501, 2026): [1, 2, 3, 4, 5, 6, 16, 125, 150, 200],
      (4724, 2025): [400, 1, 2, 3, 4, 5, 6, 160, 16, 125, 150, 200],
      (4724, 2026): [1, 2, 3, 4, 5, 6, 32, 16, 125, 150, 200],
    };

    test('fuera del Inicio y del índice; cuadro de octavos a la final', () {
      for (final d in [libertadores, sudamericana]) {
        expect(d.category, CompetitionCategory.internationalCup);
        expect(d.showInHome, isFalse);
        expect(d.inTeamIndex, isFalse);
        expect(d.phases, [
          PhaseKey.qualifying,
          PhaseKey.groups,
          PhaseKey.knockoutStage,
        ]);
        expect(d.bracketPhases, [PhaseKey.knockoutStage]);
        expect(
          [for (final r in d.bracketRounds) (r.label, r.apiRound, r.legs)],
          [
            ('Octavos de final', 16, 2),
            ('Cuartos de final', 125, 2),
            ('Semifinales', 150, 2),
            ('Final', 200, 1),
          ],
        );
      }
    });

    test('Fase D5: cada ronda del cuadro es una etapa de eliminatorias de '
        'cada temporada, con las mismas piernas y llaves', () {
      for (final d in [libertadores, sudamericana]) {
        final rules = d.rules as ContinentalCupRules;
        for (final year in rules.seasons.keys) {
          final season = Season(year);
          for (final r in d.bracketRounds) {
            final stage = rules.stageFor(
              season,
              PhaseKey.knockoutStage,
              r.apiRound,
              StageKind.knockout,
            );
            final reason = '${d.shortName} $year ${r.label}';
            expect(stage, isNotNull, reason: reason);
            expect(stage!.label, r.label, reason: reason);
            expect(stage.legs, r.legs, reason: reason);
            expect(stage.expectedMatches, r.matches * r.legs, reason: reason);
          }
        }
      }
    });

    test('Fase D5: series previas al cuadro (solo los Playoffs de la '
        'Sudamericana) y rondas de la vista «Llaves»', () {
      ContinentalCupRules rules(CompetitionDefinition d) =>
          d.rules as ContinentalCupRules;
      for (final year in [2025, 2026]) {
        expect(rules(libertadores).preliminarySeries(Season(year)), isEmpty);
        expect(libertadores.bracketApiRounds(Season(year)), [
          16,
          125,
          150,
          200,
        ]);
      }
      final playoffs2025 = rules(
        sudamericana,
      ).preliminarySeries(const Season(2025)).single;
      expect(
        (playoffs2025.label, playoffs2025.apiRound, playoffs2025.legs),
        ('Playoffs de octavos', 160, 2),
      );
      expect(
        rules(
          sudamericana,
        ).preliminarySeries(const Season(2026)).single.apiRound,
        32,
      );
      expect(sudamericana.bracketApiRounds(const Season(2025)), [
        160,
        16,
        125,
        150,
        200,
      ]);
      expect(sudamericana.bracketApiRounds(const Season(2026)), [
        32,
        16,
        125,
        150,
        200,
      ]);
      // Sin formato verificado: solo el cuadro.
      expect(sudamericana.bracketApiRounds(const Season(2024)), [
        16,
        125,
        150,
        200,
      ]);
      expect(
        CompetitionCatalog.primeraDivision.bracketApiRounds(const Season(2026)),
        [16, 0],
      );
    });

    test('etapas de cada temporada: identidad única y ventanas que no se '
        'pisan en la misma ronda', () {
      for (final d in [libertadores, sudamericana]) {
        final rules = d.rules as ContinentalCupRules;
        for (final MapEntry(key: year, value: format)
            in rules.seasons.entries) {
          final stages = format.stages;
          final reason = '${d.shortName} $year';
          expect(
            {for (final s in stages) (s.phase, s.apiRound, s.kind)},
            hasLength(stages.length),
            reason: reason,
          );
          for (final s in stages) {
            final sameRound = stages.where((o) => o.apiRound == s.apiRound);
            if (!s.verified) {
              // Sin ventana solo si es la única etapa de la ronda.
              expect(sameRound, hasLength(1), reason: '$reason r${s.apiRound}');
              continue;
            }
            for (final o in sameRound.where((o) => !identical(o, s))) {
              expect(s.to, isNotNull, reason: '$reason ${s.label}');
              expect(o.to, isNotNull, reason: '$reason ${o.label}');
              expect(
                s.to!.isBefore(o.from!) || o.to!.isBefore(s.from!),
                isTrue,
                reason: '$reason: ${s.label} y ${o.label}',
              );
            }
          }
        }
      }
    });

    for (final MapEntry(key: (id, year), value: rounds)
        in recordedRounds.entries) {
      test('$id $year: cada partido grabado cae en exactamente una etapa', () {
        final definition = CompetitionCatalog.byId(id)!;
        final rules = definition.rules as ContinentalCupRules;
        final season = Season(year);
        final counts = <ContinentalStage, int>{};
        for (final r in rounds) {
          final matches = fixtureMatches('eventsround_${id}_r${r}_s$year');
          for (final m in matches) {
            final day = m.kickoff.argentinaDay!;
            final matching = [
              for (final s in rules.stagesOf(season))
                if (s.apiRound == m.apiRound && s.contains(day)) s,
            ];
            expect(matching, hasLength(1), reason: '${m.id} r$r $day');
            counts[matching.single] = (counts[matching.single] ?? 0) + 1;
          }
          if (matches.isNotEmpty) {
            expect(
              matches,
              hasLength(definition.expectedMinimumMatches(season, r)!),
              reason: 'r$r: los partidos esperados de sus etapas',
            );
          }
        }
        // Cada etapa con datos tiene todos sus partidos; la final 2026 no
        // tiene datos todavía.
        for (final s in rules.stagesOf(season)) {
          expect(
            counts[s] ?? 0,
            s.verified ? s.expectedMatches : 0,
            reason: s.label,
          );
        }
      });
    }

    test('las rondas compartidas suman las dos etapas (calidad)', () {
      const s2026 = Season(2026);
      expect(libertadores.expectedMinimumMatches(s2026, 1), 22);
      expect(libertadores.expectedMinimumMatches(s2026, 2), 32);
      expect(libertadores.expectedMinimumMatches(s2026, 3), 24);
      expect(libertadores.expectedMinimumMatches(s2026, 16), 16);
      expect(sudamericana.expectedMinimumMatches(s2026, 1), 32);
      expect(sudamericana.expectedMinimumMatches(s2026, 32), 16);
      expect(sudamericana.expectedMinimumMatches(s2026, 160), isNull);
      expect(sudamericana.expectedMinimumMatches(const Season(2025), 160), 16);
      // Temporada sin formato verificado.
      expect(
        libertadores.expectedMinimumMatches(const Season(2024), 1),
        isNull,
      );
    });
  });

  group('Fase 15: competiciones nuevas (V8)', () {
    const bMetro = CompetitionCatalog.primeraBMetropolitana;
    const primeraC = CompetitionCatalog.primeraC;

    test('fuera del Inicio y del índice de equipos: presupuestos intactos', () {
      expect(
        [
          for (final d in CompetitionCatalog.all)
            if (d.showInHome) d.id,
        ],
        [4406, 4616, 4500],
      );
      expect(
        [
          for (final d in CompetitionCatalog.all)
            if (d.inTeamIndex) d.id,
        ],
        [4406, 4616, 4500],
      );
    });

    test('sin tabla hasta investigar su formato', () {
      for (final d in [bMetro, primeraC]) {
        for (final year in [2025, 2026]) {
          expect(d.standingsFor(Season(year)), isA<NoStandings>());
        }
      }
    });

    test('una sola fase regular', () {
      expect(bMetro.phases, [PhaseKey.regular]);
      expect(primeraC.phases, [PhaseKey.regular]);
    });

    // Cada equipo juega una vez por fecha: la cantidad de partidos por
    // fecha del catálogo es la mitad de los equipos.
    for (final (definition, rounds, teams) in [
      (bMetro, [1, 39, 40, 42], 22),
      (primeraC, [1, 32], 28),
    ]) {
      test('${definition.name}: partidos por fecha según los datos', () {
        for (final r in rounds) {
          final events = fixtureEvents(
            'eventsround_${definition.id}_r${r}_s2026',
          );
          expect(
            events,
            hasLength(
              definition.expectedMinimumMatches(const Season(2026), r)!,
            ),
            reason: 'fecha $r',
          );
          final ids = {
            for (final e in events) ...[e['idHomeTeam'], e['idAwayTeam']],
          };
          expect(ids, hasLength(teams), reason: 'fecha $r');
        }
      });
    }

    test('B Metro 2026: 42 fechas (la 43 vuelve vacía)', () {
      final rules = bMetro.rules as SingleTableLeagueRules;
      expect(rules.regularRoundsBySeason[2026], 42);
      expect(fixtureEvents('eventsround_5215_r42_s2026'), hasLength(11));
      expect(fixtureEvents('eventsround_5215_r43_s2026'), isEmpty);
    });

    test('2025 sin cantidad de fechas: la fecha 1 mezcla dos torneos', () {
      final rules = bMetro.rules as SingleTableLeagueRules;
      expect(rules.regularRoundsBySeason[2025], isNull);
      expect(fixtureEvents('eventsround_5215_r1_s2025'), hasLength(20));
    });
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
