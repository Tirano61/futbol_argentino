import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';

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
}
