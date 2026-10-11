/// Error que los repositorios exponen al dominio y a la presentación.
///
/// Un repositorio lanza un [Failure] solo cuando no tiene ningún dato para
/// devolver; si tiene datos en caché, los devuelve en un `DataResult` con el
/// error en `refreshError`.
sealed class Failure implements Exception {
  const Failure({
    required this.detail,
    this.statusCode,
    this.elapsed,
    this.responseBody,
  });

  /// Detalle técnico real (para logs y la pantalla de diagnóstico; la UI
  /// muestra un mensaje propio según el tipo).
  final String detail;
  final int? statusCode;
  final Duration? elapsed;

  /// Cuerpo recibido del servidor, si lo hubo.
  final String? responseBody;

  @override
  String toString() => '$runtimeType: $detail';
}

enum NetworkIssue {
  connection,
  timeout,

  /// Solo en Web: el navegador no distingue CORS de un fallo de red.
  possibleCors,
}

final class NetworkFailure extends Failure {
  const NetworkFailure({
    required this.issue,
    required super.detail,
    super.elapsed,
  });

  final NetworkIssue issue;
}

/// HTTP 429: se superó el límite de peticiones de TheSportsDB.
final class RateLimitFailure extends Failure {
  const RateLimitFailure({
    required super.detail,
    super.statusCode = 429,
    super.elapsed,
    super.responseBody,
  });
}

/// Respuesta HTTP de error (distinta de 404 y 429).
final class ServerFailure extends Failure {
  const ServerFailure({
    required super.detail,
    required int super.statusCode,
    super.elapsed,
    super.responseBody,
  });
}

/// La respuesta llegó pero no tiene la forma esperada.
final class FormatFailure extends Failure {
  const FormatFailure({
    required super.detail,
    super.statusCode,
    super.elapsed,
    super.responseBody,
  });
}

/// El recurso pedido no existe (HTTP 404, o la API devolvió `null`).
final class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.detail,
    super.statusCode,
    super.elapsed,
    super.responseBody,
  });
}
