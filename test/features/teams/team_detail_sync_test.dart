import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
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
/// cancelación al salir de la ficha.
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

    test('reúne Primera División y Copa Argentina', () {
      expect(detail.team!.name, 'Boca Juniors');
      expect(detail.info!.stadium, 'Estadio Alberto José Armando');
      expect(detail.competitionIds, [4406, 4500]);

      final all = [...detail.upcoming, ...detail.played];
      expect(all.map((m) => m.match.competitionId).toSet(), {4406, 4500});
      expect(all.every((m) => m.match.involvesTeam(bocaId)), isTrue);
      // Toda la temporada 2026: 32 fechas regulares de Primera (Apertura +
      // Clausura) + eliminatorias del Apertura + 5 rondas de Copa.
      expect(all.where((m) => m.match.competitionId == 4500), hasLength(5));
    });

    test('próximos en orden; disputados del más reciente', () {
      final next = detail.upcoming.first;
      expect(next.competitionName, 'Primera División');
      expect(next.phaseLabel, 'Clausura');
      expect(next.stageLabel, 'Fecha 13');

      final last = detail.played.first;
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
      final semis = [
        ...detail.upcoming,
        ...detail.played,
      ].where((m) => m.stageLabel == 'Semifinales').single;
      expect(semis.competitionName, 'Copa Argentina');
      expect(semis.phaseLabel, isNull);
    });

    test('progreso completo: 23 rondas (17 de Primera + 6 de Copa)', () {
      expect(
        detail.progress,
        const TeamSyncProgress(done: 23, total: 23, isRunning: false),
      );
    });

    test('presupuesto: 25 peticiones; P2 como mucho 10 por minuto', () {
      expect(api.requests, hasLength(25));
      expect(api.requestLabels.first, 'lookupteam:135156');
      // Bootstrap (P1): primera etapa de cada competición.
      expect(
        api.requestLabels.sublist(1, 4),
        unorderedEquals(['4406:r1:s2026', '4616:r1:s2026', '4500:r64:s2026']),
      );
      // 21 rondas P2 (las de la fecha 1 y los 32avos ya estaban): 10, 10, 1.
      final p2 = [
        for (final t in api.requestTimes.skip(4)) t.difference(start),
      ];
      expect(p2, hasLength(21));
      expect(p2.where((d) => d < const Duration(minutes: 1)), hasLength(10));
      expect(
        p2.where(
          (d) =>
              d >= const Duration(minutes: 1) && d < const Duration(minutes: 2),
        ),
        hasLength(10),
      );
    });

    test('alterna competiciones: la Copa no espera a toda la Primera', () {
      final rounds = api.requestLabels.skip(4).take(6).toList();
      expect(rounds, [
        '4406:r0:s2026',
        '4500:r200:s2026',
        '4406:r16:s2026',
        '4500:r150:s2026',
        '4406:r15:s2026',
        '4500:r125:s2026',
      ]);
    });

    test('en caliente: ninguna petición', () async {
      api.requests.clear();

      final again = await load();

      expect(api.requests, isEmpty);
      expect(again.upcoming, detail.upcoming);
      expect(again.played, detail.played);
    });
  });

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
    expect(api.requests.length, lessThan(25));
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
    expect(api.requests.length, lessThan(25));
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
