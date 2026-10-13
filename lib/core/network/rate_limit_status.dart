/// Esperas de las consultas a TheSportsDB, para poder avisarlas en pantalla
/// mientras las consultas esperan: la pausa tras un HTTP 429 y las esperas
/// largas por el tope propio de consultas por minuto.
abstract interface class RateLimitStatus {
  /// Hasta cuándo (UTC) están pausadas las consultas; `null` si no lo están.
  DateTime? get pausedUntil;

  /// Hora de fin (UTC) de cada pausa que empieza o se alarga.
  Stream<DateTime> get pauses;

  /// Hasta cuándo (UTC) espera la próxima consulta por el tope propio, si
  /// la espera es de 3 s o más; `null` si no espera.
  DateTime? get throttledUntil;

  /// Hora de fin (UTC) de cada espera de 3 s o más por el tope propio.
  Stream<DateTime> get throttles;
}
