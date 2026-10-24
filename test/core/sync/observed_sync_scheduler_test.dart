import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/sync/observed_sync_scheduler.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';

import '../../helpers/fake_clock.dart';

/// Fase R3: el scheduler observado informa cuándo dejó de reintentar un
/// trabajo tras un HTTP 429, sin cambiar la cola ni los reintentos (R2).
void main() {
  late FakeClock clock;
  late RateLimiter limiter;
  late ObservedSyncScheduler scheduler;

  setUp(() {
    clock = FakeClock();
    limiter = RateLimiter(maxRequests: 25, clock: clock);
    scheduler = ObservedSyncScheduler(
      clock: clock,
      delay: clock.delay,
      rateLimit: limiter,
    );
  });

  /// Una consulta que responde 429 las primeras [failures] veces (como el
  /// cliente: avisa al limitador y falla).
  Future<void> Function() failing(
    List<DateTime> attempts, {
    int failures = 1,
    Failure failure = const RateLimitFailure(detail: 'HTTP 429'),
    void Function()? onFailure,
  }) => () async {
    attempts.add(clock.now());
    if (attempts.length > failures) return;
    if (failure is RateLimitFailure) limiter.rateLimited(sentAt: clock.now());
    onFailure?.call();
    throw failure;
  };

  test('un 429 que se reintenta y sale bien no es un abandono', () async {
    final attempts = <DateTime>[];
    await scheduler.run('ronda', SyncPriority.visible, failing(attempts));
    await Future<void>.delayed(Duration.zero);

    expect(attempts, hasLength(2));
    expect(scheduler.abandonedPause, isNull);
  });

  test('agotados los reintentos informa la pausa vigente, una vez aunque dos '
      'pantallas esperen el trabajo', () async {
    final attempts = <DateTime>[];
    final task = failing(attempts, failures: 99);
    final first = scheduler.run('ronda', SyncPriority.visible, task);
    final second = scheduler.run('ronda', SyncPriority.context, task);

    await expectLater(first, throwsA(isA<RateLimitFailure>()));
    await expectLater(second, throwsA(isA<RateLimitFailure>()));
    await Future<void>.delayed(Duration.zero);

    // Los mismos 3 intentos que el `SyncScheduler` (60 + 120 s de pausa).
    expect(attempts, hasLength(3));
    expect(
      attempts.last.difference(attempts.first),
      const Duration(minutes: 3),
    );
    final pause = limiter.pausedUntil!;
    expect(scheduler.abandonedPause, pause);
  });

  test('Fase R3.1: informa lo pendiente y el bloqueo persistente, y avisa '
      'cada cambio', () async {
    var changes = 0;
    scheduler.changes.listen((_) => changes++);
    expect(scheduler.hasPendingWork, isFalse);

    final attempts = <DateTime>[];
    final done = scheduler.run(
      'ronda',
      SyncPriority.visible,
      failing(attempts, failures: 99),
    );
    expect(scheduler.hasPendingWork, isTrue);

    await expectLater(done, throwsA(isA<RateLimitFailure>()));
    await Future<void>.delayed(Duration.zero);

    // Tres 429 seguidos: bloqueo persistente y nada pendiente.
    expect(attempts, hasLength(3));
    expect(scheduler.isPersistentBlock, isTrue);
    expect(scheduler.hasPendingWork, isFalse);
    expect(scheduler.abandonedPause, limiter.pausedUntil);
    expect(
      changes,
      greaterThanOrEqualTo(3),
      reason: 'llega, abandono, termina',
    );
  });

  test('un trabajo cancelado no es un abandono', () async {
    final token = CancelToken();
    final attempts = <DateTime>[];
    final done = scheduler.run(
      'ronda',
      SyncPriority.visible,
      failing(attempts, onFailure: token.cancel),
      cancelToken: token,
    );

    await expectLater(done, throwsA(isA<RateLimitFailure>()));
    await Future<void>.delayed(Duration.zero);
    expect(attempts, hasLength(1));
    expect(scheduler.abandonedPause, isNull);
  });

  test('otros errores no cuentan', () async {
    final done = scheduler.run(
      'ronda',
      SyncPriority.visible,
      failing(
        [],
        failure: const NetworkFailure(
          issue: NetworkIssue.connection,
          detail: 'sin red',
        ),
      ),
    );

    await expectLater(done, throwsA(isA<NetworkFailure>()));
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.abandonedPause, isNull);
  });
}
