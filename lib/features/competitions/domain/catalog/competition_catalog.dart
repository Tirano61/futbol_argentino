import '../../../../core/time/calendar_day.dart';
import '../entities/competition.dart';
import '../entities/phase.dart';
import '../entities/season.dart';

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

/// Competición soportada por la app y sus reglas.
final class CompetitionDefinition {
  const CompetitionDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.format,
    required this.rules,
  });

  final int id;
  final String name;
  final String shortName;
  final CompetitionFormat format;
  final CompetitionRules rules;

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
    format: CompetitionFormat.league,
    rules: SplitSeasonLeagueRules(
      phases: [PhaseKey.apertura, PhaseKey.clausura],
      regularRounds: 16,
      matchesPerRound: 15,
      knockoutRound: 0,
      knockoutOpeningRound: 16,
      knockoutOpeningLabel: 'Octavos de final',
      knockoutLabel: 'Cuartos, semifinales y final',
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
  );

  static const primeraNacional = CompetitionDefinition(
    id: 4616,
    name: 'Primera Nacional',
    shortName: 'Nacional',
    format: CompetitionFormat.league,
    rules: SingleTableLeagueRules(
      matchesPerRound: 18,
      regularRoundsBySeason: {2026: 36},
    ),
  );

  static const copaArgentina = CompetitionDefinition(
    id: 4500,
    name: 'Copa Argentina',
    shortName: 'Copa',
    format: CompetitionFormat.cup,
    rules: KnockoutCupRules(
      rounds: [
        CupRound(code: 64, label: '32avos de final', matches: 32),
        CupRound(code: 32, label: '16avos de final', matches: 16),
        CupRound(code: 16, label: 'Octavos de final', matches: 8),
        CupRound(code: 125, label: 'Cuartos de final', matches: 4),
        CupRound(code: 150, label: 'Semifinales', matches: 2),
        CupRound(code: 200, label: 'Final', matches: 1, verified: false),
      ],
    ),
  );

  static const all = [primeraDivision, primeraNacional, copaArgentina];

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
