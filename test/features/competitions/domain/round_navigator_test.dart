import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/services/round_navigator.dart';
import 'package:futbol_argentino/features/competitions/domain/services/stage_labeler.dart';

void main() {
  const primera = CompetitionCatalog.primeraDivision;
  const nacional = CompetitionCatalog.primeraNacional;
  const copa = CompetitionCatalog.copaArgentina;

  group('StageLabeler', () {
    test('ligas: «Fecha N»', () {
      expect(StageLabeler.label(primera, 12, StageKind.regular), 'Fecha 12');
      expect(StageLabeler.label(nacional, 33, StageKind.regular), 'Fecha 33');
    });

    test('eliminatorias de Primera', () {
      expect(
        StageLabeler.label(primera, 16, StageKind.knockout),
        'Octavos de final',
      );
      expect(
        StageLabeler.label(primera, 0, StageKind.knockout),
        'Cuartos, semifinales y final',
      );
    });

    test('Copa por código, y código desconocido', () {
      expect(
        StageLabeler.label(copa, 64, StageKind.knockout),
        '32avos de final',
      );
      expect(
        StageLabeler.label(copa, 125, StageKind.knockout),
        'Cuartos de final',
      );
      expect(StageLabeler.label(copa, 150, StageKind.knockout), 'Semifinales');
      expect(StageLabeler.label(copa, 175, StageKind.knockout), 'Ronda 175');
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
      'Nacional: 36 fechas verificadas en 2026; otra temporada usa el dato descubierto',
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
          isEmpty,
        );
        expect(
          RoundNavigator.stagesFor(
            nacional,
            const Season(2025),
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
}
