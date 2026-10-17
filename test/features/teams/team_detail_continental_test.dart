import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/features/teams/domain/entities/team_detail.dart';
import 'package:futbol_argentino/features/teams/domain/repositories/team_repository.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/ensure_continental_team_index.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/watch_team_detail.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_teams.dart';
import '../../helpers/recorded_api.dart';
import '../../helpers/recorded_app.dart';

const river = 135171;
const racing = 135170;
const rosarioCentral = 135172;
const flamengo = 134287;

/// Fase D6: copas internacionales en la ficha de equipo, con los partidos
/// grabados en D1 (rondas) y en D6 (Flamengo). El equipo entra en la copa
/// por sus partidos guardados: antes se abre el arranque del buscador
/// (Fecha 1 de grupos de cada copa).
///
/// Sin `lookupteam` grabado de Rosario, Racing y River: sus datos y
/// punteros vienen de un repositorio falso vacío (la ficha sigue sin esa
/// sección); los partidos, de los repositorios reales.
void main() {
  late FakeClock clock;
  late RecordedApi api;

  Future<void> setUpAt(DateTime now) async {
    clock = FakeClock(now);
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
    await EnsureContinentalTeamIndex(api.matches)(now: clock.now());
    api.requests.clear();
  }

  Future<TeamDetail> load(int teamId, {TeamRepository? teams}) =>
      WatchTeamDetail(
        teams: teams ?? FakeTeamRepository(),
        matches: api.matches,
      )(teamId, now: clock.now(), cancelToken: CancelToken()).last;

  List<String> requestsOf(int league) => [
    for (final l in api.requestLabels)
      if (l.startsWith('$league:')) l,
  ];

  group('corte con evidencia (15/10/2026)', () {
    setUp(() => setUpAt(continentalRecordingTime));

    test(
      'serie perdida: Rosario Central, después de octavos no pide más',
      () async {
        final detail = await load(rosarioCentral);

        // Fecha 1 ya guardada; los cuartos y las semifinales (ya empezadas)
        // no se piden: perdió los octavos con Corinthians (0-0 y 1-0).
        expect(requestsOf(4501), [
          '4501:r2:s2026',
          '4501:r3:s2026',
          '4501:r4:s2026',
          '4501:r5:s2026',
          '4501:r6:s2026',
          '4501:r16:s2026',
        ]);
        final lib = [
          ...detail.played,
          ...detail.upcoming,
        ].where((m) => m.match.competitionId == 4501);
        expect(lib, hasLength(8)); // 6 de grupos + la serie de octavos.
        expect(detail.progress.isRunning, isFalse);
        expect(detail.progress.done, detail.progress.total);
      },
    );

    test('eliminado en grupos: Racing, 3.º en la Sudamericana', () async {
      await load(racing);

      // Con la fecha 6 su grupo quedó completo: ni Playoffs ni
      // eliminatorias.
      expect(requestsOf(4724), [
        '4724:r2:s2026',
        '4724:r3:s2026',
        '4724:r4:s2026',
        '4724:r5:s2026',
        '4724:r6:s2026',
      ]);
    });

    test('1.º de grupo ausente en los Playoffs: no corta; la tanda de '
        'octavos sí', () async {
      await load(river);

      // River no juega la ronda 32 (fue directo a octavos): se sigue. Pierde
      // los octavos en la tanda (7-8) con Independiente Santa Fe.
      expect(requestsOf(4724), [
        '4724:r2:s2026',
        '4724:r3:s2026',
        '4724:r4:s2026',
        '4724:r5:s2026',
        '4724:r6:s2026',
        '4724:r32:s2026',
        '4724:r16:s2026',
      ]);
    });

    test('en caliente: ninguna petición de las copas', () async {
      await load(river);
      api.requests.clear();

      await load(river);

      expect(requestsOf(4724), isEmpty);
    });
  });

  test('semanas sin partidos entre fases: no corta, sigue cuando empieza la '
      'etapa', () async {
    // 1/8: terminaron los Playoffs (30/7); los octavos empiezan el 11/8.
    await setUpAt(DateTime.utc(2026, 8, 1, 15));

    await load(river);
    expect(requestsOf(4724), [
      '4724:r2:s2026',
      '4724:r3:s2026',
      '4724:r4:s2026',
      '4724:r5:s2026',
      '4724:r6:s2026',
      '4724:r32:s2026',
    ]);

    // 12/8: los octavos ya empezaron.
    api.requests.clear();
    clock.advance(const Duration(days: 11));
    await load(river);

    expect(requestsOf(4724), contains('4724:r16:s2026'));
    expect(requestsOf(4724), isNot(contains('4724:r125:s2026')));
  });

  group('equipo extranjero: Flamengo (15/10/2026)', () {
    late TeamDetail detail;

    setUp(() async {
      await setUpAt(continentalRecordingTime);
      detail = await load(flamengo, teams: api.teams);
    });

    test('datos del equipo y la Libertadores con su fixture', () {
      expect(detail.team!.name, 'Flamengo');
      expect(detail.info!.stadium, 'Estádio do Maracanã');
      expect(detail.competitionIds, [4501]);

      final lib = [...detail.played, ...detail.upcoming];
      expect(lib.every((m) => m.match.competitionId == 4501), isTrue);
      // 6 de grupos, octavos, cuartos y las dos semifinales.
      expect(lib, hasLength(12));
      expect(detail.upcoming.first.stageLabel, 'Semifinales');
      expect(detail.upcoming.first.competitionName, 'Copa Libertadores');
    });

    test('otras competiciones: los punteros del Brasileirão', () {
      expect(
        [for (final m in detail.otherCompetitions) m.stageLabel],
        ['Próximo partido', 'Último partido'],
      );
      expect(detail.otherCompetitions.map((m) => m.competitionName).toSet(), {
        'Brazilian Serie A',
      });
    });

    test('presupuesto: 14 peticiones; hasta las semifinales, sin la final', () {
      expect(api.requestLabels.take(3), [
        'lookupteam:134287',
        'eventsnext:134287',
        'eventslast:134287',
      ]);
      // Índice de equipos de las competiciones argentinas (P1): 3.
      expect(api.requests, hasLength(14));
      expect(requestsOf(4501), [
        '4501:r2:s2026',
        '4501:r3:s2026',
        '4501:r4:s2026',
        '4501:r5:s2026',
        '4501:r6:s2026',
        '4501:r16:s2026',
        '4501:r125:s2026',
        '4501:r150:s2026',
      ]);
    });

    test('en caliente: ninguna petición', () async {
      api.requests.clear();

      await load(flamengo, teams: api.teams);

      expect(api.requests, isEmpty);
    });
  });
}
