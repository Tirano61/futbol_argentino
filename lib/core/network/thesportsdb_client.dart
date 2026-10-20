import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../time/clock.dart';
import 'api_exception.dart';
import 'rate_limiter.dart';
import 'retry_after.dart';

/// Respuesta exitosa (HTTP 2xx) con JSON válido cuya raíz es un objeto.
class ApiResponse {
  const ApiResponse({
    required this.uri,
    required this.statusCode,
    required this.elapsed,
    required this.json,
  });

  final Uri uri;
  final int statusCode;
  final Duration elapsed;
  final Map<String, dynamic> json;
}

/// Único punto de acceso HTTP a TheSportsDB (mismo código en Android y Web).
class TheSportsDbClient {
  TheSportsDbClient({
    required AppConfig config,
    required http.Client httpClient,
    required RateLimiter rateLimiter,
    Delay retryDelay = _realDelay,
    Random? random,
    Clock clock = const SystemClock(),
  }) : _config = config,
       _http = httpClient,
       _rateLimiter = rateLimiter,
       _retryDelay = retryDelay,
       _random = random ?? Random(),
       _clock = clock;

  /// Esperas antes de cada reintento (se les suma hasta 500 ms al azar).
  static const retryBackoff = [Duration(seconds: 1), Duration(seconds: 3)];

  final AppConfig _config;
  final http.Client _http;
  final RateLimiter _rateLimiter;
  final Delay _retryDelay;
  final Random _random;

  /// Para una fecha de `Retry-After` sin encabezado `Date`.
  final Clock _clock;

  /// GET a `<base>/<endpoint>?<query>`. Lanza [ApiException] si falla.
  Future<ApiResponse> getJson(
    String endpoint, [
    Map<String, String> query = const {},
  ]) async {
    final uri = _config.apiBaseUri
        .resolve(endpoint)
        .replace(queryParameters: query.isEmpty ? null : query);

    for (var attempt = 0; ; attempt++) {
      try {
        return await _send(uri);
      } on ApiException catch (e) {
        if (!e.isTransient || attempt >= retryBackoff.length) rethrow;
        final wait =
            retryBackoff[attempt] +
            Duration(milliseconds: _random.nextInt(500));
        debugPrint(
          'TheSportsDB reintento ${attempt + 1} en ${wait.inMilliseconds} ms '
          '(${e.type.name}): $uri',
        );
        await _retryDelay(wait);
      }
    }
  }

  Future<ApiResponse> _send(Uri uri) async {
    final sentAt = await _rateLimiter.acquire();
    debugPrint('GET $uri');

    final stopwatch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await _http.get(uri).timeout(_config.requestTimeout);
    } on TimeoutException catch (e) {
      throw ApiException(
        type: ApiExceptionType.timeout,
        message:
            'Sin respuesta en ${_config.requestTimeout.inSeconds} s para $uri '
            '($e)',
        uri: uri,
        elapsed: stopwatch.elapsed,
      );
    } on http.ClientException catch (e) {
      // En Web, un bloqueo CORS y un fallo de red llegan como el mismo
      // ClientException ("Failed to fetch"): el navegador no le expone la
      // causa a Dart.
      throw ApiException(
        type: kIsWeb
            ? ApiExceptionType.possibleCors
            : ApiExceptionType.connection,
        message: kIsWeb
            ? '${e.runtimeType}: $e\n'
                  'El navegador no informa la causa a la app: puede ser un '
                  'bloqueo CORS o un fallo de red. Revisar la consola de '
                  'Chrome (F12) para ver el motivo exacto.'
            : '${e.runtimeType}: $e',
        uri: uri,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      // Por ejemplo HandshakeException (TLS) en Android.
      throw ApiException(
        type: ApiExceptionType.connection,
        message: '${e.runtimeType}: $e',
        uri: uri,
        elapsed: stopwatch.elapsed,
      );
    }
    stopwatch.stop();
    final elapsed = stopwatch.elapsed;
    debugPrint(
      'TheSportsDB HTTP ${response.statusCode} en ${elapsed.inMilliseconds} ms',
    );

    String body() => utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode == 429) {
      final header = response.headers['retry-after'];
      final retryAfter = parseRetryAfter(
        header,
        date: response.headers['date'],
        now: _clock.now(),
      );
      final pause = _rateLimiter.rateLimited(
        sentAt: sentAt,
        retryAfter: retryAfter,
      );
      debugPrint(
        'TheSportsDB 429: Retry-After=${header ?? '(sin encabezado)'}, '
        'pausa ${pause.inSeconds} s',
      );
      throw ApiException(
        type: ApiExceptionType.rateLimited,
        message:
            'TheSportsDB respondió HTTP 429 (límite de peticiones). '
            '${header != null ? 'Retry-After: $header. ' : ''}'
            'Consultas en pausa ${pause.inSeconds} s.',
        uri: uri,
        statusCode: 429,
        elapsed: elapsed,
        rawBody: body(),
        retryAfter: retryAfter,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        type: ApiExceptionType.http,
        message:
            'El servidor respondió HTTP ${response.statusCode}'
            '${response.reasonPhrase != null ? ' ${response.reasonPhrase}' : ''}',
        uri: uri,
        statusCode: response.statusCode,
        elapsed: elapsed,
        rawBody: body(),
      );
    }
    _rateLimiter.recordAccepted(sentAt);

    Never formatError(String message) => throw ApiException(
      type: ApiExceptionType.format,
      message: message,
      uri: uri,
      statusCode: response.statusCode,
      elapsed: elapsed,
      rawBody: body(),
    );

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      formatError(
        'FormatException: ${e.message}'
        '${e.offset != null ? ' (posición ${e.offset})' : ''}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      formatError(
        'Se esperaba un objeto JSON en la raíz y llegó ${decoded.runtimeType}',
      );
    }

    return ApiResponse(
      uri: uri,
      statusCode: response.statusCode,
      elapsed: elapsed,
      json: decoded,
    );
  }
}

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);
