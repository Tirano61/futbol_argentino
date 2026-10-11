import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
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

  TheSportsDbClient buildClient(
    Future<http.Response> Function(http.Request request) handler, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final limiter = RateLimiter(
      maxRequests: 25,
      clock: clock,
      delay: clock.delay,
    );
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
    );
  }

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
    final client = buildClient((_) async => http.Response('{}', 429));

    await expectLater(
      client.getJson('eventsround.php'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.rateLimited)
            .having((e) => e.statusCode, 'statusCode', 429),
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
}
