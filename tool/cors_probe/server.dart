// Servidor local para la página `tool/cors_probe/main.dart` (Fase R4). No toca
// TheSportsDB: responde lo mismo que se vio de su API, con y sin
// encabezados CORS, para comprobar qué deja ver Chrome a la app.
//
//   dart run tool/cors_probe/server.dart [puerto]   (por defecto 8765)
import 'dart:io';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8765 : int.parse(args.first);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('cors_probe en http://localhost:$port/');
  await for (final request in server) {
    final response = request.response;
    final path = request.uri.pathSegments.isEmpty
        ? ''
        : request.uri.pathSegments.last;
    final cors = !path.startsWith('hidden');
    if (cors) response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.contentType = ContentType.json;
    switch (path) {
      case 'ok':
        response.statusCode = 200;
        response.write('{"events": []}');
      // 429 sin CORS: como el de TheSportsDB.
      case 'hidden429':
        response.statusCode = 429;
        response.headers.set('Retry-After', '90');
        response.write('{"error": "Too Many Requests"}');
      // Si algún día llegara con CORS: el código se ve, pero `Retry-After`
      // no es un encabezado de los que el navegador deja leer sin
      // `Access-Control-Expose-Headers`.
      case 'visible429':
        response.statusCode = 429;
        response.headers.set('Retry-After', '90');
        response.write('{"error": "Too Many Requests"}');
      case 'exposed429':
        response.statusCode = 429;
        response.headers
          ..set('Retry-After', '90')
          ..set('Access-Control-Expose-Headers', 'Retry-After');
        response.write('{"error": "Too Many Requests"}');
      case 'hidden500':
        response.statusCode = 500;
        response.write('{}');
      case final code when int.tryParse(code) != null:
        response.statusCode = int.parse(code);
        response.write('{}');
      default:
        response.statusCode = 404;
        response.write('{}');
    }
    await response.close();
  }
}
