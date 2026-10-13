import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/match.dart';
import 'team_stats.dart';

/// Criterio de desempate, en el orden que fija el reglamento. Siempre se
/// aplica después de los puntos.
sealed class TieBreakCriterion {
  const TieBreakCriterion();

  static const goalDifference = GoalDifferenceCriterion();
  static const goalsFor = GoalsForCriterion();
  static const headToHead = HeadToHeadCriterion();
  static const fairPlay = FairPlayCriterion();
  static const drawOfLots = DrawOfLotsCriterion();

  /// La app lo puede calcular con los datos de la API.
  bool get isComputable => true;

  String get label;
}

final class GoalDifferenceCriterion extends TieBreakCriterion {
  const GoalDifferenceCriterion();

  @override
  String get label => 'diferencia de gol';
}

final class GoalsForCriterion extends TieBreakCriterion {
  const GoalsForCriterion();

  @override
  String get label => 'goles a favor';
}

/// Partidos entre los empatados: puntos, después diferencia de gol, después
/// goles a favor; se repite con los que sigan empatados.
final class HeadToHeadCriterion extends TieBreakCriterion {
  const HeadToHeadCriterion();

  @override
  String get label => 'partidos entre los empatados';
}

/// La API no informa tarjetas: no se puede calcular.
final class FairPlayCriterion extends TieBreakCriterion {
  const FairPlayCriterion();

  @override
  bool get isComputable => false;

  @override
  String get label => 'Fair Play';
}

final class DrawOfLotsCriterion extends TieBreakCriterion {
  const DrawOfLotsCriterion();

  @override
  bool get isComputable => false;

  @override
  String get label => 'sorteo';
}

/// Fila ordenada de una tabla.
final class StandingsRow extends Equatable {
  const StandingsRow({
    required this.position,
    required this.stats,
    this.isShared = false,
  });

  /// Los que comparten posición tienen el mismo número (3, 3, 5…).
  final int position;
  final TeamStats stats;

  /// Siguen empatados al llegar a un criterio que la app no puede calcular
  /// (Fair Play, sorteo) o sin más criterios.
  final bool isShared;

  @override
  List<Object?> get props => [position, stats, isShared];
}

/// Ordena por puntos y después por [criteria], en orden.
final class TieBreaker {
  const TieBreaker(this.criteria);

  final List<TieBreakCriterion> criteria;

  /// [matches]: partidos que cuentan para la tabla (para el enfrentamiento
  /// directo; solo se usan los jugados entre los empatados).
  List<StandingsRow> rank(
    Iterable<TeamStats> teams, {
    Iterable<Match> matches = const [],
  }) {
    final counted = [
      for (final m in matches)
        if (StatsAccumulator.counts(m)) m,
    ];
    final blocks = <List<TeamStats>>[];
    for (final group in _splitBy(teams.toList(), (s) => [s.points])) {
      blocks.addAll(_resolve(group, criteria, counted));
    }

    final rows = <StandingsRow>[];
    var position = 1;
    for (final block in blocks) {
      final shared = block.length > 1;
      final ordered = shared
          ? ([...block]..sort((a, b) => a.team.name.compareTo(b.team.name)))
          : block;
      for (final stats in ordered) {
        rows.add(
          StandingsRow(position: position, stats: stats, isShared: shared),
        );
      }
      position += block.length;
    }
    return rows;
  }

  /// Bloques en orden; uno con más de un equipo sigue empatado.
  List<List<TeamStats>> _resolve(
    List<TeamStats> group,
    List<TieBreakCriterion> criteria,
    List<Match> matches,
  ) {
    if (group.length < 2 || criteria.isEmpty) return [group];
    final rest = criteria.sublist(1);
    switch (criteria.first) {
      case GoalDifferenceCriterion():
        return [
          for (final g in _splitBy(group, (s) => [s.goalDifference]))
            ..._resolve(g, rest, matches),
        ];
      case GoalsForCriterion():
        return [
          for (final g in _splitBy(group, (s) => [s.goalsFor]))
            ..._resolve(g, rest, matches),
        ];
      case HeadToHeadCriterion():
        return _headToHead(group, rest, matches);
      case FairPlayCriterion() || DrawOfLotsCriterion():
        return [group];
    }
  }

  List<List<TeamStats>> _headToHead(
    List<TeamStats> group,
    List<TieBreakCriterion> rest,
    List<Match> matches,
  ) {
    final ids = {for (final s in group) s.team.id};
    final mini = StatsAccumulator([for (final s in group) s.team])
      ..addAll(
        matches.where(
          (m) => ids.contains(m.home.id) && ids.contains(m.away.id),
        ),
      );
    final blocks = _splitBy(group, (s) {
      final h = mini[s.team.id]!;
      return [h.points, h.goalDifference, h.goalsFor];
    });
    // No separa a nadie: sigue el criterio siguiente.
    if (blocks.length == 1) return _resolve(group, rest, matches);
    return [
      for (final b in blocks)
        // Se repite con los que siguen empatados (grupo más chico).
        ...(b.length > 1 ? _headToHead(b, rest, matches) : [b]),
    ];
  }

  /// Agrupa por [key] (lista comparada en orden), de mayor a menor.
  static List<List<TeamStats>> _splitBy(
    List<TeamStats> group,
    List<int> Function(TeamStats) key,
  ) {
    int compare(List<int> a, List<int> b) {
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return b[i] - a[i];
      }
      return 0;
    }

    final sorted = [...group]..sort((a, b) => compare(key(a), key(b)));
    final blocks = <List<TeamStats>>[];
    for (final s in sorted) {
      if (blocks.isNotEmpty && compare(key(blocks.last.first), key(s)) == 0) {
        blocks.last.add(s);
      } else {
        blocks.add([s]);
      }
    }
    return blocks;
  }
}
