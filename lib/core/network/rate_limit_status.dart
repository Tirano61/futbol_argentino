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

  /// Fase R4 (Web): hasta cuándo (UTC) esperan las consultas por la
  /// sospecha de un HTTP 429 oculto por CORS; `null` si no esperan. Es
  /// aparte de [pausedUntil]: no es un 429 confirmado.
  DateTime? get suspectedUntil;

  /// Hora de fin (UTC) de cada espera por sospecha que empieza.
  Stream<DateTime> get suspicions;

  /// Hay un episodio de sospecha abierto: empezó una espera por sospecha y
  /// todavía no llegó una respuesta aceptada de una consulta posterior.
  bool get inSuspicion;
}
