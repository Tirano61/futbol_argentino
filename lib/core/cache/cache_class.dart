/// Clase de vigencia de una consulta guardada (§5.5 de DATA_STRATEGY).
enum CacheClass {
  /// Hay un partido en juego o recién empezado.
  live(Duration(minutes: 2)),

  /// Hay un partido hoy (día argentino).
  today(Duration(minutes: 10)),

  /// Partidos por jugarse en los próximos 7 días.
  upcoming(Duration(hours: 1)),

  /// Solo partidos a más de 7 días, o datos sin fecha clara.
  future(Duration(hours: 12)),

  /// Todos terminados hace más de 48 h: histórico.
  closed(Duration(days: 30)),

  /// Respuesta incompleta o vacía sospechosa: reintentar pronto.
  retrySoon(Duration(minutes: 15)),

  /// Ronda sin partidos.
  empty(Duration(hours: 24)),

  /// Próximo/último partido de una competición.
  pointers(Duration(minutes: 30)),

  /// Datos de equipos y competiciones.
  metadata(Duration(days: 7));

  const CacheClass(this.ttl);

  final Duration ttl;

  /// Un refresco manual no se repite antes de este tiempo.
  static const manualRefreshInterval = Duration(seconds: 30);
}
