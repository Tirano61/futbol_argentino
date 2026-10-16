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

/// Etapa de una copa internacional en una temporada: «Fase 1», «Fecha 3»,
/// «Octavos de final»… Corresponde a una ronda de la API; varias etapas
/// pueden compartirla (2026: la ronda 1 trae la Fase 1 en febrero y la
/// Fecha 1 de grupos en abril) y entonces se separan por la ventana.
final class ContinentalStage {
  const ContinentalStage({
    required this.phase,
    required this.label,
    required this.apiRound,
    required this.legs,
    required this.expectedMatches,
    this.from,
    this.to,
  });

  /// Fecha [apiRound] de la fase de grupos (8 grupos de 4: 16 partidos).
  const ContinentalStage.groupMatchday(
    this.apiRound, {
    required CalendarDay this.from,
    required CalendarDay this.to,
  }) : phase = PhaseKey.groups,
       label = 'Fecha $apiRound',
       legs = 1,
       expectedMatches = 16;

  /// [PhaseKey.qualifying], [PhaseKey.groups] o [PhaseKey.knockoutStage].
  final PhaseKey phase;
  final String label;

  /// `intRound` de la API.
  final int apiRound;

  /// 1: partido único; 2: ida y vuelta (las dos piernas en la misma ronda).
  final int legs;

  /// Partidos de la etapa (piernas incluidas).
  final int expectedMatches;

  /// Primer día argentino de la etapa. `null`: sin datos todavía (la final
  /// 2026); solo se admite si ninguna otra etapa de la temporada usa la
  /// misma ronda, y sus partidos quedan como inferidos.
  final CalendarDay? from;

  /// Último día argentino; `null`: en curso, sin fin conocido.
  final CalendarDay? to;

  /// Los grupos son fechas regulares; las previas y las eliminatorias, de
  /// eliminación.
  StageKind get kind =>
      phase == PhaseKey.groups ? StageKind.regular : StageKind.knockout;

  /// Tiene ventana verificada con datos reales.
  bool get verified => from != null;

  bool contains(CalendarDay day) {
    final first = from;
    final last = to;
    return first != null &&
        !day.isBefore(first) &&
        (last == null || !day.isAfter(last));
  }
}

/// Formato verificado de una temporada de una copa internacional.
final class ContinentalSeason {
  const ContinentalSeason({required this.stages});

  /// En orden cronológico.
  final List<ContinentalStage> stages;
}

/// Copa internacional con fases previas, grupos y eliminatorias (Copa
/// Libertadores, Copa Sudamericana). Los códigos de ronda cambian entre
/// temporadas: sin formato verificado, la temporada no tiene etapas.
final class ContinentalCupRules extends CompetitionRules {
  const ContinentalCupRules({required this.seasons});

  static const phases = [
    PhaseKey.qualifying,
    PhaseKey.groups,
    PhaseKey.knockoutStage,
  ];

  /// Año → formato verificado.
  final Map<int, ContinentalSeason> seasons;

  List<ContinentalStage> stagesOf(Season season) =>
      seasons[season.year]?.stages ?? const [];

