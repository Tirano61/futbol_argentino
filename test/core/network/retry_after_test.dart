import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/network/retry_after.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 20);

  group('parseRetryAfter', () {
    test('segundos', () {
      expect(parseRetryAfter('120', now: now), const Duration(seconds: 120));
      expect(parseRetryAfter(' 5 ', now: now), const Duration(seconds: 5));
      expect(parseRetryAfter('0', now: now), Duration.zero);
    });

    test('falta o no se entiende: null', () {
      expect(parseRetryAfter(null, now: now), isNull);
      expect(parseRetryAfter('', now: now), isNull);
      expect(parseRetryAfter('-5', now: now), isNull);
      expect(parseRetryAfter('1.5', now: now), isNull);
      expect(parseRetryAfter('pronto', now: now), isNull);
    });

    test('fecha HTTP: se mide contra el encabezado Date, no el reloj', () {
      // El reloj del dispositivo va 10 min adelantado: no influye.
      expect(
        parseRetryAfter(
          'Sun, 11 Oct 2026 19:51:30 GMT',
          date: 'Sun, 11 Oct 2026 19:50:00 GMT',
          now: now,
        ),
        const Duration(seconds: 90),
      );
    });

    test('fecha HTTP sin Date (o con Date inválido): contra el reloj', () {
      expect(
        parseRetryAfter('Sun, 11 Oct 2026 20:00:45 GMT', now: now),
        const Duration(seconds: 45),
      );
      expect(
        parseRetryAfter(
          'Sun, 11 Oct 2026 20:00:45 GMT',
          date: 'ayer',
          now: now,
        ),
        const Duration(seconds: 45),
      );
    });

    test('fecha ya pasada: sin espera', () {
      expect(
        parseRetryAfter('Sun, 11 Oct 2026 19:00:00 GMT', now: now),
        Duration.zero,
      );
    });
  });

  group('parseHttpDate', () {
    test('IMF-fixdate', () {
      expect(
        parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT'),
        DateTime.utc(1994, 11, 6, 8, 49, 37),
      );
    });

    test('formatos obsoletos y fechas imposibles: null', () {
      expect(parseHttpDate('Sunday, 06-Nov-94 08:49:37 GMT'), isNull);
      expect(parseHttpDate('Sun Nov  6 08:49:37 1994'), isNull);
      expect(parseHttpDate('Sun, 06 Nov 1994 08:49:37 UTC'), isNull);
      expect(parseHttpDate('Tue, 31 Feb 2026 10:00:00 GMT'), isNull);
      expect(parseHttpDate('Sun, 06 Foo 1994 08:49:37 GMT'), isNull);
      expect(parseHttpDate('Sun, 06 Nov 1994 25:00:00 GMT'), isNull);
    });
  });
}
