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

    // Fase R4 (Web): una falla de red ambigua poco después de una respuesta
    // aceptada es sospecha de 429 oculto por CORS: una espera de 60 s y un
    // reintento, de a uno, sin contar como 429.
    group('posible 429 oculto', () {
      const pause = RateLimiter.suspicionPause;

      /// Hora de envío de cada consulta.
      late List<DateTime> sent;

      /// Esperas del scheduler que terminan solo con [releaseUntil].
      late List<Completer<void>> held;

      setUp(() {
        sent = [];
        held = [];
      });

      Future<void> heldDelay(Duration duration) {
        final wake = Completer<void>();
        held.add(wake);
        return wake.future.then((_) => clock.advance(duration));
      }

      /// Termina las esperas retenidas, a medida que aparecen, hasta que
      /// termina [work].
      Future<void> releaseUntil(Future<void> work) async {
        var done = false;
        unawaited(work.then((_) => done = true, onError: (_) => done = true));
        while (!done) {
          for (final wake in [...held]) {
            if (!wake.isCompleted) wake.complete();
          }
          await Future<void>.delayed(Duration.zero);
        }
      }

      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      /// Una consulta como la del cliente en Web: pide turno y, si [fail],
      /// falla como «Failed to fetch» (con [offline], el navegador informa
      /// que no hay red). Con [hold], espera antes de responder.
      Future<void> webRequest({
        bool fail = false,
        bool offline = false,
        Future<void>? hold,
      }) async {
        final sentAt = await limiter.acquire();
        sent.add(sentAt);
        if (hold != null) await hold;
        if (!fail) {
          limiter.recordAccepted(sentAt);
          return;
        }
        if (offline) {
          throw const NetworkFailure(
            issue: NetworkIssue.offline,
            detail: 'Sin red (test)',
          );
        }
        throw NetworkFailure(
          issue: NetworkIssue.possibleCors,
          detail: 'Failed to fetch (test)',
          suspectedRateLimit: limiter.suspectRateLimit(sentAt: sentAt),
        );
      }

      /// Resultado de un trabajo: `null` si terminó bien, o el error.
      Future<Object?> outcome(Future<void> job) =>
          job.then<Object?>((_) => null, onError: (Object e) => e);

      Matcher networkFailure(NetworkIssue issue, {required bool suspected}) =>
          isA<NetworkFailure>()
              .having((f) => f.issue, 'issue', issue)
              .having((f) => f.suspectedRateLimit, 'suspected', suspected);

      /// Una respuesta aceptada poco antes (la condición de la sospecha).
      Future<void> recentSuccess(SyncScheduler scheduler) async {
        await scheduler.run('previa', SyncPriority.visible, webRequest);
        clock.advance(const Duration(seconds: 30));
      }

      test('recuperación: una espera de 60 s y un reintento que '
          'responde', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        var runs = 0;

        await scheduler.run('ronda', SyncPriority.visible, () async {
          runs++;
          await webRequest(fail: runs == 1);
        });

        expect(runs, 2);
        expect(clock.delays, [pause]);
        expect(sent.last.difference(sent[1]), pause);
        expect(limiter.inSuspicion, isFalse, reason: 'cerró el episodio');
        expect(limiter.pausedUntil, isNull);
        expect(limiter.consecutiveRateLimits, 0);
        expect(scheduler.pending, 0);
      });

      test('sin una respuesta reciente: falla en el acto, como hoy', () async {
        final scheduler = build();
        var runs = 0;

        final error = await outcome(
          scheduler.run('ronda', SyncPriority.visible, () async {
            runs++;
            await webRequest(fail: true);
          }),
        );

        expect(
          error,
          networkFailure(NetworkIssue.possibleCors, suspected: false),
        );
        expect(runs, 1);
        expect(clock.delays, isEmpty);
      });

      test('conexión perdida: un solo reintento, error marcado y los pedidos '
          'siguientes no abren otra espera', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        var runs = 0;

        final error = await outcome(
          scheduler.run('ronda', SyncPriority.visible, () async {
            runs++;
            await webRequest(fail: true);
          }),
        );

        expect(runs, 2);
        expect(
          error,
          networkFailure(NetworkIssue.possibleCors, suspected: true),
        );
        expect((error! as Failure).limitsQueries, isTrue);
        expect(clock.delays, [pause]);

        // Otro pedido dentro de los 2 min: sin espera ni reintento (sale
        // espaciado: modo prudente).
        runs = 0;
        final next = await outcome(
          scheduler.run('otra', SyncPriority.visible, () async {
            runs++;
            await webRequest(fail: true);
          }),
        );
        expect(runs, 1);
        expect(
          next,
          networkFailure(NetworkIssue.possibleCors, suspected: true),
        );
        expect(clock.delays, [pause, limiter.cautiousGap]);
        expect(limiter.consecutiveRateLimits, 0);
        expect(scheduler.isRateLimitBlocked, isFalse);
      });

      test('si en el reintento el navegador informa que no hay red: «sin '
          'red», sin otro intento', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        var runs = 0;

        final error = await outcome(
          scheduler.run('ronda', SyncPriority.visible, () async {
            runs++;
            await webRequest(fail: true, offline: runs > 1);
          }),
        );

        expect(runs, 2);
        expect(error, networkFailure(NetworkIssue.offline, suspected: false));
        expect(clock.delays, [pause]);
      });

      test('dos trabajos fallan juntos: una espera, una sonda y, si falla, '
          'el otro termina sin consultar', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        final gate = Completer<void>();
        final runs = <String, int>{'a': 0, 'b': 0};
        Future<void> job(String key) async {
          runs[key] = runs[key]! + 1;
          await webRequest(
            fail: true,
            hold: runs[key] == 1 ? gate.future : null,
          );
        }

        final a = outcome(
          scheduler.run('a', SyncPriority.visible, () => job('a')),
        );
        final b = outcome(
          scheduler.run('b', SyncPriority.visible, () => job('b')),
        );
        await settle();
        clock.advance(const Duration(milliseconds: 300));
        gate.complete();

        final errors = await Future.wait([a, b]);
        expect(runs, {'a': 2, 'b': 1});
        expect(sent, hasLength(1 + 3), reason: 'la previa, 2 y la sonda');
        for (final error in errors) {
          expect(
            error,
            networkFailure(NetworkIssue.possibleCors, suspected: true),
          );
        }
        expect(clock.delays, [pause], reason: 'una sola espera');
        expect(scheduler.pending, 0);
      });

      test('si la sonda responde, los demás siguen espaciados', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        final gate = Completer<void>();
        final runs = <String, int>{'a': 0, 'b': 0, 'c': 0};
        Future<void> job(String key) async {
          runs[key] = runs[key]! + 1;
          final first = runs[key] == 1 && key != 'c';
          await webRequest(fail: first, hold: first ? gate.future : null);
        }

        final jobs = [
          for (final key in ['a', 'b'])
            scheduler.run(key, SyncPriority.visible, () => job(key)),
        ];
        await settle();
        gate.complete();
        jobs.add(scheduler.run('c', SyncPriority.context, () => job('c')));
        await Future.wait(jobs);

        expect(runs, {'a': 2, 'b': 2, 'c': 1});
        final afterPause = sent.sublist(3);
        expect(afterPause, hasLength(3));
        expect(afterPause[0].difference(sent[1]), pause);
        expect(afterPause[1].difference(afterPause[0]), limiter.cautiousGap);
        expect(afterPause[2].difference(afterPause[1]), limiter.cautiousGap);
        expect(limiter.inSuspicion, isFalse);
      });

      test('mismo key durante la espera: un solo trabajo', () async {
        final scheduler = build(delay: heldDelay);
        await recentSuccess(scheduler);
        var runs = 0;
        Future<void> task() async {
          runs++;
          await webRequest(fail: runs == 1);
        }

        final first = scheduler.run('ronda', SyncPriority.context, task);
        await settle();
        expect(held, hasLength(1), reason: 'esperando');
        final second = scheduler.run('ronda', SyncPriority.visible, task);
        expect(scheduler.pending, 1);
        await releaseUntil(Future.wait([first, second]));

        expect(runs, 2);
        expect(sent, hasLength(1 + 2));
      });

      test('cancelado durante la espera: no vuelve a consultar', () async {
        final scheduler = build(delay: heldDelay);
        await recentSuccess(scheduler);
        final token = CancelToken();
        var runs = 0;

        final job = scheduler.run('ronda', SyncPriority.team, () async {
          runs++;
          await webRequest(fail: true);
        }, cancelToken: token);
        await settle();
        expect(runs, 1);
        expect(scheduler.pending, 1, reason: 'en la cola, esperando');
        token.cancel();

        await expectLater(job, throwsA(isA<SyncCancelled>()));
        for (final wake in held) {
          wake.complete();
        }
        await settle();
        expect(runs, 1);
        expect(sent, hasLength(1 + 1));
        expect(scheduler.pending, 0);
      });

      test('al terminar la espera elige por prioridad y la sonda va '
          'sola', () async {
        final scheduler = build(delay: heldDelay);
        await recentSuccess(scheduler);
        final log = <String>[];
        Future<void> job(String key, {bool fail = false}) async {
          log.add('empieza $key');
          try {
            await webRequest(fail: fail);
          } finally {
            log.add('termina $key');
          }
        }

        var first = true;
        final jobs = [
          scheduler
              .run('p1', SyncPriority.context, () {
                final fail = first;
                first = false;
                return job('p1', fail: fail);
              })
              .catchError((_) {}),
        ];
        await settle();
        jobs
          ..add(scheduler.run('p2', SyncPriority.team, () => job('p2')))
          ..add(scheduler.run('p1b', SyncPriority.context, () => job('p1b')))
          ..add(scheduler.run('p0', SyncPriority.visible, () => job('p0')));
        await settle();
        expect(log, [
          'empieza p1',
          'termina p1',
        ], reason: 'nada empieza durante la espera');

        await releaseUntil(Future.wait(jobs));

        final starts = [
          for (final entry in log)
            if (entry.startsWith('empieza')) entry.substring(8),
        ];
        expect(starts, ['p1', 'p0', 'p1', 'p1b', 'p2']);
        expect(
          log.indexOf('termina p0'),
          lessThan(log.lastIndexOf('empieza p1')),
          reason: 'la sonda sola, hasta su respuesta',
        );
      });

      test('un 429 visible durante el episodio sigue R2 sin cambios', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        var runs = 0;

        await scheduler.run('ronda', SyncPriority.visible, () async {
          runs++;
          if (runs == 1) return webRequest(fail: true);
          if (runs == 2) return request(limited: true);
          return request();
        });

        expect(runs, 3);
        expect(clock.delays, [pause, const Duration(seconds: 60)]);
        expect(limiter.consecutiveRateLimits, 0);
      });

      test('una sospecha no cuenta para el bloqueo persistente', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        // Un 429 y después una sospecha: los 429 seguidos siguen en 1.
        var runs = 0;
        int? streak;
        await scheduler.run('ronda', SyncPriority.visible, () async {
          runs++;
          if (runs == 1) return request(limited: true);
          if (runs == 2) {
            try {
              await webRequest(fail: true);
            } finally {
              streak = limiter.consecutiveRateLimits;
            }
          }
          await request();
        });

        expect(runs, 3);
        expect(streak, 1);
        expect(scheduler.isRateLimitBlocked, isFalse);
      });

      test('con el bloqueo persistente confirmado no hay reintento por '
          'sospecha', () async {
        final scheduler = build();
        await recentSuccess(scheduler);
        // 3 HTTP 429 seguidos (R3.1).
        await outcome(
          scheduler.run('l', SyncPriority.visible, () async {
            await request(limited: true);
          }),
        );
        expect(scheduler.isRateLimitBlocked, isTrue);
        var runs = 0;

        final error = await outcome(
          scheduler.run('ronda', SyncPriority.visible, () async {
            runs++;
            await limiter.acquire();
            throw const NetworkFailure(
              issue: NetworkIssue.possibleCors,
              detail: 'Failed to fetch (test)',
              suspectedRateLimit: true,
            );
          }),
        );

        expect(runs, 1);
        expect(error, isA<NetworkFailure>());
      });
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
