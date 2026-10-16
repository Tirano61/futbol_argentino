import '../../../../core/time/calendar_day.dart';
import '../entities/competition.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../standings/tie_breaker.dart';
import 'standings_format.dart';

export 'standings_format.dart';

/// Ventana de un torneo dentro de una temporada, en días argentinos.
final class PhaseWindow {
  const PhaseWindow({
    required this.phase,
    required this.regularFrom,
    this.regularTo,
    this.knockoutFrom,
    this.knockoutTo,
  });

  final PhaseKey phase;
  final CalendarDay regularFrom;

  /// `null`: torneo en curso, sin fin conocido.
  final CalendarDay? regularTo;

  /// `null`: eliminatorias sin datos verificados (sus partidos quedan
  /// `undetermined`).
  final CalendarDay? knockoutFrom;
  final CalendarDay? knockoutTo;

  bool get isOpenEnded => regularTo == null && knockoutTo == null;

  /// Último día conocido del torneo, o `null` si sigue en curso.
  CalendarDay? get lastDay => knockoutTo ?? regularTo;

  bool containsInSpan(CalendarDay day) {
    if (day.isBefore(regularFrom)) return false;
    final last = isOpenEnded ? null : lastDay;
    return last == null || !day.isAfter(last);
  }

  bool containsInRegular(CalendarDay day) {
    if (day.isBefore(regularFrom)) return false;
    final to = regularTo;
    return to == null || !day.isAfter(to);
  }

  bool containsInKnockout(CalendarDay day) {
    final from = knockoutFrom;
    final to = knockoutTo;
    return from != null &&
        to != null &&
        !day.isBefore(from) &&
        !day.isAfter(to);
  }
}

sealed class CompetitionRules {
  const CompetitionRules();
}

/// Ronda del cuadro de eliminación directa (a un solo partido).
///
/// Una ronda de la API puede tener varias: en Primera, la ronda 0 trae
/// cuartos, semifinales y final.
final class BracketRound {
  const BracketRound({
    required this.label,
    required this.apiRound,
    required this.matches,
  });

  final String label;

  /// `intRound` de la API.
  final int apiRound;

  /// Partidos de la ronda: la mitad que en la anterior; la final, 1.
  final int matches;
}

/// Liga con dos torneos por temporada que comparten numeración de rondas
/// (Primera División: Apertura y Clausura).
final class SplitSeasonLeagueRules extends CompetitionRules {
  const SplitSeasonLeagueRules({
    required this.phases,
    required this.regularRounds,
    required this.matchesPerRound,
    required this.knockoutRound,
    required this.knockoutOpeningRound,
    required this.knockoutOpeningLabel,
    required this.knockoutLabel,
    required this.windowsBySeason,
    this.knockoutBracket = const [],
    this.inferenceMinGapDays = 45,
  });

  /// En orden cronológico.
  final List<PhaseKey> phases;
  final int regularRounds;

  /// Partidos por fecha regular de un torneo.
  final int matchesPerRound;

  /// Ronda de la API con cuartos, semifinales y final (`0`).
  final int knockoutRound;

  /// Ronda de la API que también contiene los octavos (`16`).
  final int knockoutOpeningRound;
  final String knockoutOpeningLabel;
  final String knockoutLabel;

  /// Ventanas verificadas por temporada (año → torneos).
  final Map<int, List<PhaseWindow>> windowsBySeason;

  /// Cuadro de las eliminatorias de cada torneo, en orden.
  final List<BracketRound> knockoutBracket;

  /// Separación mínima entre torneos para inferir fases sin catálogo.
  final int inferenceMinGapDays;
}

/// Liga de una sola fase regular (Primera Nacional).
final class SingleTableLeagueRules extends CompetitionRules {
  const SingleTableLeagueRules({
    required this.matchesPerRound,
    required this.regularRoundsBySeason,
  });

  final int matchesPerRound;

  /// Cantidad de fechas regulares verificadas (año → fechas). Sin dato, se
  /// descubre consultando hasta la primera ronda vacía.
  final Map<int, int> regularRoundsBySeason;
}

