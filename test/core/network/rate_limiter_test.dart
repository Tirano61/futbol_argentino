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
}
