import '../../../matches/domain/entities/match.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/phase_assignment.dart';
import '../entities/season.dart';

/// Asigna fase y tipo de etapa a los partidos de una ronda (D6).
///
/// Nunca fuerza una asignación: sin evidencia suficiente el partido queda
/// `undetermined` y no se muestra ni en Apertura ni en Clausura.
final class PhaseResolver {
  const PhaseResolver(this.definition);

  final CompetitionDefinition definition;

  /// Clasifica **todos** los partidos de una ronda de la API (misma
  /// competición, temporada y `apiRound`): la inferencia y el control de
  /// consistencia necesitan la ronda completa.
  Map<int, PhaseAssignment> classifyRound({
    required Season season,
    required int apiRound,
    required List<Match> matches,
  }) {
    final assigned = switch (definition.rules) {
      final SplitSeasonLeagueRules rules => _splitSeason(
        rules,
        season,
        apiRound,
        matches,
      ),
      final SingleTableLeagueRules rules => {
        for (final m in matches) m.id: _singleTable(rules, season, apiRound),
      },
      final KnockoutCupRules rules => {
        for (final m in matches)
          m.id: PhaseAssignment(
            phase: PhaseKey.unica,
            stageKind: StageKind.knockout,
            source: rules.roundFor(apiRound) != null
                ? PhaseSource.catalog
                : PhaseSource.inferred,
          ),
      },
      final ContinentalCupRules rules => {
        for (final m in matches) m.id: _continental(rules, season, apiRound, m),
      },
    };
    if (definition.rules is KnockoutCupRules) return assigned;
    return _enforceOneMatchPerTeam(matches, assigned);
  }

  Map<int, PhaseAssignment> _splitSeason(
    SplitSeasonLeagueRules rules,
    Season season,
    int apiRound,
    List<Match> matches,
  ) {
    final windows = rules.windowsBySeason[season.year];
    if (windows == null) return _inferSplitSeason(rules, apiRound, matches);

    PhaseAssignment classify(Match m) {
      final day = m.kickoff.argentinaDay;
      if (day == null) return const PhaseAssignment.undetermined();
      final inSpan = windows.where((w) => w.containsInSpan(day)).toList();
      if (inSpan.length != 1) return const PhaseAssignment.undetermined();
      final window = inSpan.single;

      PhaseAssignment kind(StageKind stageKind) => PhaseAssignment(
        phase: window.phase,
        stageKind: stageKind,
        source: PhaseSource.catalog,
      );

      if (apiRound == rules.knockoutRound) {
        return window.containsInKnockout(day)
            ? kind(StageKind.knockout)
            : const PhaseAssignment.undetermined();
      }
      if (apiRound == rules.knockoutOpeningRound &&
          window.containsInKnockout(day)) {
        return kind(StageKind.knockout);
      }
      if (apiRound >= 1 &&
          apiRound <= rules.regularRounds &&
          window.containsInRegular(day)) {
        return kind(StageKind.regular);
      }
      return const PhaseAssignment.undetermined();
    }

    return {for (final m in matches) m.id: classify(m)};
  }

  /// Sin catálogo: solo fechas regulares con exactamente dos grupos de días
  /// separados por al menos `inferenceMinGapDays`, cada uno con no más
  /// partidos que una fecha completa.
  Map<int, PhaseAssignment> _inferSplitSeason(
    SplitSeasonLeagueRules rules,
    int apiRound,
    List<Match> matches,
  ) {
    const undetermined = PhaseAssignment.undetermined();
    final result = {for (final m in matches) m.id: undetermined};
    final isRegularRound = apiRound >= 1 && apiRound <= rules.regularRounds;
    if (!isRegularRound || rules.phases.length != 2) return result;
    if (matches.any((m) => m.kickoff.argentinaDay == null)) return result;

    final sorted = [...matches]
      ..sort(
        (a, b) => a.kickoff.argentinaDay!.compareTo(b.kickoff.argentinaDay!),
      );
    final groups = <List<Match>>[
      [sorted.first],
    ];
    for (final m in sorted.skip(1)) {
      final previousDay = groups.last.last.kickoff.argentinaDay!;
      final gap = m.kickoff.argentinaDay!.differenceInDays(previousDay);
      if (gap >= rules.inferenceMinGapDays) {
        groups.add([m]);
      } else {
        groups.last.add(m);
      }
    }
    if (groups.length != 2 ||
        groups.any((g) => g.length > rules.matchesPerRound)) {
      return result;
    }

    for (final (index, group) in groups.indexed) {
      for (final m in group) {
        result[m.id] = PhaseAssignment(
          phase: rules.phases[index],
          stageKind: StageKind.regular,
          source: PhaseSource.inferred,
        );
      }
    }
    return result;
  }

  /// La etapa de [season] con esa ronda cuya ventana contiene el día del
  /// partido. Ninguna o más de una: `undetermined`. Una etapa sin ventana
  /// (sin datos todavía) solo toma la ronda si es la única que la usa.
  PhaseAssignment _continental(
    ContinentalCupRules rules,
    Season season,
    int apiRound,
    Match m,
  ) {
    final candidates = [
      for (final s in rules.stagesOf(season))
        if (s.apiRound == apiRound) s,
    ];
    if (candidates case [final only] when !only.verified) {
      return PhaseAssignment(
        phase: only.phase,
        stageKind: only.kind,
        source: PhaseSource.inferred,
      );
    }
    final day = m.kickoff.argentinaDay;
    if (day == null) return const PhaseAssignment.undetermined();
    final matching = candidates.where((s) => s.contains(day)).toList();
    if (matching case [final stage]) {
      return PhaseAssignment(
        phase: stage.phase,
        stageKind: stage.kind,
        source: PhaseSource.catalog,
      );
    }
    return const PhaseAssignment.undetermined();
  }

  PhaseAssignment _singleTable(
    SingleTableLeagueRules rules,
    Season season,
    int apiRound,
  ) {
    final known = rules.regularRoundsBySeason[season.year];
    if (apiRound < 1 || (known != null && apiRound > known)) {
      return const PhaseAssignment.undetermined();
    }
    return PhaseAssignment(
      phase: PhaseKey.regular,
      stageKind: StageKind.regular,
      source: known != null ? PhaseSource.catalog : PhaseSource.inferred,
    );
  }

  /// En una fecha regular cada equipo juega una sola vez. Si un equipo
  /// aparece dos veces en la misma fase, no se puede saber cuál partido
  /// corresponde: ambos quedan `undetermined`.
  Map<int, PhaseAssignment> _enforceOneMatchPerTeam(
    List<Match> matches,
    Map<int, PhaseAssignment> assigned,
  ) {
    final appearances = <(PhaseKey, int), List<int>>{};
    for (final m in matches) {
      final a = assigned[m.id]!;
      if (!a.isDetermined || a.stageKind != StageKind.regular) continue;
      for (final team in [m.home.id, m.away.id]) {
        (appearances[(a.phase, team)] ??= []).add(m.id);
      }
    }
    final result = Map.of(assigned);
    for (final ids in appearances.values) {
      if (ids.length > 1) {
        for (final id in ids) {
          result[id] = const PhaseAssignment.undetermined();
        }
      }
    }
    return result;
  }
}