final class CupRound {
  const CupRound({
    required this.code,
    required this.label,
    required this.matches,
    this.verified = true,
  });

  /// `intRound` de la API.
  final int code;
  final String label;
  final int matches;

  /// `false` si el código todavía no apareció en datos reales.
  final bool verified;
}

/// Copa por eliminación directa (Copa Argentina).
final class KnockoutCupRules extends CompetitionRules {
  const KnockoutCupRules({required this.rounds});

  /// En orden del torneo.
  final List<CupRound> rounds;

  CupRound? roundFor(int code) {
    for (final round in rounds) {
      if (round.code == code) return round;
    }
    return null;
  }
}

/// Agrupación del selector de competiciones, en el orden en que se muestra.
enum CompetitionCategory {
  firstDivision('Primera División'),
  promotion('Ascenso'),
  nationalCup('Copas nacionales'),
  internationalCup('Copas internacionales');

  const CompetitionCategory(this.label);

  final String label;
}

/// Competición soportada por la app y sus reglas.
final class CompetitionDefinition {
  const CompetitionDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.category,
    required this.format,
    required this.rules,
    this.standingsBySeason = const {},
    this.showInHome = true,
    this.inTeamIndex = true,
  });

  final int id;
  final String name;
  final String shortName;
  final CompetitionCategory category;
  final CompetitionFormat format;
  final CompetitionRules rules;

  /// Entra en los partidos del Inicio (2 punteros + ≤ 2 rondas en frío:
  /// sumar una cuesta hasta 4 peticiones del presupuesto de 12).
  final bool showInHome;

  /// Su primera etapa se baja para el índice de equipos (1 petición más en
  /// frío al buscar o abrir una ficha). Sin la marca, sus equipos aparecen
  /// en el buscador cuando hay partidos guardados (p. ej. tras abrir su
  /// fixture).
  final bool inTeamIndex;

  /// Tablas verificadas por temporada (año → formato).
  final Map<int, StandingsFormat> standingsBySeason;

  /// Sin formato verificado para [season]: sin tablas.
  StandingsFormat standingsFor(Season season) =>
      standingsBySeason[season.year] ?? const NoStandings();

  /// Alguna temporada tiene tabla verificada: se ofrece la vista «Tabla»
  /// (una temporada sin formato la muestra vacía, «Sin tabla»).
  bool get hasStandings =>
      standingsBySeason.values.any((format) => format is! NoStandings);

  /// Tiene cuadro de llaves verificado: se ofrece la vista «Llaves».
  bool get hasBracket => bracketRounds.isNotEmpty;

  /// Cuadro de eliminación de cada fase, en orden; vacío si la
  /// competición no tiene eliminatorias verificadas (Nacional: Fase 19.2).
  List<BracketRound> get bracketRounds => switch (rules) {
    SplitSeasonLeagueRules(:final knockoutBracket) => knockoutBracket,
    SingleTableLeagueRules() => const [],
    KnockoutCupRules(:final rounds) => [
      for (final r in rounds)
        BracketRound(label: r.label, apiRound: r.code, matches: r.matches),
    ],
  };

  /// Fases que se ofrecen al usuario, en orden.
  List<PhaseKey> get phases => switch (rules) {
    SplitSeasonLeagueRules(:final phases) => phases,
    SingleTableLeagueRules() => const [PhaseKey.regular],
    KnockoutCupRules() => const [PhaseKey.unica],
  };

  /// Cantidad mínima de partidos que debería traer una consulta de la ronda
  /// [apiRound] (para clasificar respuestas incompletas). `null` si no se
  /// sabe.
  int? expectedMinimumMatches(int apiRound) => switch (rules) {
    final SplitSeasonLeagueRules r =>
      apiRound >= 1 && apiRound <= r.regularRounds ? r.matchesPerRound : null,
    SingleTableLeagueRules(:final matchesPerRound) => matchesPerRound,
    final KnockoutCupRules r => r.roundFor(apiRound)?.matches,
  };
}

