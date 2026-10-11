/// Fuente de la hora actual. Se inyecta para poder probar con tiempo
/// controlado (TTL de caché, rate limiter, "partidos de hoy").
abstract interface class Clock {
  /// Instante actual en UTC.
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
