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

/// Formatos con tablas por zona, validadas contra los partidos
/// (`ZoneValidator`).
sealed class ZonedStandingsFormat extends StandingsFormat {
  const ZonedStandingsFormat();

  /// Torneo → zona → `idTeam`.
  Map<PhaseKey, Map<String, Set<int>>> get zonesByTournament;

  /// Rondas de la API de la fase de zonas (sin eliminatorias).
  List<int> get regularRounds;

  /// Partidos contra la otra zona por equipo y torneo.
  int get interzonalsPerTeam;
  RegulationSource get regulation;

  /// Torneos en orden.
  Iterable<PhaseKey> get tournaments => zonesByTournament.keys;

  /// Cómo llama el reglamento a cada zona, en minúscula.
  String get zoneNoun => 'zona';
}

/// Liga con dos torneos de zonas y una tabla anual (Primera 2026).
final class LeagueZonesWithAnnual extends ZonedStandingsFormat {
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
  @override
  final List<int> regularRounds;
  @override
  final int interzonalsPerTeam;
  final List<TieBreakCriterion> zoneTieBreak;
  final List<TieBreakCriterion> annualTieBreak;

  /// Artículos de la tabla y el desempate de zona de cada torneo.
  final Map<PhaseKey, String> zoneArticles;
  final String annualArticle;
  @override
  final RegulationSource regulation;

  @override
  Map<PhaseKey, Map<String, Set<int>>> get zonesByTournament => zones;
}

/// Liga de un solo torneo en zonas, sin tabla anual; los interzonales suman
/// en la tabla de cada zona (Primera Nacional 2026).
final class LeagueZones extends ZonedStandingsFormat {
  const LeagueZones({
    required this.zones,
    required this.regularRounds,
    required this.interzonalsPerTeam,
    required this.tieBreak,
    required this.tableArticle,
    required this.tieBreakArticle,
    required this.relegationNote,
    required this.regulation,
  });

  /// Zona → `idTeam`.
  final Map<String, Set<int>> zones;
  @override
  final List<int> regularRounds;
  @override
  final int interzonalsPerTeam;
  final List<TieBreakCriterion> tieBreak;

  /// Dónde fija el reglamento cómo se suman los puntos.
  final String tableArticle;

  /// De dónde salen los criterios de desempate.
  final String tieBreakArticle;

  /// Qué pasa con los empates en los puestos de descenso (la app no los
  /// define).
  final String relegationNote;
  @override
  final RegulationSource regulation;

  @override
  Map<PhaseKey, Map<String, Set<int>>> get zonesByTournament => {
    PhaseKey.regular: zones,
  };
}

/// Fase de grupos de una copa internacional (Libertadores y Sudamericana):
/// grupos de 4, todos contra todos a ida y vuelta, sin partidos entre
/// grupos. Cada grupo se valida por separado: uno que no coincide con los
/// partidos no tiene tabla, los demás sí.
final class GroupStage extends ZonedStandingsFormat {
  const GroupStage({
    required this.groups,
    required this.regularRounds,
    required this.tieBreak,
    required this.pointsArticle,
    required this.tieBreakArticle,
    required this.qualificationNote,
    required this.regulation,
  });

  /// Grupo → `idTeam`.
  final Map<String, Set<int>> groups;
  @override
  final List<int> regularRounds;
  final List<TieBreakCriterion> tieBreak;

  /// Dónde fija el reglamento cómo se suman los puntos.
  final String pointsArticle;

  /// De dónde salen los criterios de desempate.
  final String tieBreakArticle;

  /// Quiénes pasan a la etapa siguiente (la app no lo marca en la tabla).
  final String qualificationNote;
  @override
  final RegulationSource regulation;

  @override
  int get interzonalsPerTeam => 0;

  @override
  String get zoneNoun => 'grupo';

  @override
  Map<PhaseKey, Map<String, Set<int>>> get zonesByTournament => {
    PhaseKey.groups: groups,
  };
}