/// Competiciones soportadas. Agregar una competición = agregar una entrada.
///
/// Las ventanas de fase salen de datos reales (`test/fixtures/api/`,
/// grabados el 11/10/2026). Mantenimiento: actualizar cada semestre
/// (ver `CLAUDE.md`).
abstract final class CompetitionCatalog {
  static const primeraDivision = CompetitionDefinition(
    id: 4406,
    name: 'Primera División',
    shortName: 'Primera',
    category: CompetitionCategory.firstDivision,
    format: CompetitionFormat.league,
    rules: SplitSeasonLeagueRules(
      phases: [PhaseKey.apertura, PhaseKey.clausura],
      regularRounds: 16,
      matchesPerRound: 15,
      knockoutRound: 0,
      knockoutOpeningRound: 16,
      knockoutOpeningLabel: 'Octavos de final',
      knockoutLabel: 'Cuartos, semifinales y final',
      // Verificado con el Apertura 2026 (octavos en la ronda 16; cuartos,
      // semifinales y final en la 0).
      knockoutBracket: [
        BracketRound(label: 'Octavos de final', apiRound: 16, matches: 8),
        BracketRound(label: 'Cuartos de final', apiRound: 0, matches: 4),
        BracketRound(label: 'Semifinales', apiRound: 0, matches: 2),
        BracketRound(label: 'Final', apiRound: 0, matches: 1),
      ],
      windowsBySeason: {
        2025: [
          // La API no tiene las eliminatorias de 2025 (r=0 vacía).
          PhaseWindow(
            phase: PhaseKey.apertura,
            regularFrom: CalendarDay(2025, 1, 23),
            regularTo: CalendarDay(2025, 5, 4),
          ),
          PhaseWindow(
            phase: PhaseKey.clausura,
            regularFrom: CalendarDay(2025, 7, 11),
            regularTo: CalendarDay(2025, 11, 17),
          ),
        ],
        2026: [
          // La fecha 9 se jugó del 2 al 4 de mayo; octavos 9–10 de mayo;
          // cuartos a final 12–24 de mayo.
          PhaseWindow(
            phase: PhaseKey.apertura,
            regularFrom: CalendarDay(2026, 1, 22),
            regularTo: CalendarDay(2026, 5, 4),
            knockoutFrom: CalendarDay(2026, 5, 9),
            knockoutTo: CalendarDay(2026, 5, 24),
          ),
          // En curso; eliminatorias aún sin datos (V3).
          PhaseWindow(
            phase: PhaseKey.clausura,
            regularFrom: CalendarDay(2026, 7, 23),
          ),
        ],
      },
    ),
    standingsBySeason: {2026: _primera2026Standings},
  );

  /// Zonas del sorteo de la AFA con `idTeam` verificados contra los partidos
  /// grabados (V12, aprobadas el 12/10/2026). Mismas zonas en los dos
  /// torneos (art. 14.1.1).
  static const _primera2026ZoneA = {
    137775, // Platense
    135159, // Defensa y Justicia
    137603, // Central Córdoba de Santiago del Estero
    135165, // Lanús
    137782, // Deportivo Riestra
    136674, // Talleres de Córdoba
    135156, // Boca Juniors
    135160, // Estudiantes de La Plata
    137786, // Instituto
    137778, // Gimnasia y Esgrima de Mendoza
    135173, // San Lorenzo
    135164, // Independiente
    135166, // Newell's Old Boys
    135178, // Unión
    135179, // Vélez Sarsfield
  };
  static const _primera2026ZoneB = {
    135151, // Argentinos Juniors
    135150, // Aldosivi
    135681, // Atlético Tucumán
    135154, // Banfield
    137771, // Barracas Central
    135155, // Belgrano
    135171, // River Plate
    135161, // Gimnasia y Esgrima de La Plata
    137773, // Estudiantes de Río Cuarto
    137777, // Independiente Rivadavia
    135163, // Huracán
    135170, // Racing Club
    135172, // Rosario Central
    135175, // Sarmiento
    135177, // Tigre
  };

