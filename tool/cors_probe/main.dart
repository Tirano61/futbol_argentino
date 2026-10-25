// Fase R4: qué deja ver Chrome de verdad a la app cuando una respuesta no
// trae encabezados CORS. Corre los chequeos con el `BrowserClient` real
// (`window.fetch`) y el `TheSportsDbClient` de la app contra el servidor
// local (`tool/cors_probe/server.dart`), nunca contra TheSportsDB.
//
//   dart run tool/cors_probe/server.dart
//   flutter build web --release -t tool/cors_probe/main.dart -o <carpeta>
//   (servir <carpeta> en otro puerto y abrirla en Chrome)
//
// Escribe un renglón por chequeo («OK | …» o «FALLA | …») en la página y en
// la consola, y al final cambia el título a «cors-probe-listo». Después
// espera a que el navegador quede sin red (DevTools › Network › Offline) y
// hace el último chequeo («cors-probe-sin-red»).
import 'dart:async';
import 'dart:js_interop';

import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:futbol_argentino/core/network/api_exception.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/network/thesportsdb_client.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

const _port = 8765;

Future<void> main() async {
  final results = <String>[];
  void report(bool ok, String name, String detail) {
    final line = '${ok ? 'OK' : 'FALLA'} | $name | $detail';
    results.add(line);
    // ignore: avoid_print
    print(line);
    final row = web.document.createElement('div')..textContent = line;
    web.document.body?.append(row);
  }

  Future<void> check(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      report(false, name, 'error inesperado: $e');
    }
  }

  await check('200 con CORS', () async {
    final response = await _client('ok').getJson('eventsround.php');
    report(response.statusCode == 200, '200 con CORS', 'HTTP 200 visible');
  });

  await check('429 sin CORS', () async {
    final e = await _failure(_client('hidden429').getJson('eventsround.php'));
    report(
      e.type == ApiExceptionType.possibleCors &&
          e.statusCode == null &&
          e.retryAfter == null &&
          !e.suspectedRateLimit,
      '429 sin CORS',
      'tipo ${e.type.name}, código ${e.statusCode}, Retry-After '
          '${e.retryAfter}, sospecha ${e.suspectedRateLimit}: '
          '${e.message.split('\n').first}',
    );
  });

  await check('puerto cerrado', () async {
    final hidden = await _failure(
      _client('hidden429').getJson('eventsround.php'),
    );
    // Un puerto libre (Chrome bloquea algunos, como el 1).
    final closed = await _failure(
      _client('ok', port: 8799).getJson('eventsround.php'),
    );
    String cause(ApiException e) =>
        e.message.split('\n').first.replaceAll(RegExp(r', uri=.*'), '');
    report(
      closed.type == hidden.type && cause(closed) == cause(hidden),
      'puerto cerrado',
      'mismo tipo (${closed.type.name}) y mismo mensaje que el 429 sin CORS: '
          '«${cause(closed)}»',
    );
  });

  await check('dominio que no resuelve', () async {
    final e = await _failure(
      _client('ok', host: 'thesportsdb-r4.invalid').getJson('eventsround.php'),
    );
    report(
      e.type == ApiExceptionType.possibleCors && !e.suspectedRateLimit,
      'dominio que no resuelve',
      'tipo ${e.type.name}: igual que un 429 sin CORS',
    );
  });

  await check('500 sin CORS', () async {
    final e = await _failure(_client('hidden500').getJson('eventsround.php'));
    report(
      e.type == ApiExceptionType.possibleCors,
      '500 sin CORS',
      'tipo ${e.type.name}: también se oculta',
    );
  });

  await check('sospecha', () async {
    final limiter = RateLimiter(maxRequests: 25);
    var target = 'ok';
    final api = _client('ok', limiter: limiter, target: () => target);
    await api.getJson('eventsround.php');
    target = 'hidden429';
    final e = await _failure(api.getJson('eventsround.php'));
    report(
      e.type == ApiExceptionType.possibleCors &&
          e.suspectedRateLimit &&
          limiter.suspectedUntil != null &&
          limiter.pausedUntil == null &&
          limiter.consecutiveRateLimits == 0,
      'sospecha',
      'tras una respuesta aceptada: sospecha ${e.suspectedRateLimit}, '
          'espera hasta ${limiter.suspectedUntil?.toIso8601String()}, '
          'pausa por 429 ${limiter.pausedUntil}, 429 seguidos '
          '${limiter.consecutiveRateLimits}',
    );
  });

  await check('429 con CORS', () async {
    final visible = await _failure(
      _client('visible429').getJson('eventsround.php'),
    );
    final exposed = await _failure(
      _client('exposed429').getJson('eventsround.php'),
    );
    report(
      visible.type == ApiExceptionType.rateLimited &&
          visible.statusCode == 429 &&
          visible.retryAfter == null &&
          exposed.type == ApiExceptionType.rateLimited &&
          exposed.retryAfter == const Duration(seconds: 90),
      '429 con CORS',
      'código visible (${visible.statusCode}); Retry-After sin exponer '
          '${visible.retryAfter}, expuesto ${exposed.retryAfter}',
    );
  });

  for (final status in [401, 403, 404, 500]) {
    await check('HTTP $status con CORS', () async {
      final e = await _failure(_client('$status').getJson('eventsround.php'));
      report(
        e.type == ApiExceptionType.http &&
            e.statusCode == status &&
            !e.suspectedRateLimit,
        'HTTP $status con CORS',
        'tipo ${e.type.name}, código ${e.statusCode}',
      );
    });
  }

  web.document.title = 'cors-probe-listo';

  // Sin red (DevTools «Offline»): `navigator.onLine` pasa a false.
  final offline = Completer<void>();
  web.window.addEventListener(
    'offline',
    ((web.Event _) {
      if (!offline.isCompleted) offline.complete();
    }).toJS,
  );
  if (!web.window.navigator.onLine) offline.complete();
  await offline.future;
  await check('sin red', () async {
    final e = await _failure(_client('ok').getJson('eventsround.php'));
    report(
      e.type == ApiExceptionType.offline,
      'sin red',
      'navigator.onLine ${web.window.navigator.onLine}: tipo ${e.type.name}',
    );
  });
  web.document.title = 'cors-probe-sin-red';
}

TheSportsDbClient _client(
  String path, {
  int port = _port,
  String host = 'localhost',
  RateLimiter? limiter,
  String Function()? target,
}) => TheSportsDbClient(
  config: const AppConfig(apiKey: '123', enableDiagnostics: false),
  httpClient: _Redirect(
    () => Uri.parse('http://$host:$port/${target?.call() ?? path}'),
  ),
  rateLimiter: limiter ?? RateLimiter(maxRequests: 25),
  retryDelay: (_) async {},
);

Future<ApiException> _failure(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('se esperaba un ApiException');
}

/// Lleva cada consulta al servidor local con el `BrowserClient` real.
class _Redirect extends http.BaseClient {
  _Redirect(this._target);

  final Uri Function() _target;
  final _inner = BrowserClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(http.Request(request.method, _target()));
}
