import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/teams/data/models/team_dto.dart';
import 'package:futbol_argentino/features/teams/domain/services/team_index.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/ensure_team_index.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/fixture_matches.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/recorded_api.dart';

const bocaId = 135156;
const riverId = 135171;

void main() {
  late FakeClock clock;
  late RecordedApi api;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  group('índice local (T7.1)', () {
    test('bootstrap en frío: 3 peticiones, una por competición', () async {
      final failure = await EnsureTeamIndex(api.matches)(now: clock.now());

      expect(failure, isNull);
      expect(
        api.requestLabels,
        unorderedEquals(['4406:r1:s2026', '4616:r1:s2026', '4500:r64:s2026']),
      );
    });

    test('en caliente: ninguna petición', () async {
      await EnsureTeamIndex(api.matches)(now: clock.now());
      api.requests.clear();

      clock.advance(const Duration(days: 7));
      await EnsureTeamIndex(api.matches)(now: clock.now());

      expect(api.requests, isEmpty);
    });

    test('«river» encuentra River Plate sin red', () async {
      await EnsureTeamIndex(api.matches)(now: clock.now());
      api
        ..offline = true
        ..requests.clear();

      final index = TeamIndex(await api.teams.storedTeams());
      final found = index.search('river');

      expect(found.map((t) => t.team.id), [riverId]);
      expect(found.single.team.name, 'River Plate');
      expect(found.single.team.badgeUrl, isNotNull);
      expect(api.requests, isEmpty);
    });

    test('cada equipo con las competiciones de su temporada', () async {
      await EnsureTeamIndex(api.matches)(now: clock.now());

      final teams = {
        for (final t in await api.teams.storedTeams()) t.team.id: t,
      };

      // Boca juega Primera y la Copa 2026.
      expect(teams[bocaId]!.competitionIds, [4406, 4500]);
      // Primera fecha 1 = 30 equipos; Nacional fecha 1 = 36.
      expect(
        teams.values.where((t) => t.competitionIds.contains(4406)),
        hasLength(30),
      );
      expect(
        teams.values.where((t) => t.competitionIds.contains(4616)),
        hasLength(36),
      );
    });

    test('solo la temporada más reciente define las competiciones', () async {
      // Copa 2025 (16avos) guardada además del bootstrap 2026.
      await api.matches.syncRound(
        const RoundQuery(competitionId: 4500, season: '2025', apiRound: 32),
      );
      await EnsureTeamIndex(api.matches)(now: clock.now());

      final competitions2026 = <int, Set<int>>{};
      for (final (name, id) in [
        ('eventsround_4406_r1_s2026', 4406),
        ('eventsround_4616_r1_s2026', 4616),
        ('eventsround_4500_r64_s2026', 4500),
      ]) {
        for (final m in fixtureMatches(name)) {
          for (final t in [m.home, m.away]) {
            (competitions2026[t.id] ??= {}).add(id);
          }
        }
      }
      final teams = {
        for (final t in await api.teams.storedTeams()) t.team.id: t,
      };

      // Quien jugó en 2026 muestra sus competiciones 2026 (la Copa 2025 no
      // cuenta); quien solo aparece en 2025, la Copa.
      final copa2025 = fixtureMatches('eventsround_4500_r32_s2025');
      var onlyIn2025 = 0;
      for (final m in copa2025) {
        for (final t in [m.home, m.away]) {
          final expected = competitions2026[t.id]?.toList() ?? [4500];
          if (!competitions2026.containsKey(t.id)) onlyIn2025++;
          expect(teams[t.id]!.competitionIds, expected..sort(), reason: t.name);
        }
      }
      expect(onlyIn2025, greaterThan(0));
    });

    test('sin red y sin nada guardado: devuelve el error', () async {
      api.offline = true;

      final failure = await EnsureTeamIndex(api.matches)(now: clock.now());

      expect(failure, isA<NetworkFailure>());
      expect(await api.teams.storedTeams(), isEmpty);
    });

    test('temporada nueva todavía vacía: usa la anterior', () async {
      // Enero de 2027: la fecha 1 de 2027 todavía no tiene partidos.
      clock = FakeClock(DateTime.utc(2027, 1, 5, 15));
      api = RecordedApi(
        clock: clock,
        db: await newDatabaseFactoryMemory().openDatabase('app.db'),
      );

      await EnsureTeamIndex(
        api.matches,
        catalog: [CompetitionCatalog.primeraDivision],
      )(now: clock.now());

      expect(api.requestLabels, ['4406:r1:s2027', '4406:r1:s2026']);
      expect(await api.teams.storedTeams(), hasLength(30));
    });
  });

  group('lookupteam', () {
    test('datos del equipo, guardados 7 días', () async {
      final first = await api.teams.getTeam(bocaId);

      expect(first.origin, DataOrigin.remote);
      expect(first.data.name, 'Boca Juniors');
      expect(first.data.stadium, 'Estadio Alberto José Armando');
      expect(first.data.alternateNames, ['Boca', 'Club Atlético Boca Juniors']);
      expect(first.data.leagueIds, [4406, 5428, 4500, 4724]);

      clock.advance(const Duration(days: 6));
      final cached = await api.teams.getTeam(bocaId);
      expect(cached.origin, DataOrigin.cache);
      expect(api.requests, hasLength(1));
    });

    test('vencido y sin red: lo guardado con el error', () async {
      await api.teams.getTeam(bocaId);
      clock.advance(const Duration(days: 8));
      api.offline = true;

      final result = await api.teams.getTeam(bocaId);

      expect(result.data.name, 'Boca Juniors');
      expect(result.refreshError, isA<NetworkFailure>());
    });

    test('sin nada guardado y sin red: lanza el error', () async {
      api.offline = true;

      expect(api.teams.getTeam(bocaId), throwsA(isA<NetworkFailure>()));
    });
  });

  group('próximo y último del equipo (D8, V9)', () {
    test('2 peticiones, guardados 30 minutos', () async {
      final first = await api.teams.getTeamPointers(bocaId);

      expect(first.origin, DataOrigin.remote);
      expect(api.requestLabels, ['eventsnext:135156', 'eventslast:135156']);
      // De cualquier competición: el próximo es de la Sudamericana.
      expect(first.data.next!.competitionId, 4724);
      expect(first.data.next!.competitionName, 'Copa Sudamericana');
      // `eventslast` responde con la clave `results`.
      expect(first.data.last!.id, 2398104);
      expect(first.data.last!.competitionId, 4406);

      clock.advance(const Duration(minutes: 29));
      final cached = await api.teams.getTeamPointers(bocaId);
      expect(cached.origin, DataOrigin.cache);
      expect(cached.data.next!.id, first.data.next!.id);
      expect(api.requests, hasLength(2));

      clock.advance(const Duration(minutes: 2));
      await api.teams.getTeamPointers(bocaId);
      expect(api.requests, hasLength(4));
    });

    test(
      'de local o de visitante: el próximo de River es en Sarmiento',
      () async {
        final result = await api.teams.getTeamPointers(riverId);

        expect(result.data.next!.home.name, 'Sarmiento');
        expect(result.data.next!.away.id, riverId);
      },
    );

    test('no se guardan con los partidos', () async {
      await api.teams.getTeamPointers(bocaId);

      expect(await api.matches.storedTeamMatches(bocaId), isEmpty);
      expect(await api.teams.storedTeams(), isEmpty);
    });

    test('vencidos y sin red: lo guardado con el error', () async {
      await api.teams.getTeamPointers(bocaId);
      clock.advance(const Duration(hours: 1));
      api.offline = true;

      final result = await api.teams.getTeamPointers(bocaId);

      expect(result.data.next!.id, 2606044);
      expect(result.refreshError, isA<NetworkFailure>());
    });

    test('sin nada guardado y sin red: lanza el error', () async {
      api.offline = true;

      expect(api.teams.getTeamPointers(bocaId), throwsA(isA<NetworkFailure>()));
    });
  });

  group('búsqueda en línea', () {
    test(
      'equipos de fútbol de Argentina o de las copas internacionales',
      () async {
        // «River» devuelve River-PI (Brasil, sin copas del catálogo).
        expect(await api.teams.searchOnline('River'), isEmpty);

        // Flamengo (Brasil) juega la Libertadores (4501).
        final flamengo = await api.teams.searchOnline('Flamengo');
        expect(flamengo.single.id, 134287);
        expect(flamengo.single.leagueIds, contains(4501));

        final river = await api.teams.searchOnline('River Plate');
        expect(river.single.id, riverId);

        final boca = await api.teams.searchOnline('Boca');
        expect(boca.single.name, 'Boca Unidos');
      },
    );

    test('sin red: lanza el error', () async {
      api.offline = true;

      expect(api.teams.searchOnline('Boca'), throwsA(isA<NetworkFailure>()));
    });
  });

  test('TeamDto: ligas idLeague…idLeague7 sin vacíos', () {
    final dto = TeamDto.fromJson(
      (fixtureJson('lookupteam_135156')['teams'] as List).single
          as Map<String, dynamic>,
    );
    expect(dto.leagueIds, [4406, 5428, 4500, 4724]);
    expect(dto.isArgentineFootball, isTrue);
  });
}