  /// Reglamento Torneos Primera División 2026 (art. 8.1, 9, 10, 14.1, 15,
  /// 16 y 24; ver D15 en `docs/DECISIONS.md`).
  static const _primera2026Standings = LeagueZonesWithAnnual(
    zones: {
      PhaseKey.apertura: {'A': _primera2026ZoneA, 'B': _primera2026ZoneB},
      PhaseKey.clausura: {'A': _primera2026ZoneA, 'B': _primera2026ZoneB},
    },
    regularRounds: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
    interzonalsPerTeam: 2,
    // Art. 10 y 16.
    zoneTieBreak: [
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
      TieBreakCriterion.headToHead,
      TieBreakCriterion.fairPlay,
      TieBreakCriterion.drawOfLots,
    ],
    // Art. 24.3: sin enfrentamiento directo.
    annualTieBreak: [
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
      TieBreakCriterion.fairPlay,
      TieBreakCriterion.drawOfLots,
    ],
    zoneArticles: {
      PhaseKey.apertura: 'art. 9 y 10',
      PhaseKey.clausura: 'art. 15 y 16',
    },
    annualArticle: 'art. 24',
    regulation: RegulationSource(
      name: 'Reglamento Torneos Primera División 2026',
      url:
          'https://assets1.afa.com.ar/2026/BOLETINES/Boletin-Resoluciones-6818---Complementario-01---Reglamento-Torneos-LPF-Primera-2026.pdf',
    ),
  );

  static const primeraNacional = CompetitionDefinition(
    id: 4616,
    name: 'Primera Nacional',
    shortName: 'Nacional',
    category: CompetitionCategory.promotion,
    format: CompetitionFormat.league,
    rules: SingleTableLeagueRules(
      matchesPerRound: 18,
      // 2025: fecha 35 vacía; 2026: fecha 37 vacía.
      regularRoundsBySeason: {2025: 34, 2026: 36},
    ),
    standingsBySeason: {2026: _nacional2026Standings},
  );

  /// Zonas deducidas de los 648 partidos grabados (rondas 1–36), iguales a
  /// las publicadas por la prensa y a `lookuptable` (V14, aprobadas el
  /// 12/10/2026).
  static const _nacional2026ZoneA = {
    143091, // Acassuso
    137781, // All Boys
    141011, // Almirante Brown
    142489, // Central Norte
    140526, // Chaco For Ever
    149544, // Ciudad de Bolívar
    135157, // Colón
    137779, // Defensores de Belgrano
    142479, // Deportivo Madryn
    137772, // Deportivo Morón
    137767, // Estudiantes de Buenos Aires
    137774, // Ferro Carril Oeste
    135162, // Godoy Cruz
    143087, // Los Andes
    137766, // Mitre
    144739, // Racing de Córdoba
    143096, // San Miguel
    141014, // San Telmo
  };
  static const _nacional2026ZoneB = {
    137769, // Agropecuario
    137787, // Almagro
    137776, // Atlanta
    135153, // Atlético de Rafaela
    135899, // Chacarita Juniors
    143095, // Colegiales
    141013, // Deportivo Maipú
    149541, // Ferrocarril Midland
    137783, // Gimnasia y Esgrima de Jujuy
    144738, // Gimnasia y Tiro
    141012, // Güemes
    135167, // Nueva Chicago
    135682, // Patronato
    135169, // Quilmes
    135174, // San Martín de San Juan
    136197, // San Martín de Tucumán
    135176, // Temperley
    141015, // Tristán Suárez
  };

  /// Boletín Especial 6823 (puntos 2, 3, 5 y 6) y Reglamento General de AFA
  /// (art. 111 a 113; ver D18 en `docs/DECISIONS.md`). Dos ruedas en la
  /// zona más la fecha interzonal de ida y vuelta (rondas 7 y 25).
  static const _nacional2026Standings = LeagueZones(
    zones: {'A': _nacional2026ZoneA, 'B': _nacional2026ZoneB},
    regularRounds: [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
    ],
    interzonalsPerTeam: 2,
    // Art. 112 del R.G., puntos 1 a 3 (el 113 los aplica durante el
    // torneo): sin Fair Play ni sorteo.
    tieBreak: [
      TieBreakCriterion.goalDifference,
      TieBreakCriterion.goalsFor,
      TieBreakCriterion.headToHead,
    ],
    tableArticle: 'punto 3',
    tieBreakArticle:
        'punto 5: art. 112 del Reglamento General de AFA, puntos 1 a 3, '
        'también para el primer puesto',
    relegationNote:
        'Descensos (los 2 últimos de cada zona): ante igualdad en puntos se '
        'juegan partidos de desempate (punto 5 y art. 111 del Reglamento '
        'General de AFA); la app no los define.',
    regulation: RegulationSource(
      name: 'Reglamento del Campeonato de Primera Nacional 2026',
      url:
          'https://assets1.afa.com.ar/2026/Lau/Boletin-Especial-6823---Reglamento-del-Campeonato-de-Primera-Nacional-2026.pdf',
    ),
  );

