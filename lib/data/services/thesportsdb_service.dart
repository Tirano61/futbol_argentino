import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/errors/api_failure.dart';

/// Respuesta HTTP sin interpretar.
class RawHttpResponse {
  const RawHttpResponse({
    required this.statusCode,
    required this.reasonPhrase,
    required this.bodyBytes,
    required this.elapsedMs,
  });

  final int statusCode;
  final String? reasonPhrase;
  final Uint8List bodyBytes;
  final int elapsedMs;
}

/// Acceso HTTP directo a TheSportsDB (mismo código para Android y Web).
class TheSportsDbService {
  TheSportsDbService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://www.thesportsdb.com/api/v1/json/123';
  static const requestTimeout = Duration(seconds: 15);

  final http.Client _client;

  Future<RawHttpResponse> getEventsRound({
    required int leagueId,
    required int round,
    required int season,
  }) async {
    final uri = Uri.parse('$_baseUrl/eventsround.php').replace(
      queryParameters: {'id': '$leagueId', 'r': '$round', 's': '$season'},
    );
    debugPrint('GET $uri');

    final stopwatch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(requestTimeout);
    } on TimeoutException catch (e) {
      throw ApiFailure(
        type: ApiFailureType.timeout,
        message:
            'Sin respuesta en ${requestTimeout.inSeconds} s para $uri ($e)',
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } on http.ClientException catch (e) {
      // En Web, un bloqueo CORS y un fallo de red llegan como el mismo
      // ClientException ("XMLHttpRequest error" / "Failed to fetch"): el
      // navegador no le expone la causa a Dart.
      throw ApiFailure(
        type: kIsWeb ? ApiFailureType.possibleCors : ApiFailureType.connection,
        message: kIsWeb
            ? '${e.runtimeType}: $e\n'
                  'El navegador no informa la causa a la app: puede ser un '
                  'bloqueo CORS o un fallo de red. Revisar la consola de '
                  'Chrome (F12) para ver el motivo exacto.'
            : '${e.runtimeType}: $e',
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      // Por ejemplo HandshakeException (TLS) en Android.
      throw ApiFailure(
        type: ApiFailureType.connection,
        message: '${e.runtimeType}: $e',
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }
    stopwatch.stop();

    return RawHttpResponse(
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      bodyBytes: response.bodyBytes,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }
}
