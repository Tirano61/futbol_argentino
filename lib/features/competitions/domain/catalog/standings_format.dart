import '../entities/phase.dart';
import '../standings/tie_breaker.dart';

/// Reglamento del que salen las reglas de una tabla.
final class RegulationSource {
  const RegulationSource({required this.name, required this.url});

  final String name;
  final String url;
}

/// Qué tablas tiene una competición en una temporada y con qué reglas.
sealed class StandingsFormat {
  const StandingsFormat();
}

/// Sin tablas (copa por eliminación, o formato todavía no validado).
final class NoStandings extends StandingsFormat {
  const NoStandings();
}

/// Liga con dos torneos de zonas y una tabla anual (Primera 2026).
final class LeagueZonesWithAnnual extends StandingsFormat {
  const LeagueZonesWithAnnual({
    required this.zones,
    required this.regularRounds,
    required this.interzonalsPerTeam,
    required this.zoneTieBreak,
    required this.annualTieBreak,
    required this.zoneArticles,
    required this.annualArticle,
    required this.regulation,
  });

  /// Torneo → zona → `idTeam`.
  final Map<PhaseKey, Map<String, Set<int>>> zones;

  /// Rondas de la API de la fase de zonas (sin eliminatorias).
  final List<int> regularRounds;

  /// Partidos contra la otra zona por equipo y torneo.
  final int interzonalsPerTeam;
  final List<TieBreakCriterion> zoneTieBreak;
  final List<TieBreakCriterion> annualTieBreak;

  /// Artículos de la tabla y el desempate de zona de cada torneo.
  final Map<PhaseKey, String> zoneArticles;
  final String annualArticle;
  final RegulationSource regulation;

  /// Torneos en orden.
  Iterable<PhaseKey> get tournaments => zones.keys;
}
