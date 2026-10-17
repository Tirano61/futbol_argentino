import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/services/continental_exit_evidence.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';

import '../../../helpers/fixture_matches.dart';

const libertadores = CompetitionCatalog.copaLibertadores;
const sudamericana = CompetitionCatalog.copaSudamericana;

const boca = 135156;
const river = 135171;
const racing = 135170;
const rosarioCentral = 135172;
const argentinosJuniors = 135151;
const barracasCentral = 137771;
const clubLibertad = 138294;
const flamengo = 134287;
const palmeiras = 134465;

/// Rondas grabadas de una copa y temporada.
List<Match> recorded(int league, int season, List<int> rounds) => [
  for (final r in rounds)
    ...fixtureMatches('eventsround_${league}_r${r}_s$season'),
];

const _groups = [1, 2, 3, 4, 5, 6];
final lib2026 = recorded(4501, 2026, [..._groups, 16, 125, 150, 200]);
final lib2025 = recorded(4501, 2025, [400, ..._groups, 16, 125, 150, 200]);
final sud2026 = recorded(4724, 2026, [..._groups, 32, 16, 125, 150, 200]);

ContinentalExit? exitOf(
  CompetitionDefinition cup,
  int season,
  int teamId,
  List<Match> matches,
) => ContinentalExitEvidence.of(
  definition: cup,
  season: Season(season),
  teamId: teamId,
  matches: matches,
);

/// Posición de la etapa con [label] en la temporada.
int stage(CompetitionDefinition cup, int season, String label) =>
    (cup.rules as ContinentalCupRules)
        .stagesOf(Season(season))
        .indexWhere((s) => s.label == label);

/// Fase D6: el corte de la ficha de equipo solo con evidencia, sobre los
/// partidos grabados.
void main() {
  group('llave perdida: corta', () {
    test('Rosario Central, octavos de la Libertadores 2026 (0-0 y 1-0)', () {
      expect(
        exitOf(libertadores, 2026, rosarioCentral, lib2026),
        ContinentalExit(
          stageIndex: stage(libertadores, 2026, 'Octavos de final'),
          reason: ContinentalExitReason.tieLost,
        ),
      );
    });

    test('Argentinos Juniors, Fase 2 de la Libertadores 2026 (tanda 4-5)', () {
      expect(
        exitOf(libertadores, 2026, argentinosJuniors, lib2026),
        ContinentalExit(
          stageIndex: stage(libertadores, 2026, 'Fase 2'),
          reason: ContinentalExitReason.tieLost,
        ),
      );
    });

    test('River, octavos de la Sudamericana 2026 (tanda 7-8)', () {
      expect(
        exitOf(sudamericana, 2026, river, sud2026),
        ContinentalExit(
          stageIndex: stage(sudamericana, 2026, 'Octavos de final'),
          reason: ContinentalExitReason.tieLost,
        ),
      );
    });

    test('Palmeiras, final de la Libertadores 2025', () {
      expect(
        exitOf(libertadores, 2025, palmeiras, lib2025),
        ContinentalExit(
          stageIndex: stage(libertadores, 2025, 'Final'),
          reason: ContinentalExitReason.tieLost,
        ),
      );
    });
  });

  group('eliminado en grupos sin posición compartida: corta', () {
    test('Racing, 3.º de su grupo de la Sudamericana 2026', () {
      expect(
        exitOf(sudamericana, 2026, racing, sud2026),
        ContinentalExit(
          stageIndex: stage(sudamericana, 2026, 'Fecha 6'),
          reason: ContinentalExitReason.groupStage,
        ),
      );
    });

    test('Barracas Central, 4.º de la Sudamericana 2026', () {
      expect(
        exitOf(sudamericana, 2026, barracasCentral, sud2026)?.reason,
        ContinentalExitReason.groupStage,
      );
    });

    test('Club Libertad, 4.º de la Libertadores 2026', () {
      expect(
        exitOf(libertadores, 2026, clubLibertad, lib2026),
        ContinentalExit(
          stageIndex: stage(libertadores, 2026, 'Fecha 6'),
          reason: ContinentalExitReason.groupStage,
        ),
      );
    });
  });

  test('copa terminada: Flamengo, campeón de la Libertadores 2025', () {
    expect(
      exitOf(libertadores, 2025, flamengo, lib2025),
      ContinentalExit(
        stageIndex: stage(libertadores, 2025, 'Final'),
        reason: ContinentalExitReason.competitionFinished,
      ),
    );
  });

  group('sin evidencia: no corta', () {
    test('el 1.º de grupo de la Sudamericana no juega los Playoffs', () {
      // River ganó su grupo y fue directo a octavos: no está en la ronda
      // 32, y eso no prueba nada.
      expect(
        exitOf(
          sudamericana,
          2026,
          river,
          recorded(4724, 2026, [..._groups, 32]),
        ),
        isNull,
      );
    });

    test(
      'el 3.º de la Libertadores entra en los Playoffs de la Sudamericana',
      () {
        // Boca no jugó los grupos de la Sudamericana: viene de la
        // Libertadores y ganó su serie de Playoffs (tanda 4-3).
        expect(
          exitOf(
            sudamericana,
            2026,
            boca,
            recorded(4724, 2026, [..._groups, 32]),
          ),
          isNull,
        );
        // En semifinales, con la vuelta por jugarse.
        expect(exitOf(sudamericana, 2026, boca, sud2026), isNull);
      },
    );

    test('en la Libertadores, el 3.º no se da por eliminado', () {
      // El tercero sigue en otra copa (la Sudamericana): solo el 4.º corta.
      expect(exitOf(libertadores, 2026, boca, lib2026), isNull);
    });

    test('grupo sin terminar (falta la fecha 6)', () {
      expect(
        exitOf(
          sudamericana,
          2026,
          racing,
          recorded(4724, 2026, [1, 2, 3, 4, 5]),
        ),
        isNull,
      );
    });

    test('posición compartida que cruza la línea', () {
      // Variante ARMADA EN EL TEST (no es un dato real): los 12 partidos
      // del grupo de Racing con 0-0. Los cuatro comparten el 1.º puesto.
      final group = (sudamericana.standingsFor(Season(2026)) as GroupStage)
          .groups
          .values
          .firstWhere((ids) => ids.contains(racing));
      final allDraws = [
        for (final m in sud2026)
          group.contains(m.home.id) && group.contains(m.away.id)
              ? rebuild(m, score: const Score(home: 0, away: 0))
              : m,
      ];

      expect(exitOf(sudamericana, 2026, racing, allDraws), isNull);
    });

    test('llave sin terminar: Flamengo en semifinales 2026', () {
      expect(exitOf(libertadores, 2026, flamengo, lib2026), isNull);
    });

    test('equipo sin partidos guardados en la copa', () {
      expect(exitOf(libertadores, 2026, racing, lib2026), isNull);
    });

    test('temporada sin formato verificado', () {
      expect(exitOf(libertadores, 2024, rosarioCentral, lib2026), isNull);
    });

    test('competición que no es una copa internacional', () {
      expect(
        exitOf(CompetitionCatalog.copaArgentina, 2026, rosarioCentral, lib2026),
        isNull,
      );
    });
  });
}
