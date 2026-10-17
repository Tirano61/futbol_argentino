import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_progress.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/teams/domain/entities/team_detail.dart';
import 'package:futbol_argentino/features/teams/domain/usecases/watch_team_detail.dart';
import 'package:futbol_argentino/features/teams/presentation/bloc/team_detail_bloc.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recorded_api.dart';

const bocaId = 135156;

/// Aceptación de la Fase 7 (T7.3/T7.4) con repositorios reales y
/// respuestas grabadas: presupuesto y cupo P2, «Primera + Copa» y
/// cancelación al salir de la ficha. Fase 15 (D8): próximo y último
/// partido del equipo. Fase D6: la Copa Sudamericana con su fixture (la
/// ronda del puntero primero, después en orden cronológico).
///
/// Las rondas de la Sudamericana se grabaron el 14/10 (D1), después de la
/// hora de estos tests: la ida de semifinales ya figura terminada.
void main() {
  late FakeClock clock;
  late DateTime start;
  late RecordedApi api;

  setUp(() async {
    start = DateTime.utc(2026, 10, 11, 20, 35);
    clock = FakeClock(start);
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  WatchTeamDetail watch() =>
      WatchTeamDetail(teams: api.teams, matches: api.matches);

  Future<TeamDetail> load() =>
      watch()(bocaId, now: clock.now(), cancelToken: CancelToken()).last;

  group('ficha de Boca en frío', () {
    late TeamDetail detail;

    setUp(() async => detail = await load());

    test('reúne Primera División, Copa Argentina y Copa Sudamericana', () {
      expect(detail.team!.name, 'Boca Juniors');
      expect(detail.info!.stadium, 'Estadio Alberto José Armando');
      expect(detail.competitionIds, [4406, 4500, 4724]);

      final all = [...detail.upcoming, ...detail.played];
      expect(all.map((m) => m.match.competitionId).toSet(), {4406, 4500, 4724});
      expect(all.every((m) => m.match.involvesTeam(bocaId)), isTrue);
      // Toda la temporada 2026: 32 fechas regulares de Primera (Apertura +
      // Clausura) + eliminatorias del Apertura + 5 rondas de Copa + 4
      // series de la Sudamericana (Playoffs a semifinales).
      expect(all.where((m) => m.match.competitionId == 4500), hasLength(5));
      expect(all.where((m) => m.match.competitionId == 4724), hasLength(8));
    });

    test('la Sudamericana con su etapa y su fase', () {
      final sud = [
        ...detail.upcoming,
        ...detail.played,
      ].where((m) => m.match.competitionId == 4724).toList();
      expect(sud.map((m) => m.stageLabel).toSet(), {
        'Playoffs de octavos',
        'Octavos de final',
        'Cuartos de final',
        'Semifinales',
      });
      expect(sud.map((m) => m.phaseLabel).toSet(), {'Eliminatorias'});
      expect(sud.first.competitionName, 'Copa Sudamericana');
      // La vuelta de semifinales (21/10) está entre los próximos.
      expect(
        detail.upcoming.map((m) => m.match.id),
        contains(2606045), // Vasco da Gama–Boca.
      );
    });

    test('próximos en orden; disputados del más reciente', () {
      final next = detail.upcoming.first;
      expect(next.competitionName, 'Primera División');
      expect(next.phaseLabel, 'Clausura');
      expect(next.stageLabel, 'Fecha 13');

      final last = detail.played.firstWhere(
        (m) => m.match.competitionId == 4406,
      );
      expect(last.stageLabel, 'Fecha 12');
      expect(last.match.status.isFinished, isTrue);

      final upcomingDays = [
        for (final m in detail.upcoming) m.match.kickoff.argentinaDay!,
      ];
      final playedDays = [
        for (final m in detail.played) m.match.kickoff.argentinaDay!,
      ];
      for (var i = 1; i < upcomingDays.length; i++) {
        expect(upcomingDays[i].isBefore(upcomingDays[i - 1]), isFalse);
      }
      for (var i = 1; i < playedDays.length; i++) {
        expect(playedDays[i].isAfter(playedDays[i - 1]), isFalse);
      }
    });

    test('Copa con el nombre de su etapa, sin fase', () {
      final semis = [...detail.upcoming, ...detail.played]
          .where(
            (m) =>
                m.match.competitionId == 4500 && m.stageLabel == 'Semifinales',
          )
          .single;
      expect(semis.competitionName, 'Copa Argentina');
      expect(semis.phaseLabel, isNull);
    });

    test('progreso completo: 33 rondas (17 de Primera, 6 de Copa y 10 de la '
        'Sudamericana)', () {
      expect(
        detail.progress,
        // Consultas: `lookupteam`, los punteros del equipo y 31 rondas (2
        // ya estaban por el índice).
        const SyncProgress(done: 33, total: 33, isRunning: false, fetched: 33),
      );
    });

    test('presupuesto: 37 peticiones; P2 como mucho 10 por minuto', () {
      expect(api.requests, hasLength(37));
      expect(api.requestLabels.first, 'lookupteam:135156');
      // Punteros del equipo (P1, D8): 2 peticiones.
      expect(api.requestLabels.sublist(1, 3), [
        'eventsnext:135156',
        'eventslast:135156',
      ]);
      // Bootstrap (P1): primera etapa de cada competición del índice.
      expect(
        api.requestLabels.sublist(3, 6),
        unorderedEquals(['4406:r1:s2026', '4616:r1:s2026', '4500:r64:s2026']),
      );
      // La ronda del puntero de la Sudamericana (P1, D6): semifinales.
      expect(api.requestLabels[6], '4724:r150:s2026');
      // 30 rondas P2 (las de la fecha 1 y los 32avos ya estaban): 10, 10,
      // 10.
      final p2 = [
        for (final t in api.requestTimes.skip(7)) t.difference(start),
      ];
      expect(p2, hasLength(30));
      for (var minute = 0; minute < 3; minute++) {
        expect(
          p2.where((d) => d.inMinutes == minute),
          hasLength(10),
          reason: 'minuto $minute',
        );
      }
    });

    test('Sudamericana: las etapas ya empezadas y hasta la del puntero', () {
      // A las 20:35 del 11/10 las semifinales (desde el 13/10) no
      // empezaron, pero el próximo partido de Boca es de esa etapa; la
      // final (sin datos) no se pide. Boca no jugó la Primera fase ni los
      // grupos (vino de la Libertadores): su ausencia no corta.
      expect(api.requestLabels.where((l) => l.startsWith('4724:')), [
        '4724:r150:s2026',
        '4724:r1:s2026',
        '4724:r2:s2026',
        '4724:r3:s2026',
        '4724:r4:s2026',
        '4724:r5:s2026',
        '4724:r6:s2026',
        '4724:r32:s2026',
        '4724:r16:s2026',
        '4724:r125:s2026',
      ]);
      // La Libertadores no entra: ningún puntero ni partido guardado de
      // Boca en ella (la continuidad entre copas no se infiere).
      expect(api.requestLabels.where((l) => l.startsWith('4501:')), isEmpty);
    });

    test('alterna competiciones: las copas no esperan a toda la Primera', () {
      // Primera y Copa Argentina de la última a la primera; la
      // Sudamericana en orden cronológico (para cortar con evidencia).
      final rounds = api.requestLabels.skip(7).take(9).toList();
      expect(rounds, [
        '4406:r0:s2026',
        '4500:r200:s2026',
        '4724:r1:s2026',
        '4406:r16:s2026',
        '4500:r150:s2026',
        '4724:r2:s2026',
        '4406:r15:s2026',
        '4500:r125:s2026',
        '4724:r3:s2026',
      ]);
    });

    test(
      'otras competiciones: el puntero de la Sudamericana pasa al fixture',
      () {
        // `eventsnext`: Boca–Vasco da Gama (Copa Sudamericana, 4724), ya
        // guardado con su ronda. `eventslast`: Boca–Unión, de Primera.
        expect(detail.otherCompetitions, isEmpty);
        final semis = detail.played.firstWhere((m) => m.match.id == 2606044);
        expect(semis.competitionName, 'Copa Sudamericana');
        expect(semis.stageLabel, 'Semifinales');
        expect(
          detail.played.map((m) => m.match.id),
          contains(2398104), // Boca–Unión, el `eventslast`.
        );
      },
    );

    test('en caliente: ninguna petición', () async {
      api.requests.clear();

      final again = await load();

      expect(api.requests, isEmpty);
      expect(again.progress.fetched, 0);
      expect(again.upcoming, detail.upcoming);
      expect(again.played, detail.played);
      expect(again.otherCompetitions, detail.otherCompetitions);
    });

    test('a los 30 minutos solo vencen los punteros del equipo', () async {
      api.requests.clear();
      clock.advance(const Duration(minutes: 31));

      await load();

      expect(
        api.requestLabels,
        containsAll(['eventsnext:135156', 'eventslast:135156']),
      );
      expect(api.requestLabels, isNot(contains('lookupteam:135156')));
    });
  });

  test(
    'el puntero de la Sudamericana se ve antes de que llegue su ronda',
    () async {
      final emissions = await watch()(
        bocaId,
        now: clock.now(),
        cancelToken: CancelToken(),
      ).toList();

      // Con los punteros y sin rondas todavía: «Otras competiciones».
      final beforeRounds = emissions.firstWhere(
        (d) => d.progress.total > 0 && d.progress.done == 0,
      );
      final other = beforeRounds.otherCompetitions.single;
      expect(other.match.id, 2606044);
      expect(other.competitionName, 'Copa Sudamericana');
      expect(other.stageLabel, 'Próximo partido');
      expect(other.phaseLabel, isNull);
      // Después de la primera ronda (la del puntero) ya está con su etapa.
      final afterPointer = emissions.firstWhere((d) => d.progress.done == 1);
      expect(afterPointer.otherCompetitions, isEmpty);
      expect(afterPointer.played.map((m) => m.match.id), contains(2606044));
    },
  );

  test('emite lo guardado antes de terminar', () async {
    await load();
    final emissions = await watch()(
      bocaId,
      now: clock.now(),
      cancelToken: CancelToken(),
    ).toList();

    final first = emissions.first;
    expect(first.progress.isRunning, isTrue);
    expect(first.team!.name, 'Boca Juniors');
    expect(first.played, isNotEmpty);
  });

  test('cancelar detiene la descarga: no hay más peticiones', () async {
    final token = CancelToken();
    final stopped = Completer<void>();
    final sub = watch()(bocaId, now: clock.now(), cancelToken: token).listen((
      detail,
    ) {
      if (detail.progress.done >= 3 && !token.isCancelled) {
        token.cancel();
        stopped.complete();
      }
    });
    await stopped.future;
    final atCancel = api.requests.length;
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Como mucho termina la ronda que ya estaba en curso.
    expect(api.requests.length, lessThanOrEqualTo(atCancel + 1));
    expect(api.requests.length, lessThan(37));
    expect(api.scheduler.pending, 0);
  });

  test('cerrar el BLoC de la ficha detiene su sincronización', () async {
    final bloc = TeamDetailBloc(
      watchTeamDetail: watch(),
      clock: _ClockOf(clock),
    )..add(const TeamDetailStarted(bocaId));
    await bloc.stream.firstWhere(
      (s) => s is TeamDetailLoaded && s.detail.progress.done >= 2,
    );
    final atClose = api.requests.length;

    await bloc.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(api.requests.length, lessThanOrEqualTo(atClose + 1));
    expect(api.requests.length, lessThan(37));
  });

  test(
    'pausar detiene la descarga y retomar completa solo lo que falta',
    () async {
      final bloc = TeamDetailBloc(
        watchTeamDetail: watch(),
        clock: _ClockOf(clock),
      )..add(const TeamDetailStarted(bocaId));
      await bloc.stream.firstWhere(
        (s) => s is TeamDetailLoaded && s.detail.progress.done >= 2,
      );

      bloc.add(const TeamDetailPaused());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final atPause = api.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.requests.length, atPause, reason: 'en pausa no pide nada');
      expect(api.requests.length, lessThan(37));

      bloc.add(const TeamDetailResumed());
      final done =
          await bloc.stream.firstWhere(
                (s) => s is TeamDetailLoaded && !s.detail.progress.isRunning,
              )
              as TeamDetailLoaded;

      expect(done.detail.progress.done, 33);
      // Las mismas 37 peticiones que sin pausa: nada se repite.
      expect(api.requests, hasLength(37));
      await bloc.close();
    },
  );

  test('actualizar con la descarga en curso la reemplaza y termina', () async {
    final bloc = TeamDetailBloc(
      watchTeamDetail: watch(),
      clock: _ClockOf(clock),
    )..add(const TeamDetailStarted(bocaId));
    await bloc.stream.firstWhere(
      (s) => s is TeamDetailLoaded && s.detail.progress.done >= 2,
    );

    bloc.add(const TeamDetailRefreshRequested());
    final done =
        await bloc.stream
                .firstWhere(
                  (s) => s is TeamDetailLoaded && !s.detail.progress.isRunning,
                )
                .timeout(const Duration(seconds: 5))
            as TeamDetailLoaded;

    expect(done.detail.progress.done, done.detail.progress.total);
    await bloc.close();
  });

  test('aviso en vivo (D11): recarga sin forzar, solo lo vencido', () async {
    final bloc = TeamDetailBloc(
      watchTeamDetail: watch(),
      clock: _ClockOf(clock),
    )..add(const TeamDetailStarted(bocaId));
    await bloc.stream.firstWhere(
      (s) => s is TeamDetailLoaded && !s.detail.progress.isRunning,
    );
    expect(api.requests, hasLength(37));
    api.requests.clear();

    // La fecha 12 de Primera tiene partidos en juego (vigencia de 2 min).
    clock.advance(const Duration(minutes: 2, seconds: 5));
    bloc.add(const TeamDetailLiveTick());
    final done =
        await bloc.stream.firstWhere(
              (s) => s is TeamDetailLoaded && !s.detail.progress.isRunning,
            )
            as TeamDetailLoaded;

    expect(api.requests.map((u) => u.query), ['id=4406&r=12&s=2026']);
    expect(done.detail.progress.fetched, 1);
    await bloc.close();
  });

  test('retomar sin descarga pendiente no hace nada', () async {
    final bloc = TeamDetailBloc(
      watchTeamDetail: watch(),
      clock: _ClockOf(clock),
    )..add(const TeamDetailStarted(bocaId));
    await bloc.stream.firstWhere(
      (s) => s is TeamDetailLoaded && !s.detail.progress.isRunning,
    );
    final states = <TeamDetailState>[];
    final sub = bloc.stream.listen(states.add);

    bloc
      ..add(const TeamDetailPaused())
      ..add(const TeamDetailResumed());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(states, isEmpty);
    await sub.cancel();
    await bloc.close();
  });

  group('sin red', () {
    test('con datos guardados: los muestra y avisa', () async {
      await load();
      api
        ..offline = true
        ..requests.clear();
      // Pasó una semana: todo lo cercano venció.
      clock.advance(const Duration(days: 8));

      final detail = await load();

      expect(detail.team!.name, 'Boca Juniors');
      expect(detail.played, isNotEmpty);
      expect(detail.progress.isRunning, isFalse);
      expect(detail.progress.failure, isA<NetworkFailure>());
    });

    test('sin nada guardado: la ficha falla', () async {
      api.offline = true;
      final bloc = TeamDetailBloc(
        watchTeamDetail: watch(),
        clock: _ClockOf(clock),
      )..add(const TeamDetailStarted(bocaId));

      final state = await bloc.stream.firstWhere((s) => s is TeamDetailFailure);

      expect((state as TeamDetailFailure).failure, isA<NetworkFailure>());
      await bloc.close();
    });
  });
}

class _ClockOf implements Clock {
  const _ClockOf(this.clock);

  final FakeClock clock;

  @override
  DateTime now() => clock.now();
}
