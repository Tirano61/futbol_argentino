import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';

import '../../helpers/fake_clock.dart';

void main() {
  late FakeClock clock;
  late RateLimiter limiter;

  setUp(() {
    clock = FakeClock();
    limiter = RateLimiter(maxRequests: 3, clock: clock, delay: clock.delay);
  });

  test('deja pasar hasta el tope sin esperar', () async {
    for (var i = 0; i < 3; i++) {
      await limiter.acquire();
    }

    expect(clock.delays, isEmpty);
  });

  test(
    'la petición siguiente al tope espera a que se libere la ventana',
    () async {
      final start = clock.now();
      for (var i = 0; i < 3; i++) {
        await limiter.acquire();
      }
      clock.advance(const Duration(seconds: 10));

      await limiter.acquire();

      expect(clock.now().difference(start), const Duration(minutes: 1));
      expect(clock.delays, [const Duration(seconds: 50)]);
    },
  );

  test('las peticiones se atienden en orden de llegada', () async {
    final order = <int>[];

    await Future.wait([
      for (var i = 0; i < 6; i++) limiter.acquire().then((_) => order.add(i)),
    ]);

    expect(order, [0, 1, 2, 3, 4, 5]);
  });

  test('pauseFor bloquea aunque haya cupo (HTTP 429)', () async {
    limiter.pauseFor(const Duration(seconds: 60));

    await limiter.acquire();

    expect(clock.delays, [const Duration(seconds: 60)]);
  });

  test('una pausa más corta no acorta una pausa vigente', () async {
    limiter
      ..pauseFor(const Duration(seconds: 60))
      ..pauseFor(const Duration(seconds: 5));

    await limiter.acquire();

    expect(clock.delays, [const Duration(seconds: 60)]);
  });

  test('informa la pausa y hasta cuándo dura', () async {
    final pauses = <DateTime>[];
    limiter.pauses.listen(pauses.add);
    final until = clock.now().add(const Duration(seconds: 60));

    limiter
      ..pauseFor(const Duration(seconds: 60))
      ..pauseFor(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);

    expect(pauses, [until], reason: 'la pausa más corta no cambia nada');
    expect(limiter.pausedUntil, until);
    clock.advance(const Duration(seconds: 60));
    expect(limiter.pausedUntil, isNull);
  });

  test('informa solo las esperas por el tope de 3 s o más', () async {
    final throttles = <DateTime>[];
    limiter.throttles.listen(throttles.add);
    final start = clock.now();
    for (var i = 0; i < 3; i++) {
      await limiter.acquire();
    }
    clock.advance(const Duration(seconds: 58));

    // Espera 2 s: no se avisa.
    await limiter.acquire();
    // Las dos siguientes entran en la ventana; la tercera espera 1 min.
    for (var i = 0; i < 3; i++) {
      await limiter.acquire();
    }
    await Future<void>.delayed(Duration.zero);

    expect(clock.delays, [
      const Duration(seconds: 2),
      const Duration(minutes: 1),
    ]);
    expect(throttles, [start.add(const Duration(minutes: 2))]);
  });

  group('HTTP 429', () {
    const s = Duration(seconds: 1);

    test('sin Retry-After, la pausa crece con cada 429 seguido', () async {
      final pauses = <Duration>[];
      for (var i = 0; i < 4; i++) {
        final sentAt = await limiter.acquire();
        clock.advance(const Duration(milliseconds: 300));
        pauses.add(limiter.rateLimited(sentAt: sentAt));
      }

      expect(pauses, [s * 60, s * 120, s * 240, s * 240]);
    });

    test(
      'una respuesta aceptada después de la pausa vuelve a la primera',
      () async {
        final first = await limiter.acquire();
        clock.advance(s);
        expect(limiter.rateLimited(sentAt: first), s * 60);

        limiter.recordAccepted(await limiter.acquire());
        final third = await limiter.acquire();
        clock.advance(s);

        expect(limiter.rateLimited(sentAt: third), s * 60);
      },
    );

    test(
      'una respuesta aceptada enviada antes de la pausa no la reinicia',
      () async {
        final first = await limiter.acquire();
        final second = await limiter.acquire();
        clock.advance(s);
        limiter.rateLimited(sentAt: first);
        limiter.recordAccepted(second);

        final third = await limiter.acquire();
        clock.advance(s);

        expect(limiter.rateLimited(sentAt: third), s * 120);
      },
    );

    test('429 simultáneos: una sola pausa, sin escalar ni alargar', () async {
      final pauses = <DateTime>[];
      limiter.pauses.listen(pauses.add);
      final start = clock.now();
      final first = await limiter.acquire();
      final second = await limiter.acquire();
      clock.advance(s);

      expect(limiter.rateLimited(sentAt: first), s * 60);
      clock.advance(s);
      expect(limiter.rateLimited(sentAt: second), s * 59);
      await Future<void>.delayed(Duration.zero);

      final until = start.add(s * 61);
      expect(limiter.pausedUntil, until);
      expect(pauses, [until]);

      // El siguiente 429 es el segundo, no el tercero.
      final third = await limiter.acquire();
      clock.advance(s);
      expect(limiter.rateLimited(sentAt: third), s * 120);
    });

    test('respeta Retry-After', () async {
      final sentAt = await limiter.acquire();

      expect(limiter.rateLimited(sentAt: sentAt, retryAfter: s * 30), s * 30);
      await limiter.acquire();
      expect(clock.delays, [s * 30]);
    });

    test('Retry-After se acota entre 1 s y 10 min', () async {
      final first = await limiter.acquire();
      expect(limiter.rateLimited(sentAt: first, retryAfter: Duration.zero), s);

      final second = await limiter.acquire();
      expect(
        limiter.rateLimited(
          sentAt: second,
          retryAfter: const Duration(hours: 1),
        ),
        const Duration(minutes: 10),
      );
    });

    test(
      'un Retry-After más largo en un 429 simultáneo alarga la pausa',
      () async {
        final first = await limiter.acquire();
        final second = await limiter.acquire();
        clock.advance(s);
        limiter.rateLimited(sentAt: first);

        expect(limiter.rateLimited(sentAt: second, retryAfter: s * 90), s * 90);
      },
    );

    test(
      'al reanudar, las que esperaban salen de a una cada 2,4 s (sin ráfaga)',
      () async {
        final limiter = RateLimiter(
          maxRequests: 25,
          clock: clock,
          delay: clock.delay,
        );
        final throttles = <DateTime>[];
        limiter.throttles.listen(throttles.add);
        final start = clock.now();
        limiter.rateLimited(sentAt: await limiter.acquire());

        final sent = await Future.wait([
          for (var i = 0; i < 25; i++) limiter.acquire(),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(limiter.cautiousGap, const Duration(milliseconds: 2400));
        expect(sent, [
          for (var i = 0; i < 25; i++)
            start.add(s * 60 + const Duration(milliseconds: 2400) * i),
        ]);
        expect(clock.delays, [
          s * 60,
          for (var i = 1; i < 25; i++) const Duration(milliseconds: 2400),
        ]);
        expect(throttles, isEmpty, reason: 'las esperas de 2,4 s no se avisan');
      },
    );

    test('el modo prudente dura una ventana después de la pausa', () async {
      final limiter = RateLimiter(
        maxRequests: 25,
        clock: clock,
        delay: clock.delay,
      );
      limiter.rateLimited(sentAt: await limiter.acquire());
      await limiter.acquire();
      clock.advance(s * 60);
      clock.delays.clear();

      for (var i = 0; i < 5; i++) {
        await limiter.acquire();
      }

      expect(clock.delays, isEmpty);
    });

    test('un 429 durante el modo prudente vuelve a pausar', () async {
      final limiter = RateLimiter(
        maxRequests: 25,
        clock: clock,
        delay: clock.delay,
      );
      limiter.rateLimited(sentAt: await limiter.acquire());
      final resumed = await limiter.acquire();
      clock.advance(s);
      limiter.rateLimited(sentAt: resumed);
      clock.delays.clear();

      await limiter.acquire();

      expect(clock.delays, [s * 120]);
    });
  });

  // Fase R3.1: la racha de 429 seguidos que usa el scheduler para dar un
  // bloqueo por persistente. Las pausas no cambian.
  group('429 seguidos (consecutiveRateLimits)', () {
    const s = Duration(seconds: 1);

    /// Una consulta que sale y recibe 429; devuelve la pausa.
    Future<Duration> limited() async {
      final sentAt = await limiter.acquire();
      clock.advance(const Duration(milliseconds: 300));
      return limiter.rateLimited(sentAt: sentAt);
    }

    test('cuenta los 429 seguidos con las mismas pausas de R1', () async {
      expect(limiter.consecutiveRateLimits, 0);
      final pauses = [for (var i = 0; i < 4; i++) await limited()];

      expect(pauses, [s * 60, s * 120, s * 240, s * 240]);
      expect(limiter.consecutiveRateLimits, 4);
    });

    test('dos 429 de consultas que salieron juntas cuentan uno', () async {
      final first = await limiter.acquire();
      final second = await limiter.acquire();
      clock.advance(s);
      limiter.rateLimited(sentAt: first);
      clock.advance(s);
      limiter.rateLimited(sentAt: second);

      expect(limiter.consecutiveRateLimits, 1);
    });

    test('una respuesta aceptada después de la pausa la vuelve a 0', () async {
      await limited();
      await limited();
      limiter.recordAccepted(await limiter.acquire());

      expect(limiter.consecutiveRateLimits, 0);
      await limited();
      expect(limiter.consecutiveRateLimits, 1);
    });

    test('pasada una ventana desde el fin de la pausa, se lee 0 y el 429 '
        'siguiente empieza otro episodio (la pausa sigue escalada)', () async {
      for (var i = 0; i < 3; i++) {
        await limited();
      }
      expect(limiter.consecutiveRateLimits, 3);

      // Termina la pausa de 240 s y pasa más de un minuto sin consultas.
      clock.advance(const Duration(minutes: 6));
      expect(limiter.consecutiveRateLimits, 0);

      expect(await limited(), s * 240, reason: 'R1 sin cambios');
      expect(limiter.consecutiveRateLimits, 1);
    });

    test('un 429 enseguida después de la pausa sigue el episodio', () async {
      await limited();
      await limited();
      // `acquire` espera la pausa de 120 s y sale enseguida.
      await limited();

      expect(limiter.consecutiveRateLimits, 3);
    });
  });

  test('mientras dura la espera por el tope, informa hasta cuándo', () async {
    final gate = Completer<void>();
    final limiter = RateLimiter(
      maxRequests: 1,
      clock: clock,
      delay: (_) => gate.future,
    );
    await limiter.acquire();

    final second = limiter.acquire();
    await Future<void>.delayed(Duration.zero);

    expect(limiter.throttledUntil, clock.now().add(const Duration(minutes: 1)));
    clock.advance(const Duration(minutes: 1));
    expect(limiter.throttledUntil, isNull);
    gate.complete();
    await second;
  });

  group('sospecha de 429 oculto (Fase R4)', () {
    const s = Duration(seconds: 1);

    /// Una consulta que sale y es aceptada.
    Future<void> accepted() async {
      final sentAt = await limiter.acquire();
      clock.advance(const Duration(milliseconds: 300));
      limiter.recordAccepted(sentAt);
    }

    /// Una consulta que sale y falla por red (ambigua); devuelve si es
    /// sospecha.
    Future<bool> failed() async {
      final sentAt = await limiter.acquire();
      clock.advance(const Duration(milliseconds: 300));
      return limiter.suspectRateLimit(sentAt: sentAt);
    }

    test('sin una respuesta aceptada antes no es sospecha', () async {
      expect(await failed(), isFalse);
      expect(limiter.suspectedUntil, isNull);
      expect(limiter.inSuspicion, isFalse);

      final before = clock.now();
      await limiter.acquire();
      expect(clock.now(), before, reason: 'sin espera');
    });

    test('con una respuesta aceptada hace menos de 2 min: espera 60 s, '
        'aparte de la pausa por 429', () async {
      await accepted();
      clock.advance(const Duration(seconds: 100));
      final until = limiter.suspicions.first;

      expect(await failed(), isTrue);
      final expected = clock.now().add(s * 60);
      expect(limiter.suspectedUntil, expected);
      expect(await until, expected);
      expect(limiter.inSuspicion, isTrue);
      expect(limiter.pausedUntil, isNull, reason: 'no es un 429');
      expect(limiter.consecutiveRateLimits, 0);

      await limiter.acquire();
      expect(clock.now(), expected, reason: 'la consulta siguiente espera');
    });

    test('con la última respuesta aceptada hace más de 2 min no es '
        'sospecha', () async {
      await accepted();
      clock.advance(const Duration(minutes: 2, seconds: 1));

      expect(await failed(), isFalse);
      expect(limiter.suspectedUntil, isNull);
    });

    test('dos consultas que salieron juntas: una sola espera', () async {
      await accepted();
      final first = await limiter.acquire();
      final second = await limiter.acquire();
      clock.advance(s);

      expect(limiter.suspectRateLimit(sentAt: first), isTrue);
      final until = limiter.suspectedUntil;
      clock.advance(s * 5);
      expect(limiter.suspectRateLimit(sentAt: second), isTrue);
      expect(limiter.suspectedUntil, until, reason: 'no se alarga');
    });

    test('si el reintento vuelve a fallar se gasta el episodio: no hay otra '
        'espera hasta una respuesta aceptada', () async {
      await accepted();
      expect(await failed(), isTrue);

      // El reintento sale después de la espera y falla.
      expect(await failed(), isFalse);
      expect(limiter.suspectedUntil, isNull);
      expect(limiter.inSuspicion, isTrue, reason: 'sigue abierto');

      // Los pedidos siguientes no la reabren, aunque sean dentro de 2 min.
      expect(await failed(), isFalse);
      expect(limiter.suspectedUntil, isNull);

      // Una respuesta aceptada cierra el episodio: otra falla vuelve a ser
      // sospecha.
      await accepted();
      expect(limiter.inSuspicion, isFalse);
      expect(await failed(), isTrue);
    });

    test('una respuesta aceptada de una consulta que salió antes de la '
        'espera no cierra el episodio', () async {
      await accepted();
      final early = await limiter.acquire();
      expect(await failed(), isTrue);

      limiter.recordAccepted(early);

      expect(limiter.inSuspicion, isTrue);
      expect(await failed(), isFalse, reason: 'el reintento falló');
    });

    test('al terminar la espera, las consultas salen espaciadas', () async {
      await accepted();
      expect(await failed(), isTrue);
      final until = limiter.suspectedUntil!;

      final first = await limiter.acquire();
      final second = await limiter.acquire();

      expect(first, until);
      expect(second.difference(first), limiter.cautiousGap);
    });

    test('no cambia las pausas de R1 ni los 429 seguidos', () async {
      await accepted();
      expect(await failed(), isTrue);

      final sentAt = await limiter.acquire();
      clock.advance(s);
      expect(limiter.rateLimited(sentAt: sentAt), s * 60);
      expect(limiter.consecutiveRateLimits, 1);
    });
  });
}
