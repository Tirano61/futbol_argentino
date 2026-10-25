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

  /// Solo en Web: el navegador no distingue CORS de un fallo de red (ni un
  /// HTTP 429 sin encabezados CORS, que oculta).
  possibleCors,

  /// Solo en Web: el navegador informa que no hay red
  /// (`navigator.onLine == false`, Fase R4).
  offline,
}

final class NetworkFailure extends Failure {
  const NetworkFailure({
    required this.issue,
    required super.detail,
    super.elapsed,
    this.suspectedRateLimit = false,
  });

  final NetworkIssue issue;

  /// Fase R4: un [NetworkIssue.possibleCors] que puede ser un HTTP 429
  /// oculto por CORS (hubo una respuesta aceptada poco antes). Es una
  /// sospecha, no un 429: el código HTTP no se conoce.
  final bool suspectedRateLimit;

  NetworkFailure withSuspectedRateLimit() => NetworkFailure(
    issue: issue,
    detail: detail,
    elapsed: elapsed,
    suspectedRateLimit: true,
  );
}

extension FailureRateLimit on Failure {
  /// Un HTTP 429 confirmado o la sospecha de uno oculto (Fase R4): seguir
  /// descargando le sumaría consultas a un servidor que quizá limita.
  bool get limitsQueries => switch (this) {
    RateLimitFailure() => true,
    NetworkFailure(:final suspectedRateLimit) => suspectedRateLimit,
    _ => false,
  };
}

/// Por qué el scheduler dejó de reintentar un HTTP 429 (Fase R3.1).
enum RateLimitReason {
  /// El trabajo hizo sus 3 intentos.
  retriesExhausted,

  /// TheSportsDB sigue limitando (3 o más 429 seguidos de cualquier
  /// trabajo): este pudo hacer menos intentos o ninguno.
  persistentBlock,

  /// TheSportsDB pidió esperar más de 5 min (`Retry-After`): un intento.
  longPause,
}

/// HTTP 429: se superó el límite de peticiones de TheSportsDB.
final class RateLimitFailure extends Failure {
  const RateLimitFailure({
    required super.detail,
    super.statusCode = 429,
    super.elapsed,
    super.responseBody,
    this.reason,
    this.retryAt,
  });

  /// Por qué no se reintentó; `null` si no pasó por el scheduler.
  final RateLimitReason? reason;

  /// Fin de la pausa (UTC) con [RateLimitReason.longPause].
  final DateTime? retryAt;

  RateLimitFailure withReason(RateLimitReason reason, {DateTime? retryAt}) =>
      RateLimitFailure(
        detail: detail,
        statusCode: statusCode,
        elapsed: elapsed,
        responseBody: responseBody,
        reason: reason,
        retryAt: retryAt,
      );
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
