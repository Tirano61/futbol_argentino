import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/stage.dart';
import 'package:futbol_argentino/features/competitions/domain/services/round_navigator.dart';
import 'package:futbol_argentino/features/competitions/domain/services/stage_labeler.dart';

import '../../../helpers/fixture_matches.dart';

void main() {
  const primera = CompetitionCatalog.primeraDivision;
  const nacional = CompetitionCatalog.primeraNacional;
  const copa = CompetitionCatalog.copaArgentina;
  const s2026 = Season(2026);

  group('StageLabeler', () {
    test('ligas: «Fecha N»', () {
      expect(
        StageLabeler.label(
          primera,
          s2026,
          PhaseKey.apertura,
          12,
          StageKind.regular,
        ),
        'Fecha 12',
      );
      expect(
        StageLabeler.label(
          nacional,
          s2026,
          PhaseKey.regular,
          33,
          StageKind.regular,
        ),
        'Fecha 33',
      );
    });

    test('eliminatorias de Primera', () {
      expect(
        StageLabeler.label(
          primera,
          s2026,
          PhaseKey.apertura,
          16,
          StageKind.knockout,
        ),
        'Octavos de final',
      );
      expect(
        StageLabeler.label(
          primera,
          s2026,
          PhaseKey.apertura,
          0,
          StageKind.knockout,
        ),
        'Cuartos, semifinales y final',
      );
    });

    test('Copa por código, y código desconocido', () {
      expect(
        StageLabeler.label(copa, s2026, PhaseKey.unica, 64, StageKind.knockout),
        '32avos de final',
      );
      expect(
        StageLabeler.label(
          copa,
          s2026,
          PhaseKey.unica,
          125,
          StageKind.knockout,
        ),
        'Cuartos de final',
      );
      expect(
        StageLabeler.label(
          copa,
          s2026,
          PhaseKey.unica,
          150,
          StageKind.knockout,
        ),
        'Semifinales',
      );
      expect(
        StageLabeler.label(
          copa,
          s2026,
          PhaseKey.unica,
          175,
          StageKind.knockout,
        ),
        'Ronda 175',
      );
    });
  });

  group('RoundNavigator', () {
    test('Apertura 2026: 16 fechas + octavos + eliminatorias', () {
      final stages = RoundNavigator.stagesFor(
        primera,
        const Season(2026),
        PhaseKey.apertura,
      );

      expect(stages, hasLength(18));
      expect(stages.first.label, 'Fecha 1');
      expect(stages[15].label, 'Fecha 16');
      expect(stages[16].label, 'Octavos de final');
      expect(stages[16].apiRound, 16);
      expect(stages[17].apiRound, 0);
      expect(stages.map((s) => s.order), List.generate(18, (i) => i));
    });

    test('Clausura 2026 sin eliminatorias verificadas: solo 16 fechas', () {
      final stages = RoundNavigator.stagesFor(
        primera,
        const Season(2026),
        PhaseKey.clausura,
      );

      expect(stages, hasLength(16));
    });

    test('fase que no corresponde a la competición: vacío', () {
      expect(
        RoundNavigator.stagesFor(primera, const Season(2026), PhaseKey.unica),
        isEmpty,
      );
    });

    test(
      'Nacional: 36 fechas en 2026, 34 en 2025; sin catálogo usa el dato descubierto',
      () {
        expect(
          RoundNavigator.stagesFor(
            nacional,
            const Season(2026),
            PhaseKey.regular,
          ),
          hasLength(36),
        );
        expect(
          RoundNavigator.stagesFor(
            nacional,
            const Season(2025),
            PhaseKey.regular,
          ),
          hasLength(34),
        );
        expect(
          RoundNavigator.stagesFor(
            nacional,
            const Season(2024),
            PhaseKey.regular,
          ),
          isEmpty,
        );
        expect(
          RoundNavigator.stagesFor(
            nacional,
            const Season(2024),
            PhaseKey.regular,
            knownMaxRound: 38,
          ),
          hasLength(38),
        );
      },
    );

    test('Copa: rondas en orden del torneo', () {
      final stages = RoundNavigator.stagesFor(
        copa,
        const Season(2026),
        PhaseKey.unica,
      );

      expect(stages.map((s) => s.apiRound), [64, 32, 16, 125, 150, 200]);
      expect(stages.last.label, 'Final');
    });

    test('anterior y siguiente', () {
      final stages = RoundNavigator.stagesFor(
        copa,
        const Season(2026),
        PhaseKey.unica,
      );

      expect(RoundNavigator.next(stages, stages[3])!.label, 'Semifinales');
      expect(
        RoundNavigator.previous(stages, stages[3])!.label,
        'Octavos de final',
      );
      expect(RoundNavigator.previous(stages, stages.first), isNull);
      expect(RoundNavigator.next(stages, stages.last), isNull);
    });
  });

  group('Fase D3: copas internacionales', () {
    const libertadores = CompetitionCatalog.copaLibertadores;
    const sudamericana = CompetitionCatalog.copaSudamericana;

    List<String> labels(CompetitionDefinition d, int year, PhaseKey phase) => [
      for (final s in RoundNavigator.stagesFor(d, Season(year), phase))
        '${s.label} (r${s.apiRound}, ${s.kind.name})',
    ];

    test('Libertadores 2026: previas, grupos y eliminatorias', () {
      expect(labels(libertadores, 2026, PhaseKey.qualifying), [
        'Fase 1 (r1, knockout)',
        'Fase 2 (r2, knockout)',
        'Fase 3 (r3, knockout)',
      ]);
      expect(labels(libertadores, 2026, PhaseKey.groups), [
        for (var r = 1; r <= 6; r++) 'Fecha $r (r$r, regular)',
      ]);
      expect(labels(libertadores, 2026, PhaseKey.knockoutStage), [
        'Octavos de final (r16, knockout)',
        'Cuartos de final (r125, knockout)',
        'Semifinales (r150, knockout)',
        'Final (r200, knockout)',
      ]);
    });

    test('Sudamericana: los códigos cambian entre temporadas', () {
      expect(labels(sudamericana, 2025, PhaseKey.qualifying), [
        'Primera fase (r400, knockout)',
      ]);
      expect(labels(sudamericana, 2026, PhaseKey.qualifying), [
        'Primera fase (r1, knockout)',
      ]);
      expect(
        labels(sudamericana, 2025, PhaseKey.knockoutStage).first,
        'Playoffs de octavos (r160, knockout)',
      );
      expect(
        labels(sudamericana, 2026, PhaseKey.knockoutStage).first,
        'Playoffs de octavos (r32, knockout)',
      );
    });

    test('temporada sin formato o fase ajena: sin etapas', () {
      expect(labels(libertadores, 2024, PhaseKey.groups), isEmpty);
      expect(labels(libertadores, 2026, PhaseKey.apertura), isEmpty);
    });

    test('StageLabeler: la etapa depende de la fase y la temporada', () {
      const s2026 = Season(2026);
      expect(
        StageLabeler.label(
          libertadores,
          s2026,
          PhaseKey.qualifying,
          1,
          StageKind.knockout,
        ),
        'Fase 1',
      );
      expect(
        StageLabeler.label(
          libertadores,
          s2026,
          PhaseKey.groups,
          1,
          StageKind.regular,
        ),
        'Fecha 1',
      );
      expect(
        StageLabeler.label(
          libertadores,
          const Season(2025),
          PhaseKey.qualifying,
          400,
          StageKind.knockout,
        ),
        'Fases 1, 2 y 3',
      );
      expect(
        StageLabeler.label(
          libertadores,
          s2026,
          PhaseKey.knockoutStage,
          999,
          StageKind.knockout,
        ),
        'Ronda 999',
      );
    });

    test('locate: el próximo partido real de cada copa', () {
      for (final (d, name) in [
        (libertadores, 'eventsnextleague_4501'),
        (sudamericana, 'eventsnextleague_4724'),
      ]) {
        final next = fixtureMatches(name).single;
        final located = RoundNavigator.locate(d, next)!;
        expect(located.stage.phase, PhaseKey.knockoutStage);
        expect(located.stage.label, 'Semifinales');
      }
    });

    test('stageOnDay: la etapa vigente o la última que empezó', () {
      Stage? on(CompetitionDefinition d, int year, CalendarDay day) =>
          RoundNavigator.stageOnDay(d, Season(year), day);

      // Antes de las semifinales (14/10): los cuartos.
      expect(
        on(libertadores, 2026, const CalendarDay(2026, 10, 11))?.label,
        'Cuartos de final',
      );
      expect(
        on(libertadores, 2026, const CalendarDay(2026, 10, 15))?.label,
        'Semifinales',
      );
      // Entre la Fase 2 y la Fase 3.
      expect(
        on(libertadores, 2026, const CalendarDay(2026, 3, 1))?.label,
        'Fase 2',
      );
      final groups = on(sudamericana, 2026, const CalendarDay(2026, 4, 20))!;
      expect((groups.phase, groups.apiRound), (PhaseKey.groups, 1));
      // Temporada terminada: la final.
      expect(
        on(sudamericana, 2025, const CalendarDay(2026, 10, 11))?.label,
        'Final',
      );
      // Antes de la primera etapa, o una liga: sin dato.
      expect(on(libertadores, 2026, const CalendarDay(2026, 1, 10)), isNull);
      expect(on(primera, 2026, const CalendarDay(2026, 10, 11)), isNull);
    });
  });
}