  ContinentalStage? stageFor(
    Season season,
    PhaseKey phase,
    int apiRound,
    StageKind kind,
  ) => stagesOf(season)
      .where(
        (s) => s.phase == phase && s.apiRound == apiRound && s.kind == kind,
      )
      .firstOrNull;
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
    // Las series de ida y vuelta llegan con el cuadro (Fase D5).
    ContinentalCupRules() => const [],
  };

  /// Fases que se ofrecen al usuario, en orden.
  List<PhaseKey> get phases => switch (rules) {
    SplitSeasonLeagueRules(:final phases) => phases,
    SingleTableLeagueRules() => const [PhaseKey.regular],
    KnockoutCupRules() => const [PhaseKey.unica],
    ContinentalCupRules() => ContinentalCupRules.phases,
  };

  /// Cantidad mínima de partidos que debería traer una consulta de la ronda
  /// [apiRound] de [season] (para clasificar respuestas incompletas). `null`
  /// si no se sabe.
  int? expectedMinimumMatches(Season season, int apiRound) => switch (rules) {
    final SplitSeasonLeagueRules r =>
      apiRound >= 1 && apiRound <= r.regularRounds ? r.matchesPerRound : null,
    SingleTableLeagueRules(:final matchesPerRound) => matchesPerRound,
    final KnockoutCupRules r => r.roundFor(apiRound)?.matches,
    // Las etapas que comparten la ronda suman (Libertadores 2026, ronda 1:
    // 6 de la Fase 1 y 16 de la Fecha 1).
    final ContinentalCupRules r => switch ([
      for (final s in r.stagesOf(season))
        if (s.apiRound == apiRound) s.expectedMatches,
    ]) {
      [] => null,
      final counts => counts.reduce((a, b) => a + b),
    },
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

  /// Copa Libertadores (V16–V18). Etapas y ventanas (días argentinos) de
  /// los partidos grabados el 14/10/2026 (`docs/evidence/d1_grupos_y_etapas.md`).
  /// Tablas de grupos 2025 y 2026 (Fase D4); sin cuadro hasta la Fase D5;
  /// fuera del Inicio.
  static const copaLibertadores = CompetitionDefinition(
    id: 4501,
    name: 'Copa Libertadores',
    shortName: 'Libertadores',
    category: CompetitionCategory.internationalCup,
    format: CompetitionFormat.cup,
    rules: ContinentalCupRules(
      seasons: {
        2025: ContinentalSeason(
          stages: [
            // Las tres fases previas vienen juntas en la ronda 400.
            ContinentalStage(
              phase: PhaseKey.qualifying,
              label: 'Fases 1, 2 y 3',
              apiRound: 400,
              legs: 2,
              expectedMatches: 30,
              from: CalendarDay(2025, 2, 4),
              to: CalendarDay(2025, 3, 13),
            ),
            ..._groups2025,
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Octavos de final',
              apiRound: 16,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2025, 8, 12),
              to: CalendarDay(2025, 8, 21),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Cuartos de final',
              apiRound: 125,
              legs: 2,
              expectedMatches: 8,
              from: CalendarDay(2025, 9, 16),
              to: CalendarDay(2025, 9, 25),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Semifinales',
              apiRound: 150,
              legs: 2,
              expectedMatches: 4,
              from: CalendarDay(2025, 10, 22),
              to: CalendarDay(2025, 10, 30),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Final',
              apiRound: 200,
              legs: 1,
              expectedMatches: 1,
              from: CalendarDay(2025, 11, 29),
              to: CalendarDay(2025, 11, 29),
            ),
          ],
        ),
        2026: ContinentalSeason(
          stages: [
            // Las previas comparten las rondas 1 a 3 con los grupos: se
            // separan por la ventana.
            ContinentalStage(
              phase: PhaseKey.qualifying,
              label: 'Fase 1',
              apiRound: 1,
              legs: 2,
              expectedMatches: 6,
              from: CalendarDay(2026, 2, 3),
              to: CalendarDay(2026, 2, 12),
            ),
            ContinentalStage(
              phase: PhaseKey.qualifying,
              label: 'Fase 2',
              apiRound: 2,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2026, 2, 17),
              to: CalendarDay(2026, 2, 26),
            ),
            ContinentalStage(
              phase: PhaseKey.qualifying,
              label: 'Fase 3',
              apiRound: 3,
              legs: 2,
              expectedMatches: 8,
              from: CalendarDay(2026, 3, 3),
              to: CalendarDay(2026, 3, 12),
            ),
            ..._groups2026,
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Octavos de final',
              apiRound: 16,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2026, 8, 11),
              to: CalendarDay(2026, 8, 25),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Cuartos de final',
              apiRound: 125,
              legs: 2,
              expectedMatches: 8,
              from: CalendarDay(2026, 9, 8),
              to: CalendarDay(2026, 9, 17),
            ),
            // En curso (14/10/2026).
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Semifinales',
              apiRound: 150,
              legs: 2,
              expectedMatches: 4,
              from: CalendarDay(2026, 10, 14),
            ),
            // Sin datos todavía (Fase D-F).
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Final',
              apiRound: 200,
              legs: 1,
              expectedMatches: 1,
            ),
          ],
        ),
      },
    ),
    standingsBySeason: {
      2025: _libertadores2025Standings,
      2026: _libertadores2026Standings,
    },
    showInHome: false,
    inTeamIndex: false,
  );

  /// Copa Sudamericana (V16–V18), como [copaLibertadores].
  static const copaSudamericana = CompetitionDefinition(
    id: 4724,
    name: 'Copa Sudamericana',
    shortName: 'Sudamericana',
    category: CompetitionCategory.internationalCup,
    format: CompetitionFormat.cup,
    rules: ContinentalCupRules(
      seasons: {
        2025: ContinentalSeason(
          stages: [
            ContinentalStage(
              phase: PhaseKey.qualifying,
              label: 'Primera fase',
              apiRound: 400,
              legs: 1,
              expectedMatches: 16,
              from: CalendarDay(2025, 3, 4),
              to: CalendarDay(2025, 3, 6),
            ),
            ..._groups2025,
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Playoffs de octavos',
              apiRound: 160,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2025, 7, 15),
              to: CalendarDay(2025, 7, 24),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Octavos de final',
              apiRound: 16,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2025, 8, 12),
              to: CalendarDay(2025, 8, 21),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Cuartos de final',
              apiRound: 125,
              legs: 2,
              expectedMatches: 8,
              from: CalendarDay(2025, 9, 16),
              to: CalendarDay(2025, 9, 25),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Semifinales',
              apiRound: 150,
              legs: 2,
              expectedMatches: 4,
              from: CalendarDay(2025, 10, 21),
              to: CalendarDay(2025, 10, 30),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Final',
              apiRound: 200,
              legs: 1,
              expectedMatches: 1,
              from: CalendarDay(2025, 11, 22),
              to: CalendarDay(2025, 11, 22),
            ),
          ],
        ),
        2026: ContinentalSeason(
          stages: [
            // Comparte la ronda 1 con la Fecha 1 de grupos.
            ContinentalStage(
              phase: PhaseKey.qualifying,
              label: 'Primera fase',
              apiRound: 1,
              legs: 1,
              expectedMatches: 16,
              from: CalendarDay(2026, 3, 3),
              to: CalendarDay(2026, 3, 5),
            ),
            ..._groups2026,
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Playoffs de octavos',
              apiRound: 32,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2026, 7, 21),
              to: CalendarDay(2026, 7, 30),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Octavos de final',
              apiRound: 16,
              legs: 2,
              expectedMatches: 16,
              from: CalendarDay(2026, 8, 11),
              to: CalendarDay(2026, 8, 26),
            ),
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Cuartos de final',
              apiRound: 125,
              legs: 2,
              expectedMatches: 8,
              from: CalendarDay(2026, 9, 8),
              to: CalendarDay(2026, 9, 17),
            ),
            // En curso (13/10/2026).
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Semifinales',
              apiRound: 150,
              legs: 2,
              expectedMatches: 4,
              from: CalendarDay(2026, 10, 13),
            ),
            // Sin datos todavía (Fase D-F).
            ContinentalStage(
              phase: PhaseKey.knockoutStage,
              label: 'Final',
              apiRound: 200,
              legs: 1,
              expectedMatches: 1,
            ),
          ],
        ),
      },
    ),
    standingsBySeason: {
      2025: _sudamericana2025Standings,
      2026: _sudamericana2026Standings,
    },
    showInHome: false,
    inTeamIndex: false,
  );

  /// Fechas de grupos de las dos copas (mismos días en las dos). La
  /// ventana es la de toda la fase: la ronda ya dice qué fecha es, y así
  /// no se separan las previas de 2026 por pocos días.
  static const _groupsFrom2025 = CalendarDay(2025, 4, 1);
  static const _groupsTo2025 = CalendarDay(2025, 5, 29);
  static const _groups2025 = [
    ContinentalStage.groupMatchday(1, from: _groupsFrom2025, to: _groupsTo2025),
    ContinentalStage.groupMatchday(2, from: _groupsFrom2025, to: _groupsTo2025),
    ContinentalStage.groupMatchday(3, from: _groupsFrom2025, to: _groupsTo2025),
    ContinentalStage.groupMatchday(4, from: _groupsFrom2025, to: _groupsTo2025),
    ContinentalStage.groupMatchday(5, from: _groupsFrom2025, to: _groupsTo2025),
    ContinentalStage.groupMatchday(6, from: _groupsFrom2025, to: _groupsTo2025),
  ];
  static const _groupsFrom2026 = CalendarDay(2026, 4, 7);
  static const _groupsTo2026 = CalendarDay(2026, 5, 28);
  static const _groups2026 = [
    ContinentalStage.groupMatchday(1, from: _groupsFrom2026, to: _groupsTo2026),
    ContinentalStage.groupMatchday(2, from: _groupsFrom2026, to: _groupsTo2026),
    ContinentalStage.groupMatchday(3, from: _groupsFrom2026, to: _groupsTo2026),
    ContinentalStage.groupMatchday(4, from: _groupsFrom2026, to: _groupsTo2026),
    ContinentalStage.groupMatchday(5, from: _groupsFrom2026, to: _groupsTo2026),
    ContinentalStage.groupMatchday(6, from: _groupsFrom2026, to: _groupsTo2026),
  ];

  /// Grupos (8 de 4, `idTeam`) de las dos copas, deducidos de los partidos
  /// de grupos grabados el 14/10/2026 y cruzados con `strGroup` cuando la
  /// API lo trae (`docs/evidence/d1_grupos_y_etapas.md`). Las previas de
  /// las rondas 1–3 de 2026 no cuentan: las separa la ventana de la etapa.
  static const _libertadores2025Groups = {
    'A': {
      134285, // Botafogo
      137630, // Carabobo
      135160, // Estudiantes de La Plata
      137736, // Universidad de Chile
    },
    'B': {
      138159, // Barcelona SC
      138225, // Independiente del Valle
      135171, // River Plate
      138329, // Universitario
    },
    'C': {
      137603, // Central Córdoba de Santiago del Estero
      137634, // Deportivo Táchira
      134287, // Flamengo
      138227, // LDU Quito
    },
    'D': {
      138311, // Alianza Lima
      138294, // Club Libertad
      134291, // São Paulo
      136674, // Talleres de Córdoba
    },
    'E': {
      137606, // Atlético Bucaramanga
      137724, // Colo-Colo
      136186, // Fortaleza
      135170, // Racing Club
    },
    'F': {
      137607, // Atlético Nacional
      134293, // Bahia
      134281, // Internacional
      135364, // Nacional Montevideo
    },
    'G': {
      138200, // Bolívar
      138290, // Cerro Porteño
      134465, // Palmeiras
      138326, // Sporting Cristal
    },
    'H': {
      138296, // Club Olimpia
      135369, // Peñarol
      148052, // San Antonio Bulo Bulo
      135179, // Vélez Sarsfield
    },
  };
  static const _libertadores2026Groups = {
    'A': {
      138320, // Cusco
      135160, // Estudiantes de La Plata
      134287, // Flamengo
      137613, // Independiente Medellín
    },
    'B': {
      137725, // Coquimbo Unido
      137609, // Deportes Tolima
      135364, // Nacional Montevideo
      138329, // Universitario
    },
    'C': {
      138200, // Bolívar
      137644, // Deportivo La Guaira
      134296, // Fluminense
      137777, // Independiente Rivadavia
    },
    'D': {
      138159, // Barcelona SC
      135156, // Boca Juniors
      134294, // Cruzeiro
      137735, // Universidad Católica
    },
    'E': {
      134284, // Corinthians
      137621, // Independiente Santa Fe
      135369, // Peñarol
      137775, // Platense
    },
    'F': {
      137615, // Atlético Junior
      138290, // Cerro Porteño
      134465, // Palmeiras
      138326, // Sporting Cristal
    },
    'G': {
      138209, // Always Ready
      138227, // LDU Quito
      135165, // Lanús
      141181, // Mirassol
    },
    'H': {
      138294, // Club Libertad
      138225, // Independiente del Valle
      135172, // Rosario Central
      141313, // Universidad Central
    },
  };
  static const _sudamericana2025Groups = {
    'A': {
      136051, // Boston River
      138293, // Club Guaraní
      135164, // Independiente
      138208, // Nacional Potosí
    },
    'B': {
      138817, // Cerro Largo
      135159, // Defensa y Justicia
      138233, // Universidad Católica del Ecuador
      134280, // Vitória
    },
    'C': {
      137604, // América de Cali
      134284, // Corinthians
      135163, // Huracán
      135370, // Racing Montevideo
    },
    'D': {
      138313, // Atlético Grau
      135162, // Godoy Cruz
      134288, // Grêmio
      138300, // Sportivo Luqueño
    },
    'E': {
      134294, // Cruzeiro
      138229, // Mushuc Runa
      137732, // Palestino
      135178, // Unión
    },
    'F': {
      134296, // Fluminense
      148051, // GV San José
      137618, // Once Caldas
      137733, // Unión Española
    },
    'G': {
      137643, // Academia Puerto Cabello
      135165, // Lanús
      138323, // Melgar
      134282, // Vasco da Gama
    },
    'H': {
      134299, // Atlético Mineiro
      137631, // Caracas
      138319, // Cienciano
      137728, // Deportes Iquique
    },
  };
  static const _sudamericana2026Groups = {
    'A': {
      140803, // Alianza Atlético
      137604, // América de Cali
      138228, // Macará
      135177, // Tigre
    },
    'B': {
      137643, // Academia Puerto Cabello
      134299, // Atlético Mineiro
      138319, // Cienciano
      135368, // Juventud Las Piedras
    },
    'C': {
      136051, // Boston River
      137617, // Millonarios
      137731, // O'Higgins
      134291, // São Paulo
    },
    'D': {
      138221, // Deportivo Cuenca
      147065, // Recoleta
      135173, // San Lorenzo
      134286, // Santos
    },
    'E': {
      134285, // Botafogo
      137631, // Caracas
      140718, // Independiente Petrolero
      135170, // Racing Club
    },
    'F': {
      137782, // Deportivo Riestra
      134288, // Grêmio
      138818, // Montevideo City Torque
      137732, // Palestino
    },
    'G': {
      137722, // Audax Italiano
      137771, // Barracas Central
      138296, // Club Olimpia
      134282, // Vasco da Gama
    },
    'H': {
      138203, // Blooming
      134736, // Bragantino
      137630, // Carabobo
      135171, // River Plate
    },
  };

  static const _groupRounds = [1, 2, 3, 4, 5, 6];

  /// Manual de Clubes 2025 (Libertadores 2.4.2, Sudamericana 2.4.3): sin
  /// enfrentamiento directo.
  static const _conmebol2025TieBreak = [
    TieBreakCriterion.goalDifference,
    TieBreakCriterion.goalsFor,
    TieBreakCriterion.awayGoalsFor,
    UnavailableCriterion('Ranking de Clubes de CONMEBOL al 16/12/2024'),
    TieBreakCriterion.drawOfLots,
  ];

  /// Manual de Clubes 2026 (Libertadores 2.4.2, Sudamericana 2.4.3): los
  /// partidos entre los empatados una sola vez («una vez aplicado un
  /// criterio, no se regresará a los anteriores»); después, diferencia de
  /// gol y goles a favor de toda la fase.
  static const _conmebol2026TieBreak = [
    TieBreakCriterion.headToHeadOnce,
    TieBreakCriterion.goalDifference,
    TieBreakCriterion.goalsFor,
    UnavailableCriterion('menos tarjetas rojas'),
    UnavailableCriterion('menos tarjetas amarillas'),
    TieBreakCriterion.drawOfLots,
  ];

  /// Formato de cada copa según su Manual de Clubes
  /// (`docs/evidence/d1_reglamentos_conmebol.txt`).
  static const _libertadoresQualification =
      'Los dos primeros de cada grupo pasan a octavos de final y el tercero, '
      'a los playoffs de octavos de la Copa Sudamericana.';
  static const _sudamericanaQualification =
      'El primero de cada grupo pasa a octavos de final y el segundo, a los '
      'playoffs de octavos (contra los terceros de la Copa Libertadores).';

  static const _libertadores2025Standings = GroupStage(
    groups: _libertadores2025Groups,
    regularRounds: _groupRounds,
    tieBreak: _conmebol2025TieBreak,
    pointsArticle: '2.4.1',
    tieBreakArticle: '2.4.2',
    qualificationNote: _libertadoresQualification,
    regulation: RegulationSource(
      name: 'Manual de Clubes CONMEBOL Libertadores 2025',
      url:
          'https://cdn.conmebol.com/wp-content/uploads/2024/12/Manual-de-Clubes-CL-2025-ESP-Digital.pdf',
    ),
  );
  static const _libertadores2026Standings = GroupStage(
    groups: _libertadores2026Groups,
    regularRounds: _groupRounds,
    tieBreak: _conmebol2026TieBreak,
    pointsArticle: '2.4.1',
    tieBreakArticle: '2.4.2',
    qualificationNote: _libertadoresQualification,
    regulation: RegulationSource(
      name: 'Manual de Clubes CONMEBOL Libertadores 2026',
      url:
          'https://cdn.conmebol.com/wp-content/uploads/2025/12/CL-2026-Manual-de-Clubes-ESP-Jun.pdf',
    ),
  );
  static const _sudamericana2025Standings = GroupStage(
    groups: _sudamericana2025Groups,
    regularRounds: _groupRounds,
    tieBreak: _conmebol2025TieBreak,
    pointsArticle: '2.4.1',
    tieBreakArticle: '2.4.3',
    qualificationNote: _sudamericanaQualification,
    regulation: RegulationSource(
      name: 'Manual de Clubes CONMEBOL Sudamericana 2025',
      url:
          'https://cdn.conmebol.com/wp-content/uploads/2024/12/Manual-de-Clubes-CS-2025-ESP-Digital.pdf',
    ),
  );
  static const _sudamericana2026Standings = GroupStage(
    groups: _sudamericana2026Groups,
    regularRounds: _groupRounds,
    tieBreak: _conmebol2026TieBreak,
    pointsArticle: '2.4.1',
    tieBreakArticle: '2.4.3',
    qualificationNote: _sudamericanaQualification,
    regulation: RegulationSource(
      name: 'Manual de Clubes CONMEBOL Sudamericana 2026',
      url:
          'https://cdn.conmebol.com/wp-content/uploads/2025/12/CS-2026-Manual-de-Clubes-ESP-Jun.pdf',
    ),
  );

  /// Torneo Federal A (5523) no entra: mezcla etapas en la numeración de
  /// rondas (V8) y necesita un relevamiento propio.
  static const all = [
    primeraDivision,
    primeraNacional,
    copaArgentina,
    primeraBMetropolitana,
    primeraC,
    copaLibertadores,
    copaSudamericana,
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
