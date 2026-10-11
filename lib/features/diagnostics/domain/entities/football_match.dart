/// Partido tal como lo necesita la capa de presentación.
class FootballMatch {
  const FootballMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffUtc,
    required this.homeScore,
    required this.awayScore,
  });

  final String homeTeam;
  final String awayTeam;

  /// Fecha y hora del partido en UTC, o `null` si no pudo interpretarse.
  final DateTime? kickoffUtc;

  final String? homeScore;
  final String? awayScore;

  bool get hasResult => homeScore != null && awayScore != null;
}
