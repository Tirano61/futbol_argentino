import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/match_status.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../services/phase_resolver.dart';
import 'standings_table.dart';
import 'team_stats.dart';

/// Partidos de la fase regular de una temporada, por torneo, con la fase
/// resuelta por [PhaseResolver] ronda por ronda. Cada partido una sola vez
/// (por `idEvent`).
final class RegularSeasonMatches {
  const RegularSeasonMatches._({
    required this.byTournament,
    required this.undetermined,
    required Map<int, TeamRef> teams,
  }) : _teams = teams;

  /// [rounds]: rondas de la API de la fase regular. Los partidos de otras
  /// rondas, de eliminatorias (octavos en la ronda 16) o de otro torneo se
  /// ignoran; los sin fase determinada quedan en [undetermined].
  factory RegularSeasonMatches.classify({
    required CompetitionDefinition definition,
    required Season season,
    required Iterable<Match> matches,
    required List<int> rounds,
    required Iterable<PhaseKey> tournaments,
  }) {
    final unique = MatchGrouping.dedupe(
      matches.where((m) => m.season == season.apiValue),
    );
    final byTournament = {for (final t in tournaments) t: <Match>[]};
    final undetermined = <Match>[];
    final resolver = PhaseResolver(definition);
    for (final round in rounds.toSet()) {
      final inRound = [
        for (final m in unique)
          if (m.apiRound == round) m,
      ];
      if (inRound.isEmpty) continue;
      final assigned = resolver.classifyRound(
        season: season,
        apiRound: round,
        matches: inRound,
      );
      for (final m in inRound) {
        final a = assigned[m.id]!;
        if (!a.isDetermined) {
          undetermined.add(m);
        } else if (a.stageKind == StageKind.regular) {
          byTournament[a.phase]?.add(m);
        }
      }
    }

    final teams = <int, (TeamRef, DateTime)>{};
    for (final m in unique) {
      for (final t in [m.home, m.away]) {
        final known = teams[t.id];
        if (known == null || m.lastSeenAt.isAfter(known.$2)) {
          teams[t.id] = (t, m.lastSeenAt);
        }
      }
    }
    return RegularSeasonMatches._(
      byTournament: byTournament,
      undetermined: undetermined,
      teams: {for (final e in teams.entries) e.key: e.value.$1},
    );
  }

  /// Torneo → partidos regulares (jugados o no).
  final Map<PhaseKey, List<Match>> byTournament;

  /// Partidos de las rondas regulares que no se pudieron ubicar: excluidos.
  final List<Match> undetermined;
  final Map<int, TeamRef> _teams;

  Iterable<Match> get all => byTournament.values.expand((l) => l);

  /// Nombre y escudo del partido visto más recientemente.
  TeamRef team(int id) => _teams[id] ?? TeamRef(id: id, name: 'Equipo $id');

  /// Por qué [m] no se suma; `null` si se suma.
  static UncountedReason? reasonFor(Match m) {
    if (StatsAccumulator.counts(m)) return null;
    return switch (m.status.kind) {
      MatchStatusKind.finished => UncountedReason.noResult,
      MatchStatusKind.live ||
      MatchStatusKind.halfTime => UncountedReason.inPlay,
      MatchStatusKind.postponed => UncountedReason.postponed,
      MatchStatusKind.suspended ||
      MatchStatusKind.abandoned => UncountedReason.suspended,
      MatchStatusKind.cancelled => UncountedReason.cancelled,
      MatchStatusKind.scheduled ||
      MatchStatusKind.unknown => UncountedReason.notPlayed,
    };
  }

  /// Cobertura de una tabla cuyo alcance son [scope] (más los sin fase
  /// determinada en los que juega alguno de [teamIds]).
  StandingsCoverage coverage({
    required Iterable<Match> scope,
    required int roundsQueried,
    required int roundsTotal,
    Set<int>? teamIds,
  }) {
    final inScope = scope.toList();
    final uncounted = [
      for (final m in inScope)
        if (reasonFor(m) case final reason?)
          UncountedMatch(match: m, reason: reason),
      for (final m in undetermined)
        if (teamIds == null ||
            teamIds.contains(m.home.id) ||
            teamIds.contains(m.away.id))
          UncountedMatch(match: m, reason: UncountedReason.undetermined),
    ]..sort((a, b) => MatchGrouping.compare(a.match, b.match));
    return StandingsCoverage(
      roundsQueried: roundsQueried,
      roundsTotal: roundsTotal,
      counted: inScope.where(StatsAccumulator.counts).length,
      scheduled: inScope.length,
      uncounted: uncounted,
    );
  }
}
