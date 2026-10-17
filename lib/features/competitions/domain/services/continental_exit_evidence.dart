import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../matches/domain/services/tie_outcome.dart';
import '../../../matches/domain/services/tie_pairing.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../standings/regular_season_matches.dart';
import '../standings/table_builders.dart';
import '../standings/zone_validator.dart';
import 'phase_resolver.dart';

/// Etapa de una copa internacional de cada partido.
abstract final class ContinentalStageIndex {
  /// `idEvent` → posición de su etapa en `stagesOf(season)` (orden
  /// cronológico). Los partidos sin etapa determinada no aparecen.
  ///
  /// Se clasifica ronda por ronda con [PhaseResolver], como en el fixture:
  /// [matches] tienen que ser rondas completas para el control de un
  /// partido por equipo en las fechas de grupos.
  static Map<int, int> of(
    CompetitionDefinition definition,
    Season season,
    Iterable<Match> matches,
  ) {
    final rules = definition.rules;
    if (rules is! ContinentalCupRules) return const {};
    final stages = rules.stagesOf(season);
    final byRound = <int, List<Match>>{};
    for (final m in MatchGrouping.dedupe(matches)) {
      if (m.competitionId != definition.id || m.season != season.apiValue) {
        continue;
      }
      (byRound[m.apiRound] ??= []).add(m);
    }
    final resolver = PhaseResolver(definition);
    final result = <int, int>{};
    for (final MapEntry(key: round, value: inRound) in byRound.entries) {
      final assigned = resolver.classifyRound(
        season: season,
        apiRound: round,
        matches: inRound,
      );
      for (final m in inRound) {
        final a = assigned[m.id]!;
        if (!a.isDetermined) continue;
        final index = stages.indexWhere(
          (s) =>
              s.apiRound == round &&
              s.phase == a.phase &&
              s.kind == a.stageKind,
        );
        if (index >= 0) result[m.id] = index;
      }
    }
    return result;
  }
}

/// Por qué un equipo ya no tiene partidos en una copa internacional.
enum ContinentalExitReason {
  /// Perdió una llave de previas o de eliminatorias ([TieOutcome.ofTie]).
  tieLost,

  /// Terminó la fase de grupos debajo de los puestos que siguen en alguna
  /// copa, sin posición compartida.
  groupStage,

  /// La final de la temporada ya se jugó.
  competitionFinished,
}

/// Última etapa de una copa en la que un equipo tiene partidos: en las
/// posteriores ya no juega.
final class ContinentalExit extends Equatable {
  const ContinentalExit({required this.stageIndex, required this.reason});

  /// Posición de la etapa en `stagesOf(season)`.
  final int stageIndex;
  final ContinentalExitReason reason;

  @override
  List<Object?> get props => [stageIndex, reason];
}

/// Evidencia, con los partidos guardados y sin red, de que un equipo ya no
/// tiene partidos en una copa internacional (corte de la ficha de equipo,
/// Fase D6). Nunca se deduce de una ausencia: que el equipo no aparezca en
/// una ronda no prueba nada (clasificación directa a octavos, ingreso desde
/// otra copa, semanas sin partidos).
///
/// En orden de etapas, la primera evidencia:
/// 1. **Llave perdida**: una llave completa de previas o de eliminatorias
///    en la que [TieOutcome.ofTie] da ganador al rival.
/// 2. **Eliminado en grupos**: el grupo es válido ([ZoneValidator]), se
///    jugaron todos sus partidos y el mejor puesto posible del equipo
///    (compartido incluido) queda debajo de `GroupStage.advancingPlaces`.
/// 3. **Copa terminada**: la final de la temporada terminó.
abstract final class ContinentalExitEvidence {
  /// [matches]: los partidos guardados de la copa en [season], rondas
  /// completas (otras competiciones o temporadas se ignoran).
  static ContinentalExit? of({
    required CompetitionDefinition definition,
    required Season season,
    required int teamId,
    required Iterable<Match> matches,
  }) {
    final rules = definition.rules;
    if (rules is! ContinentalCupRules) return null;
    final stages = rules.stagesOf(season);
    if (stages.isEmpty) return null;
    final unique = MatchGrouping.dedupe(
      matches.where(
        (m) => m.competitionId == definition.id && m.season == season.apiValue,
      ),
    );
    final stageOf = ContinentalStageIndex.of(definition, season, unique);
    List<Match> inStage(int index) => [
      for (final m in unique)
        if (stageOf[m.id] == index) m,
    ];

    final lastGroupStage = stages.lastIndexWhere(
      (s) => s.phase == PhaseKey.groups,
    );
    for (final (index, stage) in stages.indexed) {
      if (stage.kind == StageKind.knockout &&
          _lostTie(inStage(index), stage.legs, teamId, unique)) {
        return ContinentalExit(
          stageIndex: index,
          reason: ContinentalExitReason.tieLost,
        );
      }
      if (index == lastGroupStage &&
          _outInGroups(definition, season, teamId, unique)) {
        return ContinentalExit(
          stageIndex: index,
          reason: ContinentalExitReason.groupStage,
        );
      }
    }

    final finalIndex = stages.length - 1;
    if (stages[finalIndex].phase == PhaseKey.knockoutStage &&
        inStage(finalIndex).any((m) => m.status.isFinished)) {
      return ContinentalExit(
        stageIndex: finalIndex,
        reason: ContinentalExitReason.competitionFinished,
      );
    }
    return null;
  }

  /// Alguna llave del equipo en la etapa está completa y la ganó el rival
  /// (la ronda 400 de la Libertadores 2025 trae tres fases: puede haber
  /// más de una llave del mismo equipo).
  static bool _lostTie(
    List<Match> stageMatches,
    int legs,
    int teamId,
    List<Match> seasonMatches,
  ) {
    for (final tie in TiePairing.pair(stageMatches, legs: legs).ties) {
      if (!tie.involvesTeam(teamId) || !tie.isComplete) continue;
      final outcome = TieOutcome.ofTie(
        tie,
        laterMatches: seasonMatches.where(tie.isBefore),
      );
      if (outcome != null && outcome.winner.id != teamId) return true;
    }
    return false;
  }

  static bool _outInGroups(
    CompetitionDefinition definition,
    Season season,
    int teamId,
    List<Match> seasonMatches,
  ) {
    final format = definition.standingsFor(season);
    if (format is! GroupStage) return false;
    final places = format.advancingPlaces;
    if (places == null) return false;
    final group = format.groups.entries
        .where((e) => e.value.contains(teamId))
        .firstOrNull;
    if (group == null) return false;

    final classified = RegularSeasonMatches.classify(
      definition: definition,
      season: season,
      matches: seasonMatches,
      rounds: format.regularRounds,
      tournaments: const [PhaseKey.groups],
    );
    if (ZoneValidator.validate(
      format,
      classified,
    ).invalidZones.contains(group.key)) {
      return false;
    }
    final table = GroupTableBuilder.build(
      format: format,
      season: season,
      group: group.key,
      matches: classified,
      roundsQueried: format.regularRounds.length,
    );
    // Todos contra todos a ida y vuelta: cada equipo juega una vez por
    // fecha.
    final expected = group.value.length * format.regularRounds.length ~/ 2;
    final coverage = table.coverage;
    if (coverage.scheduled != expected ||
        coverage.counted != expected ||
        coverage.uncounted.isNotEmpty) {
      return false;
    }
    final row = table.rows.where((r) => r.stats.team.id == teamId).firstOrNull;
    // Compartido: el mejor puesto posible es el número que muestra la tabla.
    return row != null && row.position > places;
  }
}
