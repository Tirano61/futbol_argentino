/// Pausa de las consultas a TheSportsDB tras un HTTP 429, para poder
/// avisarla en pantalla mientras las consultas esperan.
abstract interface class RateLimitStatus {
  /// Hasta cuándo (UTC) están pausadas las consultas; `null` si no lo están.
  DateTime? get pausedUntil;

  /// Hora de fin (UTC) de cada pausa que empieza o se alarga.
  Stream<DateTime> get pauses;
}
