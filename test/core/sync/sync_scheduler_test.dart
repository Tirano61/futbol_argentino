import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';

import '../../helpers/fake_clock.dart';

void main() {
  test('misma clave: un solo trabajo compartido', () async {
    final scheduler = SyncScheduler();
    var runs = 0;
    final gate = Completer<void>();
    Future<void> task() async {
      runs++;
      await gate.future;
    }

    final a = scheduler.run('round:1', SyncPriority.visible, task);
    final b = scheduler.run('round:1', SyncPriority.context, task);
    gate.complete();
    await Future.wait([a, b]);

    expect(runs, 1);
    expect(scheduler.pending, 0);
  });

  test('respeta el máximo de trabajos simultáneos', () async {
    final scheduler = SyncScheduler(maxConcurrent: 2);
    var running = 0;
    var maxSeen = 0;
    Future<void> task() async {
      running++;
      maxSeen = running > maxSeen ? running : maxSeen;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      running--;
    }

    await Future.wait([
      for (var i = 0; i < 6; i++)
        scheduler.run('k$i', SyncPriority.context, task),
    ]);

    expect(maxSeen, 2);
  });

  test('P0 pasa adelante de los P1 que esperan en la cola', () async {
    final scheduler = SyncScheduler(maxConcurrent: 1);
    final order = <String>[];
    final gate = Completer<void>();

    final first = scheduler.run('ocupado', SyncPriority.context, () async {
      await gate.future;
      order.add('ocupado');
    });
    final p1 = scheduler.run('vecina', SyncPriority.context, () async {
      order.add('vecina');
    });
    final p0 = scheduler.run('visible', SyncPriority.visible, () async {
      order.add('visible');
    });
    gate.complete();
    await Future.wait([first, p1, p0]);

    expect(order, ['ocupado', 'visible', 'vecina']);
  });

  test('un P1 en cola sube a P0 si alguien lo pide como visible', () async {
    final scheduler = SyncScheduler(maxConcurrent: 1);
    final order = <String>[];
    final gate = Completer<void>();

    final busy = scheduler.run('ocupado', SyncPriority.visible, () async {
      await gate.future;
    });
    final other = scheduler.run('otro', SyncPriority.context, () async {
      order.add('otro');
    });
    final upgraded = scheduler.run('ronda', SyncPriority.context, () async {
      order.add('ronda');
    });
    final again = scheduler.run('ronda', SyncPriority.visible, () async {});
    gate.complete();
    await Future.wait([busy, other, upgraded, again]);

    expect(order, ['ronda', 'otro']);
  });

  test('un error llega a quien espera y no traba la cola', () async {
    final scheduler = SyncScheduler(maxConcurrent: 1);

    await expectLater(
      scheduler.run('falla', SyncPriority.visible, () async {
        throw StateError('falló');
      }),
      throwsA(isA<StateError>()),
    );
    var ran = false;
    await scheduler.run('siguiente', SyncPriority.visible, () async {
      ran = true;
    });

    expect(ran, isTrue);
  });

  group('P2 (equipo)', () {
    late FakeClock clock;
    late SyncScheduler scheduler;

    setUp(() {
      clock = FakeClock();
      scheduler = SyncScheduler(clock: clock, delay: clock.delay);
    });

    test('cupo: como mucho 10 inicios por minuto', () async {
      final starts = <DateTime>[];
      await Future.wait([
        for (var i = 0; i < 25; i++)
          scheduler.run('ronda:$i', SyncPriority.team, () async {
            starts.add(clock.now());
          }),
      ]);

      expect(starts, hasLength(25));
      for (final start in starts) {
        final inWindow = starts.where(
          (s) =>
              !s.isBefore(start) &&
              s.isBefore(start.add(const Duration(minutes: 1))),
        );
        expect(inWindow.length, lessThanOrEqualTo(10));
      }
      // 25 trabajos = 3 tandas: dos esperas de un minuto.
      expect(clock.delays, [
        const Duration(minutes: 1),
        const Duration(minutes: 1),
      ]);
    });

    test('de a uno: siempre queda lugar para P0/P1', () async {
      var running = 0;
      var maxSeen = 0;
      Future<void> task() async {
        running++;
        maxSeen = running > maxSeen ? running : maxSeen;
        await Future<void>.delayed(const Duration(milliseconds: 2));
        running--;
      }

      final gate = Completer<void>();
      final p2 = [
        for (var i = 0; i < 4; i++)
          scheduler.run('ronda:$i', SyncPriority.team, task),
      ];
      // Con un P2 en curso, un P0 empieza sin esperar.
      var visibleRan = false;
      final p0 = scheduler.run('visible', SyncPriority.visible, () async {
        visibleRan = true;
        await gate.future;
      });
      await Future<void>.delayed(Duration.zero);
      expect(visibleRan, isTrue);
      gate.complete();
      await Future.wait([...p2, p0]);

      expect(maxSeen, 1);
    });

    /// Espera de cupo que se libera a mano.
    ({SyncScheduler scheduler, Completer<void> wake}) manualWake() {
      final wake = Completer<void>();
      return (
        scheduler: SyncScheduler(clock: clock, delay: (_) => wake.future),
        wake: wake,
      );
    }

    Future<void> useQuota(SyncScheduler scheduler) => Future.wait([
      for (var i = 0; i < 10; i++)
        scheduler.run('ronda:$i', SyncPriority.team, () async {}),
    ]);

    test('sin cupo P2, un P0 no espera', () async {
      final (:scheduler, :wake) = manualWake();
      await useQuota(scheduler);
      var teamRan = false;
      final waiting = scheduler.run('ronda:10', SyncPriority.team, () async {
        teamRan = true;
      });

      await scheduler.run('visible', SyncPriority.visible, () async {});
      expect(teamRan, isFalse);

      clock.advance(const Duration(minutes: 1));
      wake.complete();
      await waiting;
      expect(teamRan, isTrue);
    });

    test('un P2 en cola pedido como P0 no espera el cupo', () async {
      final (:scheduler, wake: _) = manualWake();
      await useQuota(scheduler);

      final asTeam = scheduler.run('ronda:x', SyncPriority.team, () async {});
      final asVisible = scheduler.run(
        'ronda:x',
        SyncPriority.visible,
        () async {},
      );

      // Termina sin liberar la espera del cupo.
      await Future.wait([asTeam, asVisible]);
    });

    test('en pausa no empiezan P2; P0 sí; al reanudar siguen', () async {
      scheduler.pause();
      var teamRan = false;
      final team = scheduler.run('ronda', SyncPriority.team, () async {
        teamRan = true;
      });
      await scheduler.run('visible', SyncPriority.visible, () async {});
      await Future<void>.delayed(Duration.zero);
      expect(teamRan, isFalse);
      expect(scheduler.pending, 1);

      scheduler.resume();
      await team;
      expect(teamRan, isTrue);
    });
  });

  group('cancelación', () {
    test('descarta los trabajos en cola del dueño', () async {
      final scheduler = SyncScheduler(maxConcurrent: 1);
      final token = CancelToken();
      final gate = Completer<void>();
      final ran = <String>[];

      final busy = scheduler.run('ocupado', SyncPriority.visible, () async {
        await gate.future;
      });
      final queued = [
        for (final key in ['a', 'b'])
          scheduler.run(
            key,
            SyncPriority.team,
            () async => ran.add(key),
            cancelToken: token,
          ),
      ];
      token.cancel();
      gate.complete();
      await busy;

      for (final f in queued) {
        await expectLater(f, throwsA(isA<SyncCancelled>()));
      }
      expect(ran, isEmpty);
      expect(scheduler.pending, 0);
    });

    test('un trabajo en curso no se interrumpe', () async {
      final scheduler = SyncScheduler();
      final token = CancelToken();
      final gate = Completer<void>();
      var finished = false;

      final running = scheduler.run('ronda', SyncPriority.team, () async {
        await gate.future;
        finished = true;
      }, cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      gate.complete();
      await running;

      expect(finished, isTrue);
    });

    test('un trabajo compartido sigue si otro lo espera', () async {
      final scheduler = SyncScheduler(maxConcurrent: 1);
      final token = CancelToken();
      final gate = Completer<void>();
      var ran = false;

      final busy = scheduler.run('ocupado', SyncPriority.visible, () async {
        await gate.future;
      });
      final fromTeam = scheduler.run('ronda', SyncPriority.team, () async {
        ran = true;
      }, cancelToken: token);
      // El Inicio pide la misma ronda, sin posibilidad de cancelar.
      final fromHome = scheduler.run(
        'ronda',
        SyncPriority.context,
        () async {},
      );
      token.cancel();
      gate.complete();
      await Future.wait([busy, fromTeam, fromHome]);

      expect(ran, isTrue);
    });

    test('con el dueño ya cancelado no se encola', () async {
      final scheduler = SyncScheduler();
      final token = CancelToken()..cancel();
      var ran = false;

      await expectLater(
        scheduler.run('ronda', SyncPriority.team, () async {
          ran = true;
        }, cancelToken: token),
        throwsA(isA<SyncCancelled>()),
      );
      expect(ran, isFalse);
      expect(scheduler.pending, 0);
    });
  });
}
