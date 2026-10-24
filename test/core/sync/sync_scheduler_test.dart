import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
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

  group('HTTP 429', () {
    late FakeClock clock;
    late RateLimiter limiter;

    setUp(() {
      clock = FakeClock();
      limiter = RateLimiter(maxRequests: 25, clock: clock, delay: clock.delay);
    });

    SyncScheduler build({int maxConcurrent = 2, Delay? delay}) => SyncScheduler(
      maxConcurrent: maxConcurrent,
      clock: clock,
      delay: delay ?? clock.delay,
      rateLimit: limiter,
    );

    /// Una consulta como la del cliente: pide turno al limitador y, si le
    /// toca 429, lo informa y falla con `RateLimitFailure`.
    Future<void> request({bool limited = false, Duration? retryAfter}) async {
      final sentAt = await limiter.acquire();
      if (!limited) {
        limiter.recordAccepted(sentAt);
        return;
      }
      limiter.rateLimited(sentAt: sentAt, retryAfter: retryAfter);
      throw const RateLimitFailure(detail: 'HTTP 429 (test)');
    }

    test('un 429 y después responde: el trabajo termina solo', () async {
      final scheduler = build();
      var runs = 0;

      await scheduler.run('ronda', SyncPriority.team, () async {
        runs++;
        await request(limited: runs == 1);
      });

      expect(runs, 2);
      expect(clock.delays, [const Duration(seconds: 60)]);
      expect(scheduler.pending, 0);
    });

    test('429 persistente: falla tras 2 reintentos (3 intentos)', () async {
      final scheduler = build();
      var runs = 0;

      await expectLater(
        scheduler.run('ronda', SyncPriority.team, () async {
          runs++;
          await request(limited: true);
        }),
        throwsA(isA<RateLimitFailure>()),
      );

      expect(runs, 3);
      expect(clock.delays, [
        const Duration(seconds: 60),
        const Duration(seconds: 120),
      ]);
      expect(scheduler.pending, 0);
    });

    test('tras agotar los reintentos, los 429 de la ventana siguiente fallan '
        'sin esperar (no se encadenan esperas)', () async {
      final scheduler = build();
      await expectLater(
        scheduler.run('a', SyncPriority.visible, () => request(limited: true)),
        throwsA(isA<RateLimitFailure>()),
      );

      var runs = 0;
      await expectLater(
        scheduler.run('b', SyncPriority.team, () async {
          runs++;
          await request(limited: true);
        }),
        throwsA(isA<RateLimitFailure>()),
      );
      expect(runs, 1);

      // Pasada esa ventana, un 429 nuevo vuelve a reintentarse.
      clock.advance(const Duration(minutes: 6));
      runs = 0;
      await scheduler.run('c', SyncPriority.team, () async {
        runs++;
        await request(limited: runs == 1);
      });
      expect(runs, 2);
    });

    test('una pausa de más de 5 min no se espera sola', () async {
      final scheduler = build();
      var runs = 0;

      await expectLater(
        scheduler.run('ronda', SyncPriority.visible, () async {
          runs++;
          await request(limited: true, retryAfter: const Duration(minutes: 6));
        }),
        throwsA(isA<RateLimitFailure>()),
      );

      expect(runs, 1);
      expect(scheduler.pending, 0);
    });

    // Fase R3.1: bloqueo persistente (3 HTTP 429 seguidos de cualquier
    // trabajo): sin reintentos, una sola sonda y, si falla, la cola termina.
    group('bloqueo persistente', () {
      /// Resultado de un trabajo: `null` si terminó bien, o el error.
      Future<Object?> outcome(Future<void> job) =>
          job.then<Object?>((_) => null, onError: (Object e) => e);

      RateLimitReason? reasonOf(Object? error) =>
          error is RateLimitFailure ? error.reason : null;

      /// El limitador ya vio tres 429 seguidos (la pausa de 240 s corre).
      Future<void> confirmBlock(SyncScheduler scheduler) async {
        for (var i = 0; i < 3; i++) {
          final sentAt = await limiter.acquire();
          clock.advance(const Duration(milliseconds: 300));
          limiter.rateLimited(sentAt: sentAt);
        }
        expect(limiter.consecutiveRateLimits, 3);
        expect(scheduler.isRateLimitBlocked, isTrue);
      }

      test('tres trabajos con 429 persistente: 4 consultas y todos con '
          'error (antes, hasta 9, de a una cada 4 min)', () async {
        final scheduler = build();
        var requests = 0;
        Future<void> task() async {
          requests++;
          await request(limited: true);
        }

        final results = await Future.wait([
          for (final key in ['a', 'b', 'c'])
            outcome(scheduler.run(key, SyncPriority.context, task)),
        ]);

        expect(requests, 4);
        expect(results, everyElement(isA<RateLimitFailure>()));
        expect(results.map(reasonOf), everyElement(isNotNull));
        expect(scheduler.pending, 0);
        expect(scheduler.isRateLimitBlocked, isTrue);
      });

      test(
        'si la sonda responde, la cola sigue sola y la racha vuelve a 0',
        () async {
          final scheduler = build();
          var requests = 0;
          Future<void> task() async {
            requests++;
            // Solo las 3 primeras consultas chocan con el límite.
            await request(limited: requests <= 3);
          }

          final results = await Future.wait([
            for (final key in ['a', 'b', 'c'])
              outcome(scheduler.run(key, SyncPriority.context, task)),
          ]);

          // El trabajo del tercer 429 no se reintenta; los demás terminan.
          expect(results.whereType<RateLimitFailure>(), hasLength(1));
          expect(results.where((r) => r == null), hasLength(2));
          expect(limiter.consecutiveRateLimits, 0);
          expect(scheduler.isRateLimitBlocked, isFalse);
        },
      );

      test('con el bloqueo confirmado sale una sola sonda; si vuelve a dar '
          '429, los demás terminan sin consultar', () async {
        final wake = Completer<void>();
        final scheduler = build(maxConcurrent: 3, delay: (_) => wake.future);
        await confirmBlock(scheduler);

        var running = 0;
        var maxRunning = 0;
        final started = <String>[];
        final jobs = [
          for (final (key, priority) in [
            ('p2', SyncPriority.team),
            ('p1', SyncPriority.context),
            ('p0', SyncPriority.visible),
          ])
            outcome(
              scheduler.run(key, priority, () async {
                started.add(key);
                running++;
                if (running > maxRunning) maxRunning = running;
                try {
                  await request(limited: true);
                } finally {
                  running--;
                }
              }),
            ),
        ];
        // Termina la pausa de 240 s.
        clock.advance(const Duration(minutes: 4));
        wake.complete();
        final results = await Future.wait(jobs);

        expect(maxRunning, 1);
        expect(started, ['p0'], reason: 'la sonda es el de más prioridad');
        expect(results, everyElement(isA<RateLimitFailure>()));
        expect(
          results.map(reasonOf),
          everyElement(RateLimitReason.persistentBlock),
        );
        expect(scheduler.pending, 0);
      });

      test(
        'con la sonda fallida, los pedidos nuevos fallan en el acto hasta '
        'que termina esa pausa; después, el primero vuelve a ser sonda',
        () async {
          final scheduler = build();
          await confirmBlock(scheduler);
          // La sonda (al terminar la pausa de 240 s) vuelve a dar 429.
          expect(
            await outcome(
              scheduler.run('sonda', SyncPriority.visible, () async {
                await request(limited: true);
              }),
            ),
            isA<RateLimitFailure>(),
          );
          final pauseEnd = limiter.pausedUntil!;

          var runs = 0;
          final early = await outcome(
            scheduler.run('nuevo', SyncPriority.visible, () async {
              runs++;
              await request();
            }),
          );
          expect(runs, 0, reason: 'no consulta');
          expect(reasonOf(early), RateLimitReason.persistentBlock);

          clock.advance(pauseEnd.difference(clock.now()));
          final later = await outcome(
            scheduler.run('después', SyncPriority.visible, () async {
              runs++;
              await request();
            }),
          );
          expect(runs, 1);
          expect(later, isNull);
          expect(scheduler.isRateLimitBlocked, isFalse);
        },
      );

      test(
        'un P0 que espera mientras un P2 confirma el bloqueo no se '
        'descarta: es la sonda y, si TheSportsDB responde, termina bien',
        () async {
          final scheduler = build(maxConcurrent: 1);
          // Dos 429 seguidos; la pausa ya terminó (sigue el episodio).
          for (var i = 0; i < 2; i++) {
            final sentAt = await limiter.acquire();
            clock.advance(const Duration(milliseconds: 300));
            limiter.rateLimited(sentAt: sentAt);
          }
          clock.advance(const Duration(minutes: 2));

          final gate = Completer<void>();
          final p2 = outcome(
            scheduler.run('p2', SyncPriority.team, () async {
              await gate.future;
              await request(limited: true);
            }),
          );
          await Future<void>.delayed(Duration.zero);
          var p0Runs = 0;
          final p0 = outcome(
            scheduler.run('p0', SyncPriority.visible, () async {
              p0Runs++;
              await request();
            }),
          );
          // El tercer 429 (el del P2) confirma el bloqueo.
          gate.complete();

          expect(reasonOf(await p2), RateLimitReason.persistentBlock);
          expect(await p0, isNull);
          expect(p0Runs, 1);
          expect(limiter.consecutiveRateLimits, 0);
          expect(scheduler.isRateLimitBlocked, isFalse);
        },
      );

      test('un P0 que llega con el bloqueo confirmado: un intento y el '
          'motivo «sigue limitando», no «varios intentos»', () async {
        final scheduler = build();
        await confirmBlock(scheduler);
        var runs = 0;
        final result = await outcome(
          scheduler.run('p0', SyncPriority.visible, () async {
            runs++;
            await request(limited: true);
          }),
        );

        expect(runs, 1);
        expect(reasonOf(result), RateLimitReason.persistentBlock);
      });

      test(
        'el trabajo que hizo sus 3 intentos: motivo «varios intentos»',
        () async {
          final scheduler = build();
          final result = await outcome(
            scheduler.run('ronda', SyncPriority.team, () async {
              await request(limited: true);
            }),
          );

          expect(reasonOf(result), RateLimitReason.retriesExhausted);
        },
      );

      test(
        'dos pedidos de la misma clave durante el bloqueo: una consulta',
        () async {
          final scheduler = build();
          await confirmBlock(scheduler);
          var runs = 0;
          Future<void> task() async {
            runs++;
            await request();
          }

          final results = await Future.wait([
            outcome(scheduler.run('ronda', SyncPriority.visible, task)),
            outcome(scheduler.run('ronda', SyncPriority.team, task)),
          ]);

          expect(runs, 1);
          expect(results, [null, null]);
        },
      );

      test(
        'cancelado durante la pausa: se descarta, no termina con 429',
        () async {
          final scheduler = build();
          await confirmBlock(scheduler);
          final token = CancelToken();
          var runs = 0;
          final job = outcome(
            scheduler.run('ronda', SyncPriority.team, () async {
              runs++;
              await request(limited: true);
            }, cancelToken: token),
          );
          token.cancel();

          expect(await job, isA<SyncCancelled>());
          expect(runs, 0);
          expect(scheduler.pending, 0);
        },
      );

      test('Retry-After de más de 5 min: un intento, motivo y hora; los demás '
          'siguen después de la pausa', () async {
        final scheduler = build(maxConcurrent: 1);
        final long = outcome(
          scheduler.run('largo', SyncPriority.visible, () async {
            await request(
              limited: true,
              retryAfter: const Duration(minutes: 6),
            );
          }),
        );
        final other = outcome(
          scheduler.run('otro', SyncPriority.visible, () => request()),
        );

        final failure = await long;
        expect(reasonOf(failure), RateLimitReason.longPause);
        expect((failure! as RateLimitFailure).retryAt, isNotNull);
        expect(await other, isNull);
      });
    });

    test('los errores que no son 429 no se reintentan', () async {
      final scheduler = build();
      var runs = 0;

      await expectLater(
        scheduler.run('ronda', SyncPriority.visible, () async {
          runs++;
          throw const ServerFailure(detail: 'HTTP 503', statusCode: 503);
        }),
        throwsA(isA<ServerFailure>()),
      );

      expect(runs, 1);
    });

    test(
      'durante la pausa no empieza nada; al reanudar va primero el P0',
      () async {
        final wake = Completer<void>();
        final scheduler = build(maxConcurrent: 1, delay: (_) => wake.future);
        final order = <String>[];
        var teamRuns = 0;

        final team = scheduler.run('equipo', SyncPriority.team, () async {
          order.add('equipo');
          await request(limited: ++teamRuns == 1);
        });
        await Future<void>.delayed(Duration.zero);
        final visible = scheduler.run(
          'visible',
          SyncPriority.visible,
          () async {
            order.add('visible');
            await request();
          },
        );
        await Future<void>.delayed(Duration.zero);
        expect(order, ['equipo'], reason: 'nada empieza durante la pausa');
        expect(scheduler.pending, 2);

        clock.advance(const Duration(seconds: 60));
        wake.complete();
        await Future.wait([team, visible]);

        expect(order, ['equipo', 'visible', 'equipo']);
      },
    );

    test('al reanudar, las consultas salen de a una cada 2,4 s', () async {
      final scheduler = build();
      final start = clock.now();
      final sent = <DateTime>[];
      var limited = true;

      await Future.wait([
        for (var i = 0; i < 6; i++)
          scheduler.run('ronda:$i', SyncPriority.context, () async {
            final sentAt = await limiter.acquire();
            if (limited) {
              limited = false;
              limiter.rateLimited(sentAt: sentAt);
              throw const RateLimitFailure(detail: 'HTTP 429 (test)');
            }
            sent.add(sentAt);
          }),
      ]);

      // ronda:0 recibió el 429 y ronda:1 ya tenía turno: las dos vuelven a
      // salir después de la pausa, de a una.
      expect(sent, hasLength(6));
      final resumed = start.add(const Duration(seconds: 60));
      expect(sent.first.isBefore(resumed), isFalse);
      for (var i = 1; i < sent.length; i++) {
        expect(
          sent[i].difference(sent[i - 1]),
          greaterThanOrEqualTo(const Duration(milliseconds: 2400)),
        );
      }
    });

    test('un pedido de la misma clave durante la espera se une', () async {
      final wake = Completer<void>();
      final scheduler = build(delay: (_) => wake.future);
      var runs = 0;
      Future<void> task() async {
        runs++;
        await request(limited: runs == 1);
      }

      final first = scheduler.run('ronda', SyncPriority.team, task);
      await Future<void>.delayed(Duration.zero);
      final second = scheduler.run('ronda', SyncPriority.visible, task);
      clock.advance(const Duration(seconds: 60));
      wake.complete();
      await Future.wait([first, second]);

      expect(runs, 2);
    });

    test('cancelar durante la espera descarta el reintento', () async {
      final scheduler = build(delay: (_) => Completer<void>().future);
      final token = CancelToken();
      var runs = 0;

      final job = scheduler.run('ronda', SyncPriority.team, () async {
        runs++;
        await request(limited: true);
      }, cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.pending, 1);
      token.cancel();

      await expectLater(job, throwsA(isA<SyncCancelled>()));
      expect(runs, 1);
      expect(scheduler.pending, 0);
    });

    test('un trabajo cancelado mientras corría no se reintenta', () async {
      final scheduler = build();
      final token = CancelToken();
      final gate = Completer<void>();
      var runs = 0;

      final job = scheduler.run('ronda', SyncPriority.team, () async {
        runs++;
        await gate.future;
        await request(limited: true);
      }, cancelToken: token);
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      gate.complete();

      await expectLater(job, throwsA(isA<RateLimitFailure>()));
      expect(runs, 1);
      expect(scheduler.pending, 0);
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
