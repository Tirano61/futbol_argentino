import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/api_exception.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fixtures.dart';

void main() {
  late FakeClock clock;
  late List<Uri> requests;
  late RateLimiter limiter;

  TheSportsDbClient buildClient(
    Future<http.Response> Function(http.Request request) handler, {
    Duration timeout = const Duration(seconds: 15),
    bool isWeb = false,
    bool Function()? browserOnline,
  }) {
    limiter = RateLimiter(maxRequests: 25, clock: clock, delay: clock.delay);
    return TheSportsDbClient(
      config: AppConfig(
        apiKey: '123',
        enableDiagnostics: false,
        requestTimeout: timeout,
      ),
      httpClient: MockClient((request) {
        requests.add(request.url);
        return handler(request);
      }),
      rateLimiter: limiter,
      retryDelay: clock.delay,
      random: Random(0),
      clock: clock,
      isWeb: isWeb,
      browserOnline: browserOnline ?? () => true,
    );
  }

  http.Response tooMany([Map<String, String> headers = const {}]) =>
      http.Response('{}', 429, headers: headers);

  http.Response jsonResponse(List<int> bytes, [int status = 200]) =>
      http.Response.bytes(
        bytes,
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  setUp(() {
    clock = FakeClock();
    requests = [];
  });

  test('arma la URL con la clave y los parámetros', () async {
    final client = buildClient(
      (_) async => jsonResponse(fixtureBytes('eventsround_4406_r12_s2026')),
    );

    await client.getJson('eventsround.php', {
      'id': '4406',
      'r': '12',
      's': '2026',
    });

    expect(
      requests.single.toString(),
      'https://www.thesportsdb.com/api/v1/json/123/eventsround.php?id=4406&r=12&s=2026',
    );
  });

  test('devuelve el JSON de una respuesta real con acentos', () async {
    final client = buildClient(
      (_) async => jsonResponse(fixtureBytes('eventsround_4406_r12_s2026')),
    );

    final response = await client.getJson('eventsround.php');

    expect(response.statusCode, 200);
    final events = response.json['events'] as List;
    expect(events, hasLength(30));
    expect(
      events.map((e) => (e as Map)['strHomeTeam']),
      contains('Atlético Tucumán'),
    );
  });

  test('HTTP 429: no reintenta y pausa el rate limiter 60 s', () async {
    final client = buildClient((_) async => tooMany());

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.rateLimited)
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.retryAfter, 'retryAfter', isNull),
      ),
    );
    expect(requests, hasLength(1));

    // La consulta siguiente espera la pausa completa.
    final before = clock.now();
    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(isA<ApiException>()),
    );
    expect(clock.now().difference(before), const Duration(seconds: 60));
  });

  group('HTTP 429 y Retry-After', () {
    test('en segundos: pausa lo que pide el servidor', () async {
      final client = buildClient((_) async => tooMany({'retry-after': '30'}));

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 30),
              )
              .having((e) => e.message, 'message', contains('pausa 30 s')),
        ),
      );
      expect(requests, hasLength(1));
      expect(limiter.pausedUntil, clock.now().add(const Duration(seconds: 30)));
    });

    test('como fecha HTTP: medida contra el encabezado Date', () async {
      final client = buildClient(
        (_) async => tooMany({
          'retry-after': 'Sun, 11 Oct 2026 19:51:30 GMT',
          'date': 'Sun, 11 Oct 2026 19:50:00 GMT',
        }),
      );

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 90),
          ),
        ),
      );
      expect(limiter.pausedUntil, clock.now().add(const Duration(seconds: 90)));
    });

    test('inválido: espera propia de 60 s', () async {
      final client = buildClient(
        (_) async => tooMany({'retry-after': 'pronto'}),
      );

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(
          isA<ApiException>().having((e) => e.retryAfter, 'retryAfter', null),
        ),
      );
      expect(limiter.pausedUntil, clock.now().add(const Duration(seconds: 60)));
    });

    test('sin encabezado: la pausa crece si se repite el 429 y vuelve a 60 s '
        'después de una respuesta correcta', () async {
      final responses = [429, 429, 200, 429, 200];
      final client = buildClient(
        (_) async => responses.removeAt(0) == 429
            ? tooMany()
            : jsonResponse(utf8.encode('{"events": null}')),
      );

      for (var i = 0; i < 5; i++) {
        await client.getJson('eventsround.php').then((_) {}, onError: (_) {});
      }

      expect(requests, hasLength(5));
      expect(clock.delays, [
        const Duration(seconds: 60),
        const Duration(seconds: 120),
        // Primera salida después de la pausa: modo prudente.
        const Duration(milliseconds: 2400),
        const Duration(seconds: 60),
      ]);
    });

    test('dos 429 simultáneos: una sola pausa y un solo escalón', () async {
      final gate = Completer<void>();
      final client = buildClient((_) async {
        await gate.future;
        return tooMany();
      });
      final start = clock.now();

      final first = client.getJson('eventsround.php');
      final second = client.getJson('eventsround.php');
      while (requests.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      clock.advance(const Duration(milliseconds: 500));
      gate.complete();
      for (final call in [first, second]) {
        await expectLater(call, throwsA(isA<ApiException>()));
      }

      final until = start.add(const Duration(milliseconds: 60500));
      expect(limiter.pausedUntil, until);

      // El 429 siguiente es el segundo escalón (120 s), no el tercero.
      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(isA<ApiException>()),
      );
      expect(clock.now(), until);
      expect(limiter.pausedUntil, until.add(const Duration(seconds: 120)));
    });
  });

  test('HTTP 500 transitorio: reintenta con backoff y se recupera', () async {
    var calls = 0;
    final client = buildClient((_) async {
      calls++;
      return calls == 1
          ? http.Response('error', 500)
          : jsonResponse(utf8.encode('{"events": null}'));
    });

    final response = await client.getJson('eventsround.php');

    expect(response.json['events'], isNull);
    expect(requests, hasLength(2));
    expect(
      clock.delays.single,
      greaterThanOrEqualTo(const Duration(seconds: 1)),
    );
    expect(clock.delays.single, lessThan(const Duration(milliseconds: 1500)));
  });

  test('HTTP 500 persistente: 3 intentos y después falla', () async {
    final client = buildClient((_) async => http.Response('error', 503));

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.http)
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.rawBody, 'rawBody', 'error'),
      ),
    );
    expect(requests, hasLength(3));
  });

  test('HTTP 404: no reintenta', () async {
    final client = buildClient((_) async => http.Response('no', 404));

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
    expect(requests, hasLength(1));
  });

  test('JSON inválido: error de formato con el cuerpo recibido', () async {
    final client = buildClient(
      (_) async => jsonResponse(utf8.encode('<html>mantenimiento</html>')),
    );

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.format)
            .having((e) => e.rawBody, 'rawBody', '<html>mantenimiento</html>'),
      ),
    );
    expect(requests, hasLength(1));
  });

  test('raíz que no es objeto: error de formato', () async {
    final client = buildClient((_) async => jsonResponse(utf8.encode('[]')));

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'type',
          ApiExceptionType.format,
        ),
      ),
    );
  });

  test('timeout: reintenta y termina en error de timeout', () async {
    final client = buildClient(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'type',
          ApiExceptionType.timeout,
        ),
      ),
    );
    expect(requests, hasLength(3));
  });

  test('error de conexión: reintenta y conserva el mensaje real', () async {
    final client = buildClient(
      (_) async => throw http.ClientException('Connection refused'),
    );

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.connection)
            .having(
              (e) => e.message,
              'message',
              contains('Connection refused'),
            ),
      ),
    );
    expect(requests, hasLength(3));
  });

  group('Web (Fase R4)', () {
    final ok = fixtureBytes('eventsround_4406_r12_s2026');

    /// En Web, un 429 sin CORS llega igual que un fallo de red.
    Never failedToFetch() =>
        throw http.ClientException('TypeError: Failed to fetch');

    TypeMatcher<ApiException> apiError(
      ApiExceptionType type, {
      bool suspected = false,
    }) => isA<ApiException>()
        .having((e) => e.type, 'type', type)
        .having((e) => e.suspectedRateLimit, 'suspected', suspected);

    test('una falla ambigua sin respuesta reciente es posible CORS, sin '
        'reintentos ni espera', () async {
      final client = buildClient((_) async => failedToFetch(), isWeb: true);

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(apiError(ApiExceptionType.possibleCors)),
      );
      expect(requests, hasLength(1));
      expect(limiter.suspectedUntil, isNull);
    });

    test('poco después de una respuesta aceptada es sospecha de 429 oculto: '
        'espera 60 s sin dar el 429 por confirmado', () async {
      var fail = false;
      final client = buildClient((_) async {
        if (fail) failedToFetch();
        return jsonResponse(ok);
      }, isWeb: true);
      await client.getJson('eventsround.php');
      clock.advance(const Duration(seconds: 30));
      fail = true;

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(
          apiError(ApiExceptionType.possibleCors, suspected: true).having(
            (e) => e.toFailure(),
            'failure',
            isA<NetworkFailure>().having(
              (f) => f.suspectedRateLimit,
              'suspectedRateLimit',
              isTrue,
            ),
          ),
        ),
      );
      expect(requests, hasLength(2), reason: 'sin reintento del cliente');
      expect(
        limiter.suspectedUntil,
        clock.now().add(RateLimiter.suspicionPause),
      );
      expect(limiter.pausedUntil, isNull);
      expect(limiter.consecutiveRateLimits, 0);
    });

    test(
      'con navigator.onLine en false es «sin red», nunca sospecha',
      () async {
        var online = true;
        var fail = false;
        final client = buildClient(
          (_) async {
            if (fail) failedToFetch();
            return jsonResponse(ok);
          },
          isWeb: true,
          browserOnline: () => online,
        );
        await client.getJson('eventsround.php');
        fail = true;
        online = false;

        await expectLater(
          client.getJson('eventsround.php'),
          throwsA(
            apiError(ApiExceptionType.offline).having(
              (e) => e.toFailure(),
              'failure',
              isA<NetworkFailure>().having(
                (f) => f.issue,
                'issue',
                NetworkIssue.offline,
              ),
            ),
          ),
        );
        expect(requests, hasLength(2), reason: 'sin reintentos');
        expect(limiter.suspectedUntil, isNull);
      },
    );

    test('un 429 visible sigue el flujo de R1', () async {
      final client = buildClient((request) async {
        if (requests.length == 1) return jsonResponse(ok);
        return tooMany({'retry-after': '90'});
      }, isWeb: true);
      await client.getJson('eventsround.php');

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(
          apiError(ApiExceptionType.rateLimited).having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 90),
          ),
        ),
      );
      expect(limiter.pausedUntil, clock.now().add(const Duration(seconds: 90)));
      expect(limiter.suspectedUntil, isNull);
      expect(limiter.consecutiveRateLimits, 1);
    });

    test('401, 403, 404 y 500 visibles siguen siendo errores HTTP', () async {
      for (final status in [401, 403, 404, 500]) {
        requests.clear();
        final client = buildClient(
          (_) async => http.Response('{}', status),
          isWeb: true,
        );
        await expectLater(
          client.getJson('eventsround.php'),
          throwsA(
            apiError(
              ApiExceptionType.http,
            ).having((e) => e.statusCode, 'statusCode', status),
          ),
        );
        expect(
          requests,
          hasLength(status >= 500 ? 3 : 1),
          reason: 'solo el 5xx se reintenta',
        );
        expect(limiter.suspectedUntil, isNull);
      }
    });

    test('timeout: reintentos transitorios, sin sospecha', () async {
      var first = true;
      final client = buildClient(
        (_) async {
          if (first) {
            first = false;
            return jsonResponse(ok);
          }
          return Completer<http.Response>().future;
        },
        isWeb: true,
        timeout: const Duration(milliseconds: 20),
      );
      await client.getJson('eventsround.php');

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(apiError(ApiExceptionType.timeout)),
      );
      expect(requests, hasLength(4));
      expect(limiter.suspectedUntil, isNull);
    });

    test('Android: el mismo error sigue siendo de conexión, con sus '
        'reintentos y sin sospecha', () async {
      var fail = false;
      final client = buildClient((_) async {
        if (fail) failedToFetch();
        return jsonResponse(ok);
      });
      await client.getJson('eventsround.php');
      fail = true;

      await expectLater(
        client.getJson('eventsround.php'),
        throwsA(apiError(ApiExceptionType.connection)),
      );
      expect(requests, hasLength(4));
      expect(limiter.suspectedUntil, isNull);
      expect(limiter.inSuspicion, isFalse);
    });
  });
}
