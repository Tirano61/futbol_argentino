import '../error/failure.dart';

enum ApiExceptionType {
  http('Error HTTP'),
  rateLimited('Límite de peticiones (HTTP 429)'),
  timeout('Timeout'),
  connection('Error de conexión'),
  possibleCors('Error de conexión / posible bloqueo CORS (Flutter Web)'),
  format('Error de formato JSON');

  const ApiExceptionType(this.label);

  final String label;
}

/// Error real de una consulta a TheSportsDB, con el detalle técnico necesario
/// para diagnosticarlo. Pertenece a la capa de datos: los repositorios lo
/// traducen a `Failure`.
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    required this.uri,
    this.statusCode,
    this.elapsed,
    this.rawBody,
  });

  final ApiExceptionType type;
  final String message;
  final Uri uri;
  final int? statusCode;
  final Duration? elapsed;

  /// Cuerpo recibido del servidor, si lo hubo.
  final String? rawBody;

  /// Si vale la pena reintentar: fallas transitorias del servidor o de red.
  /// En Web un `ClientException` puede ser CORS, así que no se reintenta.
  bool get isTransient => switch (type) {
    ApiExceptionType.timeout || ApiExceptionType.connection => true,
    ApiExceptionType.http => (statusCode ?? 0) >= 500,
    _ => false,
  };

  @override
  String toString() => 'ApiException(${type.name}): $message';

  /// Traducción al error de dominio que ven los repositorios.
  Failure toFailure() => switch (type) {
    ApiExceptionType.timeout => NetworkFailure(
      issue: NetworkIssue.timeout,
      detail: message,
      elapsed: elapsed,
    ),
    ApiExceptionType.connection => NetworkFailure(
      issue: NetworkIssue.connection,
      detail: message,
      elapsed: elapsed,
    ),
    ApiExceptionType.possibleCors => NetworkFailure(
      issue: NetworkIssue.possibleCors,
      detail: message,
      elapsed: elapsed,
    ),
    ApiExceptionType.rateLimited => RateLimitFailure(
      detail: message,
      elapsed: elapsed,
      responseBody: rawBody,
    ),
    ApiExceptionType.format => FormatFailure(
      detail: message,
      statusCode: statusCode,
      elapsed: elapsed,
      responseBody: rawBody,
    ),
    ApiExceptionType.http when statusCode == 404 => NotFoundFailure(
      detail: message,
      statusCode: statusCode,
      elapsed: elapsed,
      responseBody: rawBody,
    ),
    ApiExceptionType.http => ServerFailure(
      detail: message,
      statusCode: statusCode ?? 0,
      elapsed: elapsed,
      responseBody: rawBody,
    ),
  };
}