  static const copaArgentina = CompetitionDefinition(
    id: 4500,
    name: 'Copa Argentina',
    shortName: 'Copa Argentina',
    category: CompetitionCategory.nationalCup,
    format: CompetitionFormat.cup,
    rules: KnockoutCupRules(
      rounds: [
        CupRound(code: 64, label: '32avos de final', matches: 32),
        CupRound(code: 32, label: '16avos de final', matches: 16),
        CupRound(code: 16, label: 'Octavos de final', matches: 8),
        CupRound(code: 125, label: 'Cuartos de final', matches: 4),
        CupRound(code: 150, label: 'Semifinales', matches: 2),
        // Verificado con la final 2025 (noviembre 2025).
        CupRound(code: 200, label: 'Final', matches: 1),
      ],
    ),
  );

  /// Primera B Metropolitana (V8): 22 equipos, 11 partidos por fecha. Sin
  /// formato de tabla verificado: no hay tabla.
  static const primeraBMetropolitana = CompetitionDefinition(
    id: 5215,
    name: 'Primera B Metropolitana',
    shortName: 'B Metro',
    category: CompetitionCategory.promotion,
    format: CompetitionFormat.league,
    rules: SingleTableLeagueRules(
      matchesPerRound: 11,
      // 2026: 22 equipos a dos ruedas; la fecha 43 vuelve vacía (grabada el
      // 13/10/2026). 2025 queda sin cantidad: su fecha 1 mezcla dos
      // torneos (20 partidos, febrero y junio).
      regularRoundsBySeason: {2026: 42},
    ),
    showInHome: false,
    inTeamIndex: false,
  );

  /// Primera C (V8): 28 equipos, 14 partidos por fecha. Sin cantidad de
  /// fechas ni formato de tabla verificados: las fechas se conocen por los
  /// punteros y lo guardado, y no hay tabla.
  static const primeraC = CompetitionDefinition(
    id: 5524,
    name: 'Primera C',
    shortName: 'Primera C',
    category: CompetitionCategory.promotion,
    format: CompetitionFormat.league,
    rules: SingleTableLeagueRules(
      matchesPerRound: 14,
      // 2026: la fecha 33 vuelve vacía (13/10/2026), pero 32 fechas no
      // cierran con 28 equipos todos contra todos: sin dato.
      regularRoundsBySeason: {},
    ),
    showInHome: false,
    inTeamIndex: false,
  );

  /// Torneo Federal A (5523) no entra: mezcla etapas en la numeración de
  /// rondas (V8) y necesita un relevamiento propio.
  static const all = [
    primeraDivision,
    primeraNacional,
    copaArgentina,
    primeraBMetropolitana,
    primeraC,
  ];

  /// Competiciones de [catalog] por categoría, en el orden de
  /// [CompetitionCategory] y, dentro de cada una, en el de [catalog]. Las
  /// categorías sin competiciones no aparecen.
  static Map<CompetitionCategory, List<CompetitionDefinition>> byCategory([
    List<CompetitionDefinition> catalog = all,
  ]) => {
    for (final category in CompetitionCategory.values)
      if (catalog.where((c) => c.category == category).toList()
          case final competitions when competitions.isNotEmpty)
        category: competitions,
  };

  static CompetitionDefinition? byId(int id) {
    for (final definition in all) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  /// Temporadas que ofrece la app: la actual y la anterior (D10).
  static List<Season> supportedSeasons(Season current) => [
    current,
    current.previous,
  ];
}
