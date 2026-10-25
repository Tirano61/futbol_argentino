import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../time/clock.dart';
import 'api_exception.dart';
import 'browser_online.dart' as browser;
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
    bool isWeb = kIsWeb,
    bool Function()? browserOnline,
  }) : _config = config,
       _http = httpClient,
       _rateLimiter = rateLimiter,
       _retryDelay = retryDelay,
       _random = random ?? Random(),
       _clock = clock,
       _isWeb = isWeb,
       _browserOnline = browserOnline ?? browser.browserOnline;

  /// Esperas antes de cada reintento (se les suma hasta 500 ms al azar).
  static const retryBackoff = [Duration(seconds: 1), Duration(seconds: 3)];

  final AppConfig _config;
  final http.Client _http;
  final RateLimiter _rateLimiter;
  final Delay _retryDelay;
  final Random _random;

  /// Para una fecha de `Retry-After` sin encabezado `Date`.
  final Clock _clock;

  /// En Web el navegador oculta la causa de un `ClientException` (Fase R4).
  final bool _isWeb;

  /// `navigator.onLine` en Web: solo `false` se toma como señal.
  final bool Function() _browserOnline;

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
      if (!_isWeb) {
        throw ApiException(
          type: ApiExceptionType.connection,
          message: '${e.runtimeType}: $e',
          uri: uri,
          elapsed: stopwatch.elapsed,
        );
      }
      throw _browserNetworkError(e, uri, sentAt, stopwatch.elapsed);
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

  /// En Web, un bloqueo CORS, un fallo de red y un HTTP 429 sin encabezados
  /// CORS llegan como el mismo ClientException ("Failed to fetch"): el
  /// navegador no le expone la causa ni la respuesta a Dart. Solo
  /// `navigator.onLine == false` es seguro; lo demás es ambiguo y, poco
  /// después de una respuesta aceptada, sospecha de 429 (Fase R4).
  ApiException _browserNetworkError(
    http.ClientException e,
    Uri uri,
    DateTime sentAt,
    Duration elapsed,
  ) {
    if (!_browserOnline()) {
      return ApiException(
        type: ApiExceptionType.offline,
        message:
            '${e.runtimeType}: $e\n'
            'El navegador informa que no hay red (navigator.onLine).',
        uri: uri,
        elapsed: elapsed,
      );
    }
    final suspected = _rateLimiter.suspectRateLimit(sentAt: sentAt);
    if (suspected) {
      debugPrint(
        'TheSportsDB: falla de red ambigua poco después de una respuesta '
        'aceptada (posible 429 oculto por CORS), consultas en espera hasta '
        '${_rateLimiter.suspectedUntil?.toIso8601String()}',
      );
    }
    return ApiException(
      type: ApiExceptionType.possibleCors,
      message:
          '${e.runtimeType}: $e\n'
          'El navegador no informa la causa a la app: puede ser un bloqueo '
          'CORS, un fallo de red o un HTTP 429 sin encabezados CORS. Revisar '
          'la consola de Chrome (F12) para ver el motivo exacto.'
          '${suspected ? '\nPosible 429 oculto: hubo una respuesta aceptada '
                    'hace menos de '
                    '${RateLimiter.suspicionLookback.inMinutes} min.' : ''}',
      uri: uri,
      elapsed: elapsed,
      suspectedRateLimit: suspected,
    );
  }
}

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);
