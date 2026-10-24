/// Esperas de las consultas a TheSportsDB, para poder avisarlas en pantalla
/// mientras las consultas esperan: la pausa tras un HTTP 429 y las esperas
/// largas por el tope propio de consultas por minuto.
abstract interface class RateLimitStatus {
  /// Hasta cuándo (UTC) están pausadas las consultas; `null` si no lo están.
  DateTime? get pausedUntil;

  /// Hora de fin (UTC) de cada pausa que empieza o se alarga.
  Stream<DateTime> get pauses;

  /// HTTP 429 seguidos del episodio en curso (sin una respuesta aceptada
  /// en el medio); 0 si pasó una ventana desde el fin de la última pausa.
  /// Con 3 o más, el scheduler da el bloqueo por persistente (Fase R3.1).
  int get consecutiveRateLimits;

  /// Hasta cuándo (UTC) espera la próxima consulta por el tope propio, si
  /// la espera es de 3 s o más; `null` si no espera.
  DateTime? get throttledUntil;

  /// Hora de fin (UTC) de cada espera de 3 s o más por el tope propio.
  Stream<DateTime> get throttles;
}
