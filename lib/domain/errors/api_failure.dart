enum ApiFailureType {
  http('Error HTTP'),
  timeout('Timeout'),
  connection('Error de conexión'),
  possibleCors('Error de conexión / posible bloqueo CORS (Flutter Web)'),
  format('Error de formato JSON');

  const ApiFailureType(this.label);

  final String label;
}

/// Error real de la consulta, con el detalle técnico necesario para
/// diagnosticarlo.
class ApiFailure implements Exception {
  const ApiFailure({
    required this.type,
    required this.message,
    this.statusCode,
    this.elapsedMs,
    this.rawBody,
  });

  final ApiFailureType type;
  final String message;
  final int? statusCode;
  final int? elapsedMs;

  /// Cuerpo recibido del servidor, si lo hubo.
  final String? rawBody;

  @override
  String toString() => 'ApiFailure(${type.name}): $message';
}
